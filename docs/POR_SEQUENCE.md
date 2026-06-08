<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Power-On Reset (POR) Sequence

**Audit reference:** Tapeout §3.5
**Date:** 2026-06-06

## Sequence Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Step 0: Power Rails Ramp                                     │
│   VDD, VDDIO stabilize (external, ~1-10ms)                  │
├─────────────────────────────────────────────────────────────┤
│ Step 1: POR Reset Assertion                                  │
│   i_rst = 1 held by external POR circuit (min 100 cycles)    │
│   All domains enter reset state per RESET_ARCH.md            │
├─────────────────────────────────────────────────────────────┤
│ Step 2: Reset Deassert                                       │
│   i_rst → 0 (synchronous release per domain)                 │
│   PC = RESET_PC (0x0000 default, Boot ROM start)             │
├─────────────────────────────────────────────────────────────┤
│ Step 3: Body-Bias DAC Calibration (~1000 cycles)             │
│   body_bias_ctrl sweeps P/N-well bias codes                  │
│   Leakage sensor feedback drives calibration FSM             │
│   Firmware polls bias_ctrl CSR (0x7C9) for cal_done          │
├─────────────────────────────────────────────────────────────┤
│ Step 4: ROM CRC Verification                                 │
│   Boot ROM firmware computes CRC-32 of ROM contents          │
│   Compares against stored value at ROM[0x0FFC]               │
│   FAIL → halt, assert fault_status INSTR_FAULT               │
├─────────────────────────────────────────────────────────────┤
│ Step 5: NVM Controller Init                                  │
│   Configure NVM controller via CSR 0x4xxx                    │
│   Power-on ECC scrub (reads all locations, corrects SBE)     │
│   scrub_count CSR (0x7CE) tracks progress                    │
├─────────────────────────────────────────────────────────────┤
│ Step 6: SRAM Initialization                                  │
│   Clear .bss section to zero                                 │
│   Copy .data from ROM/NVM to SRAM                            │
├─────────────────────────────────────────────────────────────┤
│ Step 7: Configure Interrupts & CSRs                          │
│   Set mtvec to trap handler address                          │
│   Configure xcew_cfg (0x7C0) defaults                        │
│   Configure sec_ctrl (0x7CA) defaults                        │
│   Enable relevant interrupts via mie                         │
├─────────────────────────────────────────────────────────────┤
│ Step 8: Jump to User Firmware                                │
│   Stack pointer set to top of SRAM (0x1FFF)                  │
│   Jump to _start / main() at 0x1000                          │
└─────────────────────────────────────────────────────────────┘
```

## Timing Budget

| Step | Est. Cycles (@250 MHz) | Est. Time | Notes |
|------|----------------------|-----------|-------|
| 0. Rails ramp | N/A | 1–10 ms | External |
| 1. Reset held | ≥100 | 400 ns | External POR circuit |
| 2. Reset deassert | 1 | 4 ns | Per-domain synchronizer |
| 3. Body-bias cal | ~1000 | 4 µs | Calibration sweep |
| 4. ROM CRC | ~1024 | 4 µs | 4KB / 4B per cycle |
| 5. NVM scrub | ~65536 | 262 µs | 64KB / 1B per cycle |
| 6. SRAM init | ~1024 | 4 µs | 4KB / 4B per cycle |
| 7. CSR config | ~20 | 80 ns | ~20 CSR writes |
| 8. Jump to user | 1 | 4 ns | JAL |
| **Total** | **~69K** | **~275 µs** | Boot ROM to main() |

## Failure Handling

| Failure | Detection | Response |
|---------|-----------|----------|
| Body-bias cal timeout | Cal FSM watchdog | Assert fault_status, halt |
| ROM CRC mismatch | Software CRC check | Assert INSTR_FAULT, halt |
| NVM not responding | Timeout on scrub | Assert NVM_BUSY fault, continue with degraded mode |
| SRAM failure | Future: MBIST (§3.4) | Assert fault, halt |

## Hardware-Software Interface

The POR sequence is split:
- **Steps 0–2:** Pure hardware (external POR + reset logic)
- **Steps 3–8:** Firmware in Boot ROM (`firmware/boot.S`)

The body-bias calibration (step 3) runs autonomously in hardware; firmware waits
for its completion flag before proceeding.
