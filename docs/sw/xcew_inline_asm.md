<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Xcew Inline Assembly Reference

**Audit reference:** Software §S1.4
**Date:** 2026-06-06

## Overview

For environments where the Azmuth patched toolchain is not available, Xcew
custom instructions can be emitted using standard RISC-V `.insn` directives
with any upstream binutils (≥2.42).

## Instruction Encoding

All Xcew instructions use R-type format:

```
[31:25] funct7  [24:20] rs2  [19:15] rs1  [14:12] funct3  [11:7] rd  [6:0] opcode
```

## Inline Assembly Macros

```c
/* xcew_inline_asm.h — Xcew .insn directives for upstream toolchains
 * SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary */

#ifndef XCEW_INLINE_ASM_H
#define XCEW_INLINE_ASM_H

#include <stdint.h>

/* XCEW_EML — EML compute (opcode 0x0B = custom-0)
 * rd = EML_compute(rs1=expression_id, rs2=operand)
 * Pipeline stalls until EML unit completes. */
#define XCEW_EML(rd, rs1, rs2) \
    __asm__ volatile (".insn r 0x0B, 0, 0, %0, %1, %2" \
                      : "=r"(rd) : "r"(rs1), "r"(rs2))

/* XCEW_POL_UPD — Policy update (opcode 0x2B = custom-1)
 * rd = policy_update(rs1=policy_id, rs2=params)
 * Uses NVM controller path; stalls until NVM not busy. */
#define XCEW_POL_UPD(rd, rs1, rs2) \
    __asm__ volatile (".insn r 0x2B, 0, 0, %0, %1, %2" \
                      : "=r"(rd) : "r"(rs1), "r"(rs2))

/* XCEW_SNN_CLASS — SNN classify (opcode 0x5B = custom-2)
 * rd = snn_classify(rs1=feature_vector_addr, rs2=config)
 * Pipeline stalls until SNN tile completes classification. */
#define XCEW_SNN_CLASS(rd, rs1, rs2) \
    __asm__ volatile (".insn r 0x5B, 0, 0, %0, %1, %2" \
                      : "=r"(rd) : "r"(rs1), "r"(rs2))

/* XCEW_CFG — Configuration write (opcode 0x7B = custom-3, funct3=0)
 * Single-cycle CSR config write.
 * rd = previous_config(rs1=new_config, rs2=mask) */
#define XCEW_CFG(rd, rs1, rs2) \
    __asm__ volatile (".insn r 0x7B, 0, 0, %0, %1, %2" \
                      : "=r"(rd) : "r"(rs1), "r"(rs2))

/* XCEW_MLOAD — Memo load (opcode 0x7B = custom-3, funct3=1)
 * rd = memo_load(rs1=address, rs2=reserved) */
#define XCEW_MLOAD(rd, rs1, rs2) \
    __asm__ volatile (".insn r 0x7B, 1, 0, %0, %1, %2" \
                      : "=r"(rd) : "r"(rs1), "r"(rs2))

/* XCEW_MSTORE — Memo store (opcode 0x7B = custom-3, funct3=2)
 * memo_store(rs1=address, rs2=data); rd receives status. */
#define XCEW_MSTORE(rd, rs1, rs2) \
    __asm__ volatile (".insn r 0x7B, 2, 0, %0, %1, %2" \
                      : "=r"(rd) : "r"(rs1), "r"(rs2))

/* CSR read/write helpers (standard RISC-V) */
#define CSR_READ(csr) ({ \
    uint32_t __v; \
    __asm__ volatile ("csrr %0, %1" : "=r"(__v) : "i"(csr)); \
    __v; })

#define CSR_WRITE(csr, val) \
    __asm__ volatile ("csrw %0, %1" :: "i"(csr), "r"(val))

/* Azmuth CSR addresses */
#define CSR_XCEW_CFG        0x7C0
#define CSR_XCEW_STATUS     0x7C1
#define CSR_SNN_CTRL_EXT    0x7C5
#define CSR_EML_DAG_CTL     0x7C6
#define CSR_PWR_CTRL        0x7C8
#define CSR_BIAS_CTRL       0x7C9
#define CSR_SEC_CTRL        0x7CA
#define CSR_POL_SEC         0x7CB
#define CSR_FAULT_STATUS    0x7CC

#endif /* XCEW_INLINE_ASM_H */
```

## Usage Example

```c
#include "xcew_inline_asm.h"

void eml_softplus(float x, float *result) {
    uint32_t input = *(uint32_t*)&x;  // Reinterpret as Q16.16
    uint32_t output;

    // Configure EML: COMPLEX_MODE=0, MAX_DEPTH=3, PRECISION=Q15.16
    CSR_WRITE(CSR_XCEW_CFG, (0 << 15) | (3 << 12) | (2 << 8));

    // Compute ln(1 + exp(x)) via EML accelerator
    uint32_t expr_id = 1;  // Pre-loaded expression ID
    XCEW_EML(output, expr_id, input);

    *result = *(float*)&output;
}

void snn_classify_sample(const int8_t *features, uint32_t *class_id) {
    uint32_t result;
    XCEW_SNN_CLASS(result, (uint32_t)features, 0);
    *class_id = result & 0xFF;
}
```

## Opcode Quick Reference

| Mnemonic | Opcode (hex) | Opcode (bin) | funct3 | Custom slot |
|----------|-------------|-------------|--------|-------------|
| xcew.eml | 0x0B | 0001011 | 0 | custom-0 |
| xcew.pol_upd | 0x2B | 0101011 | 0 | custom-1 |
| xcew.snn_cls | 0x5B | 1011011 | 0 | custom-2 |
| xcew.cfg | 0x7B | 1111011 | 0 | custom-3 |
| xcew.mload | 0x7B | 1111011 | 1 | custom-3 |
| xcew.mstore | 0x7B | 1111011 | 2 | custom-3 |
