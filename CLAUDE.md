<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Repo **NeuroRiscV** / project **Azmuth** implements the **Xcew Processor v1.1** — an RV32IMC RISC-V core extended with custom *Xcew* instructions for edge-AI workloads, targeting **TSMC 130nm CMOS** (250 MHz core / 125 MHz SNN, <18 mm², <2 W). This is a full ASIC flow repo: RTL → simulation → synthesis → DFT → PnR → MPW/tape-out package. Most "source" is Verilog-2001; the flow is driven by a large `Makefile` plus Yosys/OpenROAD TCL scripts.

There are **two top-levels**: `rtl/xcew_top_v1_1.v` (current, the build default — `TOP_MODULE = xcew_top_v1_1`) and `rtl/xcew_top.v` (v1.0 legacy, kept for reference). Build/lint/synth all target the v1.1 top unless you override `TOP_MODULE`.

## Build & simulation commands

`make all` defaults to `make synth`. Most targets degrade gracefully when a tool is missing (lint falls back iverilog → file-existence; synth auto-generates its `.ys`; formal skips absent `.sby` files).

```bash
make lint              # Verilator lint --top xcew_top_v1_1 (many -Wno-* suppressed); falls back to iverilog
make sim_core          # Unit sim: tb/core_tb.v   (iverilog + vvp)
make sim_eml           # Unit sim: tb/eml_tb.v
make sim_soc           # SoC integration sim
make sim_top           # Top-level sim
make sim_snn_tile_256  # 256-neuron SNN tile sim
make sim_cosim         # Self-contained co-sim (uses rtl/rtl_list.f, NO riscv toolchain needed) — preferred quick end-to-end check
make synth             # Yosys synth of TOP_MODULE → syn/reports/xcew_netlist.v (generates syn/synth.ys on the fly)
make synth_full        # Full Yosys flow with SDC + UPF (syn/synth_final.tcl)
make formal            # SymbiYosys BMC: sby/{eml,snn,security,power}.sby
make firmware          # riscv64-unknown-elf-gcc → firmware/build/firmware.{elf,hex,bin}
make verilator         # Build Verilator C++ cosim model
make cosim             # Firmware + Verilator cosim
make verify            # Full v1.1 pipeline → scripts/verify_v1.1.sh
make check_csr_v1.1    # Detect CSR address collisions
make signoff_v1.1      # Unified signoff (STA + DFT + security)
make pnr               # OpenROAD place & route
make signoff_postpr    # Post-PnR STA/DRC/LVS
make mpw_package / make tapeout_pkg   # Submission packages
make clean             # Remove build artifacts;  make help  # full target list
```

**Run a single testbench manually** (the `sim_*` targets just wrap this):
```bash
iverilog -g2001 -o /tmp/tb tb/<name>_tb.v <needed rtl/*.v...> && vvp /tmp/tb
# or, for anything that elaborates the full design, use the file list:
iverilog -g2001 -f rtl/rtl_list.f -s <tb_module> tb/<name>_tb.v -o /tmp/tb && vvp /tmp/tb
```
Some testbenches pair with `tb/*_stub.v` (e.g. `riscv_core_stub.v`, `eml_dag_cache_stub.v`, `fault_monitor_stub.v`) — minimal stand-ins so a module can be exercised in isolation. `rtl/rtl_list.f` is the canonical RTL file list used by sims/synth; keep it in sync with `RTL_FILES` in the Makefile when adding modules.

## Architecture (module hierarchy)

```
xcew_top_v1_1
├── riscv_core              rtl/core/riscv_core.v — 3-stage in-order (IF → ID/EX → WB); stalls on Xcew instr until i_xcew_done
│   ├── xcie_decoder        opcode → xcew_id
│   ├── xcie_csr            xcew_cfg 0x7C0 / xcew_status 0x7C1
│   ├── xcie_ctrl           FSM: IDLE→DECODE→EXE_{EML,CFG,MEMO,SNN,NVM}→WB/TRAP
│   └── policy_determinism  fixed-cycle policy exec + timeout IRQ (CSR 0x7CB)
├── eml_unit                rtl/eml/ — 5-stage FETCH→EXP→LN→SUB→WB; Q16.16 fixed-point exp/ln (minimax polys); memo cache
│   ├── eml_dag_cache       256-entry 4-way set-assoc LRU DAG cache + CSE   (eml_dag_scheduler.v is a SEPARATE file — split out to fix MULTITOP)
│   └── eml_constant_time   cycle-padded ops + ct_mux for timing-side-channel resistance
├── snn_tile / snn_tile_256 LIF neuron array + classify FSM (8-neuron tile; 256-neuron winner-take-all variant)
│   ├── lif_ttfs_neuron_v1_1  Time-to-First-Spike neuron + array wrapper
│   └── stdp_engine_v1_1      STDP learning, 6 policies   (stdp_engine.v = v1.0 legacy)
├── nvm_ctrl               rtl/nvm/ — ReRAM 64KB, wear-leveling, Hamming(38,32) SECDED ECC, 4-entry write buffer
├── axi_lite_interconnect_v1_1   rtl/soc/ — AXI4-Lite crossbar, 5 slaves (Boot ROM, SRAM, EML CSR, SNN CSR, NVM CSR), fixed-priority arb
├── orchestrator           rtl/power/ — per-tile sleep/wake FSM + retention_reg + power_state_manager
├── body_bias_ctrl         rtl/power/ — P/N-well bias DAC + leakage_sensor + calibration FSM
└── fault_monitor          rtl/security/ — watchdog, SECDED, error latch, pipeline halt
```

The flow is **phase-gated** (Phases 1–6B "locked"); validation reports live under `reports/<date>/<stage>/` (with `reports/latest` pointing at the newest set). New work should not silently break a locked phase.

Flow stages are driven via single entry points in `flow/` (`lint.sh`, `sim.sh`, `synth.sh`, `pnr.sh`, `signoff.sh`, `formal.sh`, `compliance.sh`) — thin wrappers over the Makefile. Governance lives in `LICENSE` (proprietary, SPDX `LicenseRef-Azmuth-Proprietary` on every source file), `CHANGELOG.md`, `SECURITY.md`, and `docs/DECISIONS.md` (DECISION-001..007). The two audit checklists (`docs/AZMUTH_TAPEOUT_AUDIT.md`, `docs/AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md`) are the source of truth for tapeout/SDK readiness; `docs/AUDIT_PROGRESS.md` tracks what's done.

## Reference maps

- **Custom CSRs** (machine custom space 0x7C0–0x7CF): `0x7C0` xcew_cfg, `0x7C1` xcew_status, `0x7C5` snn_ctrl_ext, `0x7C6` eml_dag_ctl, `0x7C8` pwr_ctrl, `0x7C9` bias_ctrl, `0x7CA` sec_ctrl, `0x7CB` pol_sec, `0x7CC` fault_status, `0x7CD` watchdog_timeout, `0x7CE` ecc_scrub_count, `0x7CF` ecc_corrected_count. Full bitfields in `README.md`. Run `make check_csr_v1.1` after touching the CSR map.
- **Memory map**: defined in the interconnect/top. Note `README.md` documents a compact 16-bit map (ROM 0x0000, SRAM 0x1000, EML 0x2000, SNN 0x3000, NVM 0x4000) while `xcew_top.v` (v1.0) uses a wider map. Confirm against the actual top you are building before relying on an address.
- **Constraints**: core 4.0 ns / SNN 8.0 ns (`syn/sdc*.sdc`); 5 power domains in `syn/upf_v1.1*.tcl`.

## Conventions

- **Verilog-2001 only** (`reg`/`wire`, `always @(*)`, active-high `i_rst`). Lint must stay clean under `make lint`'s suppression set — match the existing zero-extension / explicit-bit-width style rather than introducing new width warnings. The AXI interconnect is the exception that uses active-low reset (`aresetn = ~i_rst`).
- `v1_1` suffix marks the current generation of a module; the unsuffixed file is usually the v1.0 legacy kept for diff/reference. Edit the `_v1_1` version unless you specifically mean to touch legacy.
- When adding RTL: update **both** `rtl/rtl_list.f` and `RTL_FILES` in the Makefile, and add/extend a testbench.

## Known gotchas (verified current)

1. **Decoder vs core opcode mismatch (real, unresolved):** `xcie_decoder.v` uses Xcew opcodes `7'b1111011`–`7'b1111111`, but `riscv_core.v` decodes `XCEW_EML = 7'b0001011` (and other custom-space values). Instruction routing depends on which one is authoritative — reconcile before trusting Xcew dispatch.
2. **No liberty file:** synthesis references `syn/130nm_std.lib`, which does not exist; `synth_final.tcl` proceeds without it (generic mapping only). Real timing/area numbers require a PDK lib.
3. **`tb/top_tb.v` port drift:** historically declared ports that don't match the current top's AXI/debug-UART interface — check before assuming `sim_top` exercises the real top.
4. **`cosim_v1.1` is partly mock** (generates JSON reports); use `make sim_cosim` for an actual self-contained simulation, or `make verilator && make cosim` for the real Verilator path.
5. **Stray giant VCDs in repo root** (e.g. a multi-GB `eml_tb.vcd`) — simulations dump VCDs to the working dir. Don't open them blindly; `.gitignore` covers `*.vcd`. Delete stale ones if disk pressure appears.

## Docs worth reading

- `README.md` — fullest reference (per-module line counts, complete CSR bitfields, the numbered Known-Issues-&-Fixes log of bugs already fixed).
- `docs/ARCHITECTURE.md` — system block diagram, design trade-offs, clock/reset/power domains.
- `docs/v1.1_datasheet.md`, `docs/AZMUTH_TAPEOUT_AUDIT.md`, `docs/AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md` — datasheet and the latest audit findings.
