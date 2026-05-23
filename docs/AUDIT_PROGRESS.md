<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Audit Progress Tracker

Roll-up of `AZMUTH_TAPEOUT_AUDIT.md` (64 HARD GATEs + 10 EVIDENCE) and
`AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md` (39 HARD GATEs + 9 EVIDENCE) —
**122 items total**. This file records what is actually done in the repo vs.
what remains, and why remaining items are blocked.

_Last updated: 2026-05-23. Changes are in the working tree; commit hashes to be
filled when committed (audit convention: `- [x] (commit abc1234)`)._

## Done this pass — Section 0 + governance (Foundation)

| Item | Gate | What landed |
|------|------|-------------|
| Tapeout 0.1 | HARD | `flow/{lint,sim,synth,pnr,signoff,formal,compliance}.sh` + `flow/README.md`; 20 redundant root scripts removed (git-preserved) |
| Tapeout 0.2 | HARD | Root `*.txt` reports → `reports/2026-05-23/<stage>/` w/ provenance headers; `reports/latest` symlink; `reports/README.md` |
| Tapeout 0.3 | HARD | Duplicate `Claude.md` removed (`CLAUDE.md` is authoritative) |
| Tapeout 0.4 | HARD | `xcew_top_v1_1` documented as single authoritative top; legacy retained as deprecated reference (audit Option 2) — see DECISION-004 note + CLAUDE.md |
| Tapeout 0.6 | EVIDENCE | `CHANGELOG.md` backfilled from git history w/ BUG-/DECISION- traceability |
| Tapeout 0.7 | EVIDENCE | `LICENSE` (proprietary) + SPDX `LicenseRef-Azmuth-Proprietary` on 96 source files via `scripts/add_spdx.py` |
| Tapeout 8.4 | HARD | `docs/DECISIONS.md` — DECISION-001..007 |
| Software S0.4 | EVIDENCE | `toolchain/LICENSES.md` upstream-license inventory |
| Software S8.3 | EVIDENCE | `SECURITY.md` reporting policy + SLA + CVSS |

**Verification:** `python3 scripts/add_spdx.py --check` is a CI-able gate that
fails if any source file lacks a header.

### Partial / noted deviations
- **Tapeout 0.3 sub-point** ("no top-level AI-tool config files"): `CLAUDE.md`
  is intentionally kept at root because the team uses Claude Code. The actual
  hazard (the case-only `Claude.md`/`CLAUDE.md` collision) is resolved.
- **DECISION-007** sets a **proprietary** license, deviating from the audits'
  open-commercial (Apache/MIT) assumption, at the project owner's direction.

## Not started — blocked, by blocker class

**Needs external tools (not installed here):** Tapeout 1.3(c)/3.5.11 formal
(SymbiYosys), 2.4 RISCOF, 5.x synth QoR + equivalence (Yosys/OpenSTA),
6.x PnR/DFT/OpenLane/precheck (OpenROAD, Magic, Caravel), 7.3 reproducible
build (Docker); Software S0.3 Docker toolchain, S1.x LLVM/binutils patches,
S1.5 regression, S3.x picolibc/soft-float.

**Needs a human/GitHub or money decision:** Tapeout 0.5 branch protection +
signed commits, 5.5.3/DECISION-006 shuttle commitment (~$9,750), 8.1–8.3
pair assignment/cadence/issue-tracking; Software S1.1/DECISION-003 ratification.

**Large new design/verification work:** Tapeout 1.5 (external-QSPI NVM, SNN
virtualization, EML cache compression, parameterization), 3.5 (~3–5k lines
Debug Module + JTAG DTM), 2.x/3.x/4.x verification campaigns; Software S2 boot
ROM, S4 libxcew + DSL/converters, S5 OpenOCD/GDB, S6 8 examples.

**Spec/evidence authoring (doable next, no tools):** Tapeout 1.1 MICRO_ARCH_SPEC,
1.2 TRACEABILITY, 1.4 bug retrospective, 3.1/3.2 CDC/RDC analysis docs, 4.6/4.7
CC Security Target + Vulnerability Analysis, 2.1 verification plan; Software
S0.1 toolchain layout, S1.6 patch strategy, S4.5 programming model, S7.4 ABI,
S8.1/S8.2/S8.4 release/compat/maintenance docs.

## Suggested next slice
Spec-and-evidence authoring requires no toolchain and unblocks downstream
traceability: `docs/MICRO_ARCH_SPEC.md` (1.1) + `docs/TRACEABILITY.csv` (1.2),
then `docs/DECISIONS.md` ratification (flip 001/002/003/006 to ACCEPTED) and
the Section 1.5 RTL refactors (which I can write and lint locally with iverilog).
