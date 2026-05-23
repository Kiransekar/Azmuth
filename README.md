<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth — Xcew Processor v1.1

An AI Execution Context processor based on the RISC-V ISA with custom Xcew extensions for neural-network inference, expression-machine-learning acceleration, non-volatile memory, and deterministic policy execution.

**Project Azmuth** - A neuro-inspired RISC-V accelerator for edge AI workloads.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [RTL Module Reference](#rtl-module-reference)
5. [Custom Instructions](#custom-instructions)
6. [CSR Map](#csr-map)
7. [Memory Map](#memory-map)
8. [Power Domains](#power-domains)
9. [Security Features](#security-features)
10. [Build & Simulation](#build--simulation)
11. [Synthesis Flow](#synthesis-flow)
12. [Technology Targets](#technology-targets)
13. [Verification Strategy](#verification-strategy)
14. [Known Issues & Fixes](#known-issues--fixes)
15. [Contributing](#contributing)

---

## Overview

The Xcew Processor extends the standard **RV32IMC** instruction set with custom **Xcew** instructions for:

- **Expression Machine Learning (EML)** — 5-stage pipeline for exp/ln/sub evaluation with memoization cache and DAG-based Common Subexpression Elimination (CSE)
- **Spiking Neural Network (SNN)** — LIF neuron array with Time-to-First-Spike (TTFS) encoding and STDP learning
- **Non-Volatile Memory (NVM)** — ReRAM controller with wear-leveling, ECC, and write buffering
- **Deterministic Policy Execution** — Fixed-cycle enforcement to prevent timing side-channels
- **Power Orchestration** — Per-tile sleep/wake FSM with retention registers and body-bias control
- **Security** — Watchdog, fault monitor, constant-time EML operations, ECC scrubbing

The v1.1 top-level module (`xcew_top_v1_1`) integrates all components under an **AXI4-Lite interconnect** structured as **4 master ports × 5 slave ports** (Boot ROM, SRAM, EML CSR, SNN CSR, NVM CSR) with fixed-priority arbitration. In v1.1 only master port `m0` (the RISC-V core) is actively driven; `m1`–`m3` are reserved (tied off) for future masters such as the Debug Module. This resolves the earlier "1 master" vs "4M × 5S" inconsistency (see `docs/MICRO_ARCH_SPEC.md` REQ-AXI-001/002): the 4M×5S structure is ground truth; only one master is active. The previous prose claiming a single master port was incorrect.

---

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              xcew_top_v1_1                  │
                    │                                             │
  i_clk_core ──────┤  ┌──────────┐   ┌──────────────────────┐   │
  i_clk_snn  ──────┤  │ RISC-V   │   │  AXI4-Lite           │   │
  i_rst      ──────┤  │ Core     ├──►│  Interconnect         │   │
  i_v1_1_en  ──────┤  │ (3-stage)│   │  (4M × 5S)           │   │
                    │  └────┬─────┘   └──┬──┬──┬──┬──┬───────┘   │
                    │       │            │  │  │  │  │           │
                    │  ┌────▼────┐  ┌───▼┐┌▼──┐│  │  ┌▼──────┐ │
                    │  │ Xcew    │  │ROM ││RAM││  │  │NVM    │ │
                    │  │ Decoder │  │    ││   ││  │  │Ctrl   │ │
                    │  │ CSR/Ctrl│  └────┘└───┘│  │  └───────┘ │
                    │  └────┬────┘              │  │            │
                    │       │              ┌────▼──▼──┐         │
                    │  ┌────▼────┐          │ EML Unit │         │
                    │  │EML DAG  │          │ (5-stage) │         │
                    │  │Cache    │          └──────────┘         │
                    │  └─────────┘                               │
                    │                                             │
                    │  ┌──────────┐  ┌──────────┐               │
                    │  │SNN Tile  │  │STDP Eng. │               │
                    │  │(LIF+TTFS)│  │(v1.1)    │               │
                    │  └──────────┘  └──────────┘               │
                    │                                             │
                    │  ┌──────────┐  ┌──────────┐  ┌──────────┐│
                    │  │Power     │  │Body Bias │  │Fault     ││
                    │  │Orchestr. │  │Ctrl      │  │Monitor   ││
                    │  └──────────┘  └──────────┘  └──────────┘│
                    │                                             │
  o_irq_eml  ◄─────┤                                             │
  o_irq_snn  ◄─────┤                                             │
  o_irq_nvm  ◄─────┤                                             │
  o_irq_fault ◄────┤                                             │
  o_timeout_irq ◄──┤                                             │
                    └─────────────────────────────────────────────┘
```

### Pipeline

The RISC-V core implements a **3-stage in-order pipeline**:

| Stage | Function |
|-------|----------|
| **IF** | Instruction fetch from Boot ROM via PC |
| **ID/EX** | Decode, register read, ALU compute, Xcew dispatch |
| **WB** | Register file write-back (ALU or Xcew result) |

When an Xcew custom instruction is decoded, the pipeline **stalls** until the Xcew unit signals completion (`i_xcew_done`).

The core implements **M-mode trap support** (RISC-V Zicsr): machine CSRs
(`mstatus`/`mie`/`mip`/`mtvec`/`mepc`/`mcause`/`mtval`/`mscratch`), synchronous
exceptions (illegal instruction, ECALL, EBREAK, load/store misalignment),
machine interrupt taking via `i_meip`/`i_mtip`/`i_msip`, and `mret`. Taken traps
vector to `mtvec` (direct mode); trap-taking is gated on `mtvec != 0`. Verified by
`tb/trap_tb.v` and `tb/irq_tb.v` (see DECISION-009). A 1-cycle wrong-path flush on
taken branches/jumps/traps keeps the pipeline coherent.

---

## Directory Structure

```
NeuroRiscV/
├── rtl/                        # RTL source files
│   ├── xcew_top_v1_1.v         # Top-level module (v1.1)
│   ├── xcew_top.v              # Top-level module (v1.0, legacy)
│   ├── rtl_list.f              # File list for simulation/synthesis
│   ├── core/                   # RISC-V core & Xcew control
│   │   ├── riscv_core.v        # 3-stage in-order core
│   │   ├── xcie_decoder.v      # Xcew instruction decoder
│   │   ├── xcie_csr.v          # Custom CSR module (0x7C0/0x7C1)
│   │   ├── xcie_ctrl.v         # Xcew control FSM
│   │   └── policy_determinism.v # Deterministic policy controller
│   ├── eml/                    # Expression Machine Learning
│   │   ├── eml_unit.v          # 5-stage EML pipeline
│   │   ├── eml_dag_cache.v     # DAG cache + CSE scheduler
│   │   └── eml_constant_time.v # Constant-time EML operations
│   ├── snn/                    # Spiking Neural Network
│   │   ├── snn_tile.v          # LIF neuron array (8 neurons)
│   │   ├── snn_tile_256.v      # 256-neuron SNN classifier (v1.1)
│   │   ├── lif_ttfs_neuron_v1_1.v # TTFS neuron + array wrapper
│   │   ├── stdp_engine_v1_1.v # STDP learning engine + array
│   │   └── stdp_engine.v      # STDP engine (v1.0, legacy)
│   ├── nvm/                    # Non-Volatile Memory
│   │   └── nvm_ctrl.v         # ReRAM controller + ECC + wear-leveling
│   ├── power/                  # Power management
│   │   ├── orchestrator.v      # Per-tile sleep/wake FSM
│   │   └── body_bias_ctrl.v    # Body bias DAC + calibration
│   ├── security/               # Security & reliability
│   │   └── fault_monitor.v    # Watchdog, ECC, fault detection
│   └── soc/                    # SoC interconnect
│       └── axi_lite_interconnect_v1_1.v # AXI4-Lite crossbar
├── syn/                        # Synthesis scripts & constraints
│   ├── synth_final.tcl         # Full synthesis flow
│   ├── signoff_v1.1.tcl        # v1.1 signoff (STA + DFT + security)
│   ├── sdc_final.sdc           # Timing constraints
│   └── upf_v1.1_final.tcl      # UPF power intent
├── tb/                         # Testbenches
├── sby/                        # SymbiYosys formal verification
├── sim/                        # Simulation harness scripts
├── docs/                       # Documentation
│   ├── v1.1_datasheet.md       # Full v1.1 datasheet
│   └── IMPLEMENTATION_SUMMARY.md
├── firmware/                   # RISC-V firmware (boot.S, main.c)
├── Makefile                    # Build system
└── README.md                   # This file
```

---

## RTL Module Reference

### Core (`rtl/core/`)

| Module | Lines | Description |
|--------|-------|-------------|
| `riscv_core` | ~440 | 3-stage RV32IMC core with Xcew dispatch, ALU, register file, CSR/memory interfaces |
| `xcie_decoder` | ~74 | Decodes Xcew opcodes → `xcew_id` (EML/CFG/MLOAD/MSTORE/SNN/POL_UPD) |
| `xcie_csr` | ~81 | CSR read/write for `xcew_cfg` (0x7C0) and `xcew_status` (0x7C1) |
| `xcie_ctrl` | ~179 | FSM: IDLE→DECODE→EXE_EML/CFG/MEMO/SNN/NVM→TRAP |
| `policy_determinism` | ~227 | Fixed-cycle enforcement with timeout IRQ (CSR 0x7CB) |

### EML (`rtl/eml/`)

| Module | Lines | Description |
|--------|-------|-------------|
| `eml_unit` | ~201 | 5-stage pipeline: FETCH→EXP→LN→SUB→WB with memo cache |
| `eml_dag_cache` | ~217 | 256-entry 4-way set-associative DAG cache with LRU + CSE |
| `eml_dag_scheduler` | ~73 | Tracks pending subexpressions for reuse |
| `eml_constant_time` | ~292 | Constant-time operations with cycle padding for side-channel resistance |
| `ct_mux` | ~14 | Constant-time multiplexer (no branch dependency) |

### SNN (`rtl/snn/`)

| Module | Lines | Description |
|--------|-------|-------------|
| `snn_tile` | ~200 | 8-neuron LIF array with classify FSM and confidence output |
| `snn_tile_256` | ~242 | 256-neuron SNN classifier with sequential input loading, winner-take-all, spike outputs for STDP |
| `lif_ttfs_neuron_v1_1` | ~143 | Single LIF neuron with TTFS encoding + refractory |
| `lif_ttfs_neuron_v1_1_array` | ~83 | 4-neuron generate wrapper |
| `stdp_engine_v1_1` | ~234 | STDP learning with 6 policies (Hebbian, Anti-Hebbian, LTP-only, LTD-only, Homeostatic) |
| `stdp_engine_v1_1_array` | ~72 | 4-synapse generate wrapper |

### NVM (`rtl/nvm/`)

| Module | Lines | Description |
|--------|-------|-------------|
| `nvm_ctrl` | ~2213 | ReRAM controller: 64KB memory, 6-bit ECC, wear-leveling, 4-entry write buffer |

### Power (`rtl/power/`)

| Module | Lines | Description |
|--------|-------|-------------|
| `orchestrator` | ~137 | Per-tile (Core/EML/SNN/NVM) sleep/wake FSM with idle timeout |
| `retention_reg` | ~32 | Retention register with isolation control |
| `power_state_manager` | ~50 | Power switch sequencing with stabilization timer |
| `body_bias_ctrl` | ~190 | 8-bit DAC bias control with calibration sweep FSM |
| `bias_dac` | ~10 | Simulated DAC |
| `leakage_sensor` | ~28 | Simulated leakage counter |

### Security (`rtl/security/`)

| Module | Lines | Description |
|--------|-------|-------------|
| `fault_monitor` | ~260 | Watchdog timer, ECC parity, fault latching, pipeline halt, error codes |
| `ecc_memory` | ~40 | SECDED-protected memory wrapper |
| `watchdog_timer` | ~40 | Configurable timeout counter |

### SoC (`rtl/soc/`)

| Module | Lines | Description |
|--------|-------|-------------|
| `axi_lite_interconnect_v1_1` | ~524 | 4-master × 5-slave AXI4-Lite crossbar with fixed-priority arbitration |

---

## Custom Instructions

Xcew custom instructions use opcodes from the RISC-V custom opcode space:

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| `0001011` | `XCEW_EML` | EML expression evaluation |
| `0101011` | `XCEW_POL_UPD` | Policy update |
| `1011011` | `XCEW_SNN_CLASS` | SNN classification |
| `1111011` | `XCEW_MISC` | Configuration / memoization |

Decoded Xcew IDs (from `xcie_decoder`):

| ID | Operation |
|----|-----------|
| 0 | EML compute |
| 1 | CFG (configure) |
| 2 | MLOAD (memoization load) |
| 3 | MSTORE (memoization store) |
| 4 | SNN classify |
| 5 | POL_UPD (policy update) |

---

## CSR Map

### v1.0 CSRs

| Address | Name | R/W | Description |
|---------|------|-----|-------------|
| 0x7C0 | `xcew_cfg` | RW | [15] COMPLEX_MODE, [14:12] MAX_DEPTH, [11:8] PRECISION, [7] BRANCH_CUT |
| 0x7C1 | `xcew_status` | RO | [31:4] PIPELINE_STAGE, [3] IRQ_PENDING, [2] NVM_BUSY, [1] OVERFLOW, [0] NaN_FLAG |

### v1.1 Extension CSRs

| Address | Name | R/W | Description |
|---------|------|-----|-------------|
| 0x7C5 | `snn_ctrl_ext` | RW | [7] TTFS_EN, [10:8] T_WINDOW, [14:12] REFRACTORY, [20] STDP_EN, [21] LEARN_EN, [19:16] STDP_POLICY |
| 0x7C6 | `eml_dag_ctl` | RW | [0] DAG_MODE (0=tree, 1=DAG+CSE) |
| 0x7C8 | `pwr_ctrl` | RW | [3:0] TILE_STATE_REQ, [7:4] IDLE_TIMEOUT, [8] WAKE_IRQ_MASK |
| 0x7C9 | `bias_ctrl` | RW | [7:0] BIAS_CODE, [8] CAL_EN |
| 0x7CA | `sec_ctrl` | RW | Security control register |
| 0x7CB | `pol_sec` | RW | [0] DET_EN, [4:1] MAX_CYCLES |
| 0x7CC | `fault_status` | RW1C | [5:0] FAULT_CODE, [6] ECC_ERR, [7] WATCHDOG_TRIP; write [31]=1 to clear |
| 0x7CD | `watchdog_timeout` | RW | Watchdog timeout value |
| 0x7CE | `ecc_scrub_count` | RW | ECC scrub counter |
| 0x7CF | `ecc_corrected_count` | RO | ECC corrections count |

---

## Memory Map

| Base | End | Slave | Description |
|------|-----|-------|-------------|
| 0x0000 | 0x0FFF | Boot ROM | 4KB instruction ROM (1024 × 32-bit) |
| 0x1000 | 0x1FFF | SRAM | 4KB data SRAM |
| 0x2000 | 0x2FFF | EML CSR | EML configuration registers |
| 0x3000 | 0x3FFF | SNN CSR | SNN configuration registers |
| 0x4000 | 0x4FFF | NVM CSR | NVM configuration registers |

---

## Power Domains

| Domain | Tile | Clock | Sleep Support |
|--------|------|-------|---------------|
| PD_CORE | Core | `i_clk_core` (250 MHz) | Yes (idle timeout) |
| PD_EML | EML | `i_clk_core` (gated) | Yes |
| PD_SNN | SNN | `i_clk_snn` (125 MHz) | Yes |
| PD_NVM | NVM | `i_clk_core` (gated) | Yes |
| PD_TOP | Interconnect + CSRs | `i_clk_core` | Always-on |

Power states per tile: **RUN** → **SLEEP** (with isolation + retention) → **RUN** (wake on IRQ / AXI activity / explicit request).

---

## Security Features

- **Constant-time EML**: Cycle-padded operations to prevent timing side-channels (CSR 0x7CA)
- **Deterministic policy execution**: Fixed-cycle budget with timeout IRQ (CSR 0x7CB)
- **Watchdog timer**: Configurable timeout with pipeline halt on trip (CSR 0x7CD)
- **ECC**: 6-bit Hamming per 32-bit word in NVM; SECDED memory wrapper
- **Fault monitor**: Latched error codes (WATCHDOG, ECC_SINGLE, ECC_DOUBLE, SOFT_EML, SOFT_SNN, HARD_NVM, CSR_VIOLATION, INSTR_FAULT)
- **Branch-cut stalling**: Fixed 12-cycle stall for branch-cut operations

---

## Build & Simulation

### Prerequisites

| Tool | Purpose |
|------|---------|
| Icarus Verilog (`iverilog`) | Simulation |
| Verilator | Linting |
| Yosys | Synthesis |
| SymbiYosys (`sby`) | Formal verification |
| `riscv64-unknown-elf-gcc` | Firmware compilation |

### Make Targets

```bash
# Linting
make lint                    # Syntax/lint check (verilator or iverilog fallback)

# Simulation
make sim_core                # Core unit testbench
make sim_eml                 # EML unit testbench
make sim_soc                 # SoC integration testbench
make sim_top                 # Top-level testbench
make sim_snn_tile_256        # SNN Tile 256 testbench
make sim_cosim               # Co-simulation (self-contained, no toolchain)

# Synthesis
make synth                   # Quick Yosys synthesis (netlist only)
make synth_full              # Full flow with SDC + UPF constraints
make signoff                  # Post-synthesis signoff
make signoff_v1.1            # v1.1 unified signoff (STA + DFT + security)

# Formal Verification
make formal                  # SymbiYosys formal check (eml + snn + security + power)

# Firmware
make firmware                # Build firmware ELF + hex + bin

# Co-simulation
make verilator               # Build Verilator C++ model
make cosim                   # Firmware + Verilator co-simulation
make cosim_v1.1              # v1.1 extended co-simulation

# Validation
make validate_phase3         # OODA latency / EML accuracy / power validation
make validate_phase4         # Timing / area / power / DFT validation
make validate_compat         # Backward compatibility check
make check_csr_v1.1          # CSR collision report

# Physical Design (requires OpenROAD)
make pnr                     # Place and route
make signoff_postpr          # Post-PnR signoff (STA + DRC + LVS)
make mpw_package             # MPW submission package
make tapeout_pkg             # Full tape-out deliverable package

# Utilities
make deps                    # Generate dependency file
make clean                   # Remove build artifacts
```

### Flow entry points (`flow/`)

One script per flow stage wraps the Makefile (tapeout audit §0.1). These are the
canonical way to drive each stage; the previous ~20 root-level scripts
(PnR variants, monitors) were consolidated here.

```bash
flow/lint.sh                 # design lint + per-file Verilog-2001 syntax sweep
flow/sim.sh [target]         # all sims, or one (core|eml|soc|top|snn_tile_256|cosim)
flow/synth.sh [quick|full]   # Yosys synthesis
flow/formal.sh               # SymbiYosys formal proofs
flow/pnr.sh                  # dockerized OpenROAD PnR (resource-limited, timeout, local fallback)
flow/signoff.sh [v1.1|postpr]
flow/compliance.sh           # claim re-verification + CSR collision check
```

Generated reports land under `reports/<date>/<stage>/` with `reports/latest`
pointing at the newest set (see [`reports/README.md`](reports/README.md)).

---

## Synthesis Flow

The synthesis pipeline uses **Yosys** with TCL scripts:

```
RTL Sources → synth_final.tcl → Netlist + Reports
                                  │
                     sdc_final.sdc (timing constraints)
                     upf_v1.1_final.tcl (power intent)
                                  │
                     signoff_v1.1.tcl → STA + DFT + security checks
```

### Key Constraints (SDC)

- Core clock: 250 MHz (4.0 ns period)
- SNN clock: 125 MHz (8.0 ns period)
- Input delay: 0.5 ns
- Output delay: 0.5 ns
- Clock uncertainty: 0.1 ns

### UPF Power Intent

- 5 power domains (PD_CORE, PD_EML, PD_SNN, PD_NVM, PD_TOP)
- 4 power switches
- 7 isolation cells
- 4 retention registers
- 4 level shifters

---

## Technology Targets

| Parameter | Target |
|-----------|--------|
| Process | 130nm CMOS |
| Core Clock | 250 MHz (4.0 ns) |
| SNN Clock | 125 MHz (8.0 ns) |
| Area | < 18 mm² |
| Peak Power | < 2 W |
| DFT Coverage | > 95% |
| Setup Slack | ≥ 0 ns (WNS ≥ 0) |

---

## Verification Strategy

1. **Unit tests** — Per-module testbenches (`tb/core_tb.v`, `tb/eml_tb.v`, `tb/snn_tile_256_tb.v`, etc.) — **82 PASS** across 8 testbenches
2. **Integration tests** — SoC, top-level, v1.1, and co-simulation — **8 PASS** across 4 testbenches
3. **Formal verification** — SymbiYosys (`sby/eml.sby`, `sby/snn.sby`, `sby/security.sby`, `sby/power.sby`) — **18 properties** covering EML, SNN, security, and power
4. **Co-simulation** — Self-contained iverilog testbench (`make sim_cosim`) with PC tracking, AXI monitoring, and Python golden model harness
5. **Golden model** — Python reference for EML mathematical functions
6. **Boundary tests** — Depth limits, overflow, NaN, watchdog timeout
7. **CSR collision check** — `make check_csr_v1.1` verifies no address conflicts

---

## Known Issues & Fixes

The following bugs were identified and fixed during code review:

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `rtl/core/xcie_csr.v` | `xcew_cfg` assigned to undeclared output | Added `o_xcew_cfg` output port |
| 2 | `rtl/snn/stdp_engine_v1_1.v` | Homeostatic policy: `stdp_value[8] >> 1` is always 0 (single bit shift) | Changed to `stdp_value[7:0] >> 1` |
| 3 | `rtl/xcew_top_v1_1.v` | `axi_activity = core_mem_we \| (~core_mem_we)` always 1 | Changed to `core_mem_we \| core_csr_wr_en` |
| 4 | `rtl/snn/snn_tile.v` | Sequential block uses `case(next_state)` and assigns `next_state`, conflicting with combinational FSM | Refactored to `case(current_state)` in sequential, removed redundant assignments |
| 5 | `Makefile` | `RTL_FILES` missing 8 v1.1 modules (policy_determinism, eml_dag_cache, eml_constant_time, lif_ttfs_neuron_v1_1, stdp_engine_v1_1, orchestrator, body_bias_ctrl, fault_monitor) | Added all missing files |
| 6 | `rtl/core/riscv_core.v` | CSR and memory outputs hardcoded to zero — no CSR writes or memory operations possible | Added `OPCODE_SYSTEM` decode for CSR, load/store signal driving for memory |
| 7 | `rtl/core/riscv_core.v` | No way to pass register data to Xcew units | Added `o_xcew_valid`, `o_rs1_data`, `o_rs2_data` output ports |
| 8 | `rtl/xcew_top_v1_1.v` | EML/SNN inputs hardcoded to zero — units never receive data | Connected to core's Xcew interface signals |
| 9 | `rtl/snn/lif_ttfs_neuron_v1_1.v` | INTEGRATE state has redundant non-TTFS threshold check conflicting with general check | Removed redundant block; general threshold check handles both modes |
| 10 | `rtl/core/riscv_core.v` | `next_pc` always increments by 4 — no branch/jump target computation | Added branch condition evaluation (BEQ/BNE/BLT/BGE/BLTU/BGEU), jump target for JAL/JALR, and PC mux |
| 11 | `rtl/core/riscv_core.v` | JAL/JALR writeback returns ALU result instead of PC+4 | Added PC+4 to wb_data mux for jump instructions |
| 12 | `rtl/core/riscv_core.v` | `mem_wstrb` always `4'hF` regardless of store width | Proper byte-enable generation based on funct3 (SB/SH/SW) and address bits |
| 13 | `rtl/core/riscv_core.v` | CSR read data never written to register file | Added `is_csr_read` to wb_data mux and `OPCODE_SYSTEM` to writeback condition |
| 14 | `rtl/nvm/nvm_ctrl.v` | `calc_ecc` was simplified XOR of all bits; `correct_data` was a no-op | Replaced with proper Hamming(38,32) SEC code with syndrome-based single-bit error correction |
| 15 | `rtl/eml/eml_unit.v` | `compute_exp`/`compute_ln` were pass-through placeholders | Replaced with Q16.16 fixed-point polynomial approximations (exp via 2^(x/ln2) decomposition, ln via log2+polynomial) |
| 16 | `rtl/nvm/nvm_ctrl.v` | NVM reset had 2000+ lines of manual initialization for only 1024 entries | Replaced with compact for-loop initializing all 65536 entries; reduced file from 2257 to 211 lines |
| 17 | `rtl/nvm/nvm_ctrl.v` | ECC was SEC (6-bit) only — no double-bit error detection | Upgraded to 7-bit SECDED: bit[6]=overall parity covering data+check bits; syndrome+parity distinguishes single vs double errors |
| 18 | `rtl/core/riscv_core.v` | `is_load` declared both at line 414 and line 482 | Removed duplicate declaration; shared `is_load` wire used for both mem_addr generation and wb_data mux |
| 19 | `rtl/core/riscv_core.v` | Load instructions wrote ALU result (address) instead of memory data | Added `is_load ? mem_rdata` to wb_data mux so loads correctly write loaded data |
| 20 | `rtl/eml/eml_unit.v` | `compute_ln` used `while` loops that may not synthesize | Replaced with fixed for-loop priority encoder to find MSB, then conditional normalization |
| 21 | `rtl/nvm/nvm_ctrl.v` | `init_idx` declared inside procedural block (invalid Verilog) | Moved `integer init_idx` declaration to module-level internal signals |
| 22 | `rtl/core/riscv_core.v` | `regfile[0]` not initialized; 31 individual init lines | Compact for-loop initializing all 32 registers (x0–x31) |
| 23 | `rtl/eml/eml_unit.v` | `compute_exp` clamped negative inputs to a small value | Proper signed arithmetic: negative `k_int` → right-shift `pow2f`; overflow/underflow thresholds |
| 24 | `rtl/eml/eml_unit.v` | `compute_ln` had fragile sign compensation hack for sub-unity values | Signed `log2_int` + `log2_combined` arithmetic; explicit `ln(1.0) = 0` case |
| 25 | `rtl/eml/eml_unit.v` | `compute_exp` Horner polynomial used `f²` instead of `f`; x/ln2 multiply overflowed 32-bit | Fixed Horner evaluation; replaced multiply with shift-add (x+x>>2+x>>3+x>>4+x>>8+x>>9 ≈ x×1.4434) |
| 26 | `rtl/eml/eml_unit.v` | `compute_ln` priority encoder found lowest set bit (overwrote highest); unsigned multiply with negative coeffs; Taylor series 12% error at f=0.1 | Break after first match; 48-bit signed intermediates with decimal constants; least-squares minimax coefficients (<0.2% max error) |
| 27 | `tb/eml_math_tb.v` | No testbench for EML fixed-point math | 40-test suite covering edge cases, positive/negative inputs, sub-unity values, ±2% relative tolerance |

## Verilog 2001 Compliance & Tapeout Readiness

All RTL files have been verified for full **Verilog 2001 compliance** with zero warnings:

| Category | Status |
|----------|--------|
| Verilator lint (`--top xcew_top`) | **0 warnings, 0 errors** |
| Verilator lint (`--top xcew_top_v1_1`) | **0 warnings, 0 errors** |
| Iverilog simulation | **12/12 testbenches pass** (82 unit + 8 integration PASS) |
| SystemVerilog features | **None used** — pure Verilog 2001 |

### Resolved Warnings

| Warning Type | Count Fixed | Files Affected |
|-------------|-------------|---------------|
| PINMISSING | 17 | `xcew_top.v`, `xcew_top_v1_1.v`, `eml_dag_cache.v` |
| CASEINCOMPLETE | 3 | `orchestrator.v`, `body_bias_ctrl.v`, `xcie_ctrl.v` |
| ALWNEVER | 1 | `eml_dag_cache.v` |
| WIDTHCONCAT | 6 | `stdp_engine.v` |
| WIDTHEXPAND | 20 | `policy_determinism.v`, `eml_constant_time.v`, `eml_unit.v`, `snn_tile.v`, `orchestrator.v`, `body_bias_ctrl.v`, `fault_monitor.v`, `xcew_top*.v` |
| WIDTHTRUNC | 31 | `riscv_core.v`, `eml_dag_cache.v`, `eml_unit.v`, `snn_tile.v`, `stdp_engine.v`, `orchestrator.v`, `body_bias_ctrl.v`, `fault_monitor.v`, `xcew_top*.v` |
| UNSIGNED | 8 | `axi_lite_interconnect_v1_1.v`, `xcew_top*.v` |
| MULTITOP | 1 | `eml_dag_cache.v` → split `eml_dag_scheduler.v` |

**Total**: 87 warnings resolved, 0 remaining (except expected MULTITOP without `--top`).

### Key Fixes Summary

- **Zero-extended** all narrower operands to match wider targets
- **Added default cases** to all incomplete `case` statements
- **Replaced** `always @*` blocks with no sensitivities by continuous `assign` statements
- **Added explicit bit-widths** on all concatenated numbers and parameters
- **Split** `eml_dag_scheduler` into separate file to resolve MULTITOP
- **Corrected** ROM index bound comparisons (`< 1024` → `< 11'd1024` to avoid UNSIGNED wrap)
- **Fixed** J-type immediate concatenation width (12→11 sign bits for 32-bit result)

---

## Architecture Documentation

Comprehensive architecture document available at `docs/ARCHITECTURE.md`:

- Full system block diagram with all interconnections
- Detailed description of every RTL module (function, interface, significance)
- Design decisions and trade-off tables (fixed-point vs float, TTFS vs rate, etc.)
- Clock/reset/power domain reference
- Complete CSR and memory maps
- Verification summary with all 9 testbench results

---

### Remaining TODOs

- EML unit: consider CORDIC iteration for further accuracy improvement beyond 4th-order minimax
- SNN TTFS: energy reduction target (≥40%) not met in `snn_ttfs_tb` — needs TTFS optimization in neuron model
- Formal verification: install SymbiYosys (`sby`) and run `make formal` to prove all 18 properties
- SNN tile 256: add SBY with `NUM_NEURONS=4` already configured; extend to cover STDP weight-update properties
- Integration: add firmware-driven test with actual RISC-V toolchain once available
- PnR: run OpenROAD place-and-route flow for timing closure verification

---

## Contributing

1. Follow the 5-stage pipeline architecture for EML unit consistency
2. Maintain cycle-accurate timing where specified
3. Implement proper exception handling for depth limits and overflow
4. Ensure all control signals match the documented truth table
5. Add/update testbenches for new functionality
6. Run `make lint` and `make check_csr_v1.1` before submitting
7. Maintain 100% line coverage and >90% branch coverage

---

## License

**Proprietary — All Rights Reserved.** Copyright (c) 2026 Kiransekar. See
[`LICENSE`](LICENSE); every source file carries
`SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary`. Upstream toolchain
components retain their own licenses (inventory in
[`toolchain/LICENSES.md`](toolchain/LICENSES.md)). Rationale recorded as
DECISION-007 in [`docs/DECISIONS.md`](docs/DECISIONS.md).