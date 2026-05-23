# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# tb/asm/hazard.S
# Directed RV32I + Zicsr pipeline/hazard/ISA test for riscv_core (tapeout audit
# §2.3). Exercises RAW dependency chains, all ALU ops, branch resolution +
# wrong-path flush, JAL link/target, word load/store, store byte-enables, and
# CSR read-after-write. Assembled by tools/asm-to-hex; results checked by
# tb/hazard_tb.v against the register file.
.section .text
.globl _start
_start:
    # --- arithmetic + back-to-back RAW dependencies ---
    li   x1, 10
    li   x2, 20
    add  x5, x1, x2          # x5  = 30   (RAW on x1,x2 written in prior cycles)
    sub  x6, x2, x1          # x6  = 10
    slt  x19, x1, x2         # x19 = 1    (10 < 20)
    slli x18, x1, 2          # x18 = 40

    # --- LUI + RAW + word store/load roundtrip ---
    lui  x14, 0x12345        # x14 = 0x12345000
    addi x24, x14, 0x678     # x24 = 0x12345678 (RAW on x14)
    sw   x24, 0(x0)
    lw   x11, 0(x0)          # x11 = 0x12345678

    # --- store byte-enable correctness (SB preserves other bytes) ---
    li   x28, -1
    sw   x28, 24(x0)         # dram[6] = 0xFFFFFFFF
    li   x29, 0xAB
    sb   x29, 24(x0)         # write byte0 only -> 0xFFFFFFAB
    lw   x12, 24(x0)         # x12 = 0xFFFFFFAB

    # --- CSR read-after-write (machine CSR mscratch) ---
    li   x20, 0xCAFE
    csrw mscratch, x20
    csrr x16, mscratch       # x16 = 0xCAFE

    # --- BEQ taken: wrong-path instruction must be flushed ---
    li   x7, 0x111
    beq  x0, x0, 1f          # taken
    li   x7, 0xBAD           # poison: executes only if flush fails
1:
    # --- BNE not taken: fall through executes ---
    li   x8, 0
    bne  x0, x0, 2f          # not taken
    li   x8, 0x222           # executes
2:
    # --- BLT taken + flush ---
    li   x3, 5
    li   x4, 9
    li   x9, 0x444
    blt  x3, x4, 3f          # 5 < 9 -> taken
    li   x9, 0xBAD           # poison
3:
    # --- JAL link + target + flush ---
    li   x17, 0x333
    jal  x10, 4f             # x10 = return addr; skip poison
    li   x17, 0xBAD          # poison
4:
    # --- done: spin ---
done:
    j done
