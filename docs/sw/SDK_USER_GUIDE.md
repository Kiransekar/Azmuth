<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth SDK User Guide

**Audit reference:** Software §S7.1
**Date:** 2026-06-06

## What Is the Azmuth SDK?

The Azmuth SDK provides everything needed to write bare-metal firmware for the
Azmuth v1.1 processor. It includes:

- **libxcew** — C library for accessing EML, SNN, NVM, policy, power, and fault
  hardware
- **Headers** — `xcew.h` (API), `csr.h` (CSR addresses and macros)
- **Firmware** — `crt0.S` (startup), `trap_handler.S` (interrupts), `boot.S`
  (boot ROM)
- **Linker scripts** — Memory layout for ROM + SRAM targets
- **Examples** — 8 complete programs demonstrating each subsystem

## Quick Start

### Prerequisites

- RISC-V GNU toolchain: `riscv64-unknown-elf-gcc` (with `-march=rv32i` support)
- GNU Make

### Build libxcew

```bash
cd sdk/
make
# Output: lib/libxcew.a
```

### Build an Example

```bash
riscv64-unknown-elf-gcc \
    -march=rv32i -mabi=ilp32 -mcmodel=medlow -fno-pic \
    -Os -nostdlib -ffreestanding \
    -Iinclude \
    -T ../toolchain/ldscripts/azmuth_minimal.ld \
    ../firmware/crt0.S \
    ../firmware/trap_handler.S \
    examples/hello_eml.c \
    -Llib -lxcew \
    -o hello_eml.elf
```

### Run on Simulator

```bash
# Convert ELF to hex for Verilator/iverilog
riscv64-unknown-elf-objcopy -O verilog hello_eml.elf hello_eml.hex
# Load into simulation memory and run
```

## API Overview

### EML (Expression Machine Learning)

```c
xcew_eml_t eml;
xcew_eml_init(&eml, 0);          /* mode=0: tree evaluation */
uint32_t result;
xcew_eml_compute(&eml, input, &result);  /* Q16.16 fixed-point */
xcew_eml_close(&eml);
```

### SNN (Spiking Neural Network)

```c
xcew_snn_t snn;
xcew_snn_init(&snn, 128);        /* 128 neurons */
xcew_snn_load_weights(&snn, weights, 128);
uint32_t class_id;
xcew_snn_classify(&snn, input, &class_id);
xcew_snn_enable_stdp(&snn, 1);   /* Online learning */
xcew_snn_close(&snn);
```

### NVM (Non-Volatile Memory)

```c
uint32_t data;
xcew_nvm_read(0x4000, &data, 4);
data++;
xcew_nvm_write(0x4000, &data, 4);
```

### Power Management

```c
xcew_pwr_tile_sleep(2);    /* Sleep SNN tile */
xcew_pwr_tile_wake(2);     /* Wake SNN tile */
xcew_pwr_set_bias(-2);     /* Low-leakage bias */
```

### Fault Monitoring

```c
uint32_t fault;
xcew_fault_get_status(&fault);
if (fault) xcew_fault_clear(fault);
```

### Policy

```c
xcew_policy_set_deterministic(1000);  /* Max 1000 cycles */
xcew_policy_update(0, params);
```

## Memory Map

| Region | Address | Size | Description |
|--------|---------|------|-------------|
| Boot ROM | 0x00000000 | 4 KB | Boot code (read-only on silicon) |
| SRAM | 0x00010000 | 64 KB | Code + data + stack |
| UART | 0x10000000 | 4 B | TX register |
| EML CSR | 0x2000 | 256 B | EML configuration |
| SNN CSR | 0x3000 | 4 KB | SNN weights + control |
| NVM CSR | 0x4000 | 4 KB | NVM data window |

## Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | `XCEW_OK` | Success |
| -1 | `XCEW_ERR_INVALID` | Invalid parameter |
| -2 | `XCEW_ERR_TIMEOUT` | Operation timed out |
| -3 | `XCEW_ERR_FAULT` | Hardware fault detected |
| -4 | `XCEW_ERR_ECC` | Uncorrectable ECC error |

## Examples

| Example | File | What it demonstrates |
|---------|------|---------------------|
| Hello EML | `hello_eml.c` | Basic EML compute |
| SNN Classify | `snn_classify.c` | SNN init, weights, classify, STDP |
| Fault Demo | `fault_demo.c` | Fault IRQ handler, CSR W1C |
| Power Mgmt | `power_mgmt.c` | Tile sleep/wake, bias, duty-cycling |
| NVM Persist | `nvm_persist.c` | NVM read/write, ECC stats |
| Multi-Subsystem | `multi_subsystem.c` | EML→SNN→NVM pipeline |
| IRQ Driven | `irq_driven.c` | Interrupt-driven processing |
| Bare Metal Blinky | `bare_metal_blinky.c` | Board bringup validation |

## Interrupts

Azmuth supports M-mode interrupts only. To use interrupts:

1. Install a trap handler (default in `trap_handler.S`)
2. Override weak handler symbols (e.g., `irq_external_handler`)
3. Enable MIE in mstatus and MEIE in mie

```c
void irq_external_handler(void) {
    /* Your interrupt code here */
}
```

## CSR Quick Reference

See `sdk/include/azmuth/csr.h` for complete list. Key CSRs:

| Address | Name | Description |
|---------|------|-------------|
| 0x7C0 | xcew_cfg | Precision, max depth, branch cut |
| 0x7C1 | xcew_status | Tile presence (DEV-003: may be static) |
| 0x7C5 | snn_ctrl | Neuron count, TTFS enable |
| 0x7C8 | pwr_ctrl | Tile sleep/wake requests |
| 0x7CB | pol_sec | Deterministic policy control |
| 0x7CC | fault_status | Fault codes (W1C) |
| 0x7CD | watchdog_limit | Watchdog timeout value |
