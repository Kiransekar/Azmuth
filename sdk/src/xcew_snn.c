/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * xcew_snn.c — libxcew SNN subsystem implementation
 * Software audit §S4.2
 */

#include "azmuth/xcew.h"
#include "azmuth/csr.h"

int xcew_snn_init(xcew_snn_t *snn, uint32_t neuron_count) {
    if (!snn) return XCEW_ERR_INVALID;
    if (neuron_count == 0 || neuron_count > 256) return XCEW_ERR_INVALID;

    snn->tile_id = 0;
    snn->neuron_count = neuron_count;
    snn->ttfs_enabled = 1;  /* TTFS on by default */
    snn->stdp_policy = 0;

    /* Configure SNN extended control CSR */
    uint32_t snn_ctrl = (neuron_count & 0xFF)
                      | ((snn->ttfs_enabled & 0x1) << 8);
    __asm__ volatile ("csrw 0x7C5, %0" :: "r"(snn_ctrl));

    return XCEW_OK;
}

int xcew_snn_load_weights(xcew_snn_t *snn, const int8_t *weights, size_t len) {
    if (!snn || !weights) return XCEW_ERR_INVALID;
    if (len > snn->neuron_count) return XCEW_ERR_INVALID;

    /* Load weights via SNN CSR region (0x3000-0x3FFF) */
    volatile uint32_t *snn_csr = (volatile uint32_t *)0x3000;
    for (size_t i = 0; i < len; i += 4) {
        uint32_t word = 0;
        for (size_t j = 0; j < 4 && (i + j) < len; j++) {
            word |= ((uint32_t)(uint8_t)weights[i + j]) << (j * 8);
        }
        snn_csr[i / 4] = word;
    }

    return XCEW_OK;
}

int xcew_snn_classify(xcew_snn_t *snn, const int8_t *input, uint32_t *class_id) {
    if (!snn || !input || !class_id) return XCEW_ERR_INVALID;

    uint32_t result;
    /* Issue Xcew SNN classify instruction (opcode 0x5B = custom-2)
     * Pipeline stalls until SNN tile completes. */
    __asm__ volatile (".insn r 0x5B, 0, 0, %0, %1, %2"
                      : "=r"(result)
                      : "r"((uint32_t)input), "r"(0));

    *class_id = result & 0xFF;
    return XCEW_OK;
}

int xcew_snn_enable_stdp(xcew_snn_t *snn, uint32_t policy) {
    if (!snn) return XCEW_ERR_INVALID;
    if (policy > 5) return XCEW_ERR_INVALID;

    snn->stdp_policy = policy;

    /* Update SNN control CSR with STDP policy */
    uint32_t snn_ctrl = (snn->neuron_count & 0xFF)
                      | ((snn->ttfs_enabled & 0x1) << 8)
                      | ((policy & 0x7) << 12);
    __asm__ volatile ("csrw 0x7C5, %0" :: "r"(snn_ctrl));

    return XCEW_OK;
}

void xcew_snn_close(xcew_snn_t *snn) {
    if (snn) {
        snn->neuron_count = 0;
        snn->stdp_policy = 0;
    }
}
