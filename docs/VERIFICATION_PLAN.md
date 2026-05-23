<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth Verification Plan

**Project:** Azmuth — Xcew RISC-V Processor v1.1 (commit `96a282a`)
**Status:** DRAFT — tapeout audit §2.1. Owner: Pair B.
**Companion artifacts:** `MICRO_ARCH_SPEC.md` (REQ-*), `TRACEABILITY.csv`
(REQ → test), `BUG_RETROSPECTIVE.md` (gates G1–G7).

> "82 unit + 8 integration tests passing" is a count, not coverage. This plan
> defines *what* must be covered and *how each test is sufficient*, against the
> requirements. It also states honestly what is not yet covered.

## 1. Strategy by feature

| Feature | REQs | Testbench(es) | What makes it sufficient |
|---------|------|---------------|--------------------------|
| Core pipeline / ISA | REQ-PIPE-*, REQ-ISA-001..008 | `tb/core_tb.v`, `tb/cosim_tb.v` | Directed instr ROM + self-checking PC/regfile; cosim runs 500 cycles. **Gap:** no RISCOF (§2.4) — RV32IMC compliance unproven. |
| Xcew decode | REQ-ISA-010..014 | `tb/xcie_decoder_tb.v` | 10/10 directed vectors incl. illegal funct3 and non-Xcew opcodes (DECISION-008). |
| Xcew control FSM | REQ-FSM-* | `tb/core_tb.v` | **Gap:** FSM state/transition coverage not measured; `xcie_ctrl` vestigial. |
| v1.0 CSRs | REQ-CSR-001/002 | `tb/core_tb.v` | Field-mask write + RO read. **Gap:** DEV-003 (status static). |
| v1.1 CSRs | REQ-CSR-003..009 | `tb/xcew_top_v1_1_tb.v` | Per-CSR R/W incl. W1C fault_status. **Gap:** illegal-write rejection untested; 0x7CD-CF absent (DEV-004). |
| EML pipeline + math | (EML unit) | `tb/eml_tb.v`, `tb/eml_math_tb.v` | 40-test fixed-point suite vs Python golden, ±2% tol. |
| EML DAG cache | REQ-CSR-004 | `tb/eml_dag_tb.v` | Reuse/hit validation. **Gap:** all-4-ways + LRU eviction coverpoints. |
| SNN classify / TTFS / STDP | (SNN) | `tb/snn_tile_256_tb.v`, `tb/snn_ttfs_tb.v`, `tb/snn_v1_1_tb.v` | Classification + TTFS/rate compare. **Gap:** TTFS energy ≥40% unmet (§1.3b); CDC unsynchronized (§3.1). |
| NVM + ECC | REQ-MEM-005 | `tb/nvm_tb.v` | R/W. **Gap:** SECDED single/double-bit injection campaign (§4.4). |
| AXI interconnect | REQ-AXI-*, REQ-MEM-* | `tb/axi_lite_interconnect_v1_1_tb.v`, `tb/soc_tb.v` | 4M×5S routing. **Gap:** AXI4-Lite protocol checker (§3.3). |
| Power orchestration | REQ-PWR-* | `tb/power_orch_tb.v` | Sleep/wake cycles. |
| Security / fault | REQ-CSR-007/009, REQ-IRQ-001 | `tb/security_tb.v` | Fault latch/clear. **Gap:** full 8-code fault-injection matrix (§4.3); TVLA (§4.1); deterministic-policy variance (§4.2). |
| Top integration | all | `tb/top_tb.v`, `tb/cosim_tb.v` | **Gap:** `top_tb.v` port drift (CLAUDE.md gotcha). |

## 2. Coverage goals (audit §2.2 thresholds)

| Metric | Target | Current |
|--------|--------|---------|
| Functional (declared coverpoints) | ≥95% | **not measured** |
| Line | ≥90% | not measured |
| Branch | ≥85% | not measured |
| FSM state | 100% | not measured |
| FSM transition | ≥95% | not measured |
| Toggle | tracked | not measured |

No coverage instrumentation is wired yet — §2.2 is OPEN. Plan: enable Verilator
`--coverage-line --coverage-toggle --coverage-user`, aggregate into
`reports/<date>/coverage/`, track per-coverpoint over time.

## 3. Coverpoints

- **Xcew opcode × CSR mode:** each of {EML, POL_UPD, SNN, CFG, MLOAD, MSTORE} ×
  {DAG_MODE 0/1, COMPLEX_MODE 0/1, MAX_DEPTH boundary, PRECISION values}.
- **EML cache:** all 4 ways exercised; LRU correctness; hit and miss paths;
  compute-on-miss.
- **IRQ × pipeline stage:** each IRQ source asserted during IF / ID-EX / WB and
  during an Xcew stall. (Blocked: most IRQs tied to 0 — DEV-008.)
- **Fault matrix:** each of the 8 `fault_monitor` codes triggered, observed in
  `fault_status` (0x7CC), W1C-cleared.
- **Power transitions:** every RUN↔SLEEP edge per tile incl. wake-on-IRQ and
  wake-on-AXI.
- **STDP:** all 6 policies.

## 4. Cross-coverage

- EML compute with COMPLEX_MODE=1 ∧ MAX_DEPTH=max.
- Interrupt assertion while EML pipeline busy (Xcew stall × IRQ).
- Fault asserted while a tile is in SLEEP (fault × power state).
- CSR read-after-write and memory write→read same address (hazards, §2.3).

## 5. Known coverage blockers (from MICRO_ARCH_SPEC §10)

| Blocker | Effect on plan |
|---------|----------------|
| DEV-005 / DEV-009 (no exceptions / trap CSRs) | Exception coverpoints and §2.3 trap-related hazards cannot be hit until implemented; blocks RISCOF privilege/Zicsr (§2.4). |
| DEV-008 (IRQs tied 0) | IRQ × stage cross-coverage limited to the fault IRQ. |
| DEV-011 (CDC unsynchronized) | SNN crossing tests can pass in zero-delay sim yet fail on silicon; need randomized-phase CDC tb (§3.1). |
| §1.3(c) (formal harness malformed) | No formal coverage contribution until `.sby` files carry real SVA. |
