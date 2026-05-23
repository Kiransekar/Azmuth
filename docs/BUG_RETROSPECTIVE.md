<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Bug Retrospective

Tapeout audit §1.4 and CC EAL2 `ALC_LCD` (lifecycle definition) evidence.
Analyzes the 27 fixed bugs in the `README.md` "Known Issues & Fixes" table
(`BUG-001`..`BUG-027`) plus the 87 Verilator lint warnings resolved for
Verilog-2001 compliance, to identify systemic gaps and the review gates that
prevent the next class of defect.

## 1. Root-cause categorization (BUG-001..027)

| Category | Bugs | Count |
|----------|------|------:|
| Incorrect algorithm (EML/NVM math, byte-enable, ECC) | 11,12,14,15,17,19,23,24,25,26 | 10 |
| Missing functionality vs. intended behavior | 6,10,13 | 3 |
| Missing port / unconnected datapath | 1,7,8 | 3 |
| Code quality / maintainability | 16,22 | 2 |
| FSM design error | 4 | 1 |
| Non-synthesizable construct | 20 | 1 |
| Invalid Verilog / declaration scope | 21 | 1 |
| Duplicate declaration | 18 | 1 |
| Redundant / dead logic | 9 | 1 |
| Always-true / tautological expression | 3 | 1 |
| Build / configuration (Makefile) | 5 | 1 |
| Missing test | 27 | 1 |
| Width / bit-select / overflow (functional) | 2,25 | 2 |

> Width issues recur far more at the lint layer: of the 87 Verilator warnings
> resolved (README "Verilog 2001 Compliance"), **51 were width-related**
> (WIDTHTRUNC 31 + WIDTHEXPAND 20). Width discipline is the single largest
> systemic gap — see gate G1.

## 2. Would a spec-first review have caught it?

Estimated **~20 of 27** are spec-preventable:

- **All 3 missing-functionality + all 3 missing-port bugs (6 total)**: a
  micro-arch spec defining the core's CSR/memory interface, branch/jump
  semantics, and the Xcew datapath contract would have made BUG-001/06/07/08/10/13
  review-visible before RTL — these are exactly the interfaces now captured in
  `MICRO_ARCH_SPEC.md`.
- **The 10 algorithm bugs (EML/NVM)**: a *golden-model-first* discipline (write
  `sim/golden/eml_golden.py` and acceptance tolerances **before** the RTL, then
  diff) would have caught BUG-11/12/14/15/17/19/23/24/25/26 at first
  integration rather than across five debugging rounds. The golden model exists
  but post-dated the RTL.
- **FSM bug (4)** and **dead/redundant logic (9)**: caught by a state-table in
  the spec + an FSM-transition coverage goal.
- **Not spec-preventable (~7)**: BUG-16/18/20/21/22 (code hygiene,
  synthesizability, scoping) are caught by lint/style gates, not by spec; BUG-5
  by a build-list check; BUG-27 by a coverage gate.

## 3. What repeats

1. **EML fixed-point math** churned across BUG-15/20/23/24/25/26 (six fixes to
   the same `compute_exp`/`compute_ln` functions). Root cause: implementing a
   numerical algorithm in RTL without a reference model and error budget.
2. **Core datapath left unconnected** (BUG-06/07/08/13): the core was committed
   with CSR/memory/Xcew outputs stubbed to zero — the same class as the *current*
   live deviations DEV-005/DEV-008/DEV-009 in `MICRO_ARCH_SPEC.md` §10. The
   pattern (ship a stub, wire it later, forget some) is still active and is the
   strongest argument for the deviations register.
3. **Width mismatches** (functional BUG-2/25 + 51 lint warnings).

## 4. Review gates to add (prevent the next class)

| ID | Gate | Catches | Where |
|----|------|---------|-------|
| G1 | Lint must stay clean with width checks **un-suppressed** on new files (don't blanket `-Wno-WIDTHTRUNC/EXPAND`); explicit-width literals required. | width class (51+2) | `flow/lint.sh`, CI |
| G2 | Golden-model-first for any numeric block: reference + tolerance committed before RTL; `flow/compliance.sh` diffs them. | algorithm class (10) | audit §2.5, §4 |
| G3 | Spec-defined interface contract per module; PR template requires a `REQ-*` id; `TRACEABILITY.csv` updated. | missing-port/function (6) | audit §1.1/§1.2 |
| G4 | FSM state+transition coverage goal ≥95%. | FSM (1) | audit §2.2 |
| G5 | "No stub left behind": every signal assigned a constant placeholder carries `// TODO-WIRE` and is grepped in CI; deviations land in `MICRO_ARCH_SPEC.md` §10. | unconnected datapath (recurring) | this doc §3.2 |
| G6 | Synthesizability lint (no `while`, no procedural-scope `integer`) + `iverilog -tnull` per file (now in `flow/lint.sh`). | BUG-20/21 | `flow/lint.sh` |
| G7 | New module ⇒ added to `rtl/rtl_list.f` **and** Makefile `RTL_FILES`; CI diffs the two lists. | BUG-5 | audit §0.1 |

## 5. Action items

- [ ] Adopt G1–G7 as the code-review checklist (PR template).
- [ ] Back-fill golden models for SNN and NVM ECC (only EML has one).
- [ ] Close the active deviations DEV-001..011 (same class as the historical
      missing-port/stub bugs) before they become "discovered at silicon."
