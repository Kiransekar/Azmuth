# Azmuth (Xcew v1.1) Independent Audit & Remediation Report

Date: 2026-07-06 · Scope: `main` @ commit 3ca2d07 · Method: fresh clone,
independent build/lint/sim reproduction, RTL review of the EML/core/NVM paths.

## Executive summary

Azmuth is the AI-accelerator sibling of AEGIS: an RV32IMC core with custom
Xcew extensions for expression machine learning (EML), spiking neural
networks (SNN), a ReRAM NVM controller, plus power-domain and security
blocks under an AXI4-Lite fabric. It is a genuinely ambitious design and, like
AEGIS, unusually well-documented — the README's own "Known Issues & Fixes"
table (27 entries) shows real prior debugging discipline. But the same three
failure patterns from the AEGIS audit recur here, and this audit found a
functional hang plus a security-relevant timing leak that the checked-in test
suite did not catch. The good news: the core defect was fixable in one file,
and all 23 testbenches now pass on a clean clone.

The recurring lesson across both repos: **the checked-in claims are ahead of
the checked-in evidence.** Fix the evidence machine (CI, honest claims, an
external ISA suite) and the rest follows.

## What reproduced, what didn't

Clean-clone `iverilog` run of all 23 testbenches: **22 passed, 1 hung**
(`eml_tb`) before fixes. Two more (`eml_math`, `nvm`) initially looked red in a
coarse grep but actually pass (their summaries contain the substring "0
failed"). After the fixes below: **23/23 pass.** The README's "82 PASS across 8
testbenches / 12/12 testbenches" figures are not reproducible as stated and
appear hand-recorded rather than tool-emitted.

## Critical findings

### BUG-A1 — EML unit hangs when the requester deasserts `i_valid` (FIXED)

`rtl/eml/eml_unit.v`: the operation FSM only advanced its stage *while
`i_valid` was held high* (`if (i_valid) begin ... current_stage <= ...`).
A correct requester that pulses `i_valid` for one cycle and waits — exactly
what `eml_tb` does — freezes the FSM forever; `o_valid` never asserts. The SoC
and top testbenches passed only because their integration path happens to hold
valid, which is why the unit-level bug survived. Fix: the FSM now free-runs to
writeback once an operation is accepted at IDLE, independent of `i_valid`.

### BUG-A2 — Memoization cache poisoning (FIXED)

In the original writeback stage the memo cache was written with `o_rd` (the
*previous* operation's registered output) under the *current* expression's
hash/index, because of nonblocking-assignment ordering — so a later cache hit
returned a stale, wrong result. Fix: cache is written from the freshly computed
`result_r` at WB, and the result register is distinct from the output port.

### BUG-A3 — "Constant-time" EML leaks operand history via timing (FIXED)

The unit's headline security feature is constant-time operation to defeat
timing side-channels, and `tb/eml_timing_tb.v` applies a TVLA-style
zero-cycle-variance verdict. Yet once BUG-A1 was fixed and the timing TB could
run, memo **hits completed in 2 cycles vs 5 for misses** — a textbook
data-dependent timing leak in the block that exists specifically to prevent
them. (Cycle padding lived only in the separate `eml_constant_time.v` wrapper,
not in the unit the security claim covers.) Fix: memo hits now traverse the
same 5-stage path as misses (retaining the *energy* benefit of skipping
recompute, since `compute_exp/ln` are gated on a hit, while removing the timing
signature). `eml_timing_tb` now passes with zero variance.

### BUG-A4 — Single-cycle divide/modulo and triple multiplier (OPEN → timing)

`rtl/core/riscv_core.v` implements the entire M-extension combinationally in
one ALU cycle: `div_signed_result = alu_op1_signed / alu_op2_signed` and the
matching `%`, plus **three parallel 64-bit multiplies** (signed×signed,
signed×unsigned, unsigned×unsigned). This is the AEGIS BUG-005/014 defect,
worse — there is not even a wait-counter pretending at multicycle behavior — in
a design claiming **250 MHz @ 130nm**. That frequency is physically
unachievable: a 130nm combinational 32-bit divider alone is tens of
nanoseconds. The core's own logic depth measured 69 levels of 2-input gates
(≈7–10 ns of the 4.0 ns budget just there, before the divide array dominates on
the full flatten). Remediation is a dedicated sequential radix-2 divider
(fixed latency preserves the determinism/constant-time story) and a single
shared multiplier — deferred to the plan below because it ripples into the
pipeline stall logic, not patched blind here. **The 250 MHz claim must come
down to a realistic 100 MHz signoff target, verified by real STA, exactly as
in the AEGIS audit.**

## High-priority findings

**No CI.** Same gap as AEGIS. An agent-heavy build history ("Slices 12–15"
commit) with no automated gate is how BUG-A1/A2/A3 shipped green.

**Lint claim is false by 501.** README: "Verilator lint … 0 warnings, 0
errors" for both tops. Actual on a clean clone: **501 warnings** on
`xcew_top_v1_1` — 180 UNUSEDSIGNAL, 72 PINCONNECTEMPTY, 55 PINMISSING, 26
UNDRIVEN, plus width and BLKSEQ classes. The UNDRIVEN set is the concerning
one: `tile_wake_req_int`, `tile_activity_count`, `fault_detected_int`, and a
cluster of `eml_expr_*` / `eml_subexpr_*` signals in `xcew_top_v1_1.v` are
declared but never driven — unfinished integration wiring in the power, fault,
and EML-DAG paths, meaning those features may be structurally inert on silicon.
Each needs wire-up or a documented tie-off.

**Committed build artifacts (~237 files).** `logs/`, `reports/`, `floorplan.png`,
`*.vcd`, per-date report trees are checked into git. Same untrack-and-gitignore
cleanup as AEGIS; keep only source, not generated output.

**Duplicate CLAUDE.md / Claude.md** existed in the cached listing (case-only
difference — a hazard on case-insensitive filesystems). Consolidate to one.

## Medium findings

The two-clock design (`i_clk_core` 250 MHz, `i_clk_snn` 125 MHz) does have real
CDC synchronizers (`cdc_reset_sync`, `cdc_pulse_sync`) — good, and better than
AEGIS's single-domain assumption — but the crossings need a formal CDC audit
and documented constraints once frequencies are realistic. The ReRAM/NVM story
is behavioral only (no macro, no PDK NVM IP) — fine for simulation, but the
README's "ReRAM controller" language should state that clearly; on SkyWater
there is no open ReRAM, and even the commercial 130nm ReRAM (Weebit-class) is a
separate IP licensing path. The EML fixed-point exp/ln are minimax polynomials
(README claims <0.2% error) — that accuracy claim needs an evidence file, not a
comment. No external ISA suite (a `riscof` TB stub exists but isn't wired to a
reference model); the same "hand-written tests passed while a real bug hid"
risk as AEGIS applies to the M-extension here.

## What's in the attached patch

`azmuth_improvements.patch` (`git apply` from repo root) rewrites
`rtl/eml/eml_unit.v` to fix BUG-A1/A2/A3: free-running FSM (no hang), correct
memo writeback (no poisoning), constant-latency memo path (no timing leak), and
a sticky-valid output contract so fast memo-hit results aren't lost to a slow
poller. Verified post-patch: **all 23 testbenches pass** under `iverilog` on a
clean Ubuntu 24 container, including `eml_timing_tb`'s zero-variance verdict and
the `soc`/`top`/`xcew_top_v1_1`/`cosim` integration tests. BUG-A4 (mul/div) and
the hygiene/CI/claims items are documented here for the follow-on plan rather
than patched, because they either ripple across modules or are policy changes.

## Recommended next steps (mirrors the AEGIS plan set)

1. Apply this patch; add a GitHub Actions CI running the 23-TB suite + Verilator
   lint on every push (this alone would have caught all three EML bugs).
2. Strip the false claims: 250 MHz → 100 MHz target; "0 warnings" → real count
   with a burn-down plan; "82 PASS" → CI badge. Tombstone each in a corrections
   log.
3. Replace the combinational divider with a sequential fixed-latency unit and
   collapse the triple multiplier; then run OpenSTA at 100 MHz for an honest
   fmax — no `abc -D`-only "signoff."
4. Wire the `riscof` stub to Sail/Spike and run RV32IMC — the M-extension here
   has never faced an external suite.
5. Drive or tie off every UNDRIVEN signal; the power/fault/EML-DAG features may
   be inert until this is done.
6. Untrack the ~237 build artifacts; consolidate the duplicate CLAUDE.md.

Azmuth is a strong, unusually feature-rich design whose gap is the same as its
sibling's: evidence discipline. The architecture is real; the claims just need
to catch up to it.
