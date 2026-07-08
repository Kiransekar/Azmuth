<!-- ============================================================================
  AZMUTH TAPEOUT ROADMAP — MASTER PLAN v2.0 (DETAILED)
  ============================================================================
  STATUS: READ-ONLY. AGENTS MUST NOT MODIFY THIS FILE. NO EXCEPTIONS.

  Rules of engagement for every agent session that reads this file:

    1. NEVER edit, append to, reformat, re-wrap, "fix typos in", or mark
       tasks complete inside this file. Treat write access as absent.
    2. ALL progress   -> docs/PROGRESS.md   (schema defined in §A.4)
       ALL decisions  -> docs/DECISIONS.md  (continue DECISION-0NN numbering)
       ALL bug finds  -> docs/BUGLOG.md     (schema defined in §A.6)
    3. If a task here is wrong, impossible, or overtaken by events:
       record it in docs/DECISIONS.md with rationale, choose the closest
       compliant action, continue. Do NOT rewrite the plan.
    4. If you believe you must edit this file, you are wrong. Stop and
       write your reasoning to docs/DECISIONS.md instead.

  Repo owner — enforce mechanically after committing this file:
      chmod 444 TAPEOUT_PLAN_v2.md
      git update-index --skip-worktree TAPEOUT_PLAN_v2.md
  Add to CLAUDE.md (verbatim):
      "TAPEOUT_PLAN_v2.md is the immutable master plan. Never modify it.
       Progress goes to docs/PROGRESS.md, decisions to docs/DECISIONS.md,
       bugs to docs/BUGLOG.md. Read TAPEOUT_PLAN_v2.md §A before any work."
  ============================================================================ -->

# Azmuth (Xcew v1.1) — End-to-End Tapeout Plan v2.0

| Field | Value |
|---|---|
| Target | Fabricable, honest, fully traceable RV32IMC edge-AI SoC (EML + SNN + NVM-ready + power mgmt + security) |
| Process | **SkyWater SKY130**, `sky130_fd_sc_hd` std cells, open flow. "TSMC 130nm" language is removed everywhere — no PDK access exists (no liberty file has ever been in the repo; see BUG-A7) |
| Tools | Icarus 12+, Verilator 5.x, Yosys 0.38+, OpenROAD 2.0+, SymbiYosys, OpenSTA, Magic, netgen, KLayout |
| Signoff clocks | **Core 100 MHz (10.0 ns) TARGET · SNN 50 MHz (20.0 ns) · JTAG ≤10 MHz**, TT 025C 1v80, 300 ps uncertainty. **250/125 MHz is dead; never write it anywhere again** (BUG-A4). NOTE: 100 MHz is an *unvalidated target*, not precedent — no verified SKY130 RV32IMC fmax datapoint exists (docs/RESEARCH_FINDINGS.md F-12); the P5 STA baseline may force a derate to ~40–60 MHz, which is acceptable for the target market (kHz sensing). Cycles are the currency; MHz is provisional until STA |
| Positioning | Always-on edge-AI sensing SoC for **industrial machine-condition monitoring** (see INDUSTRY_TARGET.md v1.1 + docs/RESEARCH_FINDINGS.md). The niche is real but CONTESTED — SynSense Xylo IMU already ships there at <500 µW (F-1); Azmuth's differentiators are completeness (full RISC-V SoC), on-chip STDP learning, open-flow auditability, and India-sovereign supply — NOT "an SNN for vibration" |
| Tapeout vehicle | **RE-OPEN (DECISION-006 is stale): Efabless/ChipIgnite shut down** (RESEARCH_FINDINGS F-11). Candidates: ChipFoundry ChipCreate SKY130 MPW, Tiny Tapeout, IHP SG13G2 (open 130nm, EU). Decided in P6-T1 |
| Sibling plan set | TOOLCHAIN_PLAN.md (software), RISK_PLAN.md (market/risk), FPGA_PLAN.md (validation + industry benchmark), INDUSTRY_TARGET.md (positioning analysis) |
| Plan version | v2.1 — task IDs stable; mirrors AEGIS discipline. v2.1 (2026-07-08) corrects v2.0 against verified research (docs/RESEARCH_FINDINGS.md): Efabless dead → vehicle re-opened (P6-T1); ReRAM reasoning fixed (BUG-A11/P4-T2); 100 MHz flagged unvalidated; positioning corrected for the Xylo competitor |

---

# §A — AGENT OPERATING PROTOCOL (read fully before ANY task)

## A.1 Session startup checklist (every session, no skipping)

Run these in order and paste outputs into your working notes before editing
anything:

```bash
git status --short                    # know what's uncommitted; P0-T0 clears the backlog
git log --oneline -5                  # know where you are
tail -30 docs/PROGRESS.md             # know what's done
tail -30 docs/DECISIONS.md            # know what's been decided
bash flow/sim.sh 2>&1 | tail -5       # must be green BEFORE you start
```

If the sim suite is red at session start: your first task is to bisect and
fix the regression (log in docs/BUGLOG.md), regardless of what you were asked
to do. Never build on a red baseline.

## A.2 Model routing & orchestration

- **[OPUS]** tasks -> the strongest available model. Cross-module reasoning,
  RTL redesign, timing closure, formal debug, CDC analysis, or irreversible
  decisions. An Opus session may NOT delegate the core reasoning of an
  [OPUS] task to a subagent; it may delegate mechanical legwork.
- **[SONNET]** tasks -> a mid-tier model. Mechanical, parallelizable,
  per-file work. Pattern: the orchestrator spawns one subagent per
  file/unit, gives each the EXACT diff specification, collects diffs,
  reviews every diff line-by-line, and commits only after review.
- Subagent prompts MUST include: (a) the task ID, (b) the acceptance
  command(s) the subagent must run and paste, (c) the sentence "Do not
  modify any file other than <list>", (d) the sentence "Do not modify
  TAPEOUT_PLAN_v2.md".
- A subagent that needs to touch a file outside its list must return and
  report, not improvise.

## A.3 Commit & branch discipline

- Branch per task: `task/P1-T3-sequential-divider`. Merge to main only with
  CI green. No direct commits to main except docs-only changes.
- Commit message format:
  ```
  [P1-T3] Replace combinational divider with radix-2 sequential unit

  Why: single-cycle $signed division dominates the flattened critical path
  (see BUGLOG BUG-A4). Evidence: sim log path, STA delta in syn/reports/.
  Trace: docs/TRACEABILITY.md row updated.
  ```
- One logical change per commit. A commit that mixes an RTL fix with a doc
  reformat will be rejected in review.

## A.4 docs/PROGRESS.md schema (create in P0-T5 exactly like this)

```markdown
| Task | Date | Model | Branch | Evidence | Status |
|------|------|-------|--------|----------|--------|
| P0-T1 | 2026-07-09 | sonnet | task/P0-T1-purge-artifacts | CI run #3 | DONE |
```
Status ∈ {TODO, IN-PROGRESS, BLOCKED(reason), DONE, WONTDO(link to DECISIONS)}.
Evidence must be a checked-in file path, CI run, or tagged log — never prose.
docs/AUDIT_PROGRESS.md is ARCHIVED history (P0-T6); new progress goes here only.

## A.5 docs/DECISIONS.md — continue the existing log

Azmuth already has DECISION-001..009. New entries continue the numbering
(DECISION-010, -011, …) in the existing file and format, each with Context /
Options / Chosen / Consequences. This plan MANDATES several decisions below;
record each as a DECISION entry when executed (deviations need written
rationale).

## A.6 docs/BUGLOG.md schema

```markdown
## BUG-A1: EML FSM hangs when requester deasserts i_valid  [FIXED f0e6bda]
Found: 2026-07-06 external audit. RTL: rtl/eml/eml_unit.v FSM advanced only
while i_valid held. Masked by: SoC TBs holding valid. Fix: free-running FSM.
Test: eml_tb (single-pulse valid). Lesson -> CI gate P0-T4.
```
Every bug gets an entry BEFORE the fix commit, updated after.
Prefixes: BUG-Axx hardware, SW-Axx software (TOOLCHAIN_PLAN §B),
FPGA-Axx board findings (FPGA_PLAN).

## A.7 The evidence rule (zero tolerance)

Never write a number (MHz, %, cycles, cells, mm², mW, test counts, accuracy)
into README, docs, or code comments unless a checked-in artifact proves it,
and the text links to that artifact. When you delete a false claim, keep a
tombstone in docs/BUILD_LOG.md: what was claimed, why it was wrong, what
replaced it. This is the rule the 2026-07 audit found broken ("Verilator
lint 0 warnings" vs actual 501; "82 PASS" vs non-reproducible; 250 MHz vs
combinational divide).

## A.8 The red-before-green rule

For every functional bug: (1) write/extend a test that FAILS on current RTL,
commit it on the task branch with `[Pn-Tm][red]` prefix and the failing log;
(2) fix the RTL; (3) commit fix with the passing log. CI on the branch may be
red between (1) and (2) — that is the only sanctioned red.

## A.9 When uncertain

Ambiguity resolution order: (1) this plan; (2) docs/DECISIONS.md;
(3) the RISC-V ISA spec (riscv-spec-20191213 unprivileged, privileged v1.12)
— the spec ALWAYS beats existing Azmuth RTL behavior; (4) ask the human via
a BLOCKED status + a written question in PROGRESS.md. Never guess silently
on ISA semantics, memory maps, or constraint values.

## A.10 Environment bootstrap (run once per fresh container)

```bash
sudo apt-get update && sudo apt-get install -y \
  iverilog verilator yosys gtkwave python3-pip git make
pip install --break-system-packages riscof
# OSS CAD Suite for sby+solvers; OpenROAD via ORFS or release binaries.
# Sky130 liberty/LEF: vendored under third_party/sky130hd/ in P5-T0 —
# do not re-download ad hoc.
source toolchain/env.sh        # pinned RISC-V toolchain (already in repo)
```
Record tool versions in docs/PROGRESS.md at first use; pin them in CI.

---

# §B — KNOWN DEFECT REGISTER (context you must not rediscover)

From the 2026-07 external audit (AZMUTH_AUDIT_REPORT.md) plus repo-state
findings of 2026-07-08. Locate by content, not line number.

| ID | File | Defect | Status |
|---|---|---|---|
| BUG-A1 | `rtl/eml/eml_unit.v` | Operation FSM advanced only while `i_valid` held high → single-pulse requesters hang forever | FIXED f0e6bda — verify present (P1-T1) |
| BUG-A2 | `rtl/eml/eml_unit.v` | Memo cache written with previous op's registered output under current expression's hash → cache poisoning | FIXED f0e6bda — verify |
| BUG-A3 | `rtl/eml/eml_unit.v` | Memo hits completed in 2 cycles vs 5 for misses — data-dependent timing leak in the block whose headline feature is constant time | FIXED f0e6bda (hits traverse full 5-stage path; energy benefit retained) — verify `eml_timing_tb` zero variance |
| BUG-A4 | `rtl/core/riscv_core.v` | Entire M-extension combinational in one ALU cycle: `/` and `%` operators + THREE parallel 64-bit multiplies. ~69 levels of logic pre-flatten. 250 MHz physically impossible | OPEN → P1-T3/P1-T4 |
| BUG-A5 | `rtl/xcew_top_v1_1.v` + others | 501 Verilator lint warnings vs "0 warnings" claim. Worst class: 26 UNDRIVEN — `tile_wake_req_int`, `tile_activity_count`, `fault_detected_int`, `eml_expr_*`/`eml_subexpr_*` declared but never driven → power/fault/EML-DAG features may be structurally inert on silicon | OPEN → P1-T5 (UNDRIVEN), P2-T2 (burn-down) |
| BUG-A6 | repo | ~237 committed build artifacts: `logs/`, `reports/`, `*.vcd`, `floorplan.png/svg`, `*.o` in root | OPEN → P0-T1 |
| BUG-A7 | `syn/` | Synthesis references `syn/130nm_std.lib` which has never existed; all "synthesis" so far is generic mapping — no real timing/area number has ever been produced | OPEN → P5-T0/P5-T1 |
| BUG-A8 | `tb/top_tb.v` | Port drift vs current top's AXI/debug-UART interface — `sim_top` may not exercise the real top | OPEN → P1-T6 |
| BUG-A9 | `Makefile`/`cosim_v1.1` | cosim_v1.1 target is partly mock (generates JSON reports without simulating) | OPEN → P0-T3 (claim hygiene) + P2-T4 |
| BUG-A10 | interconnect vs firmware | Interconnect decodes a 16-bit map (ROM 0x0000 / SRAM 0x1000 / EML 0x2000 / SNN 0x2100 / NVM 0x2200 / DM 0x5000) while `firmware/main.c` uses 0x00020000/0x21000/0x22000 and README shows a third variant. The truncation/scaling rule between core byte-addresses and the 16-bit compare is UNDOCUMENTED and unverified at region boundaries | OPEN → P1-T2 |
| BUG-A11 | `rtl/nvm/` + README | "ReRAM controller" is behavioral only — no macro, no PDK NVM IP. CORRECTION (RESEARCH_FINDINGS F-9): SKY130 open ReRAM (`sky130_fd_pr_reram`) DOES exist, but its repo was **archived read-only 2026-04-18**, self-describes as "under development… does not guarantee the results," and has **no demonstrated shuttle tapeout**. So the NVM story cannot tape out on ReRAM — not because ReRAM is absent, but because the open ReRAM is experimental/unmaintained/unproven | OPEN → P4-T2 (mandated re-scope) |
| BUG-A12 | README | EML exp/ln "<0.2% error" claim has no evidence file | OPEN → P3-T2 |
| BUG-A13 | two-clock + JTAG | Real CDC synchronizers exist (`cdc_reset_sync`, `cdc_pulse_sync`, 4-phase req/ack) — good — but no formal CDC audit and no documented CDC constraints; JTAG adds a third domain | OPEN → P1-T7/P5-T3 |
| BUG-A14 | repo root | Duplicate `CLAUDE.md`/`Claude.md` existed in cached listings (case-only difference — hazard on case-insensitive filesystems) | Verify + consolidate → P0-T2 |
| BUG-A15 | working tree | 36-file uncommitted diff (+2426/−1305) including a functional `riscv_core.v` Xcew-writeback/stall change, AXI interconnect rework, toolchain restructure, untracked CI workflow `.github/workflows/cosim.yml`, untracked debug/NVM/CDC testbenches. Uncommitted work is unreviewed, unevidenced work | OPEN → P0-T0 (first task of the whole plan) |
| BUG-A16 | README | Non-reproducible test claims: "82 PASS across 8 testbenches / 12/12" not tool-emitted. Clean-clone truth (post-patch): 23/23 iverilog TBs | OPEN → P0-T3 |

Already-strong baseline (do not redo, do build on): rv32i_m/I 38/38, C 27/27,
privilege 16/16 vs Spike via `flow/compliance_archtest.sh`; real RISC-V Debug
Module (rtl/debug/ + toolchain/openocd); pinned toolchain with docker;
sby formal configs incl. debug_safety/debug_security; DECISIONS.md discipline.

---

# §C — THE PHASES

Dependency graph: P0 → P1 → P2 → {P3, P4 in parallel} → P5 → P6; P7 parallel
from P3 onward. Never start Pn+1 while Pn exit gate is red, except where
"overlap" is stated.

════════════════════════════════════════════════════════════════════════════
## PHASE 0 — Repo hygiene & honesty reset  [SONNET unless marked, ~2–3 days]
════════════════════════════════════════════════════════════════════════════

### P0-T0 [OPUS] Triage and land the uncommitted working tree (BUG-A15)
THE first task. Nothing else starts on a dirty tree.
**Procedure:**
1. Inventory `git status --short` into three buckets: (a) functional RTL
   changes (`riscv_core.v` Xcew WB/stall fix, `axi_lite_interconnect_v1_1.v`
   rework, `cdc_sync.v`, `nvm_ctrl.v`, `fault_monitor.v`, `body_bias_ctrl.v`,
   `eml_constant_time.v`), (b) toolchain/SDK/firmware restructure + new
   testbenches + CI workflow, (c) doc updates.
2. For bucket (a): each functional RTL change gets the §A.8 treatment
   retroactively — identify or write the test that fails without it
   (e.g. the Xcew-WB change must have a directed TB case: Xcew op followed
   immediately by a dependent read of rd), run the full 23-TB suite + the
   three arch-test suites, then commit per logical change with evidence.
   If a change cannot be justified by a test, PARK it on a branch and BUGLOG.
3. Buckets (b)/(c): commit in coherent units (toolchain restructure, CI
   workflow, new TBs each with a passing run log, docs).
4. Deleted-in-tree files (`toolchain/XcewOptPass.cpp`, old riscof env):
   confirm superseded location before committing the deletion.
**Acceptance:** `git status --short` empty; full suite + arch-test green on
the resulting HEAD; every commit message names its evidence.

### P0-T1 [SONNET] Purge committed build artifacts (BUG-A6)
`git rm -r --cached` for `logs/`, `reports/` (keep `reports/latest` as a
gitignored convention, not tracked content), root `*.vcd`, `*.o`, `*.elf`,
`floorplan.png/svg`, per-date report trees. Extend `.gitignore`. Do NOT
rewrite git history — the history is evidence.
**Acceptance:** `git ls-files | grep -cE '\.(vcd|o|elf)$|^logs/|^reports/'` → 0;
suite green.

### P0-T2 [SONNET] CLAUDE.md consolidation (BUG-A14) + plan supremacy
One `CLAUDE.md` only. Remove/replace: "TSMC 130nm", "250 MHz core / 125 MHz
SNN", "<18 mm², <2 W" with the honest targets and links. Add the verbatim
immutability sentence from this file's header, plus the same for
TOOLCHAIN_PLAN.md / RISK_PLAN.md / FPGA_PLAN.md.
**Acceptance:** `ls | grep -ci claude` → 1; CLAUDE.md contains the
immutability sentences; no stale frequency/process claims remain in it.

### P0-T3 [SONNET] Strip false/unproven claims (BUG-A4/A9/A16 + audit)
**Files:** `README.md`, `docs/*.md`, `docs/v1.1_datasheet.md`, RTL headers.
1. Every "250 MHz"/"4.0 ns" → "100 MHz signoff target (evidence:
   syn/reports/, populated in P5)". Every "125 MHz" SNN → "50 MHz". The
   DECISION-005 "time-muxed at 200 MHz" lever is re-derated or WONTDO'd
   (DECISIONS.md entry).
2. "Verilator lint … 0 warnings" → the real current count with a link to the
   P2-T2 burn-down; "82 PASS / 12/12" → CI badge + "authoritative list is
   `find tb -name '*_tb.v'`".
3. "ReRAM controller" → "NVM-ready controller (behavioral model; silicon
   backing per DECISION-0xx, see P4-T2)". "<0.2% error" exp/ln → "accuracy
   measured in P3-T2 (docs/evidence/eml/)" until the evidence exists.
4. `cosim_v1.1` mock: either delete the target or rename `cosim_report_stub`
   with a banner; `make sim_cosim` and the Verilator path stay.
5. Tombstones for every removed claim in docs/BUILD_LOG.md (§A.7).
**Acceptance:** `grep -rniE '250 ?MHz|125 ?MHz|82 PASS|0 warnings|TSMC' README.md docs/ rtl/ | grep -v BUILD_LOG | grep -v BUGLOG` → empty; CI green.
**Common mistake:** deleting cycle counts. Cycles stay (they get verified);
only unverified time/frequency/area/power claims go.

### P0-T4 [SONNET] CI as the evidence machine
`.github/workflows/` (build on the untracked cosim.yml from P0-T0):
job 1 = full iverilog TB suite (grep for FAIL markers — `vvp` exit code lies);
job 2 = Verilator lint on `xcew_top_v1_1` publishing the warning count as a
badge/summary (non-blocking until P2-T2, then zero-tolerance);
job 3 = `flow/compliance_archtest.sh` for rv32i_m/I + C + privilege (M joins
in P2-T1); job 4 = `make check_csr_v1.1`. All required on PR except lint.
**Acceptance:** CI green on main; README badges point at these workflows.

### P0-T5 [SONNET] Create tracking docs
`docs/PROGRESS.md` (§A.4 schema, all task IDs pre-seeded TODO),
`docs/BUGLOG.md` (§B entries BUG-A1..A16 verbatim + SW-Axx from
TOOLCHAIN_PLAN §B). DECISIONS.md continues as-is.
**Acceptance:** files exist; BUGLOG has all §B + TOOLCHAIN §B entries.

### P0-T6 [SONNET] Archive stale planning docs
Prepend "ARCHIVED — superseded by TAPEOUT_PLAN_v2.md + docs/PROGRESS.md" to
docs/AUDIT_PROGRESS.md (it remains the historical record of Slices 1–15).
Check docs/AZMUTH_TAPEOUT_AUDIT.md / AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md for
instructions that contradict this plan; where they conflict, this plan wins
(note it in their headers).
**Acceptance:** banners present; CLAUDE.md points here.

### PHASE 0 EXIT GATE (run all; paste into PROGRESS.md)
```bash
git status --short | wc -l                                    # 0
git ls-files | grep -cE '\.(vcd|o|elf)$|^logs/'               # 0
grep -rniE '250 ?MHz|TSMC' README.md rtl/ | wc -l             # 0
bash flow/sim.sh 2>&1 | grep -ci fail                         # 0
```

════════════════════════════════════════════════════════════════════════════
## PHASE 1 — Correctness & constraints reset  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### P1-T1 [OPUS] Verify audit fixes present (BUG-A1/A2/A3)
Confirm by content in `rtl/eml/eml_unit.v`: free-running stage FSM (no
`if (i_valid)` gating stage advance), memo written from fresh `result_r` at
WB, memo hits traversing the full 5-stage path, sticky-valid output.
Run `eml_tb` + `eml_timing_tb` (zero-variance verdict) + full suite.
**Acceptance:** greps + suite green; PROGRESS updated with log path.

### P1-T2 [OPUS] Memory-map contract (BUG-A10) — THE big decision
**Context:** three inconsistent maps exist (interconnect 16-bit constants,
firmware byte addresses, README table). The truncation rule from a 32-bit
core address to the 16-bit interconnect compare is undocumented; region
boundaries have never been tested through the mux.
**Mandated decision (record as DECISION-010, deviate only with rationale):**
one canonical map in a NEW `spec/memory_map.yaml` (single source of truth,
consumed by TOOLCHAIN_PLAN S2 codegen), documenting: full 32-bit byte
address per region, the exact bit-slice the interconnect compares, and the
alias/hole behavior for out-of-window addresses (must fault or documented-
alias, never silent wrap into another region).
**Red-first test:** `tb/soc/memory_map_tb.v` — for EVERY region: access
base, base+4, top−3, top; assert exactly one slave select; access a hole
(e.g. 0x3000_0000 and the address firmware currently calls UART) and assert
the documented miss behavior. Expect this TB to expose today's ambiguity —
commit the failing/ambiguous log first per §A.8.
**Files rippled:** `axi_lite_interconnect_v1_1.v`, `xcew_top_v1_1.v`,
`firmware/main.c` + `firmware/linker.ld` (via generated headers, S2),
README map table (regenerated, not hand-edited).
**Acceptance:** memory_map_tb green; README map generated from the YAML;
firmware links against generated addresses; full suite green.

### P1-T3 [OPUS] Sequential divider (BUG-A4, part 1)
**Spec (implement exactly):** non-restoring radix-2, 32 iterations + 2
setup/fixup = **fixed 34-cycle latency, data-independent, never
early-terminating** — determinism and constant-time are the product story;
a variable-latency divider would contradict the EML constant-time claim one
module over. Reuse the existing Xcew stall mechanism (`stall_id_ex`) —
the core already knows how to stall multi-cycle ops; extend it for M-ops.
**RISC-V semantics (spec v20191213 §7.2 — the spec wins over old RTL):**

| Case | DIV | DIVU | REM | REMU |
|---|---|---|---|---|
| b = 0 | −1 (all ones) | 2³²−1 | a | a |
| a = −2³¹, b = −1 | −2³¹ | n/a | 0 | n/a |

**Red-first test:** new `tb/muldiv_tb.v`: (1) the 4 corner cases, (2) 2,048
fixed-seed pseudorandom (a,b) pairs vs a `/`-and-`%` reference model inside
`ifdef SIMULATION`, (3) assertion that done arrives exactly 34 cycles after
issue, (4) back-to-back ops, (5) interrupt asserted mid-divide (decide
abandon-restart vs complete; DECISION entry; test the chosen behavior).
**Acceptance:** muldiv_tb green incl. determinism assertion;
`yosys -p 'read_verilog rtl/core/riscv_core.v; synth; stat' | grep -c '\$div'` → 0;
**rv32i_m/M arch-test suite green vs Spike (added in P2-T1 but smoke-run
now)** — M has never faced an external suite and this is its bug family.

### P1-T4 [OPUS] Single shared multiplier (BUG-A4, part 2)
Replace the three parallel 64-bit products (s×s, s×u, u×u) with ONE signed
33×33 multiply using sign-extended operands
(`{a[31] & sgn_a, a} * {b[31] & sgn_b, b}`), result slice selected per
MUL/MULH/MULHSU/MULHU; registered output, 2-cycle latency folded into the
same stall mechanism as P1-T3 (document the new WCET for M-ops).
**Acceptance:** muldiv_tb MUL cases green; Yosys `stat` shows the multiplier
count drop; arch-test M green.

### P1-T5 [OPUS] UNDRIVEN wire-up (BUG-A5 structural subset)
For each of the 26 UNDRIVEN signals in `xcew_top_v1_1.v` and below
(`tile_wake_req_int`, `tile_activity_count`, `fault_detected_int`, the
`eml_expr_*`/`eml_subexpr_*` cluster): trace the intended path in
docs/ARCHITECTURE.md and either wire it or tie off with
`assign x = '0; // reserved, DECISION-0xx`. These gate whether the power
orchestrator, fault monitor, and EML-DAG features exist on silicon at all.
Add/extend a directed TB per revived feature path (e.g. tile sleep→wake
round trip observable at the top; fault inject→`fault_detected` at the top).
**Acceptance:** `verilator --lint-only -Wall` shows 0 UNDRIVEN; new TB cases
green; full suite green.

### P1-T6 [SONNET] top_tb repair (BUG-A8)
Regenerate `tb/top_tb.v` ports against the current `xcew_top_v1_1` interface
(AXI + debug UART + JTAG). It must at minimum: release reset, run the boot
path, complete one EML op, one SNN op, one NVM op, one DM halt/resume via
the JTAG BFM, and check `o_debug_uart` activity once the console exists
(TOOLCHAIN S0-T3).
**Acceptance:** `make sim_top` exercises the real top; suite green.

### P1-T7 [OPUS] CDC audit part 1 — structural (BUG-A13)
Inventory every core↔SNN and JTAG↔core crossing signal. For each: which
synchronizer structure covers it (2-flop, pulse sync, 4-phase req/ack, async
FIFO), and the constraint it needs (`set_max_delay -datapath_only`, or
false-path + gray-code note). Output `docs/CDC_CONSTRAINTS.md` (table:
signal, domains, structure, constraint, test). Multi-bit buses crossing
without a qualified handshake are BUGLOG entries. The existing
`cdc_snn_tb.v` grows randomized-phase stress (both clocks with irrational
period ratio + jittered reset release).
**Acceptance:** table covers 100% of crossings; stress TB green; every
crossing has a planned SDC line (written in P5-T3).

### P1-T8 [SONNET] Single-source clock constraints
`constraints/clocks.tcl`: `set CORE_CLK_PERIOD 10.0`, `set SNN_CLK_PERIOD
20.0`, `set JTAG_CLK_PERIOD 100.0`, uncertainty 0.3, io delays. Make
`syn/*.sdc`, `syn/*.tcl`, `openlane/`/`pnr/` configs source or match it.
**Acceptance:** `grep -rnE '4\.0 ns|8\.0 ns|250|125 MHz' syn/ pnr/ openlane/ constraints/` → empty; synth dry-run still works.

### PHASE 1 EXIT GATE
```bash
bash flow/sim.sh && bash flow/compliance_archtest.sh rv32i_m/M   # green
verilator --lint-only -Wall -f rtl/rtl_list.f 2>&1 \
  | grep -cE 'UNDRIVEN'                                          # 0
yosys -p 'read_verilog -sv rtl/core/riscv_core.v; synth; stat' \
  2>/dev/null | grep -c '\$div\|\$mod'                           # 0
grep -rn '250\|4\.0ns' constraints/ syn/ | wc -l                 # 0
```

════════════════════════════════════════════════════════════════════════════
## PHASE 2 — Independent verification  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### P2-T1 [OPUS] Complete the arch-test matrix (M suite + signature CI)
I, C, privilege already pass vs Spike — the remaining and highest-risk gap
is **M** (BUG-A4's family). Wire rv32i_m/M through the existing
`flow/compliance_archtest.sh` differential path. EVERY mismatch → BUGLOG →
red-first fix. Then make all four suites a required CI job (cache the
toolchain).
**Prohibition:** never "fix" a mismatch by editing the test, the signature
range, or the reference model.
**Acceptance:** I+M+C+privilege 100% signature match in CI, required-green.

### P2-T2 [SONNET, orchestrated by OPUS] Lint burn-down 501 → 0
Inventory `verilator --lint-only -Wall` by file; one subagent per file with
the rule "change behavior = forbidden; if a fix would change behavior,
return BLOCKED with analysis". Categories: UNUSEDSIGNAL (180) delete-or-
waive with rationale; PINCONNECTEMPTY (72) explicit; PINMISSING (55)
connect or explicit-empty with comment; width/BLKSEQ per style. UNDRIVEN
already zero from P1-T5. Orchestrator reviews every diff; suite + arch-test
green proves no behavior change. Then flip the CI lint job to blocking.
**Acceptance:** 0 warnings, CI-enforced; waiver file diff reviewed — every
waiver has ≥2 sentences of rationale.

### P2-T3 [OPUS] Formal property revival + extension
Run every existing `.sby` (eml, snn, security, power, debug_safety,
debug_security); triage {PASS, harness-broken, property-false}. Minimum
green set (create missing):
1. `eml_constant_time`: for any two operand/history pairs, cycle count
   identical (the BUG-A3 regression property — this is the product claim).
2. `memo_correctness`: memo hit result == recompute result (bounded).
3. `nvm_secded`: encode→flip 1 bit→decode == original + corrected flag;
   2 flips → detected (symbolic bit index).
4. `interconnect`: exactly-one-hot slave select ∨ documented miss, ∀ addr
   (pairs with P1-T2).
5. `muldiv`: 8-bit operand slice vs reference + 34-cycle done invariant.
6. `debug_safety`/`debug_security`: keep green (already exist).
`make formal` runs the green set; CI nightly.
**Acceptance:** `bash flow/formal.sh` exits 0; each property file header
states WHAT is proven and the bound.

### P2-T4 [SONNET] Coverage + honest cosim
`flow/coverage.sh` (exists, untracked → landed in P0-T0): verilator
`--coverage` build, `verilator_coverage --annotate`, total % in CI summary,
ratchet vs committed baseline (−0.5% tolerance). Retire the BUG-A9 mock for
good: `make cosim` = firmware on the Verilator model only.
**Acceptance:** coverage number published; baseline committed; no coverage
claims outside generated files.

### PHASE 2 EXIT GATE
RV32IMC + privilege arch-test 100% in CI · lint 0 warnings, blocking ·
formal green set passing · coverage baseline committed · Phase 1 gate still
green.

════════════════════════════════════════════════════════════════════════════
## PHASE 3 — Domain verification campaign  [~2 weeks, may overlap P4]
════════════════════════════════════════════════════════════════════════════

Azmuth's product claims are (1) constant-time ML primitives, (2) accurate
fixed-point EML math, (3) a working SNN classifier with on-chip STDP,
(4) fault tolerance (SECDED, watchdog, fault monitor), (5) power
orchestration. Each claim gets a campaign; each campaign feeds
docs/evidence/ and the trust ledger (RISK_PLAN R0-T2).

### P3-T1 [OPUS] Constant-time verification campaign (TVLA-style)
Extend `eml_timing_tb` + `tb/constant_time_eml_tb.v` into a campaign:
≥10,000 randomized operand pairs × {cold cache, warm cache, adversarial
memo-thrash}, assert zero cycle variance across ALL of it; same for the
`policy_determinism` path (policy_det_1000 exists — make it 10k and CI-
nightly). Output `docs/evidence/security/ct_campaign.md` (generated).
**Acceptance:** campaign reproducible from one make target; zero variance
or a BUGLOG entry per violation.

### P3-T2 [OPUS] EML numerical accuracy evidence (BUG-A12)
Sweep exp/ln (and composed expressions) across the full Q16.16 domain
against double-precision reference: max/mean relative error, worst inputs,
error-vs-input plot. Emit `docs/evidence/eml/accuracy_report.md` +
regenerable script. README's accuracy claim becomes a link to this file
with the MEASURED number, whatever it is.
**Acceptance:** report exists, regenerated in CI (fast subset) + full run
committed once; README links it.

### P3-T3 [OPUS] SNN golden-model equivalence + STDP convergence
Python golden model of the LIF-TTFS neuron + WTA classify + the 6 STDP
policies (`sdk/models/` per TOOLCHAIN S4). Randomized stimulus equivalence
RTL-vs-model (spike times identical, not just labels). STDP: a small
synthetic task must show weight convergence on-RTL matching the model
within tolerance. This is the prerequisite for the INDUSTRY benchmark
(FPGA_PLAN F7) — the FPGA result is only meaningful if RTL == model.
**Acceptance:** equivalence TB green over ≥100 randomized episodes;
convergence plot committed under docs/evidence/snn/.

### P3-T4 [OPUS] Fault-injection framework
`scripts/fault_inject.py` + `tb/fi/fi_harness_tb.v`: Yosys-extracted FF
target list grouped by hierarchy (core pipeline, EML, SNN, NVM buffer,
fault monitor, power FSMs); iverilog force/release via
`+fault=<path>:<bit>:<cycle>`; workload = the P3-T3 SNN inference loop +
EML feature chain with a golden end-state signature; classification per run:
DETECTED_SECDED / DETECTED_WDT / DETECTED_FAULTMON / BENIGN / **SDC**
(signature differs, no flag — the bad bucket). ≥10,000 stratified runs,
fixed seed, `make -j`. Publish the SDC rate honestly whatever it is →
`docs/evidence/security/FI_REPORT.md`.
**Acceptance:** one-command campaign; every SDC case gets a BUGLOG entry
with waveform + disposition.

### P3-T5 [SONNET] Power-orchestration verification
Directed TBs through the top (enabled by P1-T5 wire-up): per-tile
sleep→retention→wake round-trip with state preserved; body-bias calibration
FSM sequence; wake latency measured in cycles and recorded as a contract in
docs/evidence/power/. UPF consistency: `syn/upf_v1.1*.tcl` domains match
the RTL isolation/retention cells (script-checked).
**Acceptance:** TBs green; wake-latency contract documented with cycle
numbers; UPF check script green.

### PHASE 3 EXIT GATE
CT campaign zero-variance · EML accuracy report live · SNN model-equivalence
green · FI report published with SDC rate + dispositions · power contracts
documented.

════════════════════════════════════════════════════════════════════════════
## PHASE 4 — Physical memory reality  [~1 week, overlaps P3]
════════════════════════════════════════════════════════════════════════════

### P4-T1 [OPUS] OpenRAM/sky130 SRAM macros for ROM+SRAM
Vendor `sky130_sram_1kbyte_1rw1r_32x256_8`-class macros into
`third_party/sky130_sram_macros/` (LEF/GDS/lib/behavioral, pinned commit).
Size per the P1-T2 map. Wrap in `*_phys.v` with behavioral models retained
under `ifdef SIMULATION` at IDENTICAL registered-read timing; equivalence
TB drives both models with the same random stimulus.
**Acceptance:** equivalence TB green; `flow/synth.sh` elaborates with
macros as blackboxes, no unresolved modules.

### P4-T2 [OPUS] NVM re-scope (BUG-A11) — mandated decision
Open SKY130 ReRAM exists but is experimental, archived (2026-04-18), and has
no proven shuttle tapeout (RESEARCH_FINDINGS F-9); a ReRAM shuttle path
exists (ChipFoundry ChipCreate, "be among the first" — F-10) but is
unproven for yield/maturity. **Mandated: DECISION-011 =** the tapeout carries
the NVM **controller** (wear-leveling + SECDED + write buffer — the real IP)
backed by an SRAM-emulation macro plus an off-die SPI-flash persistence
path; on-die ReRAM is documented as a **future/experimental path** (the open
`sky130_fd_pr_reram` library or a commercial 130nm NVM licence), NOT a claim
about this chip. **Optional stretch (only if P6-T1 picks a ReRAM-capable
vehicle and schedule allows):** a small isolated ReRAM test structure as a
de-risking experiment, explicitly flagged experimental — never on the
controller's critical path. README/datasheet updated (tombstone per §A.7).
The controller's TBs and formal (nvm_secded) remain fully valid.
**Acceptance:** DECISION-011 recorded citing F-9/F-10; docs updated; nvm TB
suite green against the emulation backing.

### PHASE 4 EXIT GATE
Macros vendored+pinned · equivalence TBs green · synth elaborates with
macros · NVM story honest end-to-end.

════════════════════════════════════════════════════════════════════════════
## PHASE 5 — Synthesis & timing closure  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### P5-T0 [SONNET] Vendor the PDK timing views (kills BUG-A7)
`third_party/sky130hd/`: tt_025C_1v80, ss_100C_1v60, ff_n40C_1v95 libs +
LEF/tech-LEF from OpenROAD-flow-scripts platform files, pinned by URL+hash.
All flows reference ONLY this vendored copy. Delete every reference to the
phantom `syn/130nm_std.lib`.

### P5-T1 [OPUS] Honest synthesis + STA baseline
`flow/synth.sh` → Yosys mapped netlist → **OpenSTA** (all corners, both
clocks + generated clocks/CDC constraints). Commit `syn/reports/summary.md`:
cell count, area µm², WNS/TNS at TT and SS per domain, top-5 critical paths.
Yosys `abc -D` alone is NOT signoff — STA or it didn't happen. Expect the
first honest numbers ever produced for this design; whatever they are, they
go in the README via link.
**Acceptance:** summary.md with real numbers; README links it.

### P5-T2 [OPUS] Critical-path closure loop
Iterate to WNS ≥ +0.3 ns at TT/10 ns core, 20 ns SNN. Likely offenders in
order: the P1-T3/T4 muldiv integration points, EML exp/ln polynomial
stages (5-stage pipeline may need re-balancing), regfile→ALU→branch in the
3-stage pipeline, CSR read mux, NVM SECDED decode in the load path.
EVERY accepted restructure re-runs: full suite + arch-test + CT campaign
smoke (P3-T1 subset — a timing fix that breaks constant-time is a product
regression, not a win) before merge. No undocumented false paths.
**Acceptance:** WNS ≥ +0.3 ns TT both domains in summary.md; SS reported;
suites + CT smoke green.

### P5-T3 [SONNET] Constraint exceptions file
`constraints/exceptions.sdc`: the P1-T7 CDC table becomes real constraint
lines, plus multicycle entries (each with a comment naming the RTL structure
guaranteeing it — e.g. divider FSM is 34-cycle by construction). [OPUS]
review required. Blanket false-path lines forbidden.

### P5-T4 [SONNET] Gate-level simulation
`make gls`: functional GLS of the mapped netlist + sky130 cell models on the
smoke TB + a 20-test arch-test subset (I: alu ops; M: mul/div; C subset) +
`eml_timing_tb` (constant-time must hold POST-synthesis — retiming can
reintroduce data-dependent paths). Nightly CI.
**Acceptance:** GLS green including the timing TB's zero-variance verdict
on the netlist.

### PHASE 5 EXIT GATE
STA WNS ≥ +0.3 ns @ TT both domains with committed reports · exceptions.sdc
fully justified · GLS nightly green incl. constant-time on netlist · honest
area/fmax table live in README via link.

════════════════════════════════════════════════════════════════════════════
## PHASE 6 — P&R, DFT, signoff, tapeout  [~2–4 weeks]
════════════════════════════════════════════════════════════════════════════

### P6-T1 [OPUS] Vehicle decision (human sign-off REQUIRED) — DECISION-006 is STALE
**Efabless/ChipIgnite shut down** (RESEARCH_FINDINGS F-11); the old
DECISION-006 slot no longer exists. Write a one-page comparison in
DECISIONS.md (supersede 006) across the real 2025-2026 options:
(a) **ChipFoundry ChipCreate SKY130 MPW** — successor to Efabless, full
projects, ReRAM-capable (F-10); (b) **Tiny Tapeout** — tile-scale, cheap,
recovered post-Efabless (F-11), fits only a heavily descoped demo; (c) **IHP
SG13G2** — open 130nm BiCMOS, EU shuttle, different PDK (porting cost);
(d) defer silicon, FPGA-only + SCL-180 second-source pitch (RISK R-09).
Re-validate against honest P5 area numbers and the descope ladder: full SoC
(core+EML+SNN256+NVM-ctrl+power+debug) → SNN 256→64 → NVM-ctrl-only → single
power domain, each rung priced. Include cost, calendar, and what each proves
to a customer. **BLOCKED until the human picks.** All P6 tasks below assume
the chosen vehicle; scale per decision.

### P6-T2 [OPUS] OpenROAD flow bring-up
Treat existing `openlane/`/`pnr/` configs as untested. floorplan (SRAM
macros first, SNN tile placement, halo/blockage) → PDN + IR check → place →
CTS **per domain** (two trees; skew <100 ps each; CDC paths get the P5-T3
constraints, not CTS heroics) → route → filler. Gate each stage on its
report.
**Acceptance:** routed DB, zero router DRC, post-route STA (SPEF) meets P5
targets in both domains.

### P6-T3 [OPUS] DFT decision
`dft/` exists. Either real scan insertion + ATPG-lite plan, or descope scan
for the demo chip with a documented strap and clean TB output. The existing
`sram_mbist.v` (landed in P0-T0) is kept and verified either way. Decide,
DECISIONS.md, implement.

### P6-T4 [SONNET] Chip wrapper, pads, boot
Caravel-style harness per vehicle. Pin map from a YAML source →
`docs/PINOUT.md` generated. Boot path per docs/BOOT_ROM_SPEC.md + POR
sequence (por_sequence_tb landed in P0-T0): validate ROM CRC32 path
(rom_crc32_tb) through the wrapper. UART loader into SRAM as the demo boot
(coordinates with TOOLCHAIN S8-T2).

### P6-T5 [OPUS] Signoff
Magic DRC + KLayout DRC on final GDS · netgen LVS · antenna · STA all
corners with SPEF, both domains · GLS smoke on final netlist. Every report
archived under a `v1.1-tapeout-candidate` tag. Any waived violation:
DECISIONS.md entry with report excerpt.

### P6-T6 [SONNET] Tapeout package + release
GDS, DEF, netlist, signoff reports, TRACEABILITY.md, FI_REPORT, CT campaign,
EML accuracy report, SNN equivalence evidence, RELEASE_NOTES.md where EVERY
claim links evidence. Tag `v1.1`. Submit per vehicle instructions.

### PHASE 6 EXIT GATE
DRC clean (both tools) · LVS clean · STA clean all corners w/ SPEF ·
GLS green · tagged release with complete evidence package · shuttle
submitted.

════════════════════════════════════════════════════════════════════════════
## PHASE 7 — Post-tapeout / market track  [parallel from P3]
════════════════════════════════════════════════════════════════════════════

- **P7-T1** FPGA validation + industry benchmark → **FPGA_PLAN.md**
  (Arty A7-100T; bearing-fault condition-monitoring workload per
  INDUSTRY_TARGET.md; the headline artifact for pilots and grants).
- **P7-T2** Market/risk closure → **RISK_PLAN.md** (trust ledger, evidence
  book, positioning vs neuromorphic incumbents, IEC 61508 gap analysis,
  pilot kit).
- **P7-T3 [SONNET]** `docs/SCL180_PORTING.md`: sky130hd → SCL-180 mapping
  table, SRAM strategy on SCL, expected derate (~1.5–2× period), constraint
  deltas — the India-sovereign second-source document (feeds RISK R-09).

---

# §D — STANDING PROHIBITIONS (all phases, all agents, no exceptions)

1. Never modify TAPEOUT_PLAN_v2.md, TOOLCHAIN_PLAN.md, RISK_PLAN.md,
   FPGA_PLAN.md, or INDUSTRY_TARGET.md.
2. Never use `/` or `%` in synthesizable RTL outside a dedicated,
   fixed-latency sequential unit.
3. Never commit generated artifacts: sim logs, VCD/FST, coverage DBs, `*.o`,
   synth netlists (exception: tagged release artifacts), OpenROAD ODBs,
   report trees.
4. Never write a performance/accuracy/power/coverage number without a
   linked, checked-in evidence file.
5. Never trade away constant-time behavior for timing closure, area, or
   convenience — it is the product. Any change to eml_unit /
   eml_constant_time / policy_determinism re-runs the P3-T1 campaign smoke.
6. Never "fix" a failing external test (riscv-arch-test) by editing the
   test, signature range, or reference model.
7. Never merge with red CI. Never start work on a red baseline (§A.1).
8. Never rewrite git history.
9. Never let a subagent commit its own diff — orchestrator reviews first.
10. Never resolve ISA ambiguity from existing Azmuth behavior — the RISC-V
    spec is the authority (§A.9).
11. Never add an SDC exception without a comment naming the RTL structure
    that justifies it and an [OPUS] review.
12. Never claim ReRAM-on-silicon, a certification level, or field heritage
    that does not exist; "designed for" phrasing only, until evidence.
