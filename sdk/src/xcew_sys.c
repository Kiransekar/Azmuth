/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * xcew_sys.c — libxcew NVM, policy, power, fault subsystem implementation
 * Software audit §S4.2
 */

#include "azmuth/xcew.h"
#include "azmuth/csr.h"

/* ===== NVM ===== */

int xcew_nvm_read(uint32_t addr, void *buf, size_t len) {
    if (!buf || len == 0) return XCEW_ERR_INVALID;
    if (addr < 0x4000 || addr + len > 0x5000) return XCEW_ERR_INVALID;

    volatile uint32_t *nvm = (volatile uint32_t *)addr;
    uint32_t *dst = (uint32_t *)buf;
    for (size_t i = 0; i < len; i += 4) {
        dst[i / 4] = nvm[i / 4];
    }

    /* Check ECC status */
    uint32_t fault;
    __asm__ volatile ("csrr %0, 0x7CC" : "=r"(fault));
    if (fault & 0x04) return XCEW_ERR_ECC;  /* FAULT_ECC_DOUBLE */

    return XCEW_OK;
}

int xcew_nvm_write(uint32_t addr, const void *buf, size_t len) {
    if (!buf || len == 0) return XCEW_ERR_INVALID;
    if (addr < 0x4000 || addr + len > 0x5000) return XCEW_ERR_INVALID;

    volatile uint32_t *nvm = (volatile uint32_t *)addr;
    const uint32_t *src = (const uint32_t *)buf;
    for (size_t i = 0; i < len; i += 4) {
        nvm[i / 4] = src[i / 4];
    }

    return XCEW_OK;
}

int xcew_nvm_get_stats(uint32_t *scrub_count, uint32_t *corrected_count) {
    if (scrub_count) {
        /* CSR 0x7CE — ECC scrub count (DEV-004: may not be decoded) */
        __asm__ volatile ("csrr %0, 0x7CE" : "=r"(*scrub_count));
    }
    if (corrected_count) {
        __asm__ volatile ("csrr %0, 0x7CF" : "=r"(*corrected_count));
    }
    return XCEW_OK;
}

int xcew_nvm_get_capacity(uint32_t *bytes) {
    if (!bytes) return XCEW_ERR_INVALID;
    /* External QSPI NVM size detected by reading NVM controller ID register.
     * For now, return the CSR-mapped region size. */
    *bytes = 4096;  /* 4KB NVM CSR window */
    return XCEW_OK;
}

/* ===== Policy ===== */

int xcew_policy_set_deterministic(uint32_t max_cycles) {
    /* pol_sec CSR (0x7CB): [0] DET_EN, [31:16] MAX_CYCLES */
    uint32_t val = (1 << 0) | ((max_cycles & 0xFFFF) << 16);
    __asm__ volatile ("csrw 0x7CB, %0" :: "r"(val));
    return XCEW_OK;
}

int xcew_policy_update(uint32_t policy_id, uint32_t params) {
    uint32_t result;
    /* Issue Xcew POL_UPD instruction (opcode 0x2B = custom-1) */
    __asm__ volatile (".insn r 0x2B, 0, 0, %0, %1, %2"
                      : "=r"(result)
                      : "r"(policy_id), "r"(params));
    return XCEW_OK;
}

/* ===== Power Management ===== */

int xcew_pwr_tile_sleep(uint32_t tile_id) {
    if (tile_id > 3) return XCEW_ERR_INVALID;

    /* pwr_ctrl CSR (0x7C8): write tile_state_req with SLEEP for target tile */
    uint32_t pwr;
    __asm__ volatile ("csrr %0, 0x7C8" : "=r"(pwr));
    pwr |= (1 << tile_id);  /* Set sleep request for tile */
    __asm__ volatile ("csrw 0x7C8, %0" :: "r"(pwr));

    return XCEW_OK;
}

int xcew_pwr_tile_wake(uint32_t tile_id) {
    if (tile_id > 3) return XCEW_ERR_INVALID;

    uint32_t pwr;
    __asm__ volatile ("csrr %0, 0x7C8" : "=r"(pwr));
    pwr &= ~(1 << tile_id);  /* Clear sleep request for tile */
    __asm__ volatile ("csrw 0x7C8, %0" :: "r"(pwr));

    return XCEW_OK;
}

int xcew_pwr_set_bias(int8_t bias_code) {
    uint32_t val = (uint32_t)(uint8_t)bias_code;
    __asm__ volatile ("csrw 0x7C9, %0" :: "r"(val));
    return XCEW_OK;
}

/* ===== Fault Monitoring ===== */

int xcew_fault_get_status(uint32_t *fault_code) {
    if (!fault_code) return XCEW_ERR_INVALID;
    __asm__ volatile ("csrr %0, 0x7CC" : "=r"(*fault_code));
    return XCEW_OK;
}

int xcew_fault_clear(uint32_t fault_mask) {
    /* fault_status is W1C: writing 1 to a bit clears it.
     * Bit 31 is the master clear bit. */
    uint32_t val = fault_mask | (1U << 31);
    __asm__ volatile ("csrw 0x7CC, %0" :: "r"(val));
    return XCEW_OK;
}
