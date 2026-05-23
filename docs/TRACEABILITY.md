<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Requirements Traceability Matrix

Human-readable view of [`TRACEABILITY.csv`](TRACEABILITY.csv) (the machine
source). Tapeout audit §1.2. Each requirement from
[`MICRO_ARCH_SPEC.md`](MICRO_ARCH_SPEC.md) traces forward to an RTL site and a
test, and back from each test to a requirement.

## Status summary (commit `96a282a`)

| Status | Count | Meaning |
|--------|-------|---------|
| IMPLEMENTED | 37 | RTL implements the requirement; a testbench exercises it |
| PARTIAL | 1 | Partially implemented (REQ-IRQ-001) |
| DEVIATION | 12 | Documented-but-unimplemented or stubbed — see `MICRO_ARCH_SPEC.md` §10 (DEV-001..011) |
| **Total** | **50** | |

## Gap analysis vs. audit §1.2 PASS criteria

The §1.2 PASS bar is: every REQ has ≥1 RTL site, ≥1 test, ≥1 **evidence file**;
<5% orphan RTL; zero orphan tests.

**Not yet PASS.** Open gaps:

1. **Evidence column is `pending` for every row.** No committed waveform/log
   artifacts exist yet. Closing this needs the verification campaign (audit §2)
   to emit per-test evidence into `reports/<date>/coverage|sim/` and the CSV
   `Evidence` cells updated to point at them.
2. **12 DEVIATION rows have no test (and 4 have no RTL site).** These trace to
   `DEV-001..011`; each must be either implemented+tested or formally struck
   from the README/CSR map. Until then they are honest orphans, not hidden ones.
3. **Tests not yet back-traced.** The 14 testbenches in `tb/` should each gain a
   header comment naming the REQ-IDs they cover (`// REQ: REQ-PIPE-001, ...`) so
   the back-trace is machine-checkable. Glue/debug code uses `// REQ: GLUE`.

## How to maintain

- Add a row to `TRACEABILITY.csv` for every new `REQ-*` in the spec.
- When a test produces a committed artifact, replace `pending` in the `Evidence`
  cell with its path under `reports/`.
- A CI check (future, audit §2.2) should fail if any REQ row has an empty
  `Test` or `Evidence` cell, or if a `tb/*.v` names a REQ-ID absent from the CSV.

## Deviation cross-reference

| DEV | REQ rows affected | One-line |
|-----|-------------------|----------|
| DEV-001 | REQ-ISA-010/012/013 | core vs decoder opcode maps disagree |
| DEV-002 | REQ-ISA-011 | POL_UPD id unreachable |
| DEV-003 | REQ-CSR-002 | xcew_status static |
| DEV-004 | REQ-CSR-010 | 0x7CD–0x7CF not decoded |
| DEV-005 | REQ-EXC-001 | exception tied 0 |
| DEV-006 | REQ-FSM-006 | EXE_MEMO no wait |
| DEV-008 | REQ-IRQ-002 | eml/snn/nvm IRQ tied 0 |
| DEV-009 | REQ-EXC-002 | no trap CSRs / privilege |
| DEV-010 | REQ-RST-001 | no reset synchronizer doc |
| DEV-011 | REQ-CDC-002 | no CDC inventory |
