<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Formal Verification Status Report

**Audit reference:** Tapeout §1.3(c)
**Date:** 2026-06-06

## Status: BLOCKED by solver performance

### Problem

The `.sby` files and `*_fv.sv` property wrappers are correctly structured and
pass Yosys elaboration. However, z3 SMT solver performance is inadequate for
the EML and SNN modules due to large internal memory arrays:

| Module | Array | Size (registers) | z3 time to step 0 |
|--------|-------|-------------------|-------------------|
| eml_unit | memo_tags[128], memo_data[128], memo_valid[128] | ~4,096 | >4 min (killed) |
| snn_tile_256 | Neuron state arrays (NUM_NEURONS=4) | ~512 | Estimated >10 min |
| fault_monitor | Moderate state machine | ~200 | Estimated 5-10 min |
| orchestrator | Moderate state machine | ~150 | Estimated 5-10 min |

### Evidence

```
SBY 14:11:17 [eml_quick] engine_0: ## 0:00:00 Solver: z3
SBY 14:15:41 [eml_quick] engine_0: ## 0:04:24 Checking assumptions in step 0..
SBY ---- Keyboard interrupt or external termination signal ----
```

z3 spent 4m24s just checking assumptions at step 0 of depth-10 BMC, before
beginning any actual property checking.

### Root Cause

The memo cache arrays (`memo_tags[128]`, `memo_data[128]`, `memo_valid[128]`)
are expanded to individual registers by Yosys `memory_map`, creating ~4K
individual state bits. This makes the SMT encoding enormous.

### Resolution Options

1. **Boolector engine** — typically 10-100x faster than z3 for hardware BMC.
   Not currently installed. Install with `pip install boolector` or build from
   source.

2. **Abstract memo cache** — create a simplified FV-specific model with a
   2-entry cache instead of 128-entry, proving the protocol correct without
   the full array. This keeps z3 tractable.

3. **Dedicated server run** — allocate a machine with 32+ GB RAM and let z3
   run for 30+ minutes per proof. Four proofs × 30 min = ~2 hours total.

4. **ABC engine with `aiger` backend** — Yosys's ABC integration can sometimes
   handle large designs faster than SMT-based BMC.

### Properties (18 total, all unproved)

| Suite | Properties | Status |
|-------|-----------|--------|
| eml_fv.sv | 3 (ready/valid complement, exc→valid, reset clears) | UNPROVED |
| snn_fv.sv | 5 (ready-in-idle, done-after-done, idle→load, class-range, counter-bound) | UNPROVED |
| security_fv.sv | 5 (halt→latch, irq→latch, latch-persists, csr-clears, reset-errcode) | UNPROVED |
| power_fv.sv | 5 (sleep→iso∧ret, iso→sleep, ret→sleep, wake-exits, activity-keeps) | UNPROVED |

### Recommendation

Install boolector and re-run, or allocate a dedicated 30-minute batch run.
The properties themselves are well-written and the FV wrappers correctly
instantiate the DUTs.
