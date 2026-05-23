<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Changelog

All notable changes to Azmuth (Xcew RISC-V Processor) are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project aims to follow [Semantic Versioning](https://semver.org/).
Per the tapeout audit (§0.6), every entry should reference a requirement ID
(`REQ-*`), bug ID (`BUG-*`), or decision (`DECISION-*`) together with the
implementing commit. Bug IDs `BUG-001`..`BUG-027` correspond to the
"Known Issues & Fixes" table in `README.md`.

## [Unreleased]

### Added
- `docs/VERIFICATION_PLAN.md` (audit §2.1, draft) and `docs/CDC_ANALYSIS.md`
  (§3.1) — the latter finds the core↔SNN crossing is unsynchronized (DEV-011).
- `docs/MICRO_ARCH_SPEC.md` (audit §1.1, draft) with a Deviations Register
  (DEV-001..011), `docs/TRACEABILITY.csv`+`.md` (§1.2), `docs/BUG_RETROSPECTIVE.md`
  (§1.4).
- `tb/xcie_decoder_tb.v` — directed decoder test (10/10) covering REQ-ISA-010..014.
- `tb/hazard_tb.v` + `tb/asm/hazard.S` + `tools/asm-to-hex.sh` — directed RV32I+Zicsr
  pipeline/hazard/ISA test (§2.3), assembled from real RISC-V asm (13/13). New
  make target `sim_hazard`.
- `reports/2026-05-23/synth/SYNTH_QOR_NOTE.md` and `reports/2026-05-23/formal/FORMAL_NOTE.md`
  — empirical §5.1 / §1.3(c) findings.
- `LICENSE` — proprietary "All Rights Reserved" license (DECISION-007, audit §0.7).
- SPDX `LicenseRef-Azmuth-Proprietary` headers across source files (audit §0.7 / §S0.4).
- `CHANGELOG.md` with requirement/bug/decision traceability (audit §0.6).
- `docs/DECISIONS.md` — decision log DECISION-001..007 (audit §8.4).
- `SECURITY.md` — vulnerability reporting policy and SLA (audit §S8.3).
- `flow/` — single consolidated entry points: `lint.sh`, `sim.sh`, `synth.sh`,
  `pnr.sh`, `signoff.sh`, `formal.sh`, `compliance.sh` (audit §0.1).
- `reports/` — date-stamped report tree with `reports/latest` pointer (audit §0.2).

### Changed
- Consolidated ~20 root-level shell scripts (six PnR variants, seven monitor
  scripts) into `flow/`; redundant variants removed, git history preserves them
  (audit §0.1).
- Relocated root `*_report.txt` / `validation_*.txt` artifacts into
  `reports/2026-05-23/<stage>/` with commit-hash + timestamp provenance headers
  (audit §0.2).
- `xcew_top_v1_1` documented as the single authoritative top-level; legacy
  `xcew_top.v` / `stdp_engine.v` retained as deprecated reference per
  DECISION-004 path Option 2 (audit §0.4).
- `README.md` license section updated from "see individual source files" to a
  declared proprietary license.

### Fixed
- BUG-028/029/030 (found by the new `tb/hazard_tb.v`, tapeout audit §2.3):
  store address used `rs1+rs2` not `rs1+imm`; loads ignored their offset
  (`generate_imm` lacked `LTYPE`); pipeline flush was 1 cycle but needs 2 (two
  fetch stages → two wrong-path instructions after a taken branch/jump/trap).
  All three fixed in `rtl/core/riscv_core.v`; no regression.
- DEV-005/DEV-009/DEV-012 (DECISION-009): implemented M-mode trap support in
  `rtl/core/riscv_core.v` — Zicsr CSRs (mstatus/mie/mip/mtvec/mepc/mcause/mtval/
  mscratch + misa/mhartid), exception detection (illegal/ECALL/EBREAK/misalign),
  machine-interrupt taking (new `i_meip/i_mtip/i_msip` ports, wired in both tops),
  and `mret`; trap-taking gated on `mtvec != 0`. Fixed the `if_pc` off-by-4
  (corrects branch/jump targets and `mepc`) and added a 1-cycle wrong-path flush
  on branch/jump/trap/mret. Tests `tb/trap_tb.v` (6/6), `tb/irq_tb.v` (5/5);
  new make targets `sim_trap`/`sim_irq`/`sim_decoder`. No regression
  (core/cosim/soc/top all pass).
- DEV-001/DEV-002: reconciled the Xcew custom opcode map to the standard
  RISC-V custom-0..3 slots (DECISION-008); `rtl/core/xcie_decoder.v` aligned to
  the core and POL_UPD made reachable. Resolves the README "1 master" vs "4M×5S"
  AXI contradiction (§1.3a) in `README.md` / `MICRO_ARCH_SPEC.md` REQ-AXI-001.

### Removed
- Duplicate `Claude.md` (case-only collision with `CLAUDE.md`) (audit §0.3).

## [1.1.0] - 2026-04-30

First integrated v1.1 of the Xcew processor. Highlights below; full per-bug
detail is in the `README.md` "Known Issues & Fixes" table (BUG-001..BUG-027).

### Added
- Initial Azmuth v1.1 RTL: RV32IMC core with Xcew dispatch, EML 5-stage pipeline,
  SNN tile (8-neuron) + STDP, NVM ReRAM controller, AXI4-Lite interconnect,
  power orchestration, body-bias control, fault monitor, policy determinism
  (commit d250b15).
- `snn_tile_256` 256-neuron classifier, self-contained `cosim_tb`, and expanded
  SymbiYosys formal property set (commit 96a282a).
- EML fixed-point math testbench `tb/eml_math_tb.v` (BUG-027, commit 92271d7).

### Fixed
- BUG-001..BUG-015: core CSR/memory drive, branch/jump target computation,
  byte-enable generation, load writeback, NVM Hamming SECDED, EML exp/ln
  fixed-point approximations (commits 3f09cfa, 7777397).
- BUG-016..BUG-024: NVM reset compaction, 7-bit SECDED upgrade, EML compute_ln
  synthesizability and sign handling, regfile init (commit c952a5b).
- BUG-025..BUG-027: EML compute_exp/ln 4th-order minimax polynomials with
  <0.2% max error (commit 92271d7, docs c276576).

### Changed
- Resolved all 87 Verilator lint warnings for Verilog-2001 tapeout compliance:
  width extension/truncation, incomplete cases, MULTITOP split of
  `eml_dag_scheduler`, J-type immediate width (commit 3c86c93).

[Unreleased]: https://github.com/Kiransekar/Azmuth/compare/96a282a...HEAD
[1.1.0]: https://github.com/Kiransekar/Azmuth/releases/tag/v1.1.0
