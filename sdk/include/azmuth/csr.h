/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * csr.h — Azmuth CSR address definitions
 */

#ifndef AZMUTH_CSR_H
#define AZMUTH_CSR_H

/* Standard M-mode CSRs */
#define CSR_MSTATUS     0x300
#define CSR_MISA        0x301
#define CSR_MIE         0x304
#define CSR_MTVEC       0x305
#define CSR_MSCRATCH    0x340
#define CSR_MEPC        0x341
#define CSR_MCAUSE      0x342
#define CSR_MTVAL       0x343
#define CSR_MIP         0x344
#define CSR_MHARTID     0xF14

/* Xcew custom CSRs (Machine custom RW space 0x7C0-0x7CF) */
#define CSR_XCEW_CFG         0x7C0  /* RW: COMPLEX_MODE, MAX_DEPTH, PRECISION, BRANCH_CUT */
#define CSR_XCEW_STATUS      0x7C1  /* RO: pipeline stage, IRQ_PENDING, NVM_BUSY, OVERFLOW, NaN */
#define CSR_SNN_CTRL_EXT     0x7C5  /* RW: SNN extended control (v1.1) */
#define CSR_EML_DAG_CTL      0x7C6  /* RW: [0] DAG_MODE (0=tree, 1=DAG+CSE) */
#define CSR_PWR_CTRL         0x7C8  /* RW: tile state req / idle timeout / wake mask */
#define CSR_BIAS_CTRL        0x7C9  /* RW: bias code / calibration enable */
#define CSR_SEC_CTRL         0x7CA  /* RW: constant-time / timing-variant enables */
#define CSR_POL_SEC          0x7CB  /* RW: DET_EN / MAX_CYCLES (policy determinism) */
#define CSR_FAULT_STATUS     0x7CC  /* W1C: fault status latch */
#define CSR_WATCHDOG_TIMEOUT 0x7CD  /* RW: watchdog timeout (DEV-004: not decoded) */
#define CSR_ECC_SCRUB_COUNT  0x7CE  /* RO: ECC scrub count (DEV-004: not decoded) */
#define CSR_ECC_CORRECTED    0x7CF  /* RO: ECC corrected count (DEV-004: not decoded) */

/* xcew_cfg (0x7C0) field definitions */
#define XCEW_CFG_COMPLEX_MODE  (1 << 15)
#define XCEW_CFG_MAX_DEPTH(n)  (((n) & 0x7) << 12)
#define XCEW_CFG_PRECISION(n)  (((n) & 0xF) << 8)
#define XCEW_CFG_BRANCH_CUT    (1 << 7)

/* fault_status (0x7CC) fault codes */
#define FAULT_WATCHDOG      (1 << 0)
#define FAULT_ECC_SINGLE    (1 << 1)
#define FAULT_ECC_DOUBLE    (1 << 2)
#define FAULT_SOFT_EML      (1 << 3)
#define FAULT_SOFT_SNN      (1 << 4)
#define FAULT_HARD_NVM      (1 << 5)
#define FAULT_CSR_VIOLATION (1 << 6)
#define FAULT_INSTR_FAULT   (1 << 7)
#define FAULT_CLEAR_BIT     (1 << 31)  /* W1C clear */

/* CSR access macros (for use in firmware) */
#define CSR_READ(csr) ({ \
    uint32_t __v; \
    __asm__ volatile ("csrr %0, " #csr : "=r"(__v)); \
    __v; })

#define CSR_WRITE(csr, val) \
    __asm__ volatile ("csrw " #csr ", %0" :: "r"((uint32_t)(val)))

#define CSR_SET(csr, val) \
    __asm__ volatile ("csrs " #csr ", %0" :: "r"((uint32_t)(val)))

#define CSR_CLEAR(csr, val) \
    __asm__ volatile ("csrc " #csr ", %0" :: "r"((uint32_t)(val)))

#endif /* AZMUTH_CSR_H */
