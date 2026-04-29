.section .text
.globl _start
.globl main

_start:
    # Set up stack pointer to end of SRAM (0x0001_FFFC)
    li sp, 0x0001FFFC

    # Initialize CSRs
    # mstatus: Enable interrupts, set to machine mode
    li t0, 0x00000008  # MIE bit
    csrw mstatus, t0

    # mie: Enable external interrupts
    li t0, 0x00000888  # MEIE, MSIE, MTIE
    csrw mie, t0

    # mtvec: Set trap vector base address
    la t0, trap_handler
    csrw mtvec, t0

    # Jump to main
    call main

    # Infinite loop after main returns
    j .

trap_handler:
    # Simple trap handler - just return
    mret

.align 4