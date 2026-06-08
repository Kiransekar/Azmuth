/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * xcew_eml.c — libxcew EML subsystem implementation
 * Software audit §S4.2
 */

#include "azmuth/xcew.h"
#include "azmuth/csr.h"

/* Internal: read a CSR by address */
static inline uint32_t _csr_read(uint32_t addr) {
    uint32_t v;
    switch (addr) {
        case 0x7C0: __asm__ volatile ("csrr %0, 0x7C0" : "=r"(v)); break;
        case 0x7C1: __asm__ volatile ("csrr %0, 0x7C1" : "=r"(v)); break;
        case 0x7C6: __asm__ volatile ("csrr %0, 0x7C6" : "=r"(v)); break;
        case 0x7CC: __asm__ volatile ("csrr %0, 0x7CC" : "=r"(v)); break;
        default: v = 0; break;
    }
    return v;
}

static inline void _csr_write(uint32_t addr, uint32_t val) {
    switch (addr) {
        case 0x7C0: __asm__ volatile ("csrw 0x7C0, %0" :: "r"(val)); break;
        case 0x7C6: __asm__ volatile ("csrw 0x7C6, %0" :: "r"(val)); break;
        case 0x7CC: __asm__ volatile ("csrw 0x7CC, %0" :: "r"(val)); break;
        default: break;
    }
}

int xcew_eml_init(xcew_eml_t *eml, uint32_t mode) {
    if (!eml) return XCEW_ERR_INVALID;
    if (mode > 1) return XCEW_ERR_INVALID;

    eml->expr_id = 0;
    eml->flags = 0;
    eml->mode = mode;
    eml->precision = 2;  /* Default: Q15.16 */

    /* Configure EML DAG mode */
    _csr_write(0x7C6, mode & 0x1);

    /* Configure xcew_cfg: PRECISION=Q15.16, MAX_DEPTH=3 */
    uint32_t cfg = (0 << 15)          /* COMPLEX_MODE=0 */
                 | (3 << 12)          /* MAX_DEPTH=3 */
                 | (eml->precision << 8)  /* PRECISION */
                 | (0 << 7);          /* BRANCH_CUT=0 (trap on overflow) */
    _csr_write(0x7C0, cfg);

    return XCEW_OK;
}

int xcew_eml_compute(xcew_eml_t *eml, uint32_t input, uint32_t *output) {
    if (!eml || !output) return XCEW_ERR_INVALID;

    uint32_t result;
    /* Issue Xcew EML instruction (opcode 0x0B = custom-0)
     * Pipeline stalls until EML unit completes. */
    __asm__ volatile (".insn r 0x0B, 0, 0, %0, %1, %2"
                      : "=r"(result)
                      : "r"(eml->expr_id), "r"(input));

    *output = result;

    /* Check for fault */
    uint32_t fault = _csr_read(0x7CC);
    if (fault & 0xFF) return XCEW_ERR_FAULT;

    return XCEW_OK;
}

void xcew_eml_close(xcew_eml_t *eml) {
    if (eml) {
        eml->expr_id = 0;
        eml->flags = 0;
    }
}
