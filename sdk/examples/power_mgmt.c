/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/power_mgmt.c — Power management example
 * Software audit §S6.4
 *
 * Demonstrates: tile sleep/wake, power bias, duty-cycling for energy savings.
 */

#include "azmuth/xcew.h"

static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;
static void uart_puts(const char *s) { while (*s) *UART_TX = (uint32_t)*s++; }

/* Simple delay (loop-based, ~10 cycles per iteration) */
static void delay(uint32_t count) {
    volatile uint32_t i;
    for (i = 0; i < count; i++) __asm__ volatile("");
}

int main(void) {
    uart_puts("Power Management Demo\r\n");

    /* Sleep all tiles initially */
    uart_puts("Sleeping all tiles...\r\n");
    xcew_pwr_tile_sleep(0);  /* EML */
    xcew_pwr_tile_sleep(1);  /* NVM */
    xcew_pwr_tile_sleep(2);  /* SNN */

    /* Set low-power bias voltage */
    xcew_pwr_set_bias(-2);   /* Reduce Vth for leakage savings */
    uart_puts("Bias set to -2 (low leakage mode)\r\n");

    /* Duty-cycle: wake EML, compute, sleep */
    uart_puts("\r\nDuty cycling EML...\r\n");
    for (int cycle = 0; cycle < 3; cycle++) {
        xcew_pwr_tile_wake(0);  /* Wake EML */
        delay(10);              /* Stabilize (~100 cycles) */

        /* Do EML work */
        xcew_eml_t eml;
        xcew_eml_init(&eml, 0);
        uint32_t result;
        xcew_eml_compute(&eml, 0x00010000, &result);  /* exp(1.0) */
        xcew_eml_close(&eml);

        xcew_pwr_tile_sleep(0);  /* Sleep EML */
        uart_puts("  Cycle done, EML sleeping\r\n");

        delay(100);  /* Sleep period */
    }

    /* Set normal bias for active work */
    xcew_pwr_set_bias(0);
    uart_puts("\r\nBias restored to nominal.\r\n");

    /* Wake all for normal operation */
    xcew_pwr_tile_wake(0);
    xcew_pwr_tile_wake(1);
    xcew_pwr_tile_wake(2);
    uart_puts("All tiles awake.\r\nDone.\r\n");

    return 0;
}
