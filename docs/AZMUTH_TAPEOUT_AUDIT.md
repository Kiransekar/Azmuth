<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth Tapeout-Readiness Audit & Certification Evidence Plan

**Project:** Azmuth — Xcew RISC-V Processor v1.1
**Status:** Working document (LIVE — update on every check completion)
**Owner:** Kiransekar (team lead)
**Cert anchors:** RISC-V ISA compatibility (RISCOF / `riscv-arch-test`) + Common Criteria EAL2 evidence package
**Market:** Open commercial
**Authority:** This checklist is the single source of truth for tapeout readiness. Items marked **HARD GATE** must be PASS before fabrication submission. No exceptions, no time-pressure overrides.

---

## Executive Summary

Azmuth v1.1 is **functionally integrated and synth-clean** but is **not tapeout-ready**. Concrete gaps, verifiable from the current repo state:

1. **Configuration management hygiene** is below commercial / CC-EAL2 threshold. ~20 root-level shell scripts with overlapping function (six PnR variants, seven monitor scripts), floating `*_report.txt` files at root, two `CLAUDE.md`/`Claude.md` files (case-only collision), two top-level modules (`xcew_top.v` legacy + `xcew_top_v1_1.v`), two STDP engines.
2. **Specification artifact is absent.** RTL evolved ahead of spec. The 27-bug list in the README is the symptom — most of those would have been caught in a spec-first review, not in late-stage debug.
3. **Empirical validation of security claims is not on file.** "Constant-time EML," "deterministic policy," "ECC-protected NVM," "watchdog-protected core" are claimed in the README and CSR map; no test report demonstrates any of them.
4. **Formal properties exist but are unproved** (18 across `sby/eml.sby`, `sby/snn.sby`, `sby/security.sby`, `sby/power.sby` — SBY not yet run).
5. **PnR closure not yet achieved.** OpenROAD scripts and floorplan are committed; signoff STA / DRC / LVS reports are not.
6. **RISC-V architectural compliance not demonstrated.** No RISCOF integration; no published pass log against `riscv-arch-test` for RV32IMC.
7. **Two declared targets are unmet.** TTFS energy reduction ≥40% (your own README flag), and AXI interconnect docstring says "1 master" while the module is named `axi_lite_interconnect_v1_1` and described as "4-master × 5-slave." Exactly one is wrong.
8. **Debug Module (DM) added to v1.1 scope** (DECISION-004). Initial RTL inventory had no DM, which would have rendered silicon undebugable via standard tooling. Adding RISC-V Debug Module + JTAG Debug Transport Module + hart-debug-state integration into the core for v1.1. Section 3.5 covers this subsystem end-to-end. This is the largest single addition to scope; expect 6–10 weeks of additional design + verification work.
9. **Five-lever area optimization to fit ChipIgnite 10 mm² user area** (DECISION-005). Original 18 mm² target is incompatible with any free open MPW shuttle. Selected single-chip ChipIgnite SKY130 (Caravel harness, ~$9,750) with **zero architectural feature reduction** via: external QSPI NVM, Caravel piggyback for debug transport + NVM access, SNN time-multiplexing (128 physical / 256 logical neurons), EML cache compression (256-entry logical retained), and aggressive synthesis + floorplan optimization. Section 1.5 covers the architectural workstream; Section 5.5 is the shuttle commitment gate; Section 6.5 covers Caravel integration.

This document defines the work to close every gap, in execution order, with PASS/FAIL criteria explicit enough that a third party can verify each from the repo alone.

---

## How To Use This Document

Each numbered check is one of:

- **[ ] HARD GATE** — must PASS before tapeout. No exceptions.
- **[ ] EVIDENCE** — must produce a written artifact stored in `docs/evidence/` for CC EAL2.
- **[ ] REVIEW** — design or process review with a written outcome.

Each check has:

- **Files:** specific repo paths to inspect/produce
- **PASS:** measurable criteria
- **FAIL:** what disqualifies
- **Owner pair:** which of the four pairs (A/B/C/D) drives it

When a check passes, the responsible pair commits the evidence and updates this file: change `- [ ]` to `- [x] (commit abc1234)`.

**Pair assignments** (see Section 8):

- **Pair A — Spec & Traceability** (REQs, traceability matrix, CHANGELOG, micro-arch spec)
- **Pair B — Functional & Compliance Verification** (testbenches, coverage, RISCOF, Xcew test suite)
- **Pair C — Formal, Security, Cross-cutting** (SBY proofs, TVLA, CDC, fault injection)
- **Pair D — Physical Implementation & Signoff** (PnR, STA, DFT, packaging)

---

## Section 0 — Gate-Zero: Repository Hygiene & Configuration Management

**Why first:** Every downstream artifact (cert evidence, audit trail, commercial due diligence) depends on a clean single-source-of-truth repo. Skip this and every later check becomes ambiguous.

### 0.1 [x] HARD GATE — Shell script consolidation

**Current state:** ~20 `.sh` files at repo root, including six PnR variants (`run_pnr_flow.sh`, `run_safe_pnr.sh`, `run_safe_pnr_v2.sh`, `run_optimized_pnr.sh`, `robust_pnr_flow.sh`, `check_and_run_pnr.sh`), seven monitor scripts (`monitor_*.sh`, `*_tracker.sh`, `realtime_monitor.sh`, `progress_monitor.sh`), two synth scripts, multiple validation scripts.

**Action:**

- Create `flow/` directory with exactly these entry points: `flow/lint.sh`, `flow/sim.sh`, `flow/synth.sh`, `flow/pnr.sh`, `flow/signoff.sh`, `flow/formal.sh`, `flow/compliance.sh`.
- Prefer Makefile targets where logic is short. Scripts only for multi-step orchestration that doesn't fit a single recipe.
- Each remaining script: header comment with PURPOSE, INPUTS, OUTPUTS, EXIT CODES.
- Delete all duplicates. Git history preserves them.

**PASS:** `ls /*.sh` at repo root returns nothing. Every flow stage has exactly one entry point documented in README. No "v2," "safe," "optimized," "robust," "fast" qualifiers on any script name.
**FAIL:** Any duplicate-purpose scripts remain.
**Owner:** Pair D

### 0.2 [x] HARD GATE — Report file consolidation

**Current state:** `integration_report.txt`, `phase5_validation_report.txt`, `phase6_validation_report.txt`, `validation_final.txt`, `validation_report_phase3.txt`, `validation_report_phase4.txt`, `floorplan_visualization.txt` at root.

**Action:**

- Create `reports/` with date-stamped subdirectories: `reports/YYYY-MM-DD/<stage>/`.
- Move existing reports there. Mark each with a header line indicating commit hash and generation date.
- Update README to point to `reports/latest/` (symlink rebuilt by flow scripts).
- Reports must be machine-generated by flow scripts going forward. No hand-edited reports.

**PASS:** Root has no `.txt` reports. `reports/` structure documented in README. All reports have commit-hash + timestamp metadata in their first 5 lines.
**FAIL:** Hand-curated reports persist.
**Owner:** Pair D

### 0.3 [x] HARD GATE — Resolve duplicate top-level documentation files

**Current state:** `CLAUDE.md` and `Claude.md` both present. Case-only collision on macOS/Windows filesystems.

**Action:** Merge into one. Move AI-tool-specific context to `docs/internal/` if useful (do not advertise AI tooling to commercial adopters in top-level docs).

**PASS:** No duplicate-name files. No top-level AI-tool config files.
**Owner:** Pair A

### 0.4 [x] HARD GATE — Single authoritative top-level module

**Current state:** `rtl/xcew_top.v` (v1.0, marked legacy) and `rtl/xcew_top_v1_1.v` both present. Same pattern in `rtl/snn/`: `stdp_engine.v` (legacy) and `stdp_engine_v1_1.v`.

**Action:** Decide explicitly:

- **Option 1 (recommended):** Delete legacy modules. Git history preserves them. `xcew_top_v1_1.v` becomes the only top.
- **Option 2:** If backward-compat is a stated design requirement, document it in `docs/ARCHITECTURE.md` with the use case, and add a parameterized wrapper that selects implementation.

Whichever path: ensure `rtl/rtl_list.f` references exactly one top.

**PASS:** One authoritative top documented in README. No dangling legacy modules without a documented role.
**FAIL:** Two top-levels coexist without documented relationship.
**Owner:** Pair A

### 0.5 [ ] EVIDENCE — Branch protection and signed commits

Required for CC EAL2 `ALC_CMC` (Configuration Management Capabilities).

**Action:**

- Protect `main` branch (no direct push; PRs only with ≥1 reviewer).
- Enable signed-commits requirement.
- Tag every release `vN.N.N` with annotated, signed tag.
- PR description must reference a requirement ID (see 1.1) or bug ID.

**PASS:** GitHub branch protection rules screenshotted in `docs/evidence/cm/branch_protection.md`. The 10 most recent main commits are signed. Latest release tag is signed-annotated.
**Owner:** Pair A

### 0.6 [x] EVIDENCE — CHANGELOG with requirement traceability

**Action:** Create `CHANGELOG.md` at repo root. Format:

```
## [v1.1.1] - YYYY-MM-DD
### Added
- REQ-EML-007: Constant-time guard for negative inputs (commit abc1234)
### Fixed
- BUG-027: EML compute_ln Taylor series accuracy (commit def5678)
### Changed
- ...
```

Backfill from existing git history for v1.1. Future entries written per PR.

**PASS:** `CHANGELOG.md` present. Every entry references a REQ-ID or BUG-ID with commit hash.
**Owner:** Pair A

### 0.7 [x] EVIDENCE — License declaration

**Current state:** README says "See individual source files for license information." That's not auditable.

**Action:** Choose a single project license (Apache-2.0 or MIT recommended for open commercial RISC-V). Place `LICENSE` at root. Add SPDX headers to all source files: `// SPDX-License-Identifier: Apache-2.0`.

**PASS:** Single LICENSE file at root. SPDX header on every `.v`, `.tcl`, `.sh`, `.py`, `.md` file.
**Owner:** Pair A

---

## Section 1 — Specification ↔ RTL ↔ Test Traceability

**Why critical:** The 27-bug list is itself the strongest argument for this section. Each bug existed because implementation had no spec to check against. CC EAL2 `ADV_FSP` (functional specification) and any DO-254-style traceability claim depend on this work.

### 1.1 [~] HARD GATE — Micro-architecture specification
> _Drafted at `docs/MICRO_ARCH_SPEC.md` (REQ-* ids + DEV-* deviations register). NOT yet PASS: needs review + team-lead sign-off, and a few sections (full per-instruction RV32IMC semantics, detailed reset sequence) are summarized rather than exhaustive._

**Action:** Create `docs/MICRO_ARCH_SPEC.md`. Required content:

- Pipeline diagram with stage timing (IF / ID-EX / WB, plus Xcew stall semantics)
- Per-instruction execution semantics — full RV32IMC plus every Xcew opcode (XCEW_EML, XCEW_POL_UPD, XCEW_SNN_CLASS, XCEW_MISC)
- Per-CSR field semantics — reset value, R/W behavior, side effects, illegal-write behavior. Cover the v1.0 set (0x7C0, 0x7C1) and v1.1 set (0x7C5–0x7CF).
- Memory map with access semantics per region (Boot ROM read-only, SRAM R/W, CSR slaves' allowed access patterns)
- Interrupt source list — `o_irq_eml`, `o_irq_snn`, `o_irq_nvm`, `o_irq_fault`, `o_timeout_irq` — with prioritization and clearing protocol
- Exception behavior — illegal instruction, misaligned access, ECC double-bit error, watchdog trip, depth-limit violation
- Reset sequence — POR vs warm reset, body-bias DAC settling time, ROM-to-execution latency
- Power state machine per tile — RUN / SLEEP transitions with isolation/retention sequencing
- Clock domain crossings — every signal that crosses from `i_clk_core` (250 MHz) to `i_clk_snn` (125 MHz) and back, with synchronizer style

Every paragraph gets a requirement ID: `REQ-PIPE-NNN`, `REQ-ISA-NNN`, `REQ-CSR-NNN`, `REQ-MEM-NNN`, `REQ-IRQ-NNN`, `REQ-EXC-NNN`, `REQ-RST-NNN`, `REQ-PWR-NNN`, `REQ-CDC-NNN`.

**PASS:** Spec covers every implemented feature. Every requirement has a unique ID. Spec reviewed and signed off by team lead and at least one engineer who did not write the RTL for that block.
**FAIL:** RTL has features not in spec, or spec has features not in RTL.
**Owner:** Pair A

### 1.2 [~] HARD GATE — Requirements traceability matrix
> _Drafted at `docs/TRACEABILITY.csv` + `docs/TRACEABILITY.md` (50 REQs → RTL site + test). NOT yet PASS: Evidence column is `pending` for all rows (no committed waveform/log artifacts yet — needs §2 verification campaign), and tests are not yet back-annotated with REQ-ids._

**Action:** Create `docs/TRACEABILITY.csv` (machine-readable) plus `docs/TRACEABILITY.md` (human-readable view).

Columns:

| REQ-ID | Description | RTL file:line | Test file:line | Evidence file | Status |

Every requirement traces forward to:

- One or more RTL implementation sites
- One or more test cases
- An evidence file (waveform / log / report) showing the test passed

Every test traces back to a REQ-ID. Every non-trivial block of RTL traces back to a REQ-ID. Glue / debug code may be exempted with `// REQ: GLUE` annotation.

**PASS:** Every REQ-ID has ≥1 RTL site, ≥1 test, ≥1 evidence file. <5% orphan RTL. Zero orphan tests.
**FAIL:** Orphan RTL or orphan tests exceeding 5%, or any REQ without test coverage.
**Owner:** Pair A drives, Pair B owns test column

### 1.3 [~] HARD GATE — Resolve known specification deviations
> _(a) AXI master count RESOLVED: RTL is 4 master × 5 slave (only m0 active); README prose corrected; see MICRO_ARCH_SPEC REQ-AXI-001/002. (b) TTFS energy ≥40% and (c) SBY proofs remain OPEN (need measurement / SymbiYosys run)._

Three specific items, all already known:

**a) AXI interconnect master count.** README/architecture diagram says "AXI4-Lite Interconnect (4M × 5S)" and the module reference says "4-master × 5-slave AXI4-Lite crossbar with fixed-priority arbitration." But the textual description earlier in the README claims "1 master (Core) and 5 slaves." Determine ground truth from `rtl/soc/axi_lite_interconnect_v1_1.v`. Fix whichever is wrong. Document the decision in CHANGELOG. If 4M is correct, identify all four masters in the spec.

**b) TTFS energy reduction ≥40% unmet.** Your README explicitly flags this. Three valid resolutions:

1. Redesign `rtl/snn/lif_ttfs_neuron_v1_1.v` to meet the target, with measurement evidence.
2. Renegotiate the target with quantitative justification (e.g. "≥25% achievable at this process node; 40% requires sub-Vt operation not available in PDK").
3. Document the gap as a known limitation in `docs/evidence/snn/ttfs_energy_report.md` and update README claims.

No fourth option. The README cannot continue to advertise an unmet quantitative target — that's a fail in any commercial due-diligence review.

**c) SBY formal properties unproven.** Two valid resolutions:

1. Install SymbiYosys, run all 18 properties (`make formal`), commit proof logs to `sby/proofs/<property>.log`.
2. Remove the formal-verification claim from README.

CC EAL2 doesn't require formal proof but does require honest claim-vs-evidence alignment.

**PASS:** All three resolved with evidence committed.
**Owner:** (a) Pair A; (b) Pair B + Pair C; (c) Pair C.

### 1.4 [x] EVIDENCE — Bug retrospective
> _Done: `docs/BUG_RETROSPECTIVE.md` — 27 bugs categorized, ~20/27 assessed spec-preventable, 7 review gates (G1–G7) defined._

The 27-bug list is itself a process artifact. Produce `docs/BUG_RETROSPECTIVE.md` analyzing:

- How many bugs would a spec-first review have caught? (Estimate per bug.)
- Categorize by root cause: missing-spec, width-mismatch, missing-default-case, sign-extension, incorrect-algorithm, missing-port, FSM-design-error, etc.
- Which categories repeat? (Width issues appear ≥6 times in the current list — sign of a systemic gap.)
- What review gates will catch the next class of bug before it ships? (Lint rules to add, code-review checklist items.)

This is internal discipline and also CC EAL2 `ALC_LCD` evidence (Lifecycle Definition).

**Owner:** Pair A

---

## Section 1.5 — Architecture Optimization for Shuttle Fit (NEW)

**Why this section exists:** The 18 mm² original target is incompatible with the ChipIgnite 10 mm² user area. DECISION-005 commits to fitting Azmuth into ChipIgnite via five compounding optimizations without removing any architectural feature. This section is the workstream for the architectural changes (levers L1, L3, L4, and the parameterization meta-lever); Section 5 covers synth-side optimization (L5), and Section 6.5 covers Caravel integration (L2).

**Combined area budget (target after all levers):**

| Block | Original (est.) | After optimization | Lever |
|-------|----------------|--------------------|-------|
| Core + Xcew dispatch | 2.5 mm² | 2.5 mm² | (unchanged) |
| EML unit + DAG cache | 2.5 mm² | 1.8 mm² | L4 (cache compression) |
| SNN tile + STDP | 3.0 mm² | 1.8 mm² | L3 (virtualization 128 phys / 256 logical) |
| NVM controller logic | 0.5 mm² | 0.5 mm² | (unchanged) |
| ReRAM macro 64 KB | 3.5 mm² | **0 mm²** | L1 (external QSPI) |
| AXI + power + security | 1.0 mm² | 1.0 mm² | (unchanged) |
| Boot ROM + SRAM | 0.5 mm² | 0.5 mm² | (unchanged) |
| Debug Module | 2.0 mm² | 1.5 mm² | L2 (Caravel SPI transport instead of dedicated JTAG TAP) |
| Routing overhead | 35% | 25% | L5 (synth + floorplan) |
| **TOTAL** | **~18 mm²** | **~10 mm²** | All levers |

**Critical:** these are estimates. Actual values from Section 5.1 (synth area measurement) and 5.5 (shuttle-commitment gate) are authoritative. The work below ensures the ESTIMATED reductions become real.

### 1.5.1 [ ] HARD GATE — External NVM architecture (Lever L1)

**Action:** Re-architect `rtl/nvm/nvm_ctrl.v` to drive an external ReRAM/Flash device via QSPI instead of an internal macro.

Specifically:

- Remove the internal ReRAM macro instantiation. The 65536-entry array initialized in nvm_ctrl.v becomes external.
- Add a QSPI master interface on `nvm_ctrl`: outputs `o_qspi_clk`, `o_qspi_cs_n`, `io_qspi_d[3:0]` (bidirectional), with proper tristate control during dummy/read cycles.
- Preserve every existing on-chip feature: 7-bit SECDED encoding (post bug #17), wear-leveling, 4-entry write buffer, scrub counter, fault-monitor integration. Adopter sees the same API.
- Address space: NVM CSR region (0x4000–0x4FFF) unchanged. Data window now references external storage; CSR controls the external transactions.
- Support common QSPI flash command set (READ_ID, READ_DATA, PAGE_PROGRAM, SECTOR_ERASE, READ_STATUS, WRITE_ENABLE) plus a ReRAM-specific subset if the chosen part needs it.
- Default external part: Adesto/Dialog ReRAM in QSPI (e.g. RM25C512C-LTAI-T) or any standard SPI/QSPI flash for adopters without ReRAM.

**Marketing reframe (also update README):** "64 KB internal ReRAM" → **"QSPI controller supports up to 16 MB external ReRAM or flash with on-chip SECDED, wear-leveling, write buffer, and scrub."** This is an upgrade, not a compromise.

**PASS:** RTL compiles. NVM read/write through controller produces correct QSPI bus transactions (verified by tb/nvm/qspi_master_tb.v with a Verilog model of a QSPI flash). All existing NVM tests pass against the QSPI model.
**FAIL:** Any existing API contract broken; adopter-visible behavior change other than capacity scaling.
**Owner:** Pair (existing NVM owner — typically a member of Pair B or DM pair coordinating)

### 1.5.2 [ ] HARD GATE — SNN time-multiplexed virtualization (Lever L3)

**Action:** Re-architect `rtl/snn/snn_tile_256.v` from 256 physical neurons → 128 physical neurons + state memory for 256 logical neurons. Time-multiplex evaluation.

Implementation:

- Physical array: 128 LIF/TTFS neurons with shared compute datapath.
- Neuron state memory: 256-entry SRAM holding membrane potentials, refractory counters, STDP eligibility traces. Single-port or dual-port depending on throughput target.
- Evaluation FSM: in each time-step, sweep all 256 logical neurons through the 128 physical units in 2 sub-cycles. Update state memory after each sweep.
- STDP engine: operates on the active sub-cycle's neurons; eligibility traces in state memory.
- Throughput preservation: push SNN clock from 125 MHz to 200 MHz (budget allows up to ~240 MHz at SKY130). Effective per-logical-neuron throughput: 200 MHz / 2 sub-cycles = 100 MHz per logical neuron, vs original 125 MHz physical. Acceptable degradation (~20%) or recovered by tighter sub-cycle pipelining.

**Datasheet language:** "256-neuron LIF/TTFS classifier with STDP, implemented via 128-way physical array time-multiplexed at 200 MHz." Honest, defensible, technically standard (this is how GPUs/TPUs present "thousands of cores").

**PASS:** New `snn_tile_256_v2.v` produces bit-identical classification results to original `snn_tile_256.v` for every test vector in the existing `tb/snn_tile_256_tb.v` suite. New SBY property: equivalence between v1 and v2 at the classify boundary.
**FAIL:** Any test vector produces different classification, or throughput drops below 80% of original on the benchmark.
**Owner:** Pair B (verification leads correctness check) + SNN design owner

### 1.5.3 [ ] HARD GATE — EML DAG cache compression (Lever L4)

**Action:** Re-architect `rtl/eml/eml_dag_cache.v` to keep 256-entry logical capacity with reduced physical area.

Implementation options (pick one or stack):

a) **Compressed tag store:** Store partial tags (e.g. 16-bit hash of full tag) with secondary full-tag check in a smaller backing array. Trades a small false-positive rate (~0.1%) for ~30% tag-array area reduction. False positives result in cache miss + recompute, not incorrect results.

b) **Set-dueling between ways:** 4-way set-associative → 2 hot ways with full data + 2 cold ways with compressed (delta-encoded or quantized) data. Adaptive eviction promotes cold-to-hot on access patterns.

c) **Decoupled tag/data with eviction:** Smaller data array than logical entries; tag hit without data triggers recompute (treated as a miss for performance, but the spec-level "256-entry" claim holds because the *index space* is 256).

Recommendation: option (a) for cleanest implementation and easiest verification. Pick (b) or stack with (a) only if (a) alone doesn't hit area target.

**PASS:** New cache produces correct EML compute results for every test in existing EML testbench suite. Hit-rate degradation <2% on representative workload (the cew_threat_classifier example). Area reduction ≥0.5 mm² versus original at synth.
**FAIL:** Any incorrect compute result, or hit-rate degradation >5%.
**Owner:** EML owner + Pair B (verification)

### 1.5.4 [ ] HARD GATE — Parameterizable RTL refactor (Product family enabler)

**Action:** Make every size-bearing block configurable via Verilog parameter:

```verilog
module xcew_top_v1_1 #(
    parameter SNN_PHYS_NEURONS = 128,    // L3: 128 phys, 256 logical
    parameter SNN_LOGICAL_NEURONS = 256,
    parameter EML_CACHE_ENTRIES = 256,
    parameter EML_CACHE_PHYS_TAGS = 64,  // L4: compressed
    parameter NVM_EXTERNAL = 1,           // L1: 1=QSPI external, 0=internal macro
    parameter DEBUG_TRANSPORT = "SPI",    // L2: "SPI" via Caravel, "JTAG" standalone
    parameter NVM_SIZE_KB = 64            // logical capacity claim
) (...);
```

This enables two configurations from the same RTL:

- **Azmuth-Lite** (ChipIgnite, 10 mm²): defaults as above
- **Azmuth-Full** (future custom MPW, 18 mm²): SNN_PHYS_NEURONS=256, EML_CACHE_PHYS_TAGS=256, NVM_EXTERNAL=0, DEBUG_TRANSPORT="JTAG"

Same codebase → two products. This is the Intel Core i3/i5/i7 pattern. Future-proofs the IP.

**PASS:** Both configurations elaborate without warnings. Both pass the full regression suite (Lite uses scaled-down configs of tests; Full uses original tests). RTL inventory documents both configurations.
**Owner:** Pair A (spec) + design owners of each block

### 1.5.5 [ ] HARD GATE — Architectural equivalence verification

**Action:** Before any of L1/L3/L4 ship, prove the optimized RTL produces functionally equivalent results to the original on every existing test.

For each lever:

- **L1 NVM:** end-to-end firmware test reads/writes NVM via external QSPI model, results match original-controller behavior bit-for-bit (ECC behavior, wear-leveling order, scrub counter advancement all identical).
- **L3 SNN:** classify 1000 test inputs through both old and new SNN; results identical (allowing for documented quantization tolerance if any).
- **L4 EML:** compute every expression in golden test set through both old and new cache; results identical; hit-rate within 2% of original.

**PASS:** All three equivalence campaigns pass. Reports in `docs/evidence/optimization/equivalence_*.md`.
**FAIL:** Any divergence not justified by an explicit, accepted spec change.
**Owner:** Pair B + Pair C (formal can be applied to L3 and L4 via SBY equivalence checking)

### 1.5.6 [ ] EVIDENCE — Decision record DECISION-005

**Action:** `docs/DECISIONS.md` entry:

```
## DECISION-005: Five-lever area optimization for ChipIgnite shuttle fit
Date: YYYY-MM-DD
Decided by: Kiransekar + team
Context: 18 mm² original target incompatible with any free open MPW
shuttle. Cost of paid 18 mm² (IHP SG13G2 ~€54k) outside student budget.
Reducing architectural features unacceptable per design intent.
Decision: Target ChipIgnite SKY130 (Caravel harness, ~$9,750) with
single-chip 10 mm² fit via five compounding optimizations preserving
all architectural claims:
  L1 - External QSPI NVM (preserves controller IP, makes NVM scalable)
  L2 - Caravel piggyback (debug transport + flash interface reuse)
  L3 - SNN virtualization (128 phys / 256 logical, time-multiplexed)
  L4 - EML cache compression (256 logical preserved, compressed tags)
  L5 - Synth + floorplan optimization (area-targeted flow)
Consequences:
  - SNN clock pushed 125→200 MHz
  - NVM bring-up requires external QSPI part on board
  - Debug uses Caravel housekeeping SPI as transport (DM unchanged)
  - RTL becomes parameterizable (enables Azmuth-Full v2 from same codebase)
  - Marketing language updated to reflect external NVM as a feature
Reviewed: YYYY-MM-DD (active)
```

**Owner:** Team lead

---

## Section 2 — Functional Verification Completeness

**Why:** "82 unit + 8 integration tests passing" is a count, not a coverage statement. Counts don't satisfy auditors. Functional coverage against a written plan does. CC EAL2 `ATE_FUN` and `ATE_COV` evidence both live here.

### 2.1 [~] HARD GATE — Verification plan document
> _Drafted at `docs/VERIFICATION_PLAN.md` (per-feature strategy, coverpoints, cross-coverage, mapped to REQ-* + the 14 testbenches). NOT yet PASS: coverage is not yet measured (§2.2 open) and several coverpoints are blocked by DEV-005/008/009/011._

**Action:** Create `docs/VERIFICATION_PLAN.md`. Content:

- Per-feature test strategy. Which tests demonstrate REQ-XYZ; what makes each test sufficient.
- Coverage goals: functional (primary), line, branch, toggle, FSM-state, FSM-transition.
- Specific coverpoints: every Xcew opcode × every CSR mode (e.g. DAG_MODE 0/1 × every EML expression), every IRQ source × every pipeline stage, every fault code from `fault_monitor`, every power-state transition in `orchestrator`, every cache hit/miss path in `eml_dag_cache` (4-way set-associative, LRU — verify all 4 ways exercised and LRU policy correct).
- Cross-coverage: Xcew op × CSR mode (e.g. EML compute with COMPLEX_MODE=1 and MAX_DEPTH=7), IRQ × Xcew stall (interrupt while EML pipeline busy), fault × power state (fault asserted in SLEEP state).

**PASS:** Plan references every REQ-ID and specifies how each is tested with measurable coverpoints.
**Owner:** Pair B

### 2.2 [ ] HARD GATE — Functional coverage measurement

**Action:**

- Add covergroups in SystemVerilog testbenches, or Verilator's `--coverage-toggle --coverage-line --coverage-user` equivalents.
- Generate coverage report on each `make sim_*` run; aggregate in `reports/latest/coverage/`.
- Track per-coverpoint hit rate over time.

**PASS:** Functional coverage ≥95% on declared coverpoints. Line coverage ≥90% on RTL (debug-only blocks exempted with `// pragma coverage_off` annotation). Branch coverage ≥85%. FSM state coverage 100%, transition coverage ≥95%.
**FAIL:** Below threshold without per-gap documented justification.
**Owner:** Pair B

### 2.3 [ ] HARD GATE — Directed tests for pipeline hazards

The 3-stage in-order pipeline plus Xcew stall is a known hazard surface. Required directed tests, each with documented expected behavior:

- Load-use hazard (load followed by ALU op consuming loaded value, ALU op followed by load to same address)
- Branch resolution timing (BEQ/BNE/BLT/BGE/BLTU/BGEU in EX, fetch ahead, mispredict recovery if any)
- JAL/JALR target computation correctness (test 11 in your bug list — make this permanent)
- Xcew op in EX coincident with interrupt assertion
- Xcew op stall coincident with fault assertion
- CSR write followed immediately by CSR read (read-after-write hazard)
- Memory write followed by memory read to same address (`mem_wstrb` byte-enable correctness — bug #12)
- Multiple back-to-back Xcew ops (FSM transition coverage in `xcie_ctrl`)
- Watchdog trip coincident with Xcew completion (race condition test)

**PASS:** Each scenario has a dedicated test in `tb/` with documented expected behavior, PASS/FAIL assertion, and waveform evidence file.
**Owner:** Pair B

### 2.4 [ ] HARD GATE — RISC-V architectural compliance (RISCOF + riscv-arch-test)

**Action:**

- Install: `pip install riscof`
- Clone: `git clone https://github.com/riscv-non-isa/riscv-arch-test`
- Implement a DUT plugin pointing at the Verilator model of Azmuth (`rtl/xcew_top_v1_1.v` driven by `tb/cosim/`)
- Implement a reference plugin (sail-riscv or Spike)
- Run full RV32IMC suite: `riscof run --config=config.ini --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env`
- Commit pass log to `docs/evidence/compliance/riscof_run_YYYYMMDD.log`

**PASS:** All `rv32i_m/I`, `rv32i_m/M`, `rv32i_m/C`, `rv32i_m/privilege`, `rv32i_m/Zicsr` tests pass. Log committed with reference commit hash of `riscv-arch-test`.
**FAIL:** Any test fails without explicit upstream waiver (and a waiver likely disqualifies "RISC-V compatible" trademark claim).
**Owner:** Pair B

### 2.5 [ ] HARD GATE — Xcew custom extension test suite

Standard `riscv-arch-test` covers IMC base. Xcew is custom and needs its own equivalent.

**Action:** Create `tests/xcew-arch-test/` mirroring riscv-arch-test layout. One directory per Xcew instruction class:

- `tests/xcew-arch-test/eml/` — EML compute with multiple expression complexities, COMPLEX_MODE on/off, MAX_DEPTH boundary tests, NaN/overflow/underflow inputs, DAG cache hit/miss verification
- `tests/xcew-arch-test/snn/` — SNN classify with 8-neuron and 256-neuron tiles, TTFS on/off, STDP learn on/off, all 6 STDP policies
- `tests/xcew-arch-test/nvm/` — NVM read/write/erase, ECC single-bit injection (must correct), ECC double-bit injection (must detect+halt), wear-leveling exercise
- `tests/xcew-arch-test/pol/` — Policy update, deterministic-mode cycle invariance, timeout-IRQ trigger
- `tests/xcew-arch-test/csr/` — Every CSR field, including illegal-write rejection, read-only enforcement, atomic update

Each test references Python golden-model outputs.

**PASS:** Every Xcew opcode has ≥3 directed tests with golden-reference output. Every CSR field has read/write/illegal-access tests.
**Owner:** Pair B

### 2.6 [ ] EVIDENCE — Co-simulation discipline

**Current state:** `make sim_cosim` and `make cosim_v1.1` exist. Output not committed.

**Action:** Treat co-simulation as a CI gate. On every PR, run firmware boot test through Verilator co-sim, compare PC trace and register state against golden trace from Spike. Diff must be zero.

**PASS:** CI workflow file (`.github/workflows/cosim.yml`) runs cosim and fails the PR on any diff. Last 10 PRs show co-sim passing.
**Owner:** Pair B

---

## Section 3 — Cross-Cutting Verification (often skipped)

**Why:** These are the failure modes that pass unit tests but kill chips. They also pass at simulation if you don't deliberately model them.

### 3.1 [~] HARD GATE — Clock domain crossing verification
> _Analysis done at `docs/CDC_ANALYSIS.md` (crossings C1–C8 inventoried). Result is FAIL: the core↔SNN crossing has **no synchronizers** in v1.1 RTL (DEV-011) — fix patterns + MTBF method specified; closing needs synchronizer insertion + a randomized-phase CDC testbench._

**Current state:** Two clock domains: `i_clk_core` (250 MHz) and `i_clk_snn` (125 MHz). No CDC analysis on file.

**Action:**

- Inventory every signal crossing between domains. Document in `docs/CDC_ANALYSIS.md` with source domain, destination domain, synchronizer style (2FF, handshake, async FIFO).
- For data crossings: confirm 2FF synchronizer minimum, or handshake protocol with Gray-coded multibit.
- For control: confirm 2FF.
- Run a CDC checker. Open-source option: `slang-cdc` or modular use of Yosys with custom passes. Commercial-equivalent rigor: write directed CDC testbenches with random-phase clocks and assertion checks.
- Compute MTBF estimate for each synchronizer at target Fmax.

**PASS:** Every CDC point documented with synchronizer style and MTBF estimate. No combinational logic crossing domains. No clock-domain mux without proper enable synchronization.
**FAIL:** Any undocumented or unsynchronized crossing.
**Owner:** Pair C

### 3.2 [ ] HARD GATE — Reset domain crossing analysis

**Action:** Document reset architecture in `docs/RESET_ARCH.md`. Specify:

- Synchronous vs asynchronous reset assertion
- Reset synchronizer per clock domain (recommended: async assert, sync de-assert)
- POR vs warm reset behavior
- Reset sequencing — order in which domains exit reset
- Body-bias DAC stabilization timer before functional reset deasserts

**PASS:** Every flop's reset signal is traceable to one reset source, with documented synchronization at any boundary.
**Owner:** Pair C

### 3.3 [ ] HARD GATE — AXI4-Lite protocol compliance

**Current state:** Custom interconnect `rtl/soc/axi_lite_interconnect_v1_1.v` (524 lines). No protocol checker on file.

**Action:**

- Add an open-source AXI4-Lite protocol checker (e.g. from PULP platform or pulp-cva6) as a bind module on every master/slave interface.
- Run all existing testbenches with checker enabled. Zero violations required.
- Specifically verify: VALID-before-READY does not lock; address-and-data handshake ordering; response within 16 cycles of request; no protocol-illegal back-pressure patterns.

**PASS:** All testbenches run with protocol checker enabled. Zero violations. Checker source committed under `tb/checkers/`.
**Owner:** Pair C

### 3.4 [ ] HARD GATE — Memory BIST and ROM integrity

**Current state:** Boot ROM (4KB), SRAM (4KB), NVM (64KB ReRAM). No BIST infrastructure.

**Action:**

- Add MBIST (March-C+ minimum) for SRAM. Triggerable via CSR. Result reported via `fault_status` or dedicated CSR.
- Add ROM signature check (CRC-32 of ROM contents verified at boot, stored at known ROM address).
- For NVM: ECC scrub already designed (CSR 0x7CE) — add a power-on scrub completion check.

**PASS:** SRAM MBIST passes on functional testbench. ROM signature verified at every boot. NVM scrub-completion bit observable. Tests for all three committed.
**Owner:** Pair C

### 3.5 [ ] HARD GATE — Power-on sequence and body-bias settling

**Current state:** `rtl/power/body_bias_ctrl.v` has calibration sweep FSM. No documented POR sequence.

**Action:** Document in `docs/POR_SEQUENCE.md`:

1. Power rails ramp (modeled or assumed)
2. POR reset assertion
3. Body-bias DAC calibration (estimated cycles)
4. ROM signature check
5. Cache/SRAM BIST
6. Functional reset deassert
7. PC fetches from boot vector

Test with a dedicated `tb/por_sequence_tb.v`. Verify no functional fetch before bias-cal complete.

**PASS:** POR sequence documented; testbench passes.
**Owner:** Pair C

### 3.6 [ ] EVIDENCE — UPF / power intent reconciliation

**Current state:** `syn/upf_v1.1_final.tcl` declares 5 PDs, 4 power switches, 7 isolation cells, 4 retention registers, 4 level shifters.

**Action:** Confirm against RTL:

- Every isolation cell in UPF maps to a real cross-domain signal in RTL with isolation logic.
- Every retention register in UPF maps to a real `rtl/power/retention_reg.v` instantiation.
- Every level shifter is at a real voltage boundary.

Inconsistency between UPF and RTL is a guaranteed PnR failure.

**PASS:** UPF-to-RTL reconciliation report in `docs/evidence/power/upf_check.md` with every UPF element mapped to RTL line.
**Owner:** Pair D + Pair C

---

## Section 3.5 — Debug Module Subsystem (NEW for v1.1)

**Why this section exists separately:** The Debug Module is a discrete subsystem affecting RTL, pad ring, AXI map, UPF, security model, and CDC. Treating it as a sub-bullet under existing sections would scatter the work. This section consolidates it.

**Scope decision:** Implement the RISC-V External Debug Specification 0.13.2 (ratified, mature, OpenOCD-supported) with minimum-viable-debug functionality. Specifically:

- Halt / resume / step on the single hart
- Read/write GPRs and CSRs via abstract commands
- Memory access via abstract commands (program-buffer route)
- Halt-on-reset support
- 4-instruction program buffer
- 2 hardware breakpoints via Trigger Module (mcontrol type)
- JTAG DTM (Debug Transport Module) per spec

Out of scope for v1.1: system bus access, multi-hart, RV32I-style debug mode (we use M-mode-only single hart), authentication beyond a simple debug-enable strap. These can be v1.2 enhancements.

**Implementation budget:** Expect ~3000–5000 lines of new RTL across DM + DTM + core integration. Verification ~2000–3000 lines of testbench. Synthesis impact: estimated +30–50K gates (5–8% of current design). Pad ring impact: +4 dedicated JTAG pins (TCK, TMS, TDI, TDO) plus optional TRST.

### 3.5.1 [ ] HARD GATE — Debug architecture specification

**Action:** Create `docs/DEBUG_ARCH_SPEC.md`. Required content:

- Reference: RISC-V External Debug Spec 0.13.2, sections covered and explicitly excluded
- DM register map (DMSTATUS, DMCONTROL, HARTINFO, ABSTRACTCS, COMMAND, ABSTRACTAUTO, PROGBUF[0..3], DATA[0..2], SBCS — even unused ones documented as read-zero/write-ignored)
- DTM register map (IDCODE, DTMCS, DMI)
- JTAG TAP state machine reference
- Halt request → halt acknowledgment timing
- Abstract command execution semantics (Access Register command primary; Quick Access used during step)
- Debug ROM contents (resides at 0x800–0xFFF in core memory map; contains the small handler that fetches commands)
- Trigger Module register map (TSELECT, TDATA1, TDATA2, TINFO)
- Debug-enable strap behavior — when held low at POR, debug is permanently disabled for this boot cycle (security)

Every requirement gets `REQ-DBG-NNN` prefix.

**PASS:** Spec covers every implemented debug feature. Cross-referenced to specific sections of RISC-V Debug Spec 0.13.2. Reviewed and signed off.
**Owner:** Pair A drives, Pair F (software) contributes adopter perspective

### 3.5.2 [ ] HARD GATE — Debug Module RTL

**Action:** Create `rtl/debug/` directory with new modules:

```
rtl/debug/
├── dm_top.v               # Debug Module top
├── dm_regfile.v           # DM-internal register file
├── dm_abstract_cmd.v      # Abstract command FSM
├── dm_progbuf.v           # 4-instruction program buffer
├── dm_trigger.v           # Trigger Module (2 hardware breakpoints)
└── debug_rom.v            # Synthesizable debug ROM (small)
```

Conformance requirements:

- DM is an AXI slave on the existing interconnect at a new base address (recommend 0x5000–0x5FFF; updates memory map). DM is also an AXI master for memory access from the debugger.
- DM controls hart halt/resume via dedicated signals to `riscv_core.v`.
- DM exposes a Debug Module Interface (DMI) to the DTM.
- Abstract commands implemented: Access Register, Quick Access, Memory Access (via program buffer).
- Reset domain: DM uses its own reset (`debug_rst_n`) so it survives functional resets and can debug a stuck hart.

**PASS:** RTL compiles, lints clean under Verilator. Module reference table in README updated. Files added to `rtl_list.f`.
**Owner:** Pair (new — designate two students, see 3.5.15)

### 3.5.3 [ ] HARD GATE — JTAG DTM RTL

**Action:** Create `rtl/debug/dtm/`:

```
rtl/debug/dtm/
├── jtag_tap.v            # IEEE 1149.1 TAP controller
├── jtag_dr.v             # Data registers (IDCODE, DTMCS, DMI)
└── dtm_top.v             # Wraps TAP + DR + DMI bridge to DM
```

Conformance: RISC-V Debug Spec 0.13.2 Chapter 6 (JTAG DTM). TAP state machine per IEEE 1149.1. DMI register width 41 bits (32 data + 7 address + 2 op).

The JTAG clock domain (`i_clk_tck`) is asynchronous to `i_clk_core`. All DMI transactions cross domains via handshake synchronizer.

**PASS:** DTM RTL compiles and lints. JTAG state-machine testbench passes (cycle through all 16 TAP states, verify register access).
**Owner:** Same DM pair

### 3.5.4 [ ] HARD GATE — Core integration (hart debug-state)

**Action:** Modify `rtl/core/riscv_core.v` to add debug-mode support:

- New CSRs: `dcsr` (0x7B0), `dpc` (0x7B1), `dscratch0` (0x7B2), `dscratch1` (0x7B3) — note these overlap CSR 0x7Bx range, verify no collision with existing CSRs
- Halt request input from DM; halt acknowledgment output to DM
- Debug-mode entry: save PC to `dpc`, save mode to `dcsr.prv`, fetch from debug ROM at 0x800
- Debug-mode exit: restore PC from `dpc`, restore mode from `dcsr.prv`, resume normal fetch
- Single-step support: `dcsr.step` set → execute one instruction, re-enter debug mode
- Halt-on-reset: when `dmcontrol.haltreq` is asserted at reset deassertion, hart enters debug mode immediately

**PASS:** Core modifications pass existing regression suite (no regression). New debug-specific tests pass.
**Owner:** Same DM pair, with Pair B (verification) review

### 3.5.5 [ ] HARD GATE — Debug-mode functional verification

**Action:** Create testbenches at `tb/debug/`:

- `tb/debug/halt_resume_tb.v` — request halt, verify hart halts within spec timing, read/write GPRs, resume, verify execution continues correctly
- `tb/debug/step_tb.v` — single-step through 100 instructions, verify each step advances PC by expected amount
- `tb/debug/breakpoint_tb.v` — set hardware breakpoint via Trigger Module, run to it, verify entry to debug mode at right PC
- `tb/debug/halt_on_reset_tb.v` — POR with haltreq asserted, verify hart halts before executing any instruction
- `tb/debug/csr_access_tb.v` — read/write every implemented CSR via abstract command, including the Xcew-specific CSRs (0x7C0–0x7CF)
- `tb/debug/memory_access_tb.v` — read/write SRAM, NVM (via CSR-mapped controller), Boot ROM (read-only verify)
- `tb/debug/jtag_protocol_tb.v` — drive JTAG TAP through all state transitions, verify DMI register access via TAP

**PASS:** All 7 testbenches PASS with directed-test coverage of every documented debug operation. 100% line coverage on `rtl/debug/`.
**Owner:** Pair B + DM pair

### 3.5.6 [ ] HARD GATE — CDC: JTAG TCK ↔ core clock

**Action:** This is a new clock domain crossing. JTAG `i_clk_tck` is asynchronous to `i_clk_core`. Document in `docs/CDC_ANALYSIS.md` (the existing CDC analysis from 3.1 must be extended):

- Every DMI signal crossing TCK → core clock: 2FF synchronizer minimum, handshake protocol for multi-bit
- Every signal crossing core clock → TCK: same
- Reset crossings: `debug_rst_n` must be synchronized into both domains
- MTBF estimate at maximum TCK (typically 20 MHz for safe operation; spec allows up to core/4 but we don't push it)

**PASS:** CDC analysis updated. Every TCK ↔ core crossing has documented synchronizer. No combinational paths cross domains.
**Owner:** Pair C

### 3.5.7 [ ] HARD GATE — Debug security model

**Critical:** Debug is the #1 IP-exfiltration vector. An adopter that ships a product with debug enabled by default is exposing every secret in NVM, every algorithm in firmware, every key in SRAM. This needs explicit treatment.

**Action:** Implement and document the following:

a) **Debug-enable strap pin** — A dedicated input pin (DEBUG_EN). Sampled at POR. If low, DM is permanently disabled for this boot cycle (DM responds to nothing). Cannot be re-enabled until next POR.

b) **Debug authentication (optional but recommended)** — A simple challenge-response gate on entry to debug mode. Read random nonce from a known DM register, hash with a fused key, write response back. Wrong response leaves DM disabled. Implementation can be deferred to v1.2 if it adds risk; v1.1 can ship with strap-only protection but it should be documented as the v1.1 security level.

c) **Sticky debug-occurred flag** — A non-clearable bit in `fault_status` (or new CSR) that sets the first time debug is entered. Adopter firmware can read this at boot and refuse to operate on a "debug-touched" chip. Forensic integrity.

d) **Disable NVM access when debug-enabled** — When DEBUG_EN was low at POR, debug cannot access NVM. This protects user keys/data. When DEBUG_EN was high at POR (development mode), debug can access everything. Adopters deploy with DEBUG_EN tied low.

**PASS:** All four implemented. Test cases verify each in `tb/debug/security_tb.v`. Documented in `docs/DEBUG_SECURITY_MODEL.md`.
**Owner:** DM pair + Pair C (security)

### 3.5.8 [ ] HARD GATE — Memory map and AXI interconnect update

**Action:** The existing memory map (per README) has Boot ROM, SRAM, EML CSR, SNN CSR, NVM CSR. Adding:

- Debug Module @ 0x5000–0x5FFF (DMI register window when accessed via core, also accessible from JTAG via DTM)
- Debug ROM @ 0x800–0xBFF (within the original Boot ROM space — relocate user boot to 0xC00 if conflict, or use the 0x800 region as standard per Debug Spec)

Update `rtl/soc/axi_lite_interconnect_v1_1.v`:

- Add DM as a new slave port (now 6 slaves)
- Add DM as a new master port (DM accesses memory on behalf of debugger; this finally justifies the "4M × 5S" naming you flagged earlier — DM is one of the masters)

This resolves deviation 1.3(a) — the README "1 master" claim was wrong; 4M × 5S becomes 5M × 6S with DM added. Update the README and ARCHITECTURE doc accordingly.

**PASS:** Interconnect updated, tested, AXI protocol checker (from 3.3) reports zero violations including on the new ports. Memory map documented in MICRO_ARCH_SPEC.md.
**Owner:** DM pair + Pair A (spec)

### 3.5.9 [ ] HARD GATE — UPF / power intent update

**Action:** DM must remain powered when other tiles are sleeping (otherwise you can't debug a sleeping system).

- Add `PD_DEBUG` as a new power domain (always-on alongside `PD_TOP`)
- Update `syn/upf_v1.1_final.tcl` with the new domain
- Add isolation cells between PD_DEBUG and switchable domains (debug requests crossing to PD_EML/PD_SNN/PD_NVM/PD_CORE)
- When DM requests access to a sleeping tile, the tile wakes (this is normal RISC-V debug behavior)

**PASS:** UPF updated. Power-aware simulation verifies DM can wake sleeping tiles. UPF-to-RTL reconciliation report (3.6) updated.
**Owner:** Pair D + DM pair

### 3.5.10 [ ] HARD GATE — Pad ring & debug transport (DECISION-005-aware)

**Action:** Per DECISION-005 (Lever L2: Caravel piggyback), the default v1.1 build uses **Caravel housekeeping SPI as the debug transport**. The DM itself is unchanged; only the transport adapter swaps.

**Default v1.1 transport (Caravel SPI, saves ~0.5 mm² and ~4 pads):**

- DM connects to Caravel's housekeeping SPI via a thin bridge module (`rtl/debug/dtm/caravel_spi_bridge.v`)
- Adopter debugger talks to Caravel SPI through Caravel's existing flash/management pins
- No new dedicated JTAG pins on Azmuth top
- `i_debug_en` strap still required (1 pad)
- Optional `o_debug_active` (1 pad)

**Parameterized alternate (DEBUG_TRANSPORT="JTAG") for Azmuth-Full v2:**

- Standalone JTAG TAP module enabled (`rtl/debug/dtm/jtag_tap.v` from 3.5.3)
- Dedicated pins: `i_jtag_tck`, `i_jtag_tms`, `i_jtag_tdi`, `o_jtag_tdo`, `i_jtag_trst_n` (5 pads)
- Used in v2 custom-MPW build outside Caravel harness

Both transports drive the same DMI; the DM module is unchanged. Per 1.5.4 parameterization, build-time selectable.

**PASS:** Caravel SPI bridge implemented and tested against Caravel's housekeeping SPI verification model. JTAG TAP still exists and lints clean (gated by parameter, not deleted). Updated floorplan in `pnr/floorplan/` includes JTAG pins on an accessible side of the die.
**Owner:** Pair D + DM pair

### 3.5.11 [ ] HARD GATE — Formal property additions

**Action:** Add to SBY formal verification suite:

- `sby/debug_safety.sby` — debug mode cannot corrupt non-debug state when entered/exited
- `sby/debug_security.sby` — debug-disabled chip never enters debug mode regardless of JTAG input

These join the existing 18 properties → now 20 properties to prove. Run as part of `make formal`.

**PASS:** Both properties prove (assuming SBY infrastructure is up per check 1.3(c)).
**Owner:** Pair C

### 3.5.12 [ ] HARD GATE — End-to-end debug flow validation

**Action:** Full software-stack validation (this also covers software-side checks but is gated here for hardware audit completeness):

1. Build firmware that loops on counter
2. Load to Verilator co-sim with JTAG simulator
3. Connect OpenOCD over simulated JTAG
4. Attach GDB
5. Halt, inspect registers, set breakpoint, resume, hit breakpoint, single-step, modify register, resume, observe behavior change
6. Inspect memory, observe NVM contents (debug-enabled mode), confirm NVM blocked (debug-disabled mode)

**PASS:** Full flow works on co-sim. Recorded as a screencast or terminal log in `docs/evidence/debug/end_to_end_flow.md`.
**Owner:** Pair F (software) + DM pair

### 3.5.13 [ ] EVIDENCE — Debug Module decision record

**Action:** `docs/DECISIONS.md` entry DECISION-004:

```
## DECISION-004: Add Debug Module to v1.1 scope
Date: YYYY-MM-DD
Decided by: Kiransekar + team
Context: Initial RTL inventory had no DM. Adopters cannot use GDB/OpenOCD
on silicon without a DM. Shipping without DM forces a v1.2 respin or
permanently degraded adopter experience. Schedule impact ~6-10 weeks for
the team; accepted to avoid second tapeout cycle.
Decision: Implement RISC-V External Debug Spec 0.13.2, minimum-viable
scope (halt/resume/step, GPR/CSR access, 2 HW breakpoints, JTAG DTM).
Consequences:
  - +30-50K gates synthesis impact
  - +4-5 pad ring pins (JTAG + strap)
  - +1 power domain (PD_DEBUG always-on)
  - +1 AXI master, +1 AXI slave on interconnect
  - New CDC domain (TCK)
  - New security threat surface requiring explicit treatment
  - 6-10 weeks added to schedule
Reviewed: YYYY-MM-DD (active)
```

**Owner:** Team lead

### 3.5.14 [ ] EVIDENCE — DM verification report

**Action:** Consolidated report in `docs/evidence/debug/DM_VERIFICATION_REPORT.md` summarizing:

- Spec coverage (which sections of RISC-V Debug Spec 0.13.2 are implemented, which are explicitly excluded)
- Testbench coverage (each test from 3.5.5, plus 3.5.11 formal, plus 3.5.12 end-to-end)
- Security model summary (from 3.5.7)
- Known limitations and v1.2 enhancement targets

This is the document that goes to adopters as proof of debug functionality.

**Owner:** DM pair

### 3.5.15 [ ] HARD GATE — DM pair assignment

**Action:** Designate two students as the **Debug Module pair**. This is enough work to warrant its own pair; it cannot be a side-task for an existing pair.

If team is at 8: this expands the structure to 5 pairs. If team is at 6: rebalance — DM pair takes priority, one of the existing pairs (likely Pair A spec, since DM heavy spec is already in scope) absorbs the slack.

Document in DECISIONS.md.

**Owner:** Team lead

---

## Section 4 — Security Claims: Empirical Validation

**Why critical:** This is where most academic processors get caught at commercial due diligence. Every claim in the README must have a corresponding experiment in the verification report. CC EAL2 `AVA_VAN` (vulnerability analysis) evidence lives here.

### 4.1 [ ] HARD GATE — Constant-time EML verification (TVLA-style)

**Claim:** `rtl/eml/eml_constant_time.v` provides cycle-padded operations to prevent timing side-channels.

**Test:**

1. Generate two large sets of EML input vectors: `S_random` (random) and `S_fixed` (all bits zero, or all bits set).
2. For each input, run through EML pipeline in cosim. Record total cycles and a switching-activity proxy (count of net toggles per cycle, dumped from VCD).
3. Welch's t-test on cycle count: must yield |t| < 4.5 (the conventional TVLA threshold) — proves no operand-dependent timing.
4. Welch's t-test on switching activity per cycle: same threshold — proves no operand-dependent power proxy.
5. Repeat with EML_DAG_MODE = 0 (tree mode) and EML_DAG_MODE = 1 (DAG+CSE mode) — both must pass.

**Script:** `tests/security/constant_time_eml.py` — generates inputs, parses VCD, computes t-statistic.

**PASS:** |t| < 4.5 on both metrics, both DAG modes. Report at `docs/evidence/security/constant_time_eml_report.md` with statistical methodology and plots.
**FAIL:** |t| ≥ 4.5 — leakage exists; redesign or document as known limitation.
**Owner:** Pair C

### 4.2 [ ] HARD GATE — Deterministic policy execution

**Claim:** `rtl/core/policy_determinism.v` enforces fixed-cycle execution with timeout IRQ (CSR 0x7CB).

**Test:**

1. Generate ≥1000 distinct policy-update operations with varying operands.
2. Measure cycles from `XCEW_POL_UPD` issue to completion under DET_EN=1.
3. Cycle count must be identical across all inputs (zero variance).
4. With DET_EN=0, variance is allowed.
5. Timeout IRQ test: configure MAX_CYCLES low enough to trip, verify IRQ fires at exactly MAX_CYCLES+1.

**PASS:** Zero cycle-count variance with DET_EN=1. Timeout IRQ fires at expected cycle. Report at `docs/evidence/security/deterministic_policy_report.md`.
**Owner:** Pair C

### 4.3 [ ] HARD GATE — Fault monitor — fault injection campaign

**Claim:** `rtl/security/fault_monitor.v` latches WATCHDOG, ECC_SINGLE, ECC_DOUBLE, SOFT_EML, SOFT_SNN, HARD_NVM, CSR_VIOLATION, INSTR_FAULT.

**Test:** For each fault code:

1. Construct a stimulus that should trigger it.
2. Verify `fault_status` CSR (0x7CC) shows the correct code.
3. Verify `o_irq_fault` asserts.
4. Verify pipeline halts (for hard faults) or continues with notification (for soft faults).
5. Verify W1C clear behavior — writing 1 to bit [31] clears, other bits preserve.

**PASS:** All 8 fault codes individually triggered, observed, cleared. Coverage matrix in `docs/evidence/security/fault_injection_report.md`.
**Owner:** Pair C

### 4.4 [ ] HARD GATE — ECC SECDED verification

**Claim (after bug #17 fix):** 7-bit SECDED in NVM — single-bit corrected silently, double-bit detected and reported.

**Test:**

1. For 100 random data words: write to NVM, inject single-bit flip in each of the 39 codeword bit positions (32 data + 7 check), read back. Result must equal original data; `ecc_corrected_count` must increment.
2. For 100 random data words: write, inject double-bit flip in 100 distinct bit-pair positions, read. Must trigger `ECC_DOUBLE` fault; data must not be silently corrupted.
3. For 100 random data words: write, inject triple-bit flip. SECDED cannot detect all triple errors — document the residual probability.

**PASS:** All single-bit injections corrected. All double-bit injections detected. Triple-bit detection rate documented (typical SECDED: ~50% of triple-bit errors detected as double-bit, the rest miscorrected — this is the known SECDED limitation).
**Owner:** Pair C

### 4.5 [ ] HARD GATE — Watchdog functional test

**Claim:** Configurable timeout, pipeline halt on trip (CSR 0x7CD).

**Test:** Configure timeout to N cycles. Issue an instruction that hangs (e.g. infinite loop). Verify watchdog trips at exactly cycle N+epsilon, pipeline halts, IRQ asserts, fault code = WATCHDOG.

**PASS:** Watchdog trip at expected cycle ±tolerance. Pipeline halt observable on VCD. Test in `tb/watchdog_tb.v`.
**Owner:** Pair C

### 4.6 [ ] EVIDENCE — Security Target document (CC EAL2)

**Action:** Produce `docs/evidence/cc/SECURITY_TARGET.md` per ISO/IEC 15408 Common Criteria Part 1 structure:

1. ST Introduction (TOE reference, TOE overview, TOE description)
2. Conformance Claims (CC version, Part 2/3 conformance, PP conformance, package conformance)
3. Security Problem Definition (threats, assumptions, organizational security policies)
4. Security Objectives (for the TOE, for the operational environment)
5. Security Requirements (functional — SFR; assurance — SAR matching EAL2)
6. TOE Summary Specification

For a cognitive-EW processor, expected threats include: timing side-channel, power side-channel (out of EAL2 scope but worth declaring), fault injection (also out of EAL2), denial-of-service via malformed Xcew operands, ECC bypass.

This document drives every empirical test in 4.1–4.5.

**PASS:** Security Target document drafted, internally reviewed, and matches the implemented security features.
**Owner:** Pair A + Pair C

### 4.7 [ ] EVIDENCE — Vulnerability analysis (CC AVA_VAN.2)

**Action:** Produce `docs/evidence/cc/VULNERABILITY_ANALYSIS.md` listing:

- Each declared security feature
- Known attack against that feature class (literature reference)
- Why the implementation resists it (or its limitation)
- Residual risk

Examples:
- Constant-time EML: DPA Book attack class → resistance demonstrated by TVLA (4.1) → residual risk: power-side-channel not in scope at EAL2.
- ECC SECDED: triple-bit injection → mitigation: periodic scrub (CSR 0x7CE) limits accumulated soft errors → residual risk: simultaneous triple-bit corruption within one scrub interval.
- Debug Module (NEW with 3.5): JTAG-based IP extraction → mitigation: DEBUG_EN strap permanently disables DM at POR + NVM access blocked in debug-enabled mode + sticky debug-occurred flag (per 3.5.7) → residual risk: physical access with strap modification; out of EAL2 scope (physical attack).

**PASS:** One row per security feature; each row complete.
**Owner:** Pair A + Pair C

---

## Section 5 — Synthesis QoR: Pre-PnR Sanity

**Why:** If synthesis says you'll miss timing, area, or power, PnR will not save you. This is the cheapest possible gate.

### 5.1 [ ] HARD GATE — Cell count and area estimate

**Action:** Run `syn/synth_final.tcl` with timing constraints. Capture from Yosys/Synlig report:

- Total cell count
- Cell-area-equivalent (in PDK units, GEs, or μm²)
- Gate count broken down by module (xcew_top_v1_1 / core / eml / snn / nvm / power / security / interconnect)

Estimate post-PnR area assuming ~50–60% utilization (routing/buffer overhead): `synth_area / 0.55`.

**PASS:** Estimated die area ≤ **10 mm²** (Caravel user area constraint per DECISION-005). Per-block area within budget as defined in Section 1.5 table. Specifically:

| Block | Target (post-optimization) |
|-------|---------------------------|
| Core + Xcew dispatch | ≤2.5 mm² |
| EML unit + compressed cache | ≤1.8 mm² |
| SNN virtualized tile | ≤1.8 mm² |
| NVM controller (logic only, external macro) | ≤0.5 mm² |
| AXI + power + security | ≤1.0 mm² |
| Boot ROM + SRAM | ≤0.5 mm² |
| Debug Module (Caravel SPI transport) | ≤1.5 mm² |
| Routing overhead at 25% | factored in above |

If any individual block exceeds budget by >15%, immediate review — likely indicates Section 1.5 lever not delivering as estimated.
**FAIL:** Estimate over 10 mm² total, or any single block over budget without documented justification + offset elsewhere.
**Owner:** Pair D

### 5.2 [ ] HARD GATE — Timing — pre-layout critical paths

**Action:** Run STA on synthesis netlist with `syn/sdc_final.sdc` (250 MHz core, 125 MHz SNN, 0.5 ns I/O delay, 0.1 ns uncertainty). Capture top 20 critical paths.

**PASS:** Worst Negative Slack ≥ 0 on both clock domains with ≥10% margin (target WNS ≥ 0.4 ns on 4.0 ns core period). Top 20 paths reviewed; none through unexpected blocks.
**FAIL:** WNS < 0 on any corner, or critical paths through Xcew dispatch (which would mean dispatch overhead exceeds budget).
**Owner:** Pair D

### 5.3 [ ] HARD GATE — Pre-layout power estimate

**Action:** Run Yosys/OpenSTA power estimation with switching activity from a representative testbench (firmware boot + EML compute + SNN classify + NVM write). Capture dynamic + static power.

**PASS:** Estimated total power ≤ 1.6 W (80% of 2 W budget — leaving 20% PnR margin).
**FAIL:** Over budget without clear path to closure.
**Owner:** Pair D

### 5.4 [ ] HARD GATE — Clock gating verification

**Action:** Confirm Yosys clock-gating insertion produced gates where UPF intent expects. Verify gate count, gating ratio, and that no functional clock arrives at a sleeping tile (per UPF).

**PASS:** Clock gating report shows enable on every PD_EML, PD_SNN, PD_NVM datapath flop. No always-on clocks in switched domains.
**Owner:** Pair D

### 5.5 [ ] HARD GATE — Synth-vs-RTL formal equivalence

**Action:** Run Yosys `equiv_make` / `equiv_induct` between RTL elaborated netlist and post-synthesis netlist. Must prove equivalence per top-level partition.

**PASS:** Equivalence proven for every top-level partition.
**FAIL:** Any non-equivalence — synthesis introduced a bug.
**Owner:** Pair D

---

## Section 5.5 — Shuttle Commitment & Area Closure (NEW)

**Why:** No PnR work proceeds without a shuttle commitment. Pad ring, floorplan, IO assignments, and harness compliance all depend on the target. This is the formal gate that locks the destination.

### 5.5.1 [ ] HARD GATE — Synth area measurement (already in 5.1, this is the commitment-check view)

**Action:** Use the area numbers from check 5.1 (per-block synth area report after L1/L3/L4 optimizations land). Combine with conservative routing overhead (28% — slightly above the 25% target to account for PnR worst case).

**PASS:** Total estimated post-PnR area ≤ 9.5 mm² (leaves 5% headroom against Caravel's 10 mm² user area, accounting for sealring and overhead).
**FAIL:** Total ≥ 9.5 mm² — additional reduction required before committing to ChipIgnite. Escalate to team lead; consider whether L5 has been fully exploited or whether one of L1/L3/L4 needs deeper cut.
**Owner:** Pair D + team lead

### 5.5.2 [ ] HARD GATE — Caravel harness compatibility check

**Action:** Verify Azmuth's external interface matches Caravel's `user_project_wrapper` contract:

- IO count: Caravel exposes 38 user IOs. Azmuth's required IOs after L1/L2 optimization:
  - QSPI master to external NVM: 6 pads (clk, cs_n, 4 data) — can map onto Caravel's spare GPIO
  - UART TX/RX for adopter logging: 2 pads
  - Debug enable strap: 1 pad
  - Optional debug-active indicator: 1 pad
  - Optional EW-input data (SDR sampling, ADC interface for CEW demo): 8-16 pads
  - Total: ~18–26 pads, comfortably within 38
- Wishbone slave port: Caravel exposes a wishbone master to user area; Azmuth must accept it as a CSR-window slave (translate to your AXI4-Lite via a thin bridge)
- Logic analyzer: Caravel's 128-bit LA bus can be optionally connected to selected internal observability points
- Clock: Caravel provides `user_clock2` to the user area; Azmuth's i_clk_core comes from this

Create `docs/CARAVEL_INTEGRATION.md` documenting every interface signal mapping.

**PASS:** Interface mapping complete. No Caravel-side feature required that we don't implement. Caravel's golden user_project_wrapper.v stub instantiates Azmuth cleanly.
**Owner:** Pair D

### 5.5.3 [ ] HARD GATE — Shuttle commitment authorization

**Action:** Formal commitment to a specific shuttle slot. Decision recorded in `docs/DECISIONS.md` as DECISION-006 with:

- Shuttle name and date (e.g. "ChipIgnite November 2026 shuttle" or "Cadence-Skywater ReRAM shuttle Q2 2026")
- Slot cost confirmation and funding source
- ChipIgnite vs Cadence-Skywater ReRAM tier rationale (since you use ReRAM externally, the standard ChipIgnite without ReRAM option works — saves ~$2k)
- Backup shuttle if primary slips
- Final GDS deadline (drives all earlier deadlines)

This authorization is signed by team lead. No PnR-related work in Section 6 starts until this is committed.

**PASS:** DECISION-006 signed and committed. Backup plan documented.
**Owner:** Team lead

### 5.5.4 [ ] EVIDENCE — Area justification document

**Action:** Single document `docs/evidence/area/AREA_JUSTIFICATION.md` mapping the journey:

- Original target: 18 mm² (rationale: feature set sized to that)
- Optimized target: 10 mm² (rationale: shuttle constraint per DECISION-005)
- Per-lever savings measured (L1 actual mm² saved, L3 actual, L4 actual, L5 actual)
- Architectural claims preserved with citation to equivalence reports from 1.5.5

This is the document an adopter or auditor reads to understand "did Azmuth really fit without compromising what it claims to do?"

**Owner:** Pair A + Pair D

---

## Section 6 — Physical Implementation & Signoff

**Why:** Everything before this is necessary but not sufficient. This is where physical reality is verified.

**Note on PDK:** The plan below assumes SKY130 (Efabless / OpenROAD-supported, mature open ecosystem). If the target is IHP SG13G2 or another PDK, library names and constraints will differ but the gate structure is the same. Decide and document in `docs/PDK_DECISION.md` before starting Section 6.

### 6.1 [ ] HARD GATE — Floorplan review

**Current state:** `floorplan.png`, `floorplan.svg`, `floorplan_visualization.txt` at root.

**Action:** Move floorplan artifacts to `pnr/floorplan/`. Review against:

- Power-domain spatial grouping (PD_EML adjacent to core; PD_SNN can be remote; PD_NVM near IO if external pins)
- Memory placement (SRAM, NVM macros placed early; clock trees routed around)
- Clock distribution feasibility (250 MHz over the die at 130nm — clock skew budget)
- Pad ring layout (assume MPW pad ring constraints if Efabless)

**PASS:** Floorplan reviewed and signed off by Pair D + team lead. Annotated in `pnr/floorplan/FLOORPLAN_REVIEW.md`.
**Owner:** Pair D

### 6.2 [ ] HARD GATE — OpenROAD PnR closure

**Action:** Run full OpenROAD flow: floorplan, placement, CTS, routing, post-route optimization. Iterate until timing meets target at all corners.

**PASS:**

- Setup WNS ≥ 0 at slow corner (SS, max T, min V)
- Hold WNS ≥ 0 at fast corner (FF, min T, max V)
- DRC clean
- LVS clean (netlist vs schematic match)
- IR drop within PDK limits
- EM within PDK limits
- Antenna violations resolved

Sign-off report in `reports/latest/pnr/`.
**FAIL:** Any check fails without documented waiver.
**Owner:** Pair D

### 6.3 [ ] HARD GATE — DFT — scan insertion and ATPG

**Current state:** `dft/` directory exists; coverage status unknown.

**Action:**

- Insert scan chains. Use Yosys scan-insertion or a chosen open tool.
- Generate ATPG patterns. Run on netlist.
- Measure stuck-at coverage.

**PASS:** Stuck-at coverage ≥ 95% (your declared target). At-speed (transition-delay) coverage ≥ 80% if achievable in open flow. Test pattern files committed under `dft/patterns/`.
**FAIL:** Coverage below threshold — review untestable nodes, add observation points if needed.
**Owner:** Pair D

### 6.4 [ ] HARD GATE — Caravel user_project_wrapper integration

**Action:** Per DECISION-006 (ChipIgnite target), Azmuth ships inside Caravel's `user_project_wrapper`, not as a standalone top-level chip.

Implementation:

- Add `caravel/user_project_wrapper.v` that instantiates `xcew_top_v1_1` (with parameters set for Lite config per 1.5.4)
- Map Caravel's IO ports (`io_in`, `io_out`, `io_oeb`) to Azmuth's interface signals per the mapping table from 5.5.2
- Map Caravel's wishbone slave port to an AXI4-Lite bridge inside the wrapper (32-bit data, supports the CSR access pattern adopters expect)
- Wire Caravel's `user_clock2` to `i_clk_core`; synthesize divided `i_clk_snn` from a PLL or counter (avoiding adding a PLL — use Caravel's clock if possible)
- Wire Caravel's POR signal into Azmuth's reset network
- Connect housekeeping SPI to the debug bridge from 3.5.10 (Caravel SPI debug transport)
- Wire selected internal signals to Caravel's 128-bit logic analyzer bus for post-silicon debug observability

**PASS:** `user_project_wrapper.v` builds successfully through the Efabless OpenLane flow. Caravel-level simulation (Verilator with full caravel harness) runs a Hello-World firmware end-to-end. DRC clean against Caravel integration rules.
**FAIL:** Any Caravel interface contract violation, or wrapper-induced timing violation.
**Owner:** Pair D + DM pair (for debug bridge)

### 6.5 [ ] HARD GATE — OpenLane flow (Caravel-required)

**Action:** ChipIgnite requires the design to harden through OpenLane (not raw OpenROAD scripts). Migrate the existing OpenROAD scripts in `pnr/` to an OpenLane `config.json` (or `config.tcl`):

- Set `DESIGN_NAME = user_project_wrapper`
- Wire up Caravel's PDK location, SCL library, std-cell selections
- Configure floorplan to match Caravel's expected die area (2920μm × 3520μm)
- Power planning matches Caravel's power grid expectations
- Configure for SKY130 high-density (`sky130_fd_sc_hd`) standard cells unless area savings demand low-density
- IO pad assignment via OpenLane's `pin_order.cfg`

Document differences from the original raw-OpenROAD flow.

**PASS:** OpenLane flow runs to completion with `make user_project_wrapper`. Output GDS is signoff-ready per Caravel integration requirements.
**Owner:** Pair D

### 6.6 [ ] EVIDENCE — Caravel pre-check report

**Action:** Run `mpw_precheck` (Efabless's automated pre-submission verification) and address every flagged issue:

- License check
- YAML manifest validity
- GDS hierarchy and naming check
- DRC check against Caravel-specific rules
- LVS against Caravel's expected netlist contract
- Magic XOR check (verifies that user_project_wrapper hasn't been modified outside the user area)
- Computational area check (verifies all logic is in the user_project_wrapper, not bleeding into Caravel's harness)

**PASS:** `mpw_precheck` exits clean. Report committed to `docs/evidence/shuttle/precheck_report_YYYYMMDD.md`.
**Owner:** Pair D

### 6.7 [ ] HARD GATE — Tape-out package contents

**Action:** Assemble final deliverables in `tapeout/`:

- GDSII (`azmuth_v1_1.gds`)
- LEF (abstract for hierarchical use, if applicable)
- Library views (LIB / CDL netlist)
- DRC clean report
- LVS clean report
- STA signoff report (all corners)
- IR drop report
- EM report
- Antenna report
- Scan / ATPG patterns
- JTAG pin assignment and TAP IDCODE register documentation (from 3.5.10)
- Debug Module register map handoff to OpenOCD developers (from 3.5.1)
- README in `tapeout/` listing every file with checksum

**PASS:** All artifacts present, checksummed, signed off.
**Owner:** Pair D

---

## Section 7 — Certification Evidence Packages

This section is the assembled artifact that goes to RVI and to adopters. Most content already lives in `docs/evidence/` per earlier sections; here it's organized for delivery.

### 7.1 [ ] EVIDENCE — RISC-V compatibility package

**Action:** Assemble `docs/evidence/compliance/RISCV_COMPATIBILITY_PACKAGE.md`:

- RV32IMC compliance statement
- RISCOF run log (from 2.4)
- Reference model used (Spike commit hash) and DUT model (Verilator commit hash)
- Coverage report against `riscv-arch-test` suite version
- Statement of Xcew custom extension (out of scope for RVI ISA compatibility but documented)

When RVI's formal core certification program opens for submissions, this package is what you submit.

**Owner:** Pair B

### 7.2 [ ] EVIDENCE — Common Criteria EAL2 evidence package

**Action:** Assemble `docs/evidence/cc/` containing:

- `SECURITY_TARGET.md` (from 4.6)
- `FUNCTIONAL_SPEC.md` — high-level functional description of the TOE (the chip) — largely drawn from MICRO_ARCH_SPEC.md
- `TOE_DESIGN.md` — subsystem decomposition with security relevance
- `VULNERABILITY_ANALYSIS.md` (from 4.7)
- `CONFIGURATION_MANAGEMENT.md` — describes the git workflow, signed commits, branch protection (from 0.5)
- `LIFECYCLE_DEFINITION.md` — describes the development process (from 1.4 bug retrospective + ongoing)
- `DELIVERY_PROCEDURES.md` — how the TOE is delivered (GDSII handoff to fab, RTL release to adopters)
- `FUNCTIONAL_TESTING.md` — pointer to the verification plan and coverage reports (from 2.x)
- `INDEPENDENT_TESTING.md` — explicitly state where independent re-execution is enabled (reproducible builds, Docker image of toolchain)
- `VULNERABILITY_TESTING.md` — pointer to security-empirical reports (from 4.1–4.5)

This package is what an accredited CC lab needs to evaluate. You can publish it as-is; formal evaluation requires the lab engagement.

**Owner:** Pair A + Pair C

### 7.3 [ ] EVIDENCE — Reproducible build

**Action:** Provide a Docker image (or Nix flake) that contains the exact toolchain — Yosys, OpenROAD, Verilator, Icarus, SBY, RISCOF — at pinned versions. Anyone running `make all` inside this container produces byte-identical netlists and reports.

**PASS:** `Dockerfile` or `flake.nix` committed. CI builds and tags the image. Documented in README.
**Owner:** Pair D

---

## Section 8 — Team Process & Governance

**Why:** 6–8 enthusiastic students will produce excellent work if integration discipline is enforced and fail catastrophically if it isn't.

### 8.1 [ ] HARD GATE — Pair assignments

Recommended structure (adjust based on individual strengths):

| Pair | Members | Scope |
|------|---------|-------|
| A | 2 | Spec, traceability, CHANGELOG, micro-arch document, debug arch spec (3.5.1), CC EAL2 narrative artifacts |
| B | 2 | Functional verification, RISCOF integration, Xcew test suite, coverage tracking, debug-mode functional verification (3.5.5) |
| C | 2 | Formal (SBY), CDC/RDC/AXI checking (extended to JTAG TCK domain), security empirical tests, fault injection, debug security model (3.5.7) |
| D | 2 | Synthesis, PnR, signoff, DFT, packaging, reproducible build, pad ring (3.5.10), UPF debug-domain (3.5.9) |
| **DM** | **2** | **Debug Module RTL (3.5.2), JTAG DTM (3.5.3), core integration (3.5.4), end-to-end debug flow validation (3.5.12)** |

If team is at 8: this is 5 pairs of 2. If team is at 6: rebalance — DM pair gets priority; Pair A absorbs spec slack (still owns 3.5.1 with DM pair contributing); Pair B absorbs debug-verification slack (3.5.5).

**Owner:** Team lead

### 8.2 [ ] HARD GATE — Cadence

- **Daily:** Async standup (Slack/Discord) — yesterday/today/blockers.
- **Twice weekly:** 30-min sync — review checklist progress, blockers.
- **Weekly:** Integration meeting — merge PRs, update this document, decide next-week priorities.
- **Monthly:** External review — invite a senior engineer outside the team to review progress against this document.

**Owner:** Team lead

### 8.3 [ ] HARD GATE — Issue tracking

Every task in this document becomes a GitHub issue (or equivalent). Issue title format: `[Sect 4.1] Constant-time EML TVLA test`. Issue body references the checklist item, owner pair, dependencies, target completion week.

PR title format: `[REQ-EML-007] Add constant-time guard for negative inputs`. PR description references issue number and checklist section.

**Owner:** Team lead

### 8.4 [x] HARD GATE — Decision log

Create `docs/DECISIONS.md`. Every architectural or process decision gets a numbered entry:

```
## DECISION-001: PDK target is SKY130
Date: YYYY-MM-DD
Decided by: Kiransekar + Pair D lead
Context: Open commercial market, fastest path to first silicon via Efabless.
Decision: Use SKY130A for v1.1 tapeout. SG13G2 evaluated as v2 option for RF integration.
Consequences: Library names, std-cell timing, memory compilers fixed to SKY130A.
Reviewed: YYYY-MM-DD (still valid)
```

Every PR that hinges on a decision references the DECISION number.

**Owner:** Team lead

---

## Appendix A — Execution Order

The checks are listed in topical order; execution order is partially constrained:

1. **Week 1–2:** Section 0 entirely. Repo cleanup unblocks every audit downstream.
2. **Week 2–4:** Section 1 (spec + traceability) in parallel with Section 3 (cross-cutting).
3. **Week 2–6:** **Section 1.5 (Architecture Optimization).** L1 (external NVM), L3 (SNN virtualization), L4 (EML cache compression) — the architectural RTL refactors. Equivalence verification (1.5.5) gates the merge. Parameterization (1.5.4) happens in parallel as a meta-task.
4. **Week 2–10:** Section 3.5 (Debug Module). Long-pole new work. RTL weeks 2–5, verification 4–8, integration + formal 7–10. Caravel SPI bridge (3.5.10) coordinates with Section 6.4.
5. **Week 3–6:** Section 2 (functional verification + RISCOF).
6. **Week 5–8:** Section 4 (security empirical).
7. **Week 6–10:** Section 5 (synth QoR). Starts after Section 1.5 RTL freezes for a release tag. Section 5.5 (shuttle commitment) gates Section 6.
8. **Week 10–18:** Section 6 (PnR + Caravel integration + OpenLane + pre-check + tape-out). Pad ring locked by 5.5.2. OpenLane migration (6.5) in parallel with PnR closure.
9. **Week 14–20:** Section 7 (cert evidence assembly).

These ranges are illustrative. **The HARD GATE on the shuttle commitment (Section 5.5.3) is the binding deadline — work backwards from the chosen ChipIgnite GDS submission date with ≥4 weeks margin for PnR iteration and ≥2 weeks for `mpw_precheck` cleanup.** Adding DM (Section 3.5) plus the Section 1.5 optimization workstream extends the original 16-week plan to ~20 weeks. If this conflicts with a chosen shuttle slot, raise immediately and consider a later shuttle.

---

## Appendix B — Risk Register

Top risks to track weekly:

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| PnR timing closure misses 250 MHz on 130nm | Medium | High | Pre-PnR critical-path review (5.2); fallback to 200 MHz with documented spec revision |
| RISCOF reveals ISA compliance failures requiring RTL changes | Medium | High | Run RISCOF early (Week 3), not late |
| TVLA test reveals operand-dependent leakage in EML | Medium | Medium | Constant-time logic already in place (`eml_constant_time.v`); fix is iterative |
| Team member departure mid-cycle | Medium | High | Pair structure ensures no single point of failure; documented decisions and traceability allow handoff |
| SBY proof finds counter-example invalidating a security claim | Low | High | Resolve by spec revision or RTL fix; transparency in CC vulnerability analysis preserves trust |
| Fab MPW slot moves | Medium | Medium | Quality-driven plan — internal deadline ahead of shuttle |
| Open PDK lib bug surfaces at PnR | Low | High | Pin PDK version in reproducible build (7.3); document workaround |
| **DM implementation overruns (8 → 14+ weeks)** | **Medium** | **High** | **Designate dedicated DM pair (3.5.15); incremental milestones at 4w/8w/12w; descope to v1.2 only as last resort, accepting v1.1 ships without DM and adopters use Verilator-only debug** |
| **Debug security flaw enables IP exfiltration on production silicon** | **Low** | **Critical** | **DEBUG_EN strap + sticky flag (3.5.7); explicit testing under 3.5.7; clear adopter documentation that strap must be tied low in production** |
| **JTAG TCK CDC metastability causes intermittent debug failures** | **Low** | **Medium** | **2FF synchronizers on every DMI signal (3.5.6); MTBF computation documented; TCK frequency limited to 20 MHz in datasheet** |
| **L3 SNN virtualization fails functional equivalence test** | **Medium** | **High** | **Equivalence campaign in 1.5.5 catches it early. If fails, fall back to 192-physical / 256-logical (1.5x area, still fits budget) or accept 192-neuron tile as v1.1 with 256-neuron deferred to v2 in Azmuth-Full** |
| **L4 EML cache compression degrades hit rate beyond 5%** | **Medium** | **Medium** | **Equivalence check in 1.5.5 gates merge. Fallback: revert to original cache but reduce DM area further or accept tighter routing budget** |
| **External QSPI NVM bring-up reveals interface bug at silicon** | **Medium** | **High** | **Extensive QSPI master verification in 1.5.1 against multiple flash models (Adesto, Winbond, Cypress); board-level debug capability via Caravel logic analyzer; firmware-driven NVM tests** |
| **Caravel harness integration reveals timing or DRC issue late** | **Medium** | **High** | **Run mpw_precheck (6.6) at weekly cadence from week 10 onward, not just at the end. Treat any precheck regression as a stop-the-line issue** |
| **OpenLane migration disrupts existing OpenROAD flow expertise** | **Low** | **Medium** | **Pair D learns OpenLane on a small block first (e.g. eml_dag_cache standalone) before tackling full integration. Keep raw OpenROAD scripts as reference / fallback** |

---

## Appendix C — Definition of "Tapeout-Ready"

Tapeout-ready means **every HARD GATE is checked PASS with linked evidence commit, and every EVIDENCE item exists as a written artifact in `docs/evidence/`**. Specifically:

- Section 0: All 7 items PASS
- Section 1: All 4 items PASS
- Section 1.5: All 5 HARD GATEs + 1 EVIDENCE item (Architecture Optimization)
- Section 2: All 6 items PASS
- Section 3: All 6 items PASS
- Section 3.5: All 13 HARD GATEs + 2 EVIDENCE items (Debug Module)
- Section 4: All 7 items PASS
- Section 5: All 5 items PASS
- Section 5.5: All 3 HARD GATEs + 1 EVIDENCE item (Shuttle Commitment)
- Section 6: All 7 items PASS (now includes Caravel-specific integration items 6.4–6.6)
- Section 7: All 3 items PASS
- Section 8: All 4 items active

Total: **64 HARD GATEs + 10 EVIDENCE items**. No exceptions.

When all are checked, the team lead writes a one-page "Tapeout Authorization" memo signed by all pair leads (including the DM pair) and the team lead, committed to `docs/TAPEOUT_AUTHORIZATION.md`, and only then is the GDS submitted to the chosen shuttle (DECISION-006).

---

*End of audit document. This is a living document — update on every check completion. Commit messages updating this file should reference the checklist item closed: `[Sect 4.1] Mark constant-time EML TVLA PASS`.*
