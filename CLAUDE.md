# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NeuroRiscV implements the **Xcew Processor** - an AI Execution Context processor targeting TSMC 130nm CMOS. It extends RV32IMC with custom Xcew instructions for neural network and AI workloads. The project has progressed through Phases 1-6 and is at MPW (shuttle) readiness.

**Target**: 130nm CMOS, 250MHz core / 125MHz SNN domain, <18mm², <2W peak

## Architecture: Module Hierarchy

```
xcew_top (top-level)
├── riscv_core          (3-stage IF→ID/EX→WB pipeline, regfile, ALU, Xcew interface)
│   ├── xcie_decoder    (opcode→Xcew ID decode, 5 custom opcodes in 0b1111xxx space)
│   ├── xcie_csr        (0x7C0-0x7C1: xcew_cfg, xcew_status)
│   └── xcie_ctrl       (FSM: IDLE→DECODE→EXE_{EML,CFG,MEMO,SNN,NVM}→IDLE/TRAP)
├── eml_unit            (5-stage: FETCH→EXP→LN→SUB→WB, 128-entry direct-mapped memo cache)
│   ├── eml_dag_cache   (v1.1: 256-entry 4-way set-assoc, LRU, XOR-fold hash compress)
│   └── eml_constant_time (v1.1: fixed-cycle execution for side-channel prevention)
├── snn_tile            (LIF neuron array, spike router, classify FSM)
│   ├── lif_ttfs_neuron (v1.1: Time-to-First-Spike encoding)
│   └── stdp_engine     (v1.1: Spike-Timing-Dependent Plasticity learning)
├── nvm_ctrl            (ReRAM 64KB, wear-leveling XOR mapping, Hamming(32,26) ECC, 4-entry write buffer)
├── axi_lite_interconnect (5 slaves: Boot ROM, SRAM, EML_CSR, SNN_CTRL, NVM_CTRL)
├── orchestrator        (v1.1: per-tile sleep/wake FSM, retention_reg, power_state_manager)
├── body_bias_ctrl      (v1.1: P/N-well bias DAC, leakage sensor, calibration FSM)
├── fault_monitor       (v1.1: watchdog, SECDED 72/64 ECC, error latch, pipeline halt)
└── policy_determinism  (v1.1: fixed-cycle policy exec, timeout IRQ, fixed_cycle_arith)
```

## Custom CSR Map (v1.1 Extended)

| Addr | Name | Function |
|------|------|----------|
| 0x7C0 | xcew_cfg | COMPLEX_MODE[15], MAX_DEPTH[14:12], PRECISION[11:8], BRANCH_CUT[7] |
| 0x7C1 | xcew_status | PIPELINE_STAGE[31:4], IRQ_PENDING[3], NVM_BUSY[2], OVERFLOW[1], NaN_FLAG[0] |
| 0x7C5 | snn_ctrl_ext | TTFS_EN[7], T_WINDOW[10:8], REFRACTORY[14:12], STDP_POLICY[19:16] |
| 0x7C6 | eml_dag_ctl | DAG mode, cache policy, compression algorithm |
| 0x7C8 | pwr_ctrl | TILE_STATE[3:0], IDLE_TIMEOUT[7:4], WAKE_IRQ_MASK[8] |
| 0x7C9 | bias_ctrl | CODE[7:0], CAL_EN[8], LEAKAGE_RDY[9] |
| 0x7CA | sec_ctrl | CONST_TIME_EN, TIMING_VAR_EN |
| 0x7CB | pol_sec | DETERM_EN, MAX_CYCLES[4:1] |
| 0x7CC | fault_status | ERROR_CODE[3:0], WATCHDOG_TRIP[4], ECC_ERR[5] |
| 0x7CD | watchdog_timeout | Watchdog limit |
| 0x7CE | ecc_scrub_count | ECC control |
| 0x7CF | ecc_corrected_count | ECC corrected counter |

## Custom Opcode Map (decoder)

| Opcode (7-bit) | Instruction | Xcew ID |
|----------------|-------------|---------|
| 0b1111011 | eml | 0x1 |
| 0b1111100 | eml.cfg | 0x2 |
| 0b1111101 | mload | 0x3 |
| 0b1111110 | mstore | 0x4 |
| 0b1111111 | snn.class | 0x5 |
| (implied) | pol.update | 0x6 |

Note: `riscv_core.v` uses *different* opcode assignments (0b0001011, 0b0101011, etc.) - these are inconsistent with the decoder. This is a known issue.

## Memory Map (SOC)

| Range | Slave |
|-------|-------|
| 0x0000_0000 - 0x0000_FFFF | Boot ROM (1024 instr) |
| 0x0001_0000 - 0x0001_FFFF | SRAM (16KB) |
| 0x0002_0000 - 0x0002_0FFF | EML CSR + Memo Cache |
| 0x0002_1000 - 0x0002_1FFF | SNN_CTRL + Weight RAM |
| 0x0002_2000 - 0x0002_2FFF | NVM_CTRL + KB window |
| 0x0003_0000 | UART |

## Build and Simulation Commands

```bash
make lint            # Verilator lint (falls back to iverilog syntax check)
make sim_core        # Core module simulation (tb/core_tb.v)
make sim_eml         # EML unit simulation (tb/eml_tb.v)
make sim_soc         # SOC simulation (tb/soc_tb.v)
make sim_top         # Top-level simulation (tb/top_tb.v)
make synth           # Yosys synthesis (generates syn/synth.ys on-the-fly)
make synth_full      # Full synthesis with SDC/UPF (requires syn/synth_final.tcl)
make formal          # SymbiYosys BMC on EML unit (sby/eml.sby)
make firmware        # Build firmware with riscv64-unknown-elf-gcc
make verilator       # Build Verilator cosimulation model
make cosim           # Run RTL/Software co-simulation
make cosim_v1.1      # Run v1.1 extended co-simulation (generates mock report)
make validate_phase3 # Validate Phase 3 from cosim report
make validate_compat # Validate backward compatibility v1.0→v1.1
make dft_insert      # DFT scan insertion
make signoff         # Signoff verification
make validate_phase4 # Phase 4 synthesis/DFT/signoff validation
make pnr             # OpenROAD physical implementation
make signoff_postpr  # Post-PnR signoff (STA, DRC, LVS)
make mpw_package     # Create MPW submission package
make bringup_validate # Validate post-silicon bring-up plan
make signoff_v1.1    # Run v1.1 unified signoff (STA + DFT + Security)
make validate_upf_v1.1 # Validate v1.1 UPF power intent
make check_csr_v1.1  # Check v1.1 CSR map for collisions
make tapeout_pkg     # Create v1.1 tape-out submission package
make verify          # Run full v1.1 verification pipeline
make clean           # Remove build artifacts
make help            # Show all targets
```

**Tool fallback**: `make lint` gracefully degrades from Verilator → iverilog → file existence check. `make synth` auto-generates `syn/synth.ys` from RTL_FILES. `make formal` requires `sby/eml.sby` to exist.

## Key Files by Category

### RTL (Verilog-2001)
- `rtl/xcew_top.v` - Top-level integration (AXI interconnect, all unit instances, CSR decode)
- `rtl/xcew_top_v1_1.v` - Updated top-level for v1.1 features (DAG cache, temporal coding, power mgmt)
- `rtl/core/riscv_core.v` - 3-stage RISC-V core with Xcew extension interface
- `rtl/core/xcie_decoder.v` - Instruction decode table
- `rtl/core/xcie_csr.v` - CSR register file (0x7C0-0x7C1)
- `rtl/core/xcie_ctrl.v` - Execution FSM (typed enum states)
- `rtl/eml/eml_unit.v` - 5-stage math pipeline with memo cache
- `rtl/eml/eml_dag_cache.v` - DAG cache + scheduler submodules (v1.1 feature)
- `rtl/eml/eml_constant_time.v` - Constant-time exec + ct_mux (v1.1 security)
- `rtl/snn/snn_tile.v` - LIF neuron array + classify FSM
- `rtl/snn/lif_ttfs_neuron.v` - TTFS neuron (v1.1 temporal coding)
- `rtl/snn/stdp_engine.v` - STDP learning engine (v1.1)
- `rtl/nvm/nvm_ctrl.v` - ReRAM controller with wear-leveling + ECC
- `rtl/soc/axi_lite_interconnect.v` - AXI4-Lite crossbar
- `rtl/power/orchestrator.v` - Power FSM + retention_reg + power_state_manager (v1.1)
- `rtl/power/body_bias_ctrl.v` - Body bias DAC + leakage_sensor (v1.1)
- `rtl/security/fault_monitor.v` - Fault monitor + ecc_memory + watchdog_timer (v1.1)
- `rtl/core/policy_determinism.v` - Policy exec + fixed_cycle_arith (v1.1)

### Testbenches
- `tb/core_tb.v` - Core decode + CSR tests
- `tb/eml_tb.v` - EML pipeline + memo cache tests
- `tb/eml_dag_tb.v` - DAG cache reuse validation (v1.1)
- `tb/snn_ttfs_tb.v` - TTFS vs rate coding energy/accuracy comparison (v1.1)
- `tb/power_orch_tb.v` - Power orchestration sleep/wake cycles (v1.1)
- `tb/security_tb.v` - Security feature tests (v1.1)
- `tb/soc_tb.v` - SOC integration tests
- `tb/top_tb.v` - Full top-level stimulus (CSR, EML, SNN, NVM)
- `tb/cosim_tb.v` - Verilator cosimulation harness

### Firmware
- `firmware/boot.S` - Boot stub
- `firmware/main.c` - Main firmware: EML exec, SNN classify, NVM write, feedback loop
- `firmware/eml_optimizer.c` - Runtime precompilation + PGO (v1.1)
- `firmware/snn_temporal.c` - TTFS spike train encoding (v1.1)
- `firmware/linker.ld` - Memory layout linker script

### Synthesis/Physical Design
- `syn/synth.tcl` - Basic Yosys flow (no liberty file)
- `syn/synth_final.tcl` - Full flow with ABC timing-driven synthesis, UPF, stats
- `syn/sdc.sdc`, `syn/sdc_final.sdc` - Timing constraints (4ns core, 8ns SNN)
- `syn/upf_final.tcl`, `syn/upf_v1.1.tcl` - Power intent (3 domains: Core/EML, SNN, NVM)
- `syn/signoff.tcl` - Signoff checks
- `syn/signoff_v1.1.tcl` - Unified v1.1 signoff (STA, DFT, security) 
- `pnr/openroad_flow.tcl` - OpenROAD floorplan → placement → CTS → routing
- `pnr/signoff_postpr.tcl` - Post-PnR STA/DRC/LVS

### DFT
- `dft/scan_insertion.tcl` - Scan chain insertion
- `dft/bist_wrapper.v` - BIST wrapper for memories
- `dft/jtag_tap.v` - JTAG TAP controller

### Toolchain
- `toolchain/XcewOptPass.cpp` - LLVM MachineFunctionPass for CSE + DAG emission

### Simulation/Golden Models
- `sim/co_sim_harness.py` - Python co-simulation driver
- `sim/golden/eml_golden.py` - Python golden model for EML math functions
- `sim/golden/snn_golden.py` - Python golden model for SNN classification

### Formal Verification
- `sby/eml.sby` - SymbiYosys BMC config (depth 20), checks depth safety, overflow flag, memo hit latency

## Verification Pipeline

The project includes a comprehensive 5-stage verification pipeline executed via `make verify`:
1. **RTL Lint**: Syntax and structural validation of all RTL files
2. **Co-Simulation**: Verilator-based RTL/Software co-simulation
3. **Formal Verification**: SymbiYosys BMC properties on critical units
4. **STA/UPF**: Static timing analysis and power intent validation
5. **DFT/Power Audit**: Design-for-test and power management validation

## Important Known Issues and Patterns

1. **Opcode inconsistency**: `xcie_decoder.v` uses `7'b1111011`-`7'b1111111` for Xcew opcodes, but `riscv_core.v` checks `7'b0001011`, `7'b0101011`, `7'b1011011`, `7'b1111011`. These must be reconciled for correct instruction routing.

2. **Top-level port mismatch**: `tb/top_tb.v` declares ports (i_inst, o_inst_req, i_xcew_rs1/2, etc.) that don't match the current `xcew_top.v` port list (which uses `o_debug_uart` and internal AXI). The TB needs updating to match the current top.

3. **Missing library files**: Synthesis references `syn/130nm_std.lib` which doesn't exist. The `synth_final.tcl` has a fallback that proceeds without it.

4. **Mock co-simulation**: `cosim_v1.1` generates mock JSON reports rather than running actual simulation. Real Verilator cosim requires `make verilator` first.

5. **Power-of-2 neuron count**: `snn_tile.v` uses 8 neurons (not 256 as spec'd). This is a simplified implementation.

6. **Verilog-2001 style**: All modules use Verilog-2001 syntax with `reg`/`wire`, `always @(*)` and `always @(posedge clk or posedge rst)`. SystemVerilog features (`typedef enum`) appear in newer modules (v1.1).

7. **Active-high reset**: Most modules use active-high reset (`i_rst`), but AXI interconnect uses active-low (`aresetn = ~i_rst`).

## Validation Reports

Completed phases and their status:
- **Phase 1**: Core decoder + CSR (locked)
- **Phase 2**: EML unit (locked)
- **Phase 3**: SNN + NVM + co-sim (locked - `validation_report_phase3.txt`)
- **Phase 4**: Synthesis + DFT + signoff (locked - `validation_report_phase4.txt`)
- **Phase 5**: Physical design + MPW package (locked - `phase5_validation_report.txt`)
- **Phase 6A**: EML DAG compression + compiler pass (locked - `phase6_validation_report.txt`)
- **Phase 6B**: SNN temporal coding + STDP (locked - `phase6_validation_report.txt`)

## v1.1 Enhancements

The v1.1 implementation adds significant improvements:
- **EML DAG Cache**: 256-entry 4-way set-associative cache with LRU replacement for improved DAG reuse
- **Temporal Coding**: TTFS (Time-to-First-Spike) neuron encoding for energy-efficient SNNs
- **Advanced Power Management**: Multi-domain power control with retention registers and bias control
- **Security Features**: Constant-time execution, fault monitoring, watchdog timers
- **Enhanced CSR Map**: Expanded register space with new power, security, and configuration controls

## Floorplan Visualization

The project includes visual floorplan information in both SVG and PNG formats (floorplan.svg, floorplan.png) and a detailed visualization text file (floorplan_visualization.txt) showing the exact layout of functional blocks.

## Development Best Practices

- When adding new RTL, follow the Verilog-2001 style used throughout the project
- Ensure all control signals match the documented truth table in Section 2
- Maintain 100% line coverage and >90% branch coverage in testbenches
- Update CSR map and opcode tables when adding new functionality
- Follow the 5-stage pipeline architecture for EML unit consistency
- Add/update testbenches for any new functionality
- Ensure all new modules have proper clock and reset connections following the power domain architecture