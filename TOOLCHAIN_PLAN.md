<!-- ============================================================================
  AZMUTH SOFTWARE TOOLCHAIN ROADMAP — MASTER PLAN v1.0
  ============================================================================
  STATUS: READ-ONLY. AGENTS MUST NOT MODIFY THIS FILE. NO EXCEPTIONS.

  Software-side companion to TAPEOUT_PLAN_v2.md; inherits its entire §A
  AGENT OPERATING PROTOCOL verbatim (session checklist, model routing,
  commit format, red-before-green, evidence rule, PROGRESS/DECISIONS/BUGLOG
  schemas). Read TAPEOUT_PLAN_v2.md §A first.
  Software bugs use the SW-Axx prefix in docs/BUGLOG.md.

    * Progress -> docs/PROGRESS.md   Decisions -> docs/DECISIONS.md
    * Cross-plan conflicts: TAPEOUT_PLAN_v2 wins on hardware-owned artifacts
      (memory map, boot vehicle, RTL); this plan wins on firmware/, sdk/,
      toolchain/. Record any conflict resolution in docs/DECISIONS.md.

  Repo owner: chmod 444 TOOLCHAIN_PLAN.md ;
              git update-index --skip-worktree TOOLCHAIN_PLAN.md
  ============================================================================ -->

# Azmuth — Software Toolchain & Firmware Plan v1.0

| Field | Value |
|---|---|
| Scope | Cross-compiler (exists — verify/pin), codegen single-source, startup/runtime, SDK + Xcew intrinsics (exist — verify), execution platforms, quality gates, debug (real DM + OpenOCD — verify end-to-end), boot, reference apps = the INDUSTRY_TARGET workload |
| Starting position | **Far ahead of a greenfield**: `toolchain/` has pinned GCC + binutils + LLVM + picolibc + docker + OpenOCD; `sdk/` has include/src/lib/benchmarks/tests; riscof runs I/C/privilege vs Spike; a real RISC-V Debug Module exists in RTL. The gap is not construction — it is **contract, evidence, and commit discipline** |
| ISA string | rv32imc + Xcew custom-0..3 (DECISION-008). Verified against RTL in S0-T2 |
| Language policy | C11; no C++ on target; assembly where contracts demand |
| Prime directive | The hardware/software contract is written down, generated from one source, and tested on both sides. BUG-A10 (three inconsistent memory maps) is exactly the class of bug this prevents |

Dependency on TAPEOUT_PLAN_v2: S0 requires P1-T2 (memory-map decision) to be
DECIDED. S5 harness shared with P2 suites. S8 boot loader implements P6-T4.
S9 apps feed P3-T4 (FI workload) and FPGA_PLAN F7 (industry benchmark).

---

# §B — SOFTWARE DEFECT REGISTER (populate docs/BUGLOG.md before S0)

| ID | File | Defect |
|---|---|---|
| SW-A1 | `firmware/main.c` | Hand-written magic addresses (`EML_CSR_ADDR 0x00020000`, `SNN_CTRL_ADDR 0x00021000`, `NVM_CTRL_ADDR 0x00022000`) that do not match the interconnect's decoded map (EML 0x2000, SNN 0x2100, NVM 0x2200 in 16-bit compare space). Whether these work today depends on an undocumented address bit-slice (BUG-A10). Single-source codegen required |
| SW-A2 | `firmware/main.c` | `UART_WRITE_ADDR 0x00030000` is a **phantom peripheral** — no UART slave exists in the interconnect, and the top ties `o_debug_uart = 8'h00`. The console output contract is undefined; any TB that "sees" UART output is being faked by a bus monitor |
| SW-A3 | contract | Xcew instruction encodings are hand-embedded as `.word` in firmware (`.word 0x00B00093` in main.c) — breaks disassembly and alignment reasoning; must be `.insn` via sdk intrinsics only |
| SW-A4 | `firmware/` vs `sdk/` | Two parallel software trees (firmware/ hand-rolled, sdk/ structured) with duplicated knowledge (CSR addresses, Xcew encodings). Consolidation rule needed: sdk/ is the product, firmware/ is bring-up-only and must consume sdk headers |
| SW-A5 | repo | The entire toolchain/SDK/CI restructure was UNCOMMITTED at plan time (BUG-A15) — resolved by TAPEOUT P0-T0; verify nothing in toolchain/ references deleted paths (old riscof env, XcewOptPass.cpp) |
| SW-A6 | `toolchain/VERSIONS.md` | Claims pinned versions — verify every tool in docker actually matches, and CI builds the container from the Dockerfile (a VERSIONS.md that drifts from the Dockerfile is fiction) |
| SW-A7 | `firmware/boot.S`/`trap_handler.S` | Trap dispatch bounds vs mcause: verify a spurious cause value cannot index outside the handler table (wild jump). Same class as AEGIS SW-010 — must be proven by a directed test, not read |
| SW-A8 | contract | EML Q16.16 fixed-point formats, memo-cache semantics (when may software assume memoization?), SNN spike-time formats, STDP policy selection encoding — none of these have a single contract document; sdk headers assert them without RTL-linked evidence |
| SW-A9 | repo | No MISRA/static-analysis gate, no stack-usage analysis, no software WCET evidence for SDK functions despite determinism being the product claim |

---

# §C — THE PHASES

Order: S0 → S1 → S2 → S3 → {S4, S5 parallel} → S6 → {S7, S8, S9 parallel}.
Every phase ends with an executable exit gate.

════════════════════════════════════════════════════════════════════════════
## PHASE S0 — Contract audit & decisions  [OPUS, ~2 days]
════════════════════════════════════════════════════════════════════════════

### S0-T1 [OPUS] Write docs/HW_SW_CONTRACT.md (the keystone task)
Every fact software relies on, each with an Evidence column (RTL file +
test), UNVERIFIED where none exists:
1. Memory map — import the P1-T2 / DECISION-010 table verbatim, including
   the exact address bit-slice the interconnect compares (resolves SW-A1).
2. Reset state: PC reset vector (read from RTL), CSR reset values, POR
   sequence (docs/POR_SEQUENCE.md cross-checked against RTL).
3. Trap/interrupt contract: mtvec gating (DECISION-009), mcause encodings,
   what hardware saves, nesting rules (resolves SW-A7's spec side).
4. Xcew contract: opcode map (DECISION-008), per-instruction operand/result
   register conventions, **cycle counts per Xcew op** (from RTL, feeds WCET),
   stall semantics (`stall_id_ex` + the P0-T0 xcew_valid WB fix behavior).
5. EML contract: Q16.16 formats, exp/ln domain limits, memo semantics
   (constant-latency guarantee post BUG-A3 — state it as a *contract*),
   CSR 0x7C0/0x7C1/0x7C6 bitfields (resolves SW-A8).
6. SNN contract: spike injection format, TTFS timing semantics, WTA result
   readout, STDP policy encoding, the 128-physical/256-logical time-mux
   behavior if kept (DECISION-005 L3 re-derate).
7. NVM contract: wear-leveling visibility, SECDED error reporting CSRs
   (0x7CE/0x7CF), write-buffer ordering, and the DECISION-011 persistence
   story (SRAM-emulation + SPI-flash path).
8. Console/IO contract: NONE exists (SW-A2). Record the S0-T3 decision.
9. Debug contract: DM base (0x5000 window), abstract command set actually
   implemented, OpenOCD config ↔ RTL DTM match.
**Method:** read the RTL, don't trust docs/ — disagreements are BUGLOG
entries. **Acceptance:** every row has Evidence or UNVERIFIED; every
UNVERIFIED row maps to a task in S3–S5.

### S0-T2 [OPUS] ISA string & flags audit
Confirm `rv32imc` end-to-end: toolchain multilib present, `-march/-mabi`
consistent across firmware/ and sdk/ Makefiles, and a CI objdump audit that
every built ELF contains only rv32imc + the DECISION-008 custom opcodes
(`objdump -d | grep -E '\bamo|\bfl[wd]|\bfs[wd]'` → empty — no A, no F).
M-ops latency change (P1-T3/T4: div=34, mul=2 cycles) noted in the contract
so nothing in software assumed single-cycle M.

### S0-T3 [OPUS] Console/IO decision (SW-A2) — mandated
`o_debug_uart` is tied off; the map has no UART. **Mandated: DECISION-012 =
(c) both**: (a) HTIF-style `tohost` word in SRAM monitored by TBs (sim
speed), and (b) a minimal memory-mapped UART-TX slave added to the
interconnect in a new window (coordinate as a TAPEOUT-side mini-task; drives
`o_debug_uart` for real and becomes the FPGA/silicon console). Firmware
`console.c` abstracts both behind `console_putc()` (link-time backend).

### S0-T4 [SONNET] Purge software fiction + tree consolidation (SW-A3/A4)
Delete hand-written `.word` Xcew encodings from firmware (use sdk intrinsics);
firmware/ consumes `sdk/include/azmuth/*` and generated headers only; any
firmware file duplicating sdk knowledge is rewritten or deleted. Tombstones
in docs/BUILD_LOG.md.

### PHASE S0 EXIT GATE
HW_SW_CONTRACT.md committed with evidence columns · DECISION-012 recorded ·
objdump audit green in CI · `grep -rn '\.word 0x' firmware/ sdk/` → 0 ·
`grep -rn '0x00030000' firmware/` → 0 or every hit tagged `// SW-A2: S3-T2`.

════════════════════════════════════════════════════════════════════════════
## PHASE S1 — Toolchain verification & pinning  [SONNET, ~1–2 days]
════════════════════════════════════════════════════════════════════════════

### S1-T1 [SONNET] Container truth (SW-A6)
CI job builds `toolchain/docker/` from scratch weekly; inside it:
`make -C firmware && make -C sdk` clean; every tool version echoed and
diffed against `toolchain/VERSIONS.md` (mismatch = build failure). Add
`cppcheck` (+MISRA addon), `gcovr`, `clang-format` to the image for S6.
**Acceptance:** container job green + required; VERSIONS.md is enforced,
not aspirational.

### S1-T2 [SONNET] Makefile hygiene
Both firmware/ and sdk/ Makefiles: `-ffreestanding -ffunction-sections
-fdata-sections -Wextra -Werror -g -fstack-usage`, `-Wl,--gc-sections
-Wl,-Map`. All artifacts under `build/` (gitignored — the `*.o` files that
littered the repo root before P0 must never return). `make disasm size`
targets. Linker scripts move to GENERATED (S2) — `toolchain/ldscripts/*.ld`
become templates consumed by codegen, not hand-maintained copies.
**Acceptance:** clean build, zero warnings; no object files outside build/.

### PHASE S1 EXIT GATE
Container reproducible + enforced · firmware+sdk compile -Werror clean ·
objdump audit green · CI `sw-build` required.

════════════════════════════════════════════════════════════════════════════
## PHASE S2 — Single source of truth codegen  [OPUS design, SONNET impl, ~3 days]
════════════════════════════════════════════════════════════════════════════

### S2-T1 [OPUS] Author the machine-readable specs
`spec/memory_map.yaml` (from P1-T2/DECISION-010 — hardware owns content,
software owns format) and `spec/csr_map.yaml` (all 0x7C0–0x7CF CSRs:
address, name, access, reset value, field bit ranges + enums — transcribed
from RTL and reviewed field-by-field against `xcie_csr.v` and the README
table; mismatches are BUGLOG entries).

### S2-T2 [SONNET] Generators + drift gate
From the YAMLs ONLY, emit:
1. `sdk/include/azmuth/generated/azmuth_csr.h` — addresses, masks/shifts,
   typed accessors; delete every hand-written CSR constant in firmware/sdk.
2. `sdk/include/azmuth/generated/azmuth_memmap.h` — bases/sizes +
   `_Static_assert`s (result marker inside SRAM, buffers within regions).
3. `firmware/generated/link.ld` + regenerated `toolchain/ldscripts/*`
   variants (bench/caravel/nvm/test/xip) from one template + the YAML.
4. `docs/CSR_SPEC.md` + `docs/MEMORY_MAP.md` regenerated with an
   AUTO-GENERATED banner.
CI job `codegen-drift`: regenerate, `git diff --exit-code`.
**Acceptance:** `grep -rn '0x7C[0-9A-F]' firmware/ sdk/ --include='*.[ch]'
| grep -v generated` → empty; firmware links with generated ld; drift gate
required-green.

### PHASE S2 EXIT GATE
spec YAMLs reviewed against RTL · all outputs generated · drift gate in CI
· zero hand-written map/CSR constants outside generated headers.

════════════════════════════════════════════════════════════════════════════
## PHASE S3 — Startup & runtime correctness  [OPUS, ~1 week]
════════════════════════════════════════════════════════════════════════════

### S3-T1 [OPUS] boot.S / crt0.S verification pass
The boot code exists (and was heavily edited in the P0-T0 landing). Verify
against the contract with directed tests, don't re-read and nod:
stack init, mtvec setup per DECISION-009 gating, .data copy (test an
initialized global — required for the S8 loader path where LMA≠VMA), BSS
clear, main call, halt/wfi loop. Red-first: boot TB checks an initialized
.data value and a deliberately-dirty BSS word.

### S3-T2 [OPUS] Console + syscalls (SW-A2 execution)
`console.c` with tohost + UART backends per DECISION-012; `syscalls.c`
(exists — verify/fix): `_write` returns int, `_sbrk` bounded by generated
heap symbols with exhaustion → fault-monitor hook, spec-correct stubs for
the rest; picolibc integration confirmed (`printf` works on RTL sim).
Remove the phantom 0x00030000 writes.

### S3-T3 [OPUS] Trap runtime hardening (SW-A7)
Directed TB + firmware proving: each defined IRQ dispatches correctly; a
spurious/out-of-range mcause lands in `unhandled_trap()` (fault-monitor
assert + safe spin), never a wild jump; EBREAK/ECALL/illegal-instr routes;
the Xcew-timeout IRQ (CSR 0x7CB policy determinism) exercised end-to-end.

### PHASE S3 EXIT GATE
Boot TB green incl. .data/BSS checks · printf over both console backends on
RTL sim · trap TB green incl. spurious-cause bound · `grep -rn '0x0003'
firmware/ sdk/` → 0.

════════════════════════════════════════════════════════════════════════════
## PHASE S4 — SDK & intrinsics verification  [~1 week, parallel with S5]
════════════════════════════════════════════════════════════════════════════

### S4-T1 [OPUS] Xcew intrinsics: verify against RTL + golden models
`sdk/include/azmuth/xcew.h` exists. For EVERY intrinsic: (a) `.insn`-based
encoding (no `.word`), (b) a TB asserting the exact expected instruction
reaches `xcie_decoder` and the result matches a golden C model
(`sdk/models/` — EML Q16.16 exp/ln model shared with P3-T2, SNN LIF/STDP
model shared with P3-T3), (c) documented cycle count from the contract.
**Acceptance:** intrinsics TB green vs golden models; every intrinsic
header comment carries its measured WCET.

### S4-T2 [SONNET] Driver layer completion (one subagent per driver)
`sdk/src/`: eml (expression build/submit/memo-aware), snn (spike inject,
classify readout, STDP policy select), nvm (read/write/wear stats/SECDED
counters), power (tile sleep/wake, body-bias), fault (watchdog kick —
executive-only, see S7; fault code read/clear), debug-safe console. Rules:
no busy-wait without timeout+fault, generated accessors only, WCET in
header docs (measured S6-T4), register I/O mockable for host tests.
**Acceptance:** each driver has a host unit test (mocked registers) + one
RTL-sim integration test in `make sw-test`.

### PHASE S4 EXIT GATE
Intrinsics TB green vs golden models · all drivers unit- + integration-
tested · no raw addresses outside generated headers.

════════════════════════════════════════════════════════════════════════════
## PHASE S5 — Execution platforms  [OPUS, ~1 week, parallel with S4]
════════════════════════════════════════════════════════════════════════════

### S5-T1 [OPUS] Unified firmware harness (`make sw-test`)
One `tb/fw/fw_harness_tb.v`: loads any `build/*.hex`, runs to tohost write
or 5M-cycle watchdog, exit code from result marker; manifest-driven suite
(`verif/sw/manifest.yaml`). Shares infrastructure with the riscof harness.
CI required.

### S5-T2 [OPUS] Verilator fast model
Verilate `xcew_top_v1_1` (post P2-T2 it is lint-clean) → `sim/vazmuth`
C++ harness: hex load, tohost, optional FST. This is the WCET reference
clock (S6-T4) and the soak/FI platform. Record the speedup number vs
iverilog honestly.

### S5-T3 [SONNET] Platform parity
`make platform-parity`: the same smoke + xcew test image runs on iverilog
harness and Verilator model with identical console output + result marker.
(Renode/QEMU custom-instruction modeling: optional later task — record a
DECISION if pursued; the two RTL-true platforms suffice for evidence.)

### PHASE S5 EXIT GATE
`make sw-test` green + required · Verilator model speedup recorded ·
platform-parity green.

════════════════════════════════════════════════════════════════════════════
## PHASE S6 — Quality gates  [SONNET, ~1 week]
════════════════════════════════════════════════════════════════════════════

### S6-T1 [SONNET] Static analysis + MISRA (SW-A9)
`clang-format --dry-run -Werror`; `cppcheck --addon=misra` over firmware/ +
sdk/ with a committed suppression file (every suppression has a rationale;
deviations log `docs/MISRA_DEVIATIONS.md`). Gate: zero unsuppressed.

### S6-T2 [SONNET] Host unit tests + coverage
Unity-class harness under `sdk/tests/` (exists — expand); golden models
tested against precomputed vectors; `gcovr` coverage in CI with ratchet.

### S6-T3 [SONNET] Stack & memory discipline
`-fstack-usage` aggregation → worst-case static stack per entry point + ISR
vs the generated link.ld stack region, margin ≥25%; stack-paint high-water
test on RTL sim; malloc forbidden in benchmark/safety builds
(`-Wl,--wrap=malloc` trap), allowed only in tagged demo apps.

### S6-T4 [SONNET] Measurement-based software WCET
`scripts/sw_wcet.py` drives the Verilator model, measures cycle counts of
every SDK public function + ISR path across structured input sweeps →
`docs/SW_TIMING.md`. The determinism argument (no cache, fixed-latency
units, constant-time EML) makes max-observed = WCET — but ONLY after the
P3-T1 constant-time campaign is green; cite it. Header-claim drift gate.

### PHASE S6 EXIT GATE
MISRA gate green with deviations log · coverage baseline · stack gate green
· SW_TIMING.md generated + drift gate green.

════════════════════════════════════════════════════════════════════════════
## PHASE S7 — Executive strategy  [OPUS decision + ~1 week]
════════════════════════════════════════════════════════════════════════════

### S7-T1 [OPUS] Static cyclic executive
For always-on sensing, the certifiable pattern is a fixed frame table:
sample frame (e.g. 12 kHz ingest window) → feature frame (EML) → inference
frame (SNN) → housekeeping (NVM log, heartbeat). Tasks carry S6-T4 WCET
budgets checked at build time (sum ≤ frame); watchdog kicked ONLY by the
frame scheduler; overrun → fault monitor. Implement `sdk/exec/`; document
that an RTOS is not needed for the target workload (DECISION entry).
**Acceptance:** executive runs the S9 pipeline with budget enforcement; a
deliberately-overrun task in a test build triggers the fault monitor on
RTL sim.

════════════════════════════════════════════════════════════════════════════
## PHASE S8 — Debug & boot completion  [OPUS, ~1 week]
════════════════════════════════════════════════════════════════════════════

### S8-T1 [OPUS] Debug end-to-end proof
Azmuth has what AEGIS lacked: a real DM/DTM + `toolchain/openocd` +
`gdb_test.sh`. Prove the whole chain on the Verilator model (JTAG bitbang
or DPI adapter): OpenOCD connect → halt → register/memory read-write →
breakpoint → step → resume, scripted as `make debug-test`, evidence
committed. The existing debug TBs (halt/step/breakpoint/csr/memory) remain
the RTL-level truth; this task proves the HOST tool stack against them.
**Acceptance:** `make debug-test` green in CI (nightly); docs/DEBUG.md
describes the real workflow.

### S8-T2 [OPUS] UART boot loader (implements TAPEOUT P6-T4)
ROM-resident loader per docs/BOOT_ROM_SPEC.md: framed image (length+CRC32),
write to SRAM, verify (rom_crc32 path), jump. Host tool
`scripts/fw_load.py`. TB: full load-and-boot over the UART model (requires
DECISION-012's UART slave).

### PHASE S8 EXIT GATE
debug-test green · loader TB green · DEBUG.md real, openocd config verified
against RTL.

════════════════════════════════════════════════════════════════════════════
## PHASE S9 — Reference application = the industry workload  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### S9-T1 [OPUS] `apps/bench_cm/` — bearing-fault condition monitoring
THE reference app, specified fully in FPGA_PLAN.md F7 and
INDUSTRY_TARGET.md §4: vibration frame ingest → EML feature extraction
(log-energy bands, kurtosis, crest factor via exp/ln) → spike encoding →
SNN-256 classify → NVM event log, under the S7 executive. Built in three
configurations: (a) pure RV32IMC software (baseline), (b) EML-accelerated
features, (c) EML + SNN full pipeline — the (a)→(c) delta is Xcew's
published value. Host-validated against the Python golden pipeline BEFORE
any board time.

### S9-T2 [SONNET] Fault-demo firmware
`apps/fault_demo/`: runs the S9-T1 loop while printing fault-monitor/SECDED
/watchdog status; pairs with the FI harness (P3-T4) and the FPGA inject
switch (F6). Output designed for a live audience.

### S9-T3 [SONNET] SDK packaging
`sdk/` shippable: quickstart (container → build → run on Verilator in
<10 min), doxygen API reference, examples/, HW_SW_CONTRACT + SW_TIMING
included, `sdk-vX.Y` tags aligned to RTL tags, license per DECISION-007.

### PHASE S9 EXIT GATE
bench_cm green on both platforms in all three configs with budget
enforcement · fault demo end-to-end under injection · `sdk-v0.1` tag with
quickstart verified from a clean container by CI.

---

# §D — STANDING PROHIBITIONS (software, in addition to TAPEOUT §D)

1. Never modify any plan file.
2. Never hand-write a register address, CSR number, or memory-map constant
   in C/asm — generated headers only.
3. Never encode a custom instruction with raw `.word` — `.insn` via the sdk
   intrinsics only.
4. Never let ISA string/ABI/flags drift from S0-T2; the objdump audit is a
   required CI gate.
5. Never claim a software WCET, stack bound, or coverage number without the
   generated evidence file.
6. Never kick the watchdog outside the executive's frame scheduler.
7. Never use malloc in benchmark/safety builds; no recursion in ISR or
   executive task code.
8. Never resolve a HW/SW contract ambiguity by matching current RTL
   silently — contract row, test, BUGLOG.
9. Never publish benchmark numbers from a build configuration different
   from the committed canonical one (flags beside every number).
10. Never treat a host-model pass as verification — RTL sim is truth;
    models are velocity.
