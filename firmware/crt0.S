# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# crt0.S — C runtime startup for Azmuth Xcew processor
# Software audit §S2.4

.section .text.start, "ax"
.global _start
.type _start, @function

_start:
    # Set up stack pointer to top of SRAM
    la      sp, __stack_top

    # Set up global pointer (if using relaxation)
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    # Clear .bss section
    la      t0, __bss_start
    la      t1, __bss_end
.Lclear_bss:
    bge     t0, t1, .Lbss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .Lclear_bss
.Lbss_done:

    # Copy .data from ROM/NVM to SRAM (if load address != runtime address)
    la      t0, __data_load_start
    la      t1, __data_start
    la      t2, __data_end
    beq     t0, t1, .Ldata_done     # Skip if already in place
.Lcopy_data:
    bge     t1, t2, .Ldata_done
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       .Lcopy_data
.Ldata_done:

    # Set up trap handler vector base (mtvec)
    la      t0, _trap_handler
    csrw    mtvec, t0

    # Call main()
    jal     ra, main

    # If main() returns, enter halt loop
    csrw    mie, zero               # Disable all interrupts
.Lhalt:
    wfi                             # Wait for interrupt (none will come)
    j       .Lhalt

.size _start, . - _start
