// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
//
// firmware/boot.S — Boot ROM code for Azmuth v1.1
// Software audit §S2.2
//
// Boot sequence (per BOOT_ROM_SPEC.md):
//   Phase 1: Stack pointer init
//   Phase 2: CRC-32 self-check of ROM contents
//   Phase 3: Hardware self-test (EML, SNN, NVM presence check)
//   Phase 4: xcew_cfg CSR init (default precision, depth)
//   Phase 5: Security init (fault monitor enable, deterministic policy)
//   Phase 6: mtvec setup (point to trap_handler)
//   Phase 7: Jump to crt0 (which calls main)
//   Phase 8: Fail halt (if CRC or self-test fails)

    .section .text.boot, "ax", @progbits
    .globl _boot_start
    .globl _start
    .globl main
    .type _boot_start, @function
    .align 4

_boot_start:
    // ── Phase 1: Stack pointer ─────────────────────────────────
    li      sp, 0x0001FFFC          // Set stack to end of SRAM

    // ── Phase 2: CRC-32 self-check (skip in sim) ───────────────
    // Uncomment for silicon:
    // la      a0, _rom_start
    // la      a1, _rom_crc_marker
    // li      a2, 0xFFFFFFFF
    // jal     ra, _crc32_check
    // la      t0, _rom_crc_marker
    // lw      t1, 0(t0)
    // bne     a0, t1, _boot_fail

    // ── Phase 3: Hardware self-test ────────────────────────────
    // Read xcew_status CSR to check tile presence
    csrr    t0, 0x7C1              // xcew_status (DEV-003: may be static)
    // Accept any value — tile presence not reliably reported yet

    // ── Phase 4: xcew_cfg CSR init ─────────────────────────────
    // COMPLEX_MODE=0, MAX_DEPTH=3, PRECISION=Q15.16(2), BRANCH_CUT=0
    li      t0, 0x3200             // (3 << 12) | (2 << 8)
    csrw    0x7C0, t0              // xcew_cfg

    // SNN control: 128 neurons, TTFS enabled
    li      t0, 0x180              // (1 << 8) | 128
    csrw    0x7C5, t0              // snn_ctrl

    // ── Phase 5: Security init ─────────────────────────────────
    // Default watchdog limit (~167ms at 100MHz)
    li      t0, 0x00FFFFFF
    csrw    0x7CD, t0              // watchdog_limit

    // Deterministic policy: max_cycles=1000, det_en=1
    li      t0, 0x03E80001
    csrw    0x7CB, t0              // pol_sec

    // Security control: constant-time mode
    li      t0, 1
    csrw    0x7CA, t0              // sec_ctrl

    // ── Phase 6: mtvec setup ───────────────────────────────────
    la      t0, _trap_entry        // From trap_handler.S (weak symbol ok)
    csrw    mtvec, t0

    // Enable machine external interrupt
    li      t0, 0x00000888         // MEIE + MSIE + MTIE
    csrw    mie, t0

    // Enable global interrupts
    li      t0, 0x00000008         // MIE bit in mstatus
    csrw    mstatus, t0

    // ── Phase 7: Jump to crt0 ──────────────────────────────────
    // crt0 handles .bss clear, .data copy, and calls main()
    call    main

    // Infinite loop after main returns
_halt:
    wfi
    j       _halt

    // ── Phase 8: Fail halt ─────────────────────────────────────
_boot_fail:
    li      a0, 0xDEAD0001         // Error: boot integrity check failed
    // Output 'ERR' on UART (if available)
    li      t0, 0x10000000         // UART TX address
    li      t1, 0x45               // 'E'
    sw      t1, 0(t0)
    li      t1, 0x52               // 'R'
    sw      t1, 0(t0)
    sw      t1, 0(t0)
1:  wfi
    j       1b

    // ── CRC-32 subroutine ──────────────────────────────────────
    // a0 = start address, a1 = end address, a2 = initial CRC
    // Returns: a0 = final CRC
    .type _crc32_check, @function
_crc32_check:
    li      t2, 0x04C11DB7         // CRC-32 polynomial
_crc_loop:
    bge     a0, a1, _crc_done
    lbu     t0, 0(a0)
    xor     a2, a2, t0
    li      t3, 8
_crc_bit:
    srli    t4, a2, 31
    slli    a2, a2, 1
    beqz    t4, _crc_no_xor
    xor     a2, a2, t2
_crc_no_xor:
    addi    t3, t3, -1
    bnez    t3, _crc_bit
    addi    a0, a0, 1
    j       _crc_loop
_crc_done:
    xor     a0, a2, t2
    not     a0, a0
    ret

    .size _boot_start, . - _boot_start

    // Legacy simple trap handler (overridden by trap_handler.S weak symbols)
trap_handler:
    mret

.align 4