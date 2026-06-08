<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Boot ROM Specification

**Audit reference:** Software §S2.1
**Date:** 2026-06-06

## Overview

The Boot ROM occupies 4KB at address range 0x0000–0x0FFF (slave s0 on the AXI
interconnect). It is read-only in hardware — the AXI address decoder routes
writes to s0 as a no-op. ROM contents are fixed at fabrication time.

## Boot Sequence (firmware)

```
Phase 0: Hardware POR (see POR_SEQUENCE.md)
  └── Clocks stable, i_rst deasserted, PC = 0x0000

Phase 1: Stack initialization (crt0.S)
  ├── sp = __stack_top (0x1FFF)
  ├── gp = __global_pointer$ (data segment base + 0x800)
  └── Clear .bss, copy .data from ROM to SRAM

Phase 2: Trap handler installation (crt0.S)
  └── mtvec = &_trap_handler

Phase 3: Self-test (boot ROM code)
  ├── CRC-32 check: compute CRC over ROM[0x0000..0x0FFB],
  │   compare vs stored value at ROM[0x0FFC..0x0FFF]
  │   FAIL → assert INSTR_FAULT via CSR 0x7CC, halt
  ├── Body-bias calibration wait: poll bias_ctrl.cal_done
  └── NVM controller init + ECC scrub

Phase 4: Application handoff (crt0.S → main.c)
  └── jal main
```

## Memory Layout

| Offset | Content | Size |
|--------|---------|------|
| 0x0000 | `_start` (reset vector) | Variable |
| 0x0004+ | `_trap_handler` | ~300 bytes |
| ... | Boot ROM firmware code | Variable |
| 0x0F00 | `.rodata` (constants, CRC table) | Variable |
| 0x0FFC | CRC-32 checksum of ROM[0x0000..0x0FFB] | 4 bytes |

## CRC-32 Integrity Check

Algorithm: CRC-32/ISO-HDLC (polynomial 0x04C11DB7, init 0xFFFFFFFF, final XOR
0xFFFFFFFF, reflected I/O).

The CRC is computed at build time by the Makefile and inserted at offset 0x0FFC
in the ROM image. The boot firmware recomputes and compares.

## Failure Modes

| Failure | Detection | Response |
|---------|-----------|----------|
| CRC mismatch | Software CRC check | Assert INSTR_FAULT (0x7CC[7]), infinite halt |
| Body-bias cal timeout | Cal FSM timeout (>10000 cycles) | Assert fault, continue with default bias |
| NVM not present | NVM_BUSY timeout | Continue without NVM (degraded mode) |

## Hardware Dependencies

- HW §3.5 POR sequence (reset + clock stability)
- HW §1.5.1 External NVM (NVM controller init path)
- HW §6.4 Caravel integration (`azmuth_caravel.ld` variant for Caravel memory map)
