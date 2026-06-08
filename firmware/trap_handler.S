# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# trap_handler.S — M-mode trap handler for Azmuth Xcew processor
# Software audit §S2.5

.section .text.trap, "ax"
.global _trap_handler
.global _trap_entry
.type _trap_handler, @function
.balign 4

_trap_entry:
_trap_handler:
    # Save context (caller-saved registers + ra + mepc)
    addi    sp, sp, -64
    sw      ra,  0(sp)
    sw      t0,  4(sp)
    sw      t1,  8(sp)
    sw      t2, 12(sp)
    sw      a0, 16(sp)
    sw      a1, 20(sp)
    sw      a2, 24(sp)
    sw      a3, 28(sp)
    sw      a4, 32(sp)
    sw      a5, 36(sp)
    sw      a6, 40(sp)
    sw      a7, 44(sp)
    sw      t3, 48(sp)
    sw      t4, 52(sp)
    sw      t5, 56(sp)
    sw      t6, 60(sp)

    # Read mcause to determine trap type
    csrr    a0, mcause

    # Check if interrupt (bit 31) or exception
    bgez    a0, .Lexception

    # === Interrupt handling ===
    andi    a0, a0, 0x1F            # Mask cause code
    li      t0, 11                  # Machine External Interrupt
    beq     a0, t0, .Lirq_mei
    li      t0, 7                   # Machine Timer Interrupt
    beq     a0, t0, .Lirq_mti
    li      t0, 3                   # Machine Software Interrupt
    beq     a0, t0, .Lirq_msi
    j       .Ltrap_done             # Unknown interrupt

.Lirq_mei:
    jal     ra, irq_external_handler
    j       .Ltrap_done

.Lirq_mti:
    jal     ra, irq_timer_handler
    j       .Ltrap_done

.Lirq_msi:
    jal     ra, irq_software_handler
    j       .Ltrap_done

    # === Exception handling ===
.Lexception:
    li      t0, 2                   # Illegal instruction
    beq     a0, t0, .Lexc_illegal
    li      t0, 11                  # ECALL from M-mode
    beq     a0, t0, .Lexc_ecall
    li      t0, 3                   # Breakpoint
    beq     a0, t0, .Lexc_ebreak
    li      t0, 4                   # Load address misaligned
    beq     a0, t0, .Lexc_load_ma
    li      t0, 6                   # Store address misaligned
    beq     a0, t0, .Lexc_store_ma
    j       .Lexc_default

.Lexc_illegal:
    jal     ra, exc_illegal_handler
    j       .Ltrap_advance_pc

.Lexc_ecall:
    jal     ra, exc_ecall_handler
    j       .Ltrap_advance_pc

.Lexc_ebreak:
    jal     ra, exc_ebreak_handler
    j       .Ltrap_advance_pc

.Lexc_load_ma:
    jal     ra, exc_load_misalign_handler
    j       .Ltrap_done

.Lexc_store_ma:
    jal     ra, exc_store_misalign_handler
    j       .Ltrap_done

.Lexc_default:
    jal     ra, exc_default_handler
    j       .Ltrap_done

.Ltrap_advance_pc:
    # For ECALL/EBREAK/illegal: advance mepc past the faulting instruction
    csrr    t0, mepc
    addi    t0, t0, 4
    csrw    mepc, t0

.Ltrap_done:
    # Restore context
    lw      ra,  0(sp)
    lw      t0,  4(sp)
    lw      t1,  8(sp)
    lw      t2, 12(sp)
    lw      a0, 16(sp)
    lw      a1, 20(sp)
    lw      a2, 24(sp)
    lw      a3, 28(sp)
    lw      a4, 32(sp)
    lw      a5, 36(sp)
    lw      a6, 40(sp)
    lw      a7, 44(sp)
    lw      t3, 48(sp)
    lw      t4, 52(sp)
    lw      t5, 56(sp)
    lw      t6, 60(sp)
    addi    sp, sp, 64

    mret

.size _trap_handler, . - _trap_handler

# === Weak default handlers (adopter overrides these) ===
.weak irq_external_handler
.weak irq_timer_handler
.weak irq_software_handler
.weak exc_illegal_handler
.weak exc_ecall_handler
.weak exc_ebreak_handler
.weak exc_load_misalign_handler
.weak exc_store_misalign_handler
.weak exc_default_handler

# Default: spin forever (adopter MUST override for meaningful behavior)
.type irq_external_handler, @function
irq_external_handler:
irq_timer_handler:
irq_software_handler:
exc_illegal_handler:
exc_ecall_handler:
exc_ebreak_handler:
exc_load_misalign_handler:
exc_store_misalign_handler:
exc_default_handler:
    j       .
