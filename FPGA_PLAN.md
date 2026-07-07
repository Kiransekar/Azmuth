<!-- ============================================================================
  AZMUTH FPGA VALIDATION & BENCHMARK PLAN — v1.0 (INTERN-EXECUTABLE)
  ============================================================================
  STATUS: READ-ONLY. Do not modify this file. Progress -> docs/PROGRESS.md,
  decisions -> docs/DECISIONS.md, bugs -> docs/BUGLOG.md (FPGA-Axx prefix).
  Inherits TAPEOUT_PLAN_v2.md §A protocol. Agents AND human interns follow it.

  Audience: a fresh intern with Linux basics and one semester of digital
  design, optionally assisted by Claude Code agents. Every phase has:
  GOAL -> STEPS -> CHECKPOINT (how you KNOW it worked) -> IF IT FAILS.

  Golden rules:
   1. Never edit rtl/core/**, rtl/eml/**, rtl/snn/**, rtl/nvm/** to "make
      FPGA work". Only files under fpga/ may differ from the ASIC design.
      If the core seems to need a change, STOP and file FPGA-Axx.
   2. Copy checkpoint evidence (photo, terminal paste, log) into
      docs/PROGRESS.md for every phase. No evidence = not done.
   3. FPGA results NEVER prove ASIC timing. Cycle COUNTS transfer between
      platforms; nanoseconds do not. Report cycles first, always.
   4. The benchmark workload is INDUSTRY_TARGET.md §4 verbatim — no
      substitute datasets, no cherry-picked splits.

  Owner: chmod 444 FPGA_PLAN.md ; git update-index --skip-worktree FPGA_PLAN.md
  ============================================================================ -->

# Azmuth — FPGA Validation & Industry Benchmark Plan v1.0

| Field | Value |
|---|---|
| Primary board | **Digilent Arty A7-100T** (Artix-7 XC7A100T, ~101k LUTs — core + EML + SNN-256 + NVM-emu should fit; utilization gate in F2) |
| Secondary board | Digilent Atlys (Spartan-6 LX45, ISE 14.7 ONLY, ~27k LUTs) — soak rig with the SNN-64 reduced tile only; see §F-ATLYS |
| Cloud track | AWS F2 + FPGA Developer AMI — mass fault-injection farm only (F9) |
| Clocks on FPGA | **Core 50 MHz + SNN 25 MHz** (two real domains — the CDC design is exercised for real, unlike single-clock FPGA shortcuts). 10/5 MHz fallback. ASIC targets stay 100/50 MHz — unrelated numbers |
| Headline deliverable | **CWRU bearing-fault benchmark on Azmuth hardware** (INDUSTRY_TARGET.md §4): accuracy, cycles/frame per stage, frames/s headroom, measured ZERO cycle jitter, Xcew speedup (3 configs), STDP adaptation demo |
| Prerequisites | TAPEOUT P0–P1 done (working tree landed, muldiv sequential, memory-map contract, UNDRIVEN wired); TOOLCHAIN S0–S3 done (contract, console/UART DECISION-012, generated headers, traps); P3-T3 SNN golden-model equivalence green |

Repo layout this plan creates:
```
fpga/
├── arty/
│   ├── fpga_top.v          # board wrapper (F2)
│   ├── uart_tx.v uart_rx.v # console + frame streaming
│   ├── bram_rom.v bram_sram.v bram_nvm_emu.v
│   ├── fault_inject.v      # switch-driven bit flips (F6)
│   ├── arty.xdc            # pin constraints
│   └── build.tcl           # scripted Vivado build
├── atlys/                  # ISE variant (optional, SNN-64)
├── sw/                     # host-side python tools
└── README.md
firmware/apps/bench_cm/     # the benchmark app (TOOLCHAIN S9-T1)
```

════════════════════════════════════════════════════════════════════════════
## PHASE F0 — Environment setup (half a day)
════════════════════════════════════════════════════════════════════════════

**GOAL:** Vivado installed, board recognized, repo builds firmware.

**STEPS**
1. Install **Vivado ML Standard** (free; ~60 GB). Select only Artix-7
   device support.
2. Digilent board files:
   ```bash
   git clone https://github.com/Digilent/vivado-boards
   cp -r vivado-boards/new/board_files/* <Vivado>/data/boards/board_files/
   ```
3. USB/JTAG drivers: `<Vivado>/data/xicom/cable_drivers/lin64/install_script/
   install_drivers && sudo ./install_drivers`.
4. Confirm the pinned toolchain builds firmware before touching the FPGA:
   `source toolchain/env.sh && make -C firmware && make -C sdk`.

**CHECKPOINT:** `lsusb` shows FTDI; Vivado Hardware Manager auto-connect
finds `xc7a100t_0`.
**IF IT FAILS:** (1) re-run driver script + replug; (2) try another USB
cable (many are power-only); (3) `dmesg | tail` for the FTDI probe.

════════════════════════════════════════════════════════════════════════════
## PHASE F1 — First light: blink an LED (half a day)
════════════════════════════════════════════════════════════════════════════

**GOAL:** prove board + toolchain + constraints + programming path with the
dumbest possible design. Every bring-up in history starts here. Do not skip.

**STEPS:** `fpga/arty/blink.v` (27-bit counter on the 100 MHz pin E3 clock,
top 4 bits → LEDs), minimal `arty.xdc` (E3 clock + H5/J5/T9/T10 LEDs,
LVCMOS33), scripted `build.tcl`:
```tcl
# usage: vivado -mode batch -source build.tcl -tclargs <top_module>
set top [lindex $argv 0]
create_project -in_memory -part xc7a100tcsg324-1
read_verilog [glob ./fpga/arty/*.v]
if {[file exists ./rtl/rtl_list.f]} {
  foreach f [split [exec grep -v {^#} ./rtl/rtl_list.f] "\n"] {
    if {$f ne ""} { read_verilog ./$f }
  }
}
read_xdc ./fpga/arty/arty.xdc
synth_design -top $top
opt_design ; place_design ; route_design
report_timing_summary -file build/timing_summary.rpt
report_utilization    -file build/utilization.rpt
write_bitstream -force build/${top}.bit
```
NEVER click through the GUI for real builds — scripts are reproducible.

**CHECKPOINT:** four LEDs counting in binary. Photograph it.
**IF IT FAILS:** (1) no timing_summary.rpt → build died earlier, read the
log tail; (2) wrong part (`xc7a100tcsg324-1`); (3) dark LEDs → XDC typo.

════════════════════════════════════════════════════════════════════════════
## PHASE F2 — Board wrapper: TWO clocks, reset, memory, UART (3–4 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** the FPGA-specific pieces. The SoC is instantiated UNTOUCHED —
including its CDC synchronizers, which now cross two REAL clock domains.

### F2.1 Clocks: one PLL, two outputs (50 MHz core, 25 MHz SNN)
```verilog
wire clk_fb, clk_core_raw, clk_snn_raw, clk_core, clk_snn, pll_locked;
PLLE2_BASE #(
    .CLKFBOUT_MULT(10), .CLKIN1_PERIOD(10.0),   // 100 MHz × 10 = 1 GHz VCO
    .CLKOUT0_DIVIDE(20),                        // 50 MHz core
    .CLKOUT1_DIVIDE(40)                         // 25 MHz SNN
) u_pll (
    .CLKIN1(clk100), .CLKFBIN(clk_fb), .CLKFBOUT(clk_fb),
    .CLKOUT0(clk_core_raw), .CLKOUT1(clk_snn_raw),
    .LOCKED(pll_locked), .RST(1'b0), .PWRDWN(1'b0)
);
BUFG bufg_core (.I(clk_core_raw), .O(clk_core));
BUFG bufg_snn  (.I(clk_snn_raw),  .O(clk_snn));
```
Timing fails at 50 MHz → drop both dividers ×2 (25/12.5 MHz); cycle counts
in every published result stay identical. Do NOT tie both domains to one
clock "to simplify" — exercising the real CDC paths is half the point.
JTAG `i_tck` for the DM: route to a PMOD header (F5.2) or tie safe.

### F2.2 Reset: button + PLL lock → 2-flop synchronizer per domain
Async assert, sync deassert, one synchronizer per clock domain, polarity
per the SoC's active-high `i_rst` (interconnect internally derives its
active-low — do not "help").

### F2.3 Memory: BRAM behind the unmodified controllers
- `bram_rom.v` — boot ROM image via `$readmemh` (firmware baked into the
  bitstream for F3; UART loader from F4 on).
- `bram_sram.v` — SRAM sized per the DECISION-010 map, 1-cycle registered
  read (SAME timing contract as the ASIC macro wrapper from P4-T1 — reuse
  that wrapper's `ifdef` seam, adding an FPGA leg is allowed INSIDE the
  wrapper file only).
- `bram_nvm_emu.v` — backs the NVM controller per DECISION-011 (SRAM
  emulation). Keep the full SECDED width (39-bit words) — F6 injects real
  correctable errors through it. BRAMs are 36-bit native; Vivado pairs
  them automatically.
- Firmware hex: `make -C firmware fpga_mem` (objcopy → 32-bit-word hex).

### F2.4 UART (115200 8N1) — the DECISION-012 slave, now real
The interconnect's UART-TX slave drives a `uart_tx.v` shifter; `uart_rx.v`
feeds the loader (F4) and the benchmark frame-streaming path (F7). Standard
divider implementations (~434 @ 50 MHz); verify both in a quick iverilog TB
BEFORE synthesis. Console backend `console.c(UART)` becomes real here.

### F2.5 fpga_top.v
Instantiate `xcew_top_v1_1` unmodified: two clocks, synced resets, AXI to
BRAM/UART glue per the generated memory map, `o_debug_uart` → uart_tx,
LEDs: led[0] = firmware heartbeat, led[1] = fault_detected (P1-T5 wired it),
led[2] = SNN classify-done pulse stretcher, led[3] = SDC canary (F6).
Switches: sw[0] = fault-inject enable, sw[2:1] = inject target select.

**CHECKPOINT:** scripted build completes, **WNS ≥ 0 in BOTH clock domains**
in timing_summary.rpt, utilization <80%. Commit both reports.
**IF IT FAILS (timing):** (1) confirm P1-T3/T4 muldiv is in — a
combinational divider will never close; (2) drop clocks ×2; (3) read the
worst path, file FPGA-Axx — do NOT edit core RTL.
**IF IT FAILS (utilization):** the SNN-256 tile is the likely hog; if >100%
file FPGA-Axx with the report and build the SNN-64 parameterization
(NUM_NEURONS is a parameter) as a documented reduced config — do not
silently trim anything else.

════════════════════════════════════════════════════════════════════════════
## PHASE F3 — BOOT_OK: the processor says hello (1–2 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** firmware boots on real hardware and prints over a real wire.

**Debug ladder — IN ORDER, each proves one more layer:**
a. `led[3:1] = pc[k:k-2]` via an `ifdef FPGA` debug port — flicker = fetch.
b. Heartbeat firmware toggling a CSR-driven LED = fetch+decode+execute+CSR.
c. Full boot → `picocom -b 115200 /dev/ttyUSB1` shows:
```
main_reached
BOOT_OK
```

**CHECKPOINT:** picocom screenshot of BOOT_OK. Frame it.
**IF IT FAILS:** (1) PC LEDs dead → reset polarity or PLL lock (ILA in F5);
(2) PC stuck at reset vector → .mem path is relative to where Vivado runs;
(3) garbage chars → baud divisor vs actual clock (fell back to 25 MHz and
forgot CLK_HZ?).

════════════════════════════════════════════════════════════════════════════
## PHASE F4 — The real test suites on hardware (2–3 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** the SAME tests from simulation, on the board. Zero new test logic.

1. Test-runner protocol: each test prints `TEST <name> PASS|FAIL <detail>`,
   then `SUITE DONE <pass>/<total>`. Reuse the S5-T1 manifest.
2. Host checker `fpga/sw/run_board_tests.py` (pyserial; counts PASS/FAIL,
   exits nonzero on any FAIL or timeout).
3. UART loader (TOOLCHAIN S8-T2) pushes each image; until it's ready, bake
   rotating multi-test images per bitstream.
4. Run on hardware: the firmware suite, the Xcew intrinsics suite (S4-T1),
   and the arch-test signature subset — board returns signatures over UART,
   host diffs against the Spike references.

**CHECKPOINT:** run_board_tests.py exits 0; signature diffs empty. Logs to
docs/evidence/fpga/.
**Every sim-pass/board-fail divergence is GOLD:** file FPGA-Axx, reproduce
in simulation (where you can see everything), root-cause there. Watch
especially for CDC-related flakiness — the FPGA's two real clock domains
will find what a single-clock sim cannot; that is why they exist here.

════════════════════════════════════════════════════════════════════════════
## PHASE F5 — Seeing inside (1–2 days, then as-needed)
════════════════════════════════════════════════════════════════════════════

### F5.1 ILA
`(* mark_debug = "true" *)` on wrapper-side nets (AXI address/valid, fault
flags, SNN spike-out, CDC handshake req/ack pairs); scripted debug-core
insertion in build.tcl; trigger on the EVENT, capture 2048 pre/post.
**CHECKPOINT:** capture the exact cycle a UART write occurs (addr matches
the generated UART address) — your ILA "hello". Then capture one full
core→SNN CDC 4-phase handshake and archive it — the CDC evidence picture.

### F5.2 OpenOCD/GDB on hardware (Azmuth's unfair advantage)
The DM/DTM is real RTL and `toolchain/openocd` exists. Route `i_tck/i_tms/
i_tdi/o_tdo` to a PMOD, connect an FT2232 dongle, and prove:
halt → reg read/write → memory read/write → breakpoint → step → resume on
the BOARD, with the same config S8-T1 proved on the Verilator model.
**CHECKPOINT:** gdb session transcript committed. This is a demo asset —
none of the neuromorphic competitors hands you a gdb prompt into the chip.

════════════════════════════════════════════════════════════════════════════
## PHASE F6 — Fault-injection panel: the reliability demo (3–4 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** flip a switch → corrupt a bit → SECDED corrects / fault monitor
flags → the benchmark keeps running. RISK R2's live-demo material.

1. `fault_inject.v` between controllers and BRAMs (memory side), one-shot
   XOR per button press; `sw[2:1]` selects target: SRAM read path (SECDED
   corrects), NVM-emu path (controller SECDED corrects + counts CSR
   0x7CF), fault-monitor input (latch + led[1]), watchdog starve (firmware
   test mode stops kicking → reset + event logged).
2. led[3] = SDC canary: firmware running-checksum mismatch WITHOUT any
   fault flag. It must NEVER light — if it does, that is a P3-T4-class
   finding, file FPGA-Axx immediately with the ILA capture.
3. Demo firmware = `apps/fault_demo` (S9-T2): one status line per second
   `t=NNN class=OK faults=<ecc:N wdt:N mon:N> status=OK`.
4. Write and rehearse the 90-second runbook in `fpga/README.md#demo-runbook`:
   power → BOOT_OK → steady lines → inject → correction counter increments,
   lines CONTINUE uninterrupted → point at the never-lit SDC LED.

**CHECKPOINT:** video of the full runbook → RISK R5 pitch stack.
**IF IT FAILS (no correction):** injection is probably on the wrong side of
the ECC encode — ILA the 39-bit bus at the controller boundary.

════════════════════════════════════════════════════════════════════════════
## PHASE F7 — THE BENCHMARK: CWRU bearing-fault condition monitoring
##             on Azmuth hardware (1–2 weeks)
════════════════════════════════════════════════════════════════════════════

**Source of truth:** INDUSTRY_TARGET.md §4. Dataset: Case Western Reserve
University Bearing Data Center corpus (drive-end accelerometer, 12 kHz,
SKF 6205, seeded inner-race/outer-race/ball faults × 0.007″/0.014″/0.021″,
0–3 hp loads). Standard 10-class split. Commit the exact file list +
preprocessing script + split definition to `docs/references/cwru_manifest.md`
— reviewers must be able to reproduce the split byte-for-byte.

**GOAL:** the numbers INDUSTRY_TARGET.md promises, measured, on hardware:
accuracy, cycles/frame per stage, frames/s headroom, ZERO jitter, the Xcew
delta across three build configs, and the STDP adaptation result.

### F7.1 Host-side golden pipeline FIRST — no board time before this is green
`fpga/sw/cm_golden.py` (numpy):
1. Load CWRU .mat files per the manifest; frame into 2048-sample windows,
   75% overlap for training statistics, no overlap for test.
2. Features per frame (float reference): log band energies over bearing-
   characteristic bands (BPFO/BPFI/BSF/FTF ±harmonics computed from rpm),
   total RMS, kurtosis, crest factor → feature vector (dimension recorded).
3. Q16.16 quantized re-run of the same features using the EML golden model
   (sdk/models/) — max feature deviation vs float documented (this is the
   EML accuracy evidence P3-T2 applied to real data).
4. TTFS spike encoding (earlier spike = larger feature; encoding window and
   resolution documented).
5. SNN-256 golden model (P3-T3) trained/configured offline; 10-class
   accuracy + confusion matrix. STDP novelty leg: train on normal-only,
   measure fault-detection ROC after simulated baseline drift.
**CHECKPOINT F7.1:** `cm_golden.py` reproduces literature-plausible
accuracy on the standard split; the Q16.16 leg is within its documented
tolerance of float; all plots to docs/evidence/benchmark/. The measured
numbers — whatever they are — replace INDUSTRY_TARGET.md §4's [verify]
placeholders via the trust ledger (never edit INDUSTRY_TARGET.md itself).

### F7.2 The firmware — `firmware/apps/bench_cm/` (TOOLCHAIN S9-T1)
Three build configs from one source tree:
- **(a) SOFT:** features + classifier in plain rv32imc C (fixed-point;
  no Xcew instructions — objdump-audited).
- **(b) EML:** features via EML intrinsics; classifier still software.
- **(c) FULL:** EML features + SNN-256 hardware classify (+ NVM event log).
Frame delivery: host streams test frames over UART-RX (`fpga/sw/
cm_stream.py`), firmware double-buffers in SRAM; a baked-in 8-frame subset
serves as the no-host smoke. Weights/config: computed offline by F7.1,
loaded as a const table (SOFT/EML) or via SNN CSR writes (FULL).

### F7.3 Measurement harness
```c
static inline uint32_t rdcycle(void){ uint32_t c;
    __asm__ volatile("rdcycle %0":"=r"(c)); return c; }
/* per frame: t0..t4 around ingest / features / encode / classify / log */
```
Per config, over the full test set: min/max/mean cycles per stage,
`JITTER = max−min` per stage and total, and
`max frames/s @ MHz = MHz*1e6 / max_total_cycles`. One CSV row per frame
over UART; `fpga/sw/cm_report.py` aggregates and renders the report.

**The claim under test: JITTER == 0 for features+encode+classify.**
No cache, fixed-latency muldiv (P1-T3/T4), constant-latency EML memo
(BUG-A3 fix), fixed SNN evaluation window ⇒ identical control path =
identical cycles. Data-dependent branches in YOUR benchmark code are the
usual culprit — compute-and-select instead of branch. Nonzero jitter from
the hardware is a BUGLOG finding, not a footnote. Ingest (UART-paced) is
reported separately and excluded from the jitter claim, with that exclusion
stated.

### F7.4 The published table (docs/evidence/benchmark/cm_bench.md)
1. Accuracy: hardware (c) vs golden (must match P3-T3-style — spike-time
   equivalence on a sampled subset, label equivalence on the full set);
   10-class % + confusion matrix; STDP novelty ROC + the R2-T2 drift demo
   numbers.
2. Cycles table: per stage × config (a)/(b)/(c); the (a)→(b) delta is the
   EML value, (b)→(c) is the SNN value — Xcew's published worth.
3. JITTER=0 line (or per-path counts + justification).
4. Frames/s headroom vs the 12 kHz native frame rate (2048-sample frames
   arrive at ~5.9 Hz; headroom shows how deeply the node can sleep —
   feeds the R2-T4 energy-posture evidence: sleep residency = 1 −
   busy_cycles/total).
5. MCU baseline: config (a) source compiled for a Cortex-M4 board at its
   own MHz, cycles measured with DWT->CYCCNT — reported as cycles vs
   cycles with clocks stated, no MHz-normalized spin.
6. Exact build flags, commit hash, dataset manifest hash beside every
   number. Reproduce-don't-assert: every figure regenerates from
   `make bench_cm_report`.

**CHECKPOINT F7 (final):** cm_bench.md complete with (1)–(6); numbers enter
the trust ledger; the pitch stack (R5-T2) and Evidence Book (R1-T1) import
from it automatically.

════════════════════════════════════════════════════════════════════════════
## PHASE F8 — The soak (ongoing; feeds RISK R6-T1)
════════════════════════════════════════════════════════════════════════════

Firmware: bench_cm FULL config looping the baked-in frames + heartbeat
line every 60 s (iteration count, running checksum, fault counters).
`fpga/sw/soak_logger.py` timestamps every line and flags >180 s silences as
possible hangs. Weekly `soak_summary.py` appends uptime + fault stats to
docs/TRUST_LEDGER.md. Any hang: ILA capture, reproduce in sim, BUGLOG.
Atlys runs the same duty with the SNN-64 build (below).

### §F-ATLYS — the second board (optional but free)
Single core + SNN-64 + 64 KB fits the LX45. Toolchain is **ISE 14.7**
(Xilinx's free VM is the sane route); clock primitive `PLL_BASE`/`DCM_SP`;
constraints are UCF not XDC. No ILA convenience — treat it purely as the
soak rig + BOOT_OK sanity board. Do NOT spend intern-days fighting ISE for
anything F5+.

════════════════════════════════════════════════════════════════════════════
## PHASE F9 — AWS F2 fault-injection farm (advanced; agent-assisted)
════════════════════════════════════════════════════════════════════════════

Scope strictly: mass FI campaigns and long regressions — never demos.
1. FPGA Developer AMI (Vivado preinstalled); `aws-fpga` HDK, f2 branch.
2. CL wrapper: xcew_top + N-way replication; host↔CL over shell AXI-Lite;
   per-instance fault-injection registers replace the F6 switches (same
   fault_inject.v, register-driven) so ONE bitstream serves the whole
   campaign.
3. `fpga/aws/fi_farm.py`: same JSON schema as P3-T4 so the aggregator and
   FI_REPORT.md are shared.
4. **COST GUARDS (mandatory before first launch):** instance-initiated
   shutdown + `shutdown -h +MAX_MIN` in user-data + an AWS Budget alarm.
   An agent that cannot verify termination reports BLOCKED; it does not
   assume.
**CHECKPOINT:** 10,000-injection campaign completes; classification
distribution matches the P3-T4 Verilator campaign within statistical noise
(chi-square in the report) — the agreement is itself evidence both
platforms tell the truth.

---

# §D — STANDING RULES (this plan)

1. Never modify this file; never modify core RTL to satisfy the FPGA.
2. Every phase checkpoint needs committed evidence — no evidence, not done.
3. Cycles are the currency of every published number; wall-clock always
   carries its clock; ASIC projections always labeled "projected, pending
   silicon".
4. Board-fail/sim-pass divergences are reproduced in simulation before any
   fix is attempted.
5. The benchmark dataset, split, and preprocessing are manifest-pinned;
   changing any of them restarts F7.1 and is a DECISIONS.md entry.
6. AWS: hard auto-termination set BEFORE launch; budget alarm active; no
   instance left running without a live job.
7. The demo runbook is rehearsed before any external showing; a stage-dead
   demo costs more trust than no demo.
