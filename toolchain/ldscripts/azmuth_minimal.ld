/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * azmuth_minimal.ld — Linker script for Azmuth (standalone, no NVM)
 * Software audit §S2.3
 *
 * Memory map:
 *   Boot ROM: 0x0000_0000 – 0x0000_0FFF (4KB, read-only)
 *   SRAM:     0x0000_1000 – 0x0000_1FFF (4KB, read-write)
 *   EML CSR:  0x0000_2000 – 0x0000_2FFF (4KB, device)
 *   SNN CSR:  0x0000_3000 – 0x0000_3FFF (4KB, device)
 *   NVM CSR:  0x0000_4000 – 0x0000_4FFF (4KB, device)
 */

ENTRY(_start)

MEMORY
{
    ROM  (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    SRAM (rwx) : ORIGIN = 0x00001000, LENGTH = 4K
}

SECTIONS
{
    /* Boot ROM: code + read-only data */
    .text : ALIGN(4)
    {
        *(.text.start)       /* crt0: _start must be first */
        *(.text.trap)        /* Trap handler */
        *(.text .text.*)     /* All other code */
        *(.rodata .rodata.*) /* Read-only data */
        . = ALIGN(4);
    } > ROM

    /* Data section: initialized data, loaded from ROM, runs in SRAM */
    __data_load_start = LOADADDR(.data);
    .data : ALIGN(4)
    {
        __data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > SRAM AT > ROM

    /* Global pointer: used for linker relaxation (if enabled) */
    PROVIDE(__global_pointer$ = __data_start + 0x800);

    /* BSS section: uninitialized data */
    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > SRAM

    /* Stack: grows downward from end of SRAM */
    __stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
    __stack_size = 512;
    __stack_bottom = __stack_top - __stack_size;

    /* Heap: between BSS end and stack bottom */
    __heap_start = __bss_end;
    __heap_end = __stack_bottom;

    /* Discard debugging sections to save ROM space */
    /DISCARD/ :
    {
        *(.comment)
        *(.debug*)
        *(.note*)
    }
}
