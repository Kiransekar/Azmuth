/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * xcew.h — Azmuth Xcew C API (libxcew)
 * Software audit §S4.1
 *
 * This is the primary adopter-facing API for Xcew custom extensions.
 * Stable across hardware versions; v1.2 must not break adopter code.
 */

#ifndef AZMUTH_XCEW_H
#define AZMUTH_XCEW_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ===== Error codes ===== */
#define XCEW_OK           0
#define XCEW_ERR_INVALID  (-1)
#define XCEW_ERR_BUSY     (-2)
#define XCEW_ERR_TIMEOUT  (-3)
#define XCEW_ERR_ECC      (-4)
#define XCEW_ERR_FAULT    (-5)
#define XCEW_ERR_NOSUPPORT (-6)

/* ===== EML (Expression Machine Learning) ===== */

typedef struct {
    uint32_t expr_id;    /* Expression identifier (loaded via EML DAG cache) */
    uint32_t flags;      /* Configuration flags */
    uint32_t mode;       /* 0=tree, 1=DAG+CSE */
    uint32_t precision;  /* 0=BF16, 1=FP16, 2=Q15.16 */
} xcew_eml_t;

/** Initialize an EML context with the given mode.
 * @param eml  Pointer to EML context structure
 * @param mode 0=standard tree evaluation, 1=DAG+CSE optimized
 * @return XCEW_OK on success */
int xcew_eml_init(xcew_eml_t *eml, uint32_t mode);

/** Compute an EML expression.
 * @param eml    Initialized EML context
 * @param input  Input value (Q16.16 fixed-point)
 * @param output Pointer to receive result (Q16.16 fixed-point)
 * @return XCEW_OK on success, XCEW_ERR_TIMEOUT on EML pipeline timeout */
int xcew_eml_compute(xcew_eml_t *eml, uint32_t input, uint32_t *output);

/** Release EML context resources.
 * @param eml EML context to close */
void xcew_eml_close(xcew_eml_t *eml);

/* ===== SNN (Spiking Neural Network) ===== */

typedef struct {
    uint32_t tile_id;        /* SNN tile identifier */
    uint32_t neuron_count;   /* Logical neuron count (256 max) */
    uint32_t ttfs_enabled;   /* Time-to-First-Spike mode */
    uint32_t stdp_policy;    /* STDP learning policy (0-5) */
} xcew_snn_t;

/** Initialize an SNN context.
 * @param snn          Pointer to SNN context
 * @param neuron_count Number of logical neurons (max 256)
 * @return XCEW_OK on success */
int xcew_snn_init(xcew_snn_t *snn, uint32_t neuron_count);

/** Load weight matrix into SNN tile.
 * @param snn     Initialized SNN context
 * @param weights Pointer to weight array (int8_t, neuron_count elements)
 * @param len     Length of weight array in bytes
 * @return XCEW_OK on success */
int xcew_snn_load_weights(xcew_snn_t *snn, const int8_t *weights, size_t len);

/** Run SNN classification on input features.
 * @param snn      Initialized SNN context
 * @param input    Input feature vector (int8_t, neuron_count elements)
 * @param class_id Pointer to receive winning class index
 * @return XCEW_OK on success */
int xcew_snn_classify(xcew_snn_t *snn, const int8_t *input, uint32_t *class_id);

/** Enable STDP learning on the SNN tile.
 * @param snn    Initialized SNN context
 * @param policy STDP policy (0-5, per stdp_engine_v1_1)
 * @return XCEW_OK on success */
int xcew_snn_enable_stdp(xcew_snn_t *snn, uint32_t policy);

/** Release SNN context resources. */
void xcew_snn_close(xcew_snn_t *snn);

/* ===== NVM (Non-Volatile Memory) ===== */

/** Read data from NVM.
 * @param addr NVM address (within 0x4000-0x4FFF CSR window)
 * @param buf  Destination buffer
 * @param len  Number of bytes to read
 * @return XCEW_OK on success, XCEW_ERR_ECC on uncorrectable error */
int xcew_nvm_read(uint32_t addr, void *buf, size_t len);

/** Write data to NVM.
 * @param addr NVM address
 * @param buf  Source buffer
 * @param len  Number of bytes to write
 * @return XCEW_OK on success */
int xcew_nvm_write(uint32_t addr, const void *buf, size_t len);

/** Get NVM health statistics.
 * @param scrub_count     Pointer to receive ECC scrub count (CSR 0x7CE)
 * @param corrected_count Pointer to receive corrected error count (CSR 0x7CF)
 * @return XCEW_OK on success */
int xcew_nvm_get_stats(uint32_t *scrub_count, uint32_t *corrected_count);

/** Get NVM capacity in bytes (detects external QSPI part size). */
int xcew_nvm_get_capacity(uint32_t *bytes);

/* ===== Policy ===== */

/** Enable deterministic (fixed-cycle) policy execution.
 * @param max_cycles Maximum cycles before timeout IRQ
 * @return XCEW_OK on success */
int xcew_policy_set_deterministic(uint32_t max_cycles);

/** Execute a policy update.
 * @param policy_id Policy identifier
 * @param params    Policy parameters
 * @return XCEW_OK on success */
int xcew_policy_update(uint32_t policy_id, uint32_t params);

/* ===== Power Management ===== */

/** Put a tile to sleep.
 * @param tile_id 0=Core, 1=EML, 2=SNN, 3=NVM
 * @return XCEW_OK on success */
int xcew_pwr_tile_sleep(uint32_t tile_id);

/** Wake a sleeping tile.
 * @param tile_id 0=Core, 1=EML, 2=SNN, 3=NVM
 * @return XCEW_OK on success */
int xcew_pwr_tile_wake(uint32_t tile_id);

/** Set body-bias voltage code.
 * @param bias_code 8-bit bias DAC code
 * @return XCEW_OK on success */
int xcew_pwr_set_bias(int8_t bias_code);

/* ===== Fault Monitoring ===== */

/** Get current fault status.
 * @param fault_code Pointer to receive fault_status CSR (0x7CC)
 * @return XCEW_OK */
int xcew_fault_get_status(uint32_t *fault_code);

/** Clear fault status bits (W1C semantics).
 * @param fault_mask Bits to clear (write-1-to-clear)
 * @return XCEW_OK */
int xcew_fault_clear(uint32_t fault_mask);

#ifdef __cplusplus
}
#endif

#endif /* AZMUTH_XCEW_H */
