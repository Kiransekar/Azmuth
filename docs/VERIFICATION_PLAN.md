<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Verification Plan

**Audit reference:** Tapeout §2.1
**Date:** 2026-06-06

## Strategy

Multi-method verification: simulation (directed + compliance), formal (BMC),
security empirical testing, and (future) gate-level simulation.

## Testbench Inventory

| Testbench | DUT | REQs Covered | Status | Evidence |
|-----------|-----|-------------|--------|----------|
| `core_tb.v` | `riscv_core` | PIPE-001..005, ISA-001..009, FSM-001..005, CSR-M01..M10 | PASS | `core_tb.log` |
| `isa_tb.v` | `riscv_core` | ISA-001..007 (ALU completeness) | PASS | `isa_tb.log` |
| `hazard_tb.v` | `riscv_core` | PIPE-006, ISA-005..006 (flush, branches, jumps) | PASS | `hazard_tb.log` |
| `trap_tb.v` | `riscv_core` | EXC-001..002, CSR-M04..M08 | PASS | `trap_tb.log` |
| `irq_tb.v` | `riscv_core` | IRQ-002, CSR-M03/M09 | PASS | `irq_tb.log` |
| `xcie_decoder_tb.v` | `xcie_decoder` | ISA-010..014 | PASS 10/10 | `decoder_tb.log` |
| `soc_tb.v` | `xcew_top_v1_1` SoC | MEM-001..005, AXI-001..003 | PASS | `soc_tb.log` |
| `top_tb.v` | `xcew_top_v1_1` | Integration | PASS | `top_tb.log` |
| `snn_tile_256_tb.v` | `snn_tile_256` | SNN classification | PASS | `snn_tile_256_tb.log` |
| `security_empirical_tb.v` | `fault_monitor` | Fault codes 1-8, W1C, IRQ, watchdog | PASS 17/17 | `security_empirical_tb.log` |
| `eml_timing_tb.v` | `eml_unit` | Constant-time (§4.1) | MARGINAL (1-cycle var.) | `eml_timing_tb.log` |
| `policy_det_tb.v` | `policy_determinism` | Det. policy (§4.2) | 3 FAIL (FSM reset) | `policy_det_tb.log` |
| `cosim_tb.v` | `riscv_core` | Multi-instruction trace (499 PCs) | PASS | (VCD only) |

### RISCOF Compliance

| Suite | Result |
|-------|--------|
| rv32i_m/I (38 tests) | PASS 38/38 vs Spike |
| rv32i_m/M | NOT RUN (M-extension not implemented) |
| rv32i_m/C | NOT RUN (C-extension not implemented) |

### Formal Verification

| Suite | Properties | Status |
|-------|-----------|--------|
| eml_fv.sv | 3 | UNPROVED (z3 timeout) |
| snn_fv.sv | 5 | UNPROVED (z3 timeout) |
| security_fv.sv | 5 | UNPROVED (z3 timeout) |
| power_fv.sv | 5 | UNPROVED (z3 timeout) |

See `reports/2026-06-06/formal/FORMAL_STATUS.md` for details.

## Coverage Model (planned)

### Functional Coverage Points

| Group | Coverpoints | Method |
|-------|-------------|--------|
| ISA instruction types | All 40+ instructions executed | Simulation + RISCOF |
| Branch outcomes | Taken/not-taken for all 6 branch types | `hazard_tb.v` |
| Xcew FSM states | All 8 states visited | `core_tb.v` |
| CSR operations | CSRRW/S/C + imm variants on all CSRs | `trap_tb.v` |
| Trap types | All 5 sync exceptions + 3 interrupt types | `trap_tb.v` + `irq_tb.v` |
| Fault codes | All 8 fault codes triggered | `security_empirical_tb.v` |
| Power states | RUN↔SLEEP for all 4 tiles | formal (power_fv.sv) |

### Cross-Coverage

| Cross | Method |
|-------|--------|
| ISA op × fault (interrupt during execution) | Not yet tested |
| Branch × Xcew stall (branch shadow + stall) | Partially tested |
| Reset × active operation (mid-op reset) | Not yet tested |

### Line/Toggle Coverage

Not yet measured. Requires Verilator `--coverage` or VCS.
Planned: ≥90% line coverage on `riscv_core.v` and ≥80% on all RTL files.

## Findings from This Verification Campaign

| Finding | Severity | Module | Status |
|---------|----------|--------|--------|
| Policy FSM doesn't reset `policy_done` between runs | Medium | `policy_determinism.v` | OPEN — needs fix |
| EML 1-cycle timing variance on first operation | Low | `eml_unit.v` | KNOWN — pipeline startup artifact |
| Non-det policy timeout (run1=200 cycles) | Low | `policy_determinism.v` | OPEN — non-det path may hang |
| Formal proofs unrunnable with z3 | Medium | All FV suites | BLOCKED — need boolector |
