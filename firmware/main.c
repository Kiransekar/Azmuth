// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
#include <stdint.h>

// Memory-mapped I/O addresses
#define EML_CSR_ADDR     0x00020000
#define SNN_CTRL_ADDR    0x00021000
#define NVM_CTRL_ADDR    0x00022000
#define UART_WRITE_ADDR  0x00030000
#define RF_BUFFER_ADDR   0x00010000  // Dummy RF buffer in SRAM
#define SRAM_START       0x00010000

// Xcew custom instructions
static inline uint32_t eml_exec(uint32_t rs1, uint32_t rs2) {
    uint32_t result;
    asm volatile (
        ".word 0x00B00093\n\t"  // Custom EML instruction (0b0001011)
        : "=r"(result)
        : "r"(rs1), "r"(rs2)
    );
    return result;
}

static inline void eml_cfg_write(uint32_t cfg) {
    *(volatile uint32_t*)EML_CSR_ADDR = cfg;
}

static inline uint32_t eml_cfg_read(void) {
    return *(volatile uint32_t*)EML_CSR_ADDR;
}

static inline void snn_ctrl_write(uint32_t val) {
    *(volatile uint32_t*)SNN_CTRL_ADDR = val;
}

static inline uint32_t snn_classify(uint32_t buffer_addr) {
    // This would trigger the SNN classification process
    // For simulation, we'll write the buffer address and return a result
    *(volatile uint32_t*)SNN_CTRL_ADDR = buffer_addr | 0x80000000; // Trigger bit
    // Wait for completion (in simulation this is instant)
    return *(volatile uint32_t*)(SNN_CTRL_ADDR + 4); // Read classification result
}

static inline void pol_update(uint32_t addr, uint32_t val1, uint32_t val2) {
    // Write to NVM at specified address
    *(volatile uint32_t*)(NVM_CTRL_ADDR + (addr & 0xFFF)) = val1;
    *(volatile uint32_t*)(NVM_CTRL_ADDR + ((addr + 4) & 0xFFF)) = val2;
}

static inline void uart_write(uint32_t addr, uint8_t data) {
    *(volatile uint8_t*)addr = data;
}

// Simple delay function
static void delay(volatile int count) {
    while(count--);
}

int main() {
    uint32_t result;
    uint8_t pass_fail = 0;

    // a. Configure EML: set COMPLEX=0, DEPTH=5, PRECISION=BF16
    eml_cfg_write(0x8000);  // 0b1000_0000_0000: COMPLEX=0, DEPTH=5, PRECISION=BF16

    // b. Test EML: eml_exec(1.0, 1.0) should return approximately exp(1) - ln(1) = e - 0 ≈ 1.718
    // In IEEE 754 BF16 format: 1.0 = 0x3F800000
    result = eml_exec(0x3F800000, 0x3F800000);
    // Expected: exp(1.0) - ln(1.0) = 2.71828... -> in BF16 ~0x402DF854

    // Basic check: result should be roughly 2.718 in BF16 format
    if ((result & 0xFFFF0000) == 0x402D0000) {  // Approximate check
        pass_fail |= 0x01;  // EML test passed
    }

    // c. Configure SNN: enable 256 neurons, learning rate=0.01
    snn_ctrl_write(0x01);

    // d. Trigger classification: read from dummy RF buffer in SRAM
    result = snn_classify(RF_BUFFER_ADDR);

    // Simple check for reasonable classification result
    if (result != 0) {
        pass_fail |= 0x02;  // SNN test passed
    }

    // e. Update policy: write to NVM window
    pol_update(0x00022000, 0x00000001, 0x00000001);

    // f. Print result: write PASS/FAIL byte to UART
    uart_write(UART_WRITE_ADDR, pass_fail);

    // g. Loop: simulate feedback → adjust EML params → re-synthesize → log outcome
    int iteration = 0;
    while (iteration < 10) {
        // Adjust EML parameters for feedback loop
        uint32_t new_cfg = eml_cfg_read();
        new_cfg ^= (iteration << 4); // Modify precision slightly each iteration

        eml_cfg_write(new_cfg);

        // Re-test with adjusted parameters
        result = eml_exec(0x40000000, 0x3F800000);  // 2.0, 1.0

        // Log outcome (write to SRAM for monitoring)
        *(volatile uint32_t*)(SRAM_START + (iteration * 4)) = result;

        iteration++;

        // Small delay
        delay(1000);
    }

    // Final result
    uart_write(UART_WRITE_ADDR + 1, 0xFF); // End marker

    return 0;
}