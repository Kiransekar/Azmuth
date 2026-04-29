// rtl/eml/eml_dag_cache.v
// Enhanced EML DAG Cache with compression and CSE support
// 256-entry set-associative (4-way) cache with LRU replacement
// Subtree hash compressor and DAG scheduler

`timescale 1ns/1ps

module eml_dag_cache (
    // Global signals
    input wire clk,
    input wire rst,

    // Control signals
    input wire enable,
    input wire dag_mode,  // CSR eml_cfg[5]: 0=tree, 1=DAG+CSE

    // Input from EML computation
    input wire [31:0] expr_hash_in,      // Hash of expression tree
    input wire [31:0] expr_result_in,    // Computed result
    input wire expr_valid_in,            // Result is valid
    input wire expr_compute_done,        // Computation completed

    // Output to EML computation
    output reg [31:0] cached_result,     // Cached result if hit
    output reg cache_hit,                // Cache hit indicator
    output reg cache_miss,               // Cache miss indicator
    output reg [31:0] alloc_addr,        // Address for new allocation

    // DAG scheduler interface
    input wire [31:0] subexpr_hash,      // Hash of subexpression
    input wire subexpr_valid,            // Subexpression is valid
    output reg subexpr_cached,           // Subexpression is cached
    output reg [31:0] subexpr_result,    // Cached subexpression result

    // Memory interface for cache
    output reg [7:0] cache_tag_wr,
    output reg [7:0] cache_data_wr,
    output reg [7:0] cache_lru_wr,
    output reg [7:0] cache_tag_rd,
    output reg [7:0] cache_data_rd,
    output reg [7:0] cache_lru_rd,
    input wire [31:0] cache_data_out,
    input wire [7:0] cache_lru_out
);

    // Cache configuration
    parameter SET_BITS = 6;      // 64 sets (256 entries / 4 ways)
    parameter WAY_BITS = 2;      // 4 ways
    parameter INDEX_BITS = 6;    // Index bits for 64 sets
    parameter TAG_BITS = 8;      // Tag bits (compressed from 32 to 8 via XOR folding)

    // Cache entry structure
    reg [7:0] cache_tags [0:255];      // 8-bit tags (compressed)
    reg [31:0] cache_data [0:255];     // 32-bit data
    reg [1:0] lru_counters [0:63];     // 2-bit LRU per set

    // Address breakdown
    wire [INDEX_BITS-1:0] cache_index = expr_hash_in[INDEX_BITS-1:0];
    wire [WAY_BITS-1:0] way_select;
    wire [TAG_BITS-1:0] compressed_tag = compress_hash(expr_hash_in);

    // DAG scheduler state
    reg [31:0] pending_subexpr [0:15];  // Track pending subexpressions
    reg [3:0] pending_count;
    reg [3:0] pending_age [0:15];      // Age counter for LRU

    // Compress 32-bit hash to 8-bit tag using XOR folding
    function [7:0] compress_hash;
        input [31:0] hash_in;
        begin
            compress_hash = hash_in[7:0] ^
                           hash_in[15:8] ^
                           hash_in[23:16] ^
                           hash_in[31:24];
        end
    endfunction

    // Find LRU way in a set
    function [1:0] get_lru_way;
        input [INDEX_BITS-1:0] index;
        begin
            get_lru_way = lru_counters[index];
        end
    endfunction

    // Update LRU for a set and way
    task update_lru;
        input [INDEX_BITS-1:0] index;
        input [WAY_BITS-1:0] way;
        begin
            if (way == 0) lru_counters[index] = 2'b01;
            else if (way == 1) lru_counters[index] = 2'b00;
            else if (way == 2) lru_counters[index] = 2'b11;
            else lru_counters[index] = 2'b10;
        end
    endtask

    // Cache lookup and update logic
    reg [1:0] way_hit;
    reg hit_found;
    integer i, j;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cache_hit <= 1'b0;
            cache_miss <= 1'b0;
            cached_result <= 32'h0;
            alloc_addr <= 32'h0;
            pending_count <= 4'd0;

            // Initialize LRU counters
            for (i = 0; i < 64; i = i + 1) begin
                lru_counters[i] <= 2'b00;
            end

            // Initialize pending expressions
            for (i = 0; i < 16; i = i + 1) begin
                pending_subexpr[i] <= 32'h0;
                pending_age[i] <= 4'd0;
            end
        end
        else begin
            cache_hit <= 1'b0;
            cache_miss <= 1'b0;
            subexpr_cached <= 1'b0;

            if (enable && dag_mode) begin
                // DAG mode: perform CSE and cache operations

                // Check for cache hit
                hit_found = 1'b0;
                way_hit = 2'b00;

                for (i = 0; i < 4; i = i + 1) begin
                    if (cache_tags[{cache_index, i}] == compressed_tag &&
                        cache_data[{cache_index, i}] != 32'h0) begin
                        cache_hit <= 1'b1;
                        cached_result <= cache_data[{cache_index, i}];
                        way_hit = i;
                        hit_found = 1'b1;
                        update_lru(cache_index, i);
                        break;
                    end
                end

                if (!hit_found) begin
                    cache_miss <= 1'b1;
                    // Allocate new entry using LRU replacement
                    way_select = get_lru_way(cache_index);
                    alloc_addr = {cache_index, way_select};

                    // Store computed result if valid
                    if (expr_valid_in && expr_compute_done) begin
                        cache_tags[{cache_index, way_select}] <= compressed_tag;
                        cache_data[{cache_index, way_select}] <= expr_result_in;
                        update_lru(cache_index, way_select);
                    end
                end

                // Handle subexpression scheduling
                if (subexpr_valid) begin
                    // Check if subexpression is already cached
                    for (i = 0; i < 4; i = i + 1) begin
                        if (cache_tags[{subexpr_hash[INDEX_BITS-1:0], i}] == compress_hash(subexpr_hash) &&
                            cache_data[{subexpr_hash[INDEX_BITS-1:0], i}] != 32'h0) begin
                            subexpr_cached <= 1'b1;
                            subexpr_result <= cache_data[{subexpr_hash[INDEX_BITS-1:0], i}];
                            update_lru(subexpr_hash[INDEX_BITS-1:0], i);
                            break;
                        end
                    end

                    // If not cached and we have space, add to pending
                    if (!subexpr_cached && pending_count < 16) begin
                        pending_subexpr[pending_count] <= subexpr_hash;
                        pending_age[pending_count] <= 4'd0;
                        pending_count <= pending_count + 1;
                    end
                end

                // Age pending expressions and remove old ones
                for (i = 0; i < 16; i = i + 1) begin
                    if (pending_age[i] < 4'hF) begin
                        pending_age[i] <= pending_age[i] + 1;
                    end else begin
                        // Expire old pending expressions
                        if (i < pending_count) begin
                            pending_count <= pending_count - 1;
                        end
                    end
                end
            end
            else begin
                // Tree mode: simple pass-through
                cache_hit <= 1'b0;
                cache_miss <= 1'b0;
                subexpr_cached <= 1'b0;
            end
        end
    end

    // Assign memory interface signals
    always @(*) begin
        cache_tag_wr = 8'h0;
        cache_data_wr = 8'h0;
        cache_lru_wr = 8'h0;
        cache_tag_rd = 8'h0;
        cache_data_rd = 8'h0;
        cache_lru_rd = 8'h0;
    end

endmodule

// EML DAG Scheduler module for tracking and reusing nodes
module eml_dag_scheduler (
    input wire clk,
    input wire rst,
    input wire dag_mode,

    // Input expression stream
    input wire [31:0] expr_hash,
    input wire expr_valid,
    output reg reuse_available,
    output reg [31:0] reuse_addr,

    // Node completion feedback
    input wire node_completed,
    input wire [31:0] completed_hash
);

    // Pending node tracking
    reg [31:0] pending_nodes [0:63];
    reg [5:0] pending_indices [0:63];
    reg [5:0] pending_count;
    reg [5:0] oldest_idx;

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pending_count <= 6'd0;
            oldest_idx <= 6'd0;
            reuse_available <= 1'b0;
            reuse_addr <= 32'h0;

            for (i = 0; i < 64; i = i + 1) begin
                pending_nodes[i] <= 32'h0;
                pending_indices[i] <= 6'd0;
            end
        end
        else begin
            reuse_available <= 1'b0;

            if (dag_mode) begin
                // Check for node reuse opportunity
                for (i = 0; i < pending_count; i = i + 1) begin
                    if (pending_nodes[i] == expr_hash) begin
                        reuse_available <= 1'b1;
                        reuse_addr <= pending_indices[i];
                        break;
                    end
                end

                // Add new node if not already pending
                if (expr_valid && !reuse_available && pending_count < 64) begin
                    pending_nodes[pending_count] <= expr_hash;
                    pending_indices[pending_count] <= pending_count;  // Simplified addressing
                    pending_count <= pending_count + 1;
                end

                // Remove completed nodes
                if (node_completed) begin
                    for (i = 0; i < pending_count; i = i + 1) begin
                        if (pending_nodes[i] == completed_hash) begin
                            // Shift remaining entries
                            for (j = i; j < pending_count - 1; j = j + 1) begin
                                pending_nodes[j] <= pending_nodes[j + 1];
                                pending_indices[j] <= pending_indices[j + 1];
                            end
                            pending_count <= pending_count - 1;
                            break;
                        end
                    end
                end
            end
        end
    end

endmodule