/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/nvm_persist.c — NVM persistence example
 * Software audit §S6.5
 *
 * Demonstrates: NVM read/write, ECC status, boot-count persistence.
 */

#include "azmuth/xcew.h"
#include <stdint.h>

static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;
static void uart_puts(const char *s) { while (*s) *UART_TX = (uint32_t)*s++; }
static void uart_puthex(uint32_t v) {
    const char h[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) *UART_TX = (uint32_t)h[(v >> i) & 0xF];
}

/* NVM layout */
#define NVM_BOOT_COUNT_ADDR 0x4000
#define NVM_CONFIG_ADDR     0x4004
#define NVM_WEIGHTS_ADDR    0x4100

int main(void) {
    uart_puts("NVM Persistence Demo\r\n");

    /* Read boot count from NVM */
    uint32_t boot_count = 0;
    int rc = xcew_nvm_read(NVM_BOOT_COUNT_ADDR, &boot_count, 4);
    if (rc != XCEW_OK) {
        uart_puts("ERR: NVM read failed\r\n");
        boot_count = 0;
    }

    uart_puts("Boot count: 0x");
    uart_puthex(boot_count);
    uart_puts("\r\n");

    /* Increment and write back */
    boot_count++;
    rc = xcew_nvm_write(NVM_BOOT_COUNT_ADDR, &boot_count, 4);
    if (rc != XCEW_OK) {
        uart_puts("ERR: NVM write failed\r\n");
    } else {
        uart_puts("Boot count incremented.\r\n");
    }

    /* Store a configuration word */
    uint32_t config = 0xCAFEBABE;
    xcew_nvm_write(NVM_CONFIG_ADDR, &config, 4);

    /* Read it back to verify */
    uint32_t readback = 0;
    xcew_nvm_read(NVM_CONFIG_ADDR, &readback, 4);
    uart_puts("Config readback: 0x");
    uart_puthex(readback);
    uart_puts(readback == config ? " (match)\r\n" : " (MISMATCH!)\r\n");

    /* Check ECC health */
    uint32_t scrub, corrected;
    xcew_nvm_get_stats(&scrub, &corrected);
    uart_puts("ECC scrubs: 0x");
    uart_puthex(scrub);
    uart_puts("  corrections: 0x");
    uart_puthex(corrected);
    uart_puts("\r\n");

    uart_puts("Done.\r\n");
    return 0;
}
