<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Requirements Traceability Matrix

Human-readable view of [`TRACEABILITY.csv`](TRACEABILITY.csv) (the machine
source). Tapeout audit §1.2. Each requirement from
[`MICRO_ARCH_SPEC.md`](MICRO_ARCH_SPEC.md) traces forward to an RTL site and a
test, and back from each test to a requirement.

## Status summary (2026-06-08)

| Status | Count | Meaning |
|--------|-------|---------|
| IMPLEMENTED (with evidence) | 32 | RTL implements; testbench exercises; sim log committed |
| IMPLEMENTED (evidence pending) | 22 | RTL implements; testbench exists; sim log not yet captured |
| PARTIAL | 1 | Partially implemented (REQ-IRQ-001 top-level sources) |
| DEVIATION | 5 | Documented-but-unimplemented or stubbed — DEV-003,004,006,010,011 |
| **Total** | **60** | (was 50; expanded with M-mode CSR REQs + REQ-PIPE-006 + REQ-RST-002 + REQ-ISA-009) |

## Slice 10 updates (2026-06-08)

### Formal verification evidence

All 4 SymbiYosys formal proofs now PASS with Boolector solver:

| Proof | REQs covered | Evidence |
|-------|-------------|----------|
| `sby/eml.sby` | REQ-FSM-003 (EML completion) | `make formal` eml DONE (PASS, rc=0) |
| `sby/snn.sby` | REQ-FSM-003 (SNN completion) | `make formal` snn DONE (PASS, rc=0) |
| `sby/security.sby` | REQ-CSR-009 (fault_status W1C) | `make formal` security DONE (PASS, rc=0) |
| `sby/power.sby` | REQ-PWR-001 (per-tile FSM) | `make formal` power DONE (PASS, rc=0) |

**BUG-038 (security.sby FAIL):** CSR fault-clear priority bug in
`rtl/security/fault_monitor.v` — non-blocking last-write-wins caused FSM to
override CSR clear. Fixed: CSR-clear block moved after FSM.

### Firmware build evidence

`make firmware` now succeeds, producing `firmware/build/firmware.{elf,hex,bin}`.
Three bugs fixed: BUG-039 (march flag), BUG-040 (missing source), BUG-041
(symbol mismatch). Covers: REQ-ISA-008 (Zicsr CSR access in boot.S),
`firmware/boot.S` §S2.2, `firmware/trap_handler.S` §S2.5.

## Gap analysis vs. audit §1.2 PASS criteria

The §1.2 PASS bar is: every REQ has ≥1 RTL site, ≥1 test, ≥1 **evidence file**;
<5% orphan RTL; zero orphan tests.

**Progress toward PASS.** Remaining gaps:

1. **Evidence partially populated.** 32 of 60 rows now have committed sim log
   evidence in `reports/latest/sim/`. The remaining 22 IMPLEMENTED rows need
   their testbenches run with evidence capture (mostly peripheral: SoC, power,
   security, NVM testbenches).
2. **Formal proof evidence (NEW).** All 4 formal proofs PASS (Slice 10) — these
   provide additional coverage for security, power, EML, and SNN REQs beyond
   simulation.
3. **5 DEVIATION rows** have no test (and some have no RTL site). These trace to
   `DEV-003,004,006,010,011`; each must be either implemented+tested or formally
   struck from the README/CSR map.
4. **Test back-tracing:** Testbenches should gain `// REQ: REQ-*` header comments
   for machine-checkable back-trace (partially started).

## How to maintain

- Add a row to `TRACEABILITY.csv` for every new `REQ-*` in the spec.
- When a test produces a committed artifact, replace `pending` in the `Evidence`
  cell with its path under `reports/`.
- A CI check (future, audit §2.2) should fail if any REQ row has an empty
  `Test` or `Evidence` cell, or if a `tb/*.v` names a REQ-ID absent from the CSV.

## Deviation cross-reference

| DEV | REQ rows affected | One-line |
|-----|-------------------|----------|
| ~~DEV-001~~ CLOSED | REQ-ISA-010/012/013 | core vs decoder opcode maps — aligned (DECISION-008) |
| ~~DEV-002~~ CLOSED | REQ-ISA-011 | POL_UPD now decodes from custom-1 |
| DEV-003 | REQ-CSR-002 | xcew_status static |
| DEV-004 | REQ-CSR-010 | 0x7CD–0x7CF not decoded |
| ~~DEV-005~~ CLOSED | REQ-EXC-001 | exceptions detected+taken (DECISION-009) |
| DEV-006 | REQ-FSM-006 | EXE_MEMO no wait (xcie_ctrl vestigial) |
| DEV-007 PARTIAL | — | wrong-path flush added; no forwarding network |
| DEV-008 PARTIAL | REQ-IRQ-002 | core takes i_meip; top eml/snn/nvm sources still tied 0 |
| ~~DEV-009~~ CLOSED | REQ-EXC-002 | M-mode trap CSRs + Zicsr + mret (DECISION-009) |
| DEV-010 | REQ-RST-001 | no reset synchronizer — documented in RESET_ARCH.md |
| DEV-011 | REQ-CDC-002 | no CDC inventory — documented in CDC_ANALYSIS.md |
| ~~DEV-012~~ CLOSED | (branch/jump/mepc) | if_pc off-by-4 fixed (DECISION-009) |

