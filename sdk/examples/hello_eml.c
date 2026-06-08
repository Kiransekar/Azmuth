/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/hello_eml.c — Minimal EML compute example
 * Software audit §S6.1
 *
 * Demonstrates: EML init, compute (exp - ln), fault check.
 * Runs on bare metal (no OS, no libc).
 */

#include "azmuth/xcew.h"
#include "azmuth/csr.h"

/* Simple UART output (placeholder — uses MMIO at 0x10000000) */
static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;

static void uart_putc(char c) {
    *UART_TX = (uint32_t)c;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

static void uart_puthex(uint32_t val) {
    const char hex[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) {
        uart_putc(hex[(val >> i) & 0xF]);
    }
}

int main(void) {
    uart_puts("Azmuth EML Example\r\n");

    /* Initialize EML in tree mode (mode=0) */
    xcew_eml_t eml;
    int rc = xcew_eml_init(&eml, 0);
    if (rc != XCEW_OK) {
        uart_puts("ERR: EML init failed\r\n");
        return -1;
    }

    /* Compute exp(2.0) - ln(1.0) in Q16.16
     * 2.0 in Q16.16 = 0x00020000
     * 1.0 in Q16.16 = 0x00010000
     * Expected: exp(2.0) ≈ 7.389 → 0x00076276
     *           ln(1.0)  = 0.0   → 0x00000000
     *           Result   ≈ 7.389 → 0x00076276 */
    uint32_t input = 0x00020000;   /* 2.0 */
    uint32_t output;

    rc = xcew_eml_compute(&eml, input, &output);
    if (rc != XCEW_OK) {
        uart_puts("ERR: EML compute failed\r\n");
        return -1;
    }

    uart_puts("EML result (Q16.16): 0x");
    uart_puthex(output);
    uart_puts("\r\n");

    /* Check for faults */
    uint32_t fault;
    xcew_fault_get_status(&fault);
    if (fault) {
        uart_puts("WARN: Fault status: 0x");
        uart_puthex(fault);
        uart_puts("\r\n");
        xcew_fault_clear(fault);
    }

    xcew_eml_close(&eml);
    uart_puts("Done.\r\n");

    return 0;
}
