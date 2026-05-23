# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# tb/asm/isa.S
# Directed RV32I ALU-completeness + load-use + branch coverage test (audit §2.3).
# Targets ops the decode/ALU may mishandle: SLTU/SLTIU (unsigned compare),
# SRA/SRAI (arithmetic shift), plus load-use hazard and BGE/BLTU/BGEU flush.
.section .text
.globl _start
_start:
    li   x1, -1              # 0xFFFFFFFF
    li   x2, 1
    li   x3, -16             # 0xFFFFFFF0

    # --- unsigned compares (SLTU / SLTIU) ---
    sltu x5,  x2, x1         # 1 <u 0xFFFFFFFF -> 1   (ADD-bug would give 0)
    sltu x7,  x0, x2         # 0 <u 1          -> 1   (ADD-bug would give 2)
    sltiu x11, x2, 5         # 1 <u 5          -> 1   (ADD-bug would give 6)

    # --- signed compare sanity (SLT) ---
    slt  x6,  x1, x2         # -1 <s 1         -> 1

    # --- arithmetic vs logical shift (SRA/SRAI vs SRL/SRLI) ---
    srai x8,  x3, 2          # -16 >>a 2 -> 0xFFFFFFFC  (logical-bug: 0x3FFFFFFC)
    srli x9,  x3, 2          # -16 >>l 2 -> 0x3FFFFFFC
    sra  x10, x3, x2         # -16 >>a 1 -> 0xFFFFFFF8  (logical-bug: 0x7FFFFFF8)

    # --- bitwise with sign-extended immediate ---
    xori x13, x2, -1         # 1 ^ 0xFFFFFFFF -> 0xFFFFFFFE

    # --- load-use hazard: use loaded value in the very next instruction ---
    sw   x3, 0(x0)           # mem[0] = -16
    lw   x14, 0(x0)          # x14 = -16
    addi x15, x14, 1         # x15 = -15 = 0xFFFFFFF1  (depends on prior load)

    # --- BGE taken + 2-slot flush ---
    li   x4, 5
    li   x20, 0x111
    bge  x4, x2, 1f          # 5 >= 1 -> taken
    li   x20, 0xBAD          # poison
1:
    # --- BLTU taken + flush ---
    li   x21, 0x222
    bltu x2, x1, 2f          # 1 <u 0xFFFFFFFF -> taken
    li   x21, 0xBAD
2:
    # --- BGEU taken + flush ---
    li   x22, 0x333
    bgeu x1, x2, 3f          # 0xFFFFFFFF >=u 1 -> taken
    li   x22, 0xBAD
3:
done:
    j done
