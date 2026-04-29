/*
 * firmware/eml_optimizer.c
 * EML DAG optimizer with profiling and runtime adaptation
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// EML-specific includes
#include "eml_unit.h"
#include "eml_cache.h"
#include "profiler.h"

// EML optimizer configuration
typedef struct {
    uint32_t *tree_ptr;
    uint32_t max_depth;
    uint8_t cache_policy;  // 0=LRU, 1=FIFO, 2=Random
    uint32_t hit_count;
    uint32_t miss_count;
    uint32_t compile_count;
} eml_opt_config_t;

// Profiling data structure
typedef struct {
    uint32_t expr_hash;
    uint32_t execution_count;
    uint32_t avg_cycles;
    uint32_t hit_rate;      // Percentage of cache hits
    bool is_hot_path;       // Marked as frequently executed
} eml_profile_entry_t;

#define EML_PROFILE_SIZE 256
#define EML_HOT_THRESHOLD 100  // executions to mark as hot

static eml_profile_entry_t profile_table[EML_PROFILE_SIZE];
static uint8_t profile_usage[EML_PROFILE_SIZE / 8];  // Bit vector for usage
static bool profiling_enabled = true;

// Function prototypes
uint32_t eml_hash_expr(uint32_t *expr_tree, uint32_t depth);
uint32_t eml_precompile(uint32_t *tree_ptr, uint32_t max_depth, uint8_t cache_policy);
void eml_profile_record(uint32_t hash, uint32_t cycles, bool cache_hit);
bool eml_is_hot_path(uint32_t hash);
void eml_recompile_hot_paths(void);

/**
 * Precompile an EML expression tree with optimization
 * @param tree_ptr Pointer to the expression tree
 * @param max_depth Maximum depth to consider for optimization
 * @param cache_policy Caching policy to use
 * @return Compiled expression ID or 0 on failure
 */
uint32_t eml_precompile(uint32_t *tree_ptr, uint32_t max_depth, uint8_t cache_policy) {
    if (!tree_ptr) return 0;

    // Create configuration
    eml_opt_config_t config;
    config.tree_ptr = tree_ptr;
    config.max_depth = max_depth;
    config.cache_policy = cache_policy;
    config.hit_count = 0;
    config.miss_count = 0;
    config.compile_count = 0;

    // Calculate hash for the expression tree
    uint32_t expr_hash = eml_hash_expr(tree_ptr, max_depth);

    // Check if already optimized
    for (int i = 0; i < EML_PROFILE_SIZE; i++) {
        if (profile_table[i].expr_hash == expr_hash) {
            // Already in profile, update stats
            profile_table[i].execution_count++;
            return expr_hash;  // Return existing ID
        }
    }

    // Find empty slot in profile table
    int slot = -1;
    for (int i = 0; i < EML_PROFILE_SIZE; i++) {
        if (!(profile_usage[i / 8] & (1 << (i % 8)))) {
            slot = i;
            break;
        }
    }

    if (slot == -1) {
        // Profile table full, try to evict a cold entry
        slot = eml_find_cold_slot();
        if (slot == -1) return 0; // No space available
    }

    // Initialize profile entry
    profile_table[slot] = (eml_profile_entry_t){
        .expr_hash = expr_hash,
        .execution_count = 1,
        .avg_cycles = 0,
        .hit_rate = 0,
        .is_hot_path = false
    };

    // Mark slot as used
    profile_usage[slot / 8] |= (1 << (slot % 8));

    // Perform DAG optimization and CSE
    if (eml_perform_optimization(&config)) {
        config.compile_count++;

        // Set DAG mode in CSR
        uint32_t csr_val = eml_get_csr(0x7C0);  // EML_CFG
        csr_val |= (1 << 5);  // Set DAG_MODE bit
        eml_set_csr(0x7C0, csr_val);

        return expr_hash;
    }

    return 0;
}

/**
 * Calculate hash for an expression tree
 */
uint32_t eml_hash_expr(uint32_t *expr_tree, uint32_t max_depth) {
    if (!expr_tree || max_depth == 0) return 0;

    uint32_t hash = 5381;  // DJB2 initial value

    // Hash the expression structure and values
    for (uint32_t i = 0; i < max_depth && expr_tree[i] != 0; i++) {
        // Update hash using polynomial rolling hash
        hash = ((hash << 5) + hash) + expr_tree[i];
    }

    // Compress to 8-bit tag as per RTL spec (XOR folding)
    uint8_t compressed = (hash & 0xFF) ^
                        ((hash >> 8) & 0xFF) ^
                        ((hash >> 16) & 0xFF) ^
                        ((hash >> 24) & 0xFF);

    return (uint32_t)compressed;
}

/**
 * Record execution profile data
 */
void eml_profile_record(uint32_t hash, uint32_t cycles, bool cache_hit) {
    if (!profiling_enabled) return;

    // Find corresponding profile entry
    for (int i = 0; i < EML_PROFILE_SIZE; i++) {
        if (profile_table[i].expr_hash == hash) {
            profile_table[i].avg_cycles =
                (profile_table[i].avg_cycles + cycles) / 2;  // Moving average

            if (cache_hit) {
                profile_table[i].hit_rate += 5;  // Increment hit rate
                if (profile_table[i].hit_rate > 100) profile_table[i].hit_rate = 100;
            } else {
                if (profile_table[i].hit_rate > 5) profile_table[i].hit_rate -= 5;
            }

            // Check if this is becoming a hot path
            if (profile_table[i].execution_count > EML_HOT_THRESHOLD &&
                profile_table[i].hit_rate > 80) {
                profile_table[i].is_hot_path = true;
            }

            break;
        }
    }
}

/**
 * Check if expression is in a hot execution path
 */
bool eml_is_hot_path(uint32_t hash) {
    for (int i = 0; i < EML_PROFILE_SIZE; i++) {
        if (profile_table[i].expr_hash == hash) {
            return profile_table[i].is_hot_path;
        }
    }
    return false;
}

/**
 * Recompile hot paths based on profile data
 */
void eml_recompile_hot_paths(void) {
    for (int i = 0; i < EML_PROFILE_SIZE; i++) {
        if (profile_table[i].is_hot_path) {
            // Attempt to recompile with aggressive optimization
            eml_aggressive_optimization(profile_table[i].expr_hash);
        }
    }
}

/**
 * Find a cold slot for profile table eviction
 */
int eml_find_cold_slot(void) {
    uint32_t min_exec_count = UINT32_MAX;
    int coldest_slot = -1;

    for (int i = 0; i < EML_PROFILE_SIZE; i++) {
        if (profile_usage[i / 8] & (1 << (i % 8))) {  // Slot is used
            if (!profile_table[i].is_hot_path &&
                profile_table[i].execution_count < min_exec_count) {
                min_exec_count = profile_table[i].execution_count;
                coldest_slot = i;
            }
        }
    }

    if (coldest_slot != -1) {
        // Mark slot as free
        profile_usage[coldest_slot / 8] &= ~(1 << (coldest_slot % 8));
    }

    return coldest_slot;
}

/**
 * Perform DAG optimization on expression
 */
bool eml_perform_optimization(eml_opt_config_t *config) {
    // Placeholder for DAG construction and CSE
    // In a real implementation, this would:
    // 1. Build DAG from expression tree
    // 2. Identify common subexpressions
    // 3. Create optimized computation schedule
    // 4. Update cache policies

    // For now, just simulate optimization
    uint32_t original_complexity = config->max_depth;
    uint32_t optimized_complexity = original_complexity * 0.6;  // 40% reduction

    if (optimized_complexity < 2) optimized_complexity = 2;  // Minimum complexity

    // Update profiling with estimated gains
    config->hit_count += optimized_complexity;  // Simulated cache hits
    config->miss_count += (original_complexity - optimized_complexity);  // Remaining work

    return true;
}

/**
 * Aggressive optimization for hot paths
 */
void eml_aggressive_optimization(uint32_t hash) {
    // Placeholder for advanced optimization techniques:
    // - Unrolling of common patterns
    // - Vectorization where applicable
    // - Specialized microcode generation
    // - Cache layout optimization
}

/**
 * Get profiling statistics
 */
void eml_get_stats(uint32_t *hit_count, uint32_t *miss_count, uint32_t *hot_paths) {
    *hit_count = 0;
    *miss_count = 0;
    *hot_paths = 0;

    for (int i = 0; i < EML_PROFILE_SIZE; i++) {
        if (profile_usage[i / 8] & (1 << (i % 8))) {
            *hit_count += profile_table[i].hit_rate * profile_table[i].execution_count / 100;
            *miss_count += (100 - profile_table[i].hit_rate) * profile_table[i].execution_count / 100;

            if (profile_table[i].is_hot_path) {
                (*hot_paths)++;
            }
        }
    }
}

/**
 * Enable/disable profiling
 */
void eml_set_profiling(bool enable) {
    profiling_enabled = enable;
}