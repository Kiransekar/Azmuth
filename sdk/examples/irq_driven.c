/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/irq_driven.c — Interrupt-driven processing example
 * Software audit §S6.7
 *
 * Demonstrates: interrupt handler, fault-driven processing, CSR polling.
 */

#include "azmuth/xcew.h"
#include "azmuth/csr.h"

static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;
static void uart_puts(const char *s) { while (*s) *UART_TX = (uint32_t)*s++; }

/* Shared state between ISR and main loop */
static volatile uint32_t irq_count = 0;
static volatile uint32_t last_fault = 0;

/* Override weak default handler from trap_handler.S */
void irq_external_handler(void) {
    uint32_t fault;
    xcew_fault_get_status(&fault);
    last_fault = fault;
    irq_count++;

    /* Clear the fault */
    xcew_fault_clear(fault);
}

int main(void) {
    uart_puts("Interrupt-Driven Processing Demo\r\n");

    /* Configure trap handler and enable interrupts */
    __asm__ volatile ("csrsi mie, 0x8");      /* MEIE = 1 */
    __asm__ volatile ("csrsi mstatus, 0x8");  /* MIE = 1 */

    uart_puts("Interrupts enabled.\r\n");

    /* Main processing loop — poll for work, handle interrupts */
    for (int iter = 0; iter < 5; iter++) {
        /* Do some EML work */
        xcew_eml_t eml;
        xcew_eml_init(&eml, 0);
        uint32_t result;
        xcew_eml_compute(&eml, 0x00010000 * (iter + 1), &result);
        xcew_eml_close(&eml);

        /* Check if any interrupts occurred during processing */
        if (irq_count > 0) {
            uart_puts("  IRQ occurred during iteration ");
            *UART_TX = '0' + iter;
            uart_puts(", fault=0x");
            const char h[] = "0123456789ABCDEF";
            for (int i = 28; i >= 0; i -= 4)
                *UART_TX = (uint32_t)h[(last_fault >> i) & 0xF];
            uart_puts("\r\n");
            irq_count = 0;  /* Reset counter */
        }

        /* Poll fault status (non-interrupt path) */
        uint32_t fault;
        xcew_fault_get_status(&fault);
        if (fault) {
            uart_puts("  Polled fault detected, clearing.\r\n");
            xcew_fault_clear(fault);
        }
    }

    uart_puts("Processing complete.\r\n");

    /* Disable interrupts before exit */
    __asm__ volatile ("csrci mstatus, 0x8");  /* Clear MIE */
    uart_puts("Interrupts disabled. Done.\r\n");

    return 0;
}
