/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/snn_classify.c — SNN classification example
 * Software audit §S6.2
 *
 * Demonstrates: SNN init, weight loading, classify, power management.
 */

#include "azmuth/xcew.h"
#include "azmuth/csr.h"

static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;

static void uart_puts(const char *s) {
    while (*s) *UART_TX = (uint32_t)*s++;
}

static void uart_putdec(uint32_t val) {
    char buf[12];
    int i = 10;
    buf[11] = '\0';
    do {
        buf[i--] = '0' + (val % 10);
        val /= 10;
    } while (val && i >= 0);
    uart_puts(&buf[i + 1]);
}

int main(void) {
    uart_puts("Azmuth SNN Classification Example\r\n");

    /* Wake SNN tile (may be sleeping) */
    xcew_pwr_tile_wake(2);  /* tile 2 = SNN */

    /* Initialize SNN with 4 neurons */
    xcew_snn_t snn;
    int rc = xcew_snn_init(&snn, 4);
    if (rc != XCEW_OK) {
        uart_puts("ERR: SNN init failed\r\n");
        return -1;
    }

    /* Load simple weights (identity-like pattern) */
    int8_t weights[4] = {100, -50, 30, -10};
    rc = xcew_snn_load_weights(&snn, weights, 4);
    if (rc != XCEW_OK) {
        uart_puts("ERR: Weight load failed\r\n");
        return -1;
    }

    /* Classify a sample input */
    int8_t input[4] = {80, 20, 60, 10};
    uint32_t class_id;

    rc = xcew_snn_classify(&snn, input, &class_id);
    if (rc != XCEW_OK) {
        uart_puts("ERR: SNN classify failed\r\n");
        return -1;
    }

    uart_puts("Classification result: class ");
    uart_putdec(class_id);
    uart_puts("\r\n");

    /* Enable STDP learning with policy 1 */
    xcew_snn_enable_stdp(&snn, 1);
    uart_puts("STDP learning enabled (policy 1)\r\n");

    /* Sleep SNN tile when done to save power */
    xcew_snn_close(&snn);
    xcew_pwr_tile_sleep(2);
    uart_puts("SNN tile sleeping.\r\n");

    return 0;
}
