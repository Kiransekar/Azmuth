<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Audit Progress Tracker

Roll-up of `AZMUTH_TAPEOUT_AUDIT.md` (64 HARD GATEs + 10 EVIDENCE) and
`AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md` (39 HARD GATEs + 9 EVIDENCE) —
**122 items total**. This file records what is actually done in the repo vs.
what remains, and why remaining items are blocked.

_Last updated: 2026-05-23. Changes are in the working tree; commit hashes to be
filled when committed (audit convention: `- [x] (commit abc1234)`)._

## Section 1 — Spec & Traceability (slice 2)

| Item | Gate | Status | What landed |
|------|------|--------|-------------|
| Tapeout 1.1 | HARD | **drafted** | `docs/MICRO_ARCH_SPEC.md` — REQ-* ids across pipeline/ISA/CSR/FSM/mem/AXI/IRQ/exc/rst/pwr/cdc + a **Deviations Register (DEV-001..011)** of documented-but-unimplemented behavior. Sign-off + exhaustive per-instruction semantics pending. |
| Tapeout 1.2 | HARD | **drafted** | `docs/TRACEABILITY.csv` + `.md` — 50 REQs → RTL site + test (37 IMPLEMENTED, 1 PARTIAL, 12 DEVIATION). Evidence column `pending` (needs §2). |
| Tapeout 1.3(a) | HARD | **resolved** | AXI master count: RTL is **4 master × 5 slave**, only `m0` (core) active; README prose corrected. (b) TTFS energy + (c) SBY proofs still open. |
| Tapeout 1.4 | EVIDENCE | **done** | `docs/BUG_RETROSPECTIVE.md` — 27 bugs categorized, ~20 spec-preventable, gates G1–G7. |

**Key finding (honest):** writing the spec against the RTL surfaced 11 live
deviations — most importantly the core has **no machine trap CSRs / privilege
model**, `exception` is tied to 0, and 3 of 4 IRQs are tied off. These block
RISCOF privilege/Zicsr (§2.4) and trap-handler firmware (§S2.5) and are recorded
as DEV-005/008/009 rather than presented as working.

## Slice 4 — verification plan + CDC analysis

| Item | Status | What landed |
|------|--------|-------------|
| Tapeout 2.1 | **drafted** | `docs/VERIFICATION_PLAN.md` — per-feature strategy + coverpoints + cross-coverage mapped to REQ-* and the 14 testbenches. NOT PASS: coverage unmeasured (§2.2 open). |
| Tapeout 3.1 | **analysis done — FAIL** | `docs/CDC_ANALYSIS.md` — core↔SNN crossings C1–C8 inventoried; **no synchronizers exist** (confirms DEV-011). Fix patterns + MTBF method given. |

**Key finding:** the only true CDC boundary (core 250 MHz ↔ SNN 125 MHz) is
**entirely unsynchronized** — multi-bit config/data/results cross between
asynchronous clocks with no 2-FF/handshake. Passes in zero-delay sim, would be
intermittently broken on silicon.

## Slice 3 — deviation closure + tool-run evidence

| Item | Status | What landed |
|------|--------|-------------|
| DEV-001 / DEV-002 | **CLOSED** | `rtl/core/xcie_decoder.v` aligned to standard custom-0..3 map (DECISION-008); POL_UPD reachable; `tb/xcie_decoder_tb.v` 10/10. Lint clean after change. |
| Tapeout 5.1 (synth area) | **OPEN — finding** | `make synth` does not converge (300 s timeout) because `nvm_ctrl`'s 64 KB internal memory lowers to ~2 M registers. Empirically validates DECISION-005 L1 (external NVM). `reports/2026-05-23/synth/SYNTH_QOR_NOTE.md`. |
| Tapeout 1.3(c) (formal) | **OPEN — finding** | `sby` installed but the `.sby` files are malformed (invalid `[defs]`/`[property]` sections; properties not embedded as SVA). "18 properties" never ran. Not hot-fixed to avoid a vacuous proof. `reports/2026-05-23/formal/FORMAL_NOTE.md`. |

Traceability now: 41 IMPLEMENTED / 1 PARTIAL / 8 DEVIATION (DEV-001/002 closed).

## Done — Section 0 + governance (Foundation, slice 1)

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

**Spec/evidence authoring (doable next, no tools):** ~~1.1 MICRO_ARCH_SPEC, 1.2
TRACEABILITY, 1.4 retrospective~~ (done this slice); remaining: 3.1/3.2 CDC/RDC
analysis docs, 4.6/4.7 CC Security Target + Vulnerability Analysis, 2.1
verification plan; Software S0.1 toolchain layout, S1.6 patch strategy, S4.5
programming model, S7.4 ABI, S8.1/S8.2/S8.4 release/compat/maintenance docs.

## Suggested next slice
Two tracks, both unblocked:
1. **Close the deviations (highest value):** the DEV-001..011 register exposes
   real RTL gaps. DEV-001 (opcode-map reconciliation), DEV-002 (POL_UPD), DEV-006
   (EXE_MEMO wait) are small, local RTL fixes I can write + lint with iverilog
   and add directed tests for. DEV-005/008/009 (exceptions, IRQ wiring, trap CSRs)
   are larger and gate RISCOF.
2. **More evidence docs (no tools):** §2.1 verification plan, §3.1 CDC analysis,
   §4.6/4.7 CC Security Target + Vulnerability Analysis.

Tools (verilator/iverilog/yosys/sby) are present, so §5 synth QoR and §1.3(c)
formal proofs are also now runnable here if prioritized.
