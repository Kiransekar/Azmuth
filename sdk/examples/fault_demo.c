/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/fault_demo.c — Fault monitoring and recovery example
 * Software audit §S6.3
 *
 * Demonstrates: fault detection, IRQ handler, CSR W1C clear.
 */

#include "azmuth/xcew.h"
#include "azmuth/csr.h"
#include <stdint.h>

static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;
static volatile uint32_t fault_seen = 0;

static void uart_puts(const char *s) {
    while (*s) *UART_TX = (uint32_t)*s++;
}

static void uart_puthex(uint32_t val) {
    const char hex[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) {
        *UART_TX = (uint32_t)hex[(val >> i) & 0xF];
    }
}

/* Override the weak default IRQ handler from trap_handler.S */
void irq_external_handler(void) {
    uint32_t fault;
    xcew_fault_get_status(&fault);

    uart_puts("IRQ: Fault detected! Status=0x");
    uart_puthex(fault);
    uart_puts("\r\n");

    /* Decode fault type */
    if (fault & 0x01) uart_puts("  - Watchdog trip\r\n");
    if (fault & 0x02) uart_puts("  - ECC single-bit (corrected)\r\n");
    if (fault & 0x04) uart_puts("  - ECC double-bit (uncorrectable!)\r\n");
    if (fault & 0x08) uart_puts("  - EML soft error\r\n");
    if (fault & 0x10) uart_puts("  - SNN soft error\r\n");
    if (fault & 0x20) uart_puts("  - NVM hard error\r\n");
    if (fault & 0x40) uart_puts("  - CSR violation\r\n");
    if (fault & 0x80) uart_puts("  - Instruction fault\r\n");

    /* Clear the fault (W1C semantics) */
    xcew_fault_clear(fault);
    fault_seen = 1;
}

int main(void) {
    uart_puts("Azmuth Fault Monitoring Demo\r\n");

    /* Enable deterministic policy with 1000-cycle timeout */
    xcew_policy_set_deterministic(1000);
    uart_puts("Policy determinism enabled (max 1000 cycles)\r\n");

    /* Enable interrupts (mie.MEIE + mstatus.MIE) */
    __asm__ volatile ("csrsi mie, 0x8");     /* MEIE = 1 */
    __asm__ volatile ("csrsi mstatus, 0x8"); /* MIE = 1 */

    /* Run a policy update (will complete within timeout) */
    xcew_policy_update(0, 0);
    uart_puts("Policy update 0 complete\r\n");

    /* Check fault status */
    uint32_t fault;
    xcew_fault_get_status(&fault);
    uart_puts("Current fault status: 0x");
    uart_puthex(fault);
    uart_puts("\r\n");

    if (fault == 0 && !fault_seen) {
        uart_puts("No faults detected — system healthy.\r\n");
    }

    /* Check NVM health */
    uint32_t scrub, corrected;
    xcew_nvm_get_stats(&scrub, &corrected);
    uart_puts("NVM: scrub=");
    uart_puthex(scrub);
    uart_puts(" corrected=");
    uart_puthex(corrected);
    uart_puts("\r\n");

    uart_puts("Done.\r\n");
    return 0;
}
