/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/bare_metal_blinky.c — Minimal bare-metal "blinky" for board bringup
 * Software audit §S6.8
 *
 * The simplest possible program: writes characters to UART in a loop.
 * Used to verify the boot chain (boot.S → crt0.S → main()) works on
 * first silicon. No Xcew dependencies.
 */

#include <stdint.h>

static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;

static void uart_putc(char c) {
    *UART_TX = (uint32_t)c;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

static void delay(uint32_t count) {
    volatile uint32_t i;
    for (i = 0; i < count; i++) __asm__ volatile("");
}

int main(void) {
    uart_puts("Azmuth v1.1 Boot OK\r\n");

    /* Read mhartid to verify CSR access */
    uint32_t hartid;
    __asm__ volatile ("csrr %0, mhartid" : "=r"(hartid));
    uart_puts("Hart ID: ");
    uart_putc('0' + (hartid & 0xF));
    uart_puts("\r\n");

    /* Read misa to verify ISA configuration */
    uint32_t misa;
    __asm__ volatile ("csrr %0, misa" : "=r"(misa));
    uart_puts("MISA: ");
    if (misa & (1 << 8))  uart_putc('I');  /* Base integer */
    if (misa & (1 << 12)) uart_putc('M');  /* Multiply */
    if (misa & (1 << 2))  uart_putc('C');  /* Compressed */
    uart_puts("\r\n");

    /* Blinky loop: output a heartbeat character every ~1M cycles */
    int count = 0;
    while (1) {
        uart_putc('.');
        count++;
        if (count % 40 == 0) uart_puts("\r\n");
        delay(100000);

        /* Safety: exit after 200 beats (for simulation) */
        if (count >= 200) break;
    }

    uart_puts("\r\nHalting.\r\n");
    return 0;
}
