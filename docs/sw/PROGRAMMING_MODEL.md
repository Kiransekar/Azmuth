<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Xcew Programming Model

**Audit reference:** Software §S4.5
**Date:** 2026-06-06

## Architecture Overview

Azmuth extends the RISC-V RV32I base with the **Xcew** (Cognitive Electronic
Warfare) custom extension. The extension provides hardware acceleration for:

1. **EML** — Expression Machine Learning: evaluation of pre-compiled mathematical
   expressions (activation functions, softmax, polynomial approximations)
2. **SNN** — Spiking Neural Network: leaky-integrate-and-fire (LIF) classification
   with time-to-first-spike (TTFS) encoding and STDP learning
3. **NVM** — Non-Volatile Memory: ECC-protected persistent storage with hardware
   scrub
4. **Policy** — Deterministic policy execution with fixed-cycle enforcement

## Execution Model

### Synchronous Dispatch

All Xcew instructions use the **synchronous stall** model: the RISC-V pipeline
stalls (holds PC and pipeline registers) until the accelerator completes. There
is no out-of-order execution or speculative dispatch.

```
┌─────────┐     ┌──────────┐     ┌─────────┐
│  IF     │────▶│ ID/EX    │────▶│  WB     │
│ (fetch) │     │ (decode+ │     │ (write  │
│         │     │  execute)│     │  back)  │
└─────────┘     └──────────┘     └─────────┘
                     │
                     │ Xcew instruction detected
                     ▼
                ┌──────────┐
                │ Pipeline │
                │  STALL   │◀─── i_xcew_done = 0
                └──────────┘
                     │
                     │ Accelerator completes
                     ▼
                ┌──────────┐
                │ Result   │
                │ writeback│──── rd = xcew_result
                └──────────┘
```

### Register Convention

Xcew instructions use the standard R-type encoding:
- **rs1, rs2**: input operands (read from integer register file)
- **rd**: result destination (written to integer register file)
- **funct3**: sub-operation selector (for custom-3 only)
- **funct7**: reserved (must be 0 for forward compatibility)

### CSR Configuration

Xcew behavior is configured via custom CSRs in the 0x7C0–0x7CF range. CSR
writes take effect immediately (single-cycle). The recommended pattern:

```c
// 1. Configure the accelerator
CSR_WRITE(CSR_XCEW_CFG, XCEW_CFG_PRECISION(2) | XCEW_CFG_MAX_DEPTH(3));
CSR_WRITE(CSR_SEC_CTRL, 1);  // Enable constant-time mode

// 2. Issue Xcew instruction (pipeline stalls until done)
uint32_t result;
XCEW_EML(result, expr_id, input);

// 3. Check for faults
uint32_t fault = CSR_READ(CSR_FAULT_STATUS);
if (fault) { /* handle */ }
```

## Power Management

Tiles (EML, SNN, NVM) can be independently power-gated:

```c
// Put SNN tile to sleep when not classifying
xcew_pwr_tile_sleep(2);  // tile_id=2 = SNN

// ... do non-SNN work ...

// Wake SNN before classification
xcew_pwr_tile_wake(2);
uint32_t class_id;
xcew_snn_classify(&snn, features, &class_id);
```

The orchestrator FSM handles isolation, retention, and clock gating
automatically. A sleeping tile preserves its state (retention registers).
Wake latency is ~10 cycles for clock stabilization.

## Interrupt Model

Azmuth supports M-mode interrupts only (no S/U mode):

| Source | mie bit | Use |
|--------|---------|-----|
| Machine External (MEIP) | [11] | Fault/timeout aggregate |
| Machine Timer (MTIP) | [7] | External timer (if connected) |
| Machine Software (MSIP) | [3] | Software-triggered (if connected) |

The firmware must install a trap handler at `mtvec` before enabling interrupts.
Traps are only taken when `mtvec != 0` (DECISION-009).

## Concurrency & Ordering

- **Single-hart:** no multi-threaded programming model
- **In-order:** instructions execute in program order
- **FENCE is NOP:** single hart with no cache hierarchy
- **No load-use interlock:** (DEV-007) — structurally safe in single-issue in-order pipeline
- **Xcew stalls are blocking:** firmware cannot overlap Xcew with integer work

## Error Handling

Faults are reported via `fault_status` CSR (0x7CC) with W1C semantics:

```c
uint32_t fault;
xcew_fault_get_status(&fault);
if (fault & FAULT_ECC_DOUBLE) {
    // Uncorrectable NVM error — data is corrupt
    xcew_fault_clear(FAULT_ECC_DOUBLE);
    // ... recovery logic ...
}
```

Hard faults (ECC double, NVM failure) halt the pipeline. Soft faults (ECC
single, overflow) notify via IRQ but allow continued execution.
