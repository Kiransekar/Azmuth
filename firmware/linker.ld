SECTIONS
{
    /* Program code and read-only data */
    . = 0x00000000;
    .text : {
        *(.text.start)
        *(.text)
        *(.rodata)
    }

    /* Initialized data */
    . = 0x00010000;
    .data : {
        *(.data)
    }

    /* Uninitialized data (zero-initialized) */
    .bss : {
        *(.bss)
        *(COMMON)
    }

    /* Define end of memory */
    _end = .;
}

/* Stack pointer location */
PROVIDE(__stack_start = 0x0001FFFC);