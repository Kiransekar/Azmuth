/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
 * Copyright (c) 2026 Kiransekar. All rights reserved.
 *
 * examples/multi_subsystem.c — Multi-subsystem pipeline example
 * Software audit §S6.6
 *
 * Demonstrates: EML → SNN → NVM full pipeline.
 * Use case: Feature extraction (EML) → Classification (SNN) → Result storage (NVM).
 */

#include "azmuth/xcew.h"

static volatile uint32_t *const UART_TX = (volatile uint32_t *)0x10000000;
static void uart_puts(const char *s) { while (*s) *UART_TX = (uint32_t)*s++; }
static void uart_putdec(uint32_t v) {
    char b[12]; int i = 10; b[11] = 0;
    do { b[i--] = '0' + v % 10; v /= 10; } while (v && i >= 0);
    uart_puts(&b[i + 1]);
}

/* Simulated sensor readings (Q16.16 fixed-point) */
static const uint32_t sensor_data[4] = {
    0x00020000,  /* 2.0 */
    0x00018000,  /* 1.5 */
    0x00030000,  /* 3.0 */
    0x00008000,  /* 0.5 */
};

int main(void) {
    uart_puts("Multi-Subsystem Pipeline Demo\r\n");

    /* Wake all tiles */
    xcew_pwr_tile_wake(0);  /* EML */
    xcew_pwr_tile_wake(1);  /* NVM */
    xcew_pwr_tile_wake(2);  /* SNN */

    /* ── Stage 1: Feature extraction via EML ──────────────── */
    uart_puts("\n[Stage 1] EML Feature Extraction\r\n");
    xcew_eml_t eml;
    xcew_eml_init(&eml, 0);

    uint32_t features[4];
    for (int i = 0; i < 4; i++) {
        xcew_eml_compute(&eml, sensor_data[i], &features[i]);
    }
    xcew_eml_close(&eml);
    uart_puts("  4 features extracted.\r\n");

    /* ── Stage 2: Classification via SNN ──────────────────── */
    uart_puts("[Stage 2] SNN Classification\r\n");
    xcew_snn_t snn;
    xcew_snn_init(&snn, 4);

    int8_t weights[4] = {100, -50, 30, -10};
    xcew_snn_load_weights(&snn, weights, 4);

    int8_t snn_input[4];
    for (int i = 0; i < 4; i++) {
        snn_input[i] = (int8_t)((features[i] >> 16) & 0xFF);  /* Q16.16 → int8 */
    }

    uint32_t class_id;
    xcew_snn_classify(&snn, snn_input, &class_id);
    xcew_snn_close(&snn);

    uart_puts("  Classification: class ");
    uart_putdec(class_id);
    uart_puts("\r\n");

    /* ── Stage 3: Store result in NVM ─────────────────────── */
    uart_puts("[Stage 3] NVM Result Storage\r\n");
    uint32_t result_record[2] = {class_id, features[0]};
    int rc = xcew_nvm_write(0x4200, result_record, 8);
    if (rc == XCEW_OK) {
        uart_puts("  Result stored at NVM 0x4200.\r\n");
    } else {
        uart_puts("  ERR: NVM write failed.\r\n");
    }

    /* ── Cleanup ──────────────────────────────────────────── */
    xcew_pwr_tile_sleep(0);
    xcew_pwr_tile_sleep(2);
    uart_puts("\nPipeline complete. EML+SNN sleeping.\r\n");

    return 0;
}
