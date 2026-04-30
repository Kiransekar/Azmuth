# Azmuth Xcew Processor — Comprehensive Architecture Document

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture Overview](#2-system-architecture-overview)
3. [The RISC-V Core](#3-the-risc-v-core)
4. [AXI4-Lite Interconnect](#4-axi4-lite-interconnect)
5. [Expression Machine Learning (EML) Unit](#5-expression-machine-learning-eml-unit)
6. [Spiking Neural Network (SNN) Tile](#6-spiking-neural-network-snn-tile)
7. [Non-Volatile Memory (NVM) Controller](#7-non-volatile-memory-nvm-controller)
8. [Power Management System](#8-power-management-system)
9. [Security & Reliability Subsystem](#9-security--reliability-subsystem)
10. [Custom Instructions & CSR Map](#10-custom-instructions--csr-map)
11. [Clocking, Reset & Power Domains](#11-clocking-reset--power-domains)
12. [Memory Map](#12-memory-map)
13. [Design Decisions & Trade-offs](#13-design-decisions--trade-offs)
14. [Verification Summary](#14-verification-summary)

---

## 1. Executive Summary

The **Azmuth Xcew Processor** is a neuro-inspired RISC-V accelerator designed for edge AI workloads. It extends the standard **RV32IMC** instruction set with custom **Xcew** instructions that offload neural-network inference, expression learning, and policy execution to dedicated hardware units. The design prioritizes:

- **Energy efficiency** via Time-to-First-Spike (TTFS) encoding and per-tile power gating
- **Deterministic execution** to prevent timing side-channels
- **Reliability** via ECC-protected NVM, watchdog timers, and fault monitoring
- **Area efficiency** via memoization caches and DAG-based Common Subexpression Elimination (CSE)

**Target applications**: Edge AI inference, neuromorphic computing, secure embedded systems, low-power sensor fusion.

---

## 2. System Architecture Overview

### 2.1 High-Level Block Diagram

```
                              ┌─────────────────────────────────────────────────────┐
                              │              xcew_top_v1_1 (Top Level)               │
                              │                                                      │
   i_clk_core ────────────────┤  ┌──────────────┐    ┌─────────────────────────┐    │
   i_clk_snn  ────────────────┤  │  RISC-V Core │    │  AXI4-Lite Interconnect  │    │
   i_rst      ────────────────┤  │  (3-stage)   ├────►  (4M × 5S crossbar)      │    │
   i_v1_1_en  ────────────────┤  │  RV32IMC+X   │    │  Fixed-priority arbiter  │    │
                              │  └──────┬───────┘    └──────────┬────────────────┘    │
                              │         │                      │                     │
                              │  ┌──────┴───────┐    ┌─────────┼─────────┐          │
                              │  │ Xcew Decoder │    │         │         │          │
                              │  │ + CSR/Ctrl   │    │         │         │          │
                              │  └──────────────┘    │         │         │          │
                              │                      │         │         │          │
                              │  ┌───────────────────┐ ┌───────┐ ┌───────┐ ┌──────┐ │
                              │  │  EML Unit         │ │ Boot  │ │ SRAM │ │ NVM  │ │
                              │  │  5-stage pipeline │ │ ROM   │ │      │ │ Ctrl │ │
                              │  │  + DAG Cache      │ │       │ │      │ │      │ │
                              │  └───────────────────┘ └───────┘ └───────┘ └──────┘ │
                              │                                                      │
                              │  ┌──────────────┐  ┌──────────────┐                │
                              │  │ SNN Tile     │  │ STDP Engine  │                │
                              │  │ (8 LIF +     │  │ (6 policies) │                │
                              │  │  TTFS)       │  │              │                │
                              │  └──────────────┘  └──────────────┘                │
                              │                                                      │
                              │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
                              │  │ Power Orche- │  │ Body Bias    │  │ Fault    │ │
                              │  │ strator      │  │ Controller   │  │ Monitor  │ │
                              │  │ (4 tiles)    │  │ (DAC+Calib)  │  │ (WDT+ECC)│ │
                              │  └──────────────┘  └──────────────┘  └──────────┘ │
                              │                                                      │
   o_irq_eml  ◄───────────────┤                                                      │
   o_irq_snn  ◄───────────────┤                                                      │
   o_irq_nvm  ◄───────────────┤                                                      │
   o_irq_fault◄───────────────┤                                                      │
   o_debug_uart◄──────────────┤                                                      │
   o_debug_status◄────────────┤                                                      │
                              └─────────────────────────────────────────────────────┘
```

### 2.2 Design Philosophy

| Design Goal | Implementation |
|-------------|---------------|
| **Modularity** | Each major function is a self-contained tile with its own clock/power domain |
| **Determinism** | Fixed-cycle execution for security-critical paths; padding cycles ensure constant time |
| **Efficiency** | Memoization caches reuse computation; TTFS encoding reduces spike count; power gating saves energy |
| **Reliability** | ECC on NVM, watchdog timer, fault latching with error codes |
| **Verilog 2001 Compliance** | No SystemVerilog features; synthesizable across all standard tools |

---

## 3. The RISC-V Core

### 3.1 Module: `riscv_core`

**File**: `rtl/core/riscv_core.v` (~493 lines)

**Purpose**: The RISC-V core is the central controller of the Xcew processor. It fetches instructions from the Boot ROM, decodes them, executes standard RV32IMC instructions, and dispatches custom Xcew instructions to dedicated accelerator units.

**Pipeline Architecture**: 3-stage in-order pipeline

| Stage | Name | Function |
|-------|------|----------|
| **IF** | Instruction Fetch | PC-driven read from Boot ROM via AXI4-Lite |
| **ID/EX** | Decode/Execute | Opcode decode, register file read, ALU compute, Xcew dispatch |
| **WB** | Write-Back | Write ALU or Xcew result back to register file |

**Key Features**:
- **32-register file** (x0-x31) with 2 read ports + 1 write port
- **Full RV32I** base integer instruction set
- **Partial RV32M** multiply support (simplified)
- **Partial RV32C** compressed instruction support
- **4 custom opcodes** in the RISC-V custom space:
  - `0001011` — XCEW_EML (Expression Machine Learning)
  - `0101011` — XCEW_POL_UPD (Policy Update)
  - `1011011` — XCEW_SNN_CLASS (SNN Classification)
  - `1111011` — XCEW_MISC (Configuration / Memoization)
- **Immediate generation** for I/S/B/J/U-type instructions
- **Branch comparison** with full condition evaluation (EQ, NE, LT, GE, LTU, GEU)
- **Pipeline stall** on Xcew instruction until unit signals completion (`i_xcew_done`)
- **Exception/interrupt** output for illegal instructions and external events

**Interface Signals**:

```verilog
// Instruction ROM
output [31:0] pc           // Program counter
input  [31:0] instr        // Instruction word from ROM

// Data memory (via AXI interconnect)
output [31:0] mem_addr, mem_wdata
output        mem_we
output [3:0]  mem_wstrb
input  [31:0] mem_rdata

// CSR interface
output [11:0] csr_addr
output        csr_wr_en
output [31:0] csr_wr_data
input  [31:0] csr_rd_data

// Xcew custom interface
output [31:0] o_xcew_req    // Encoded Xcew request
output        o_xcew_valid  // Request valid
input         i_xcew_ready  // Unit ready to accept
input  [31:0] i_xcew_resp   // Response data
input         i_xcew_done   // Operation complete

// Register file outputs (for Xcew units)
output [31:0] o_rs1_data, o_rs2_data

// Control
output wb_stall
output exception
output interrupt
```

**Significance**: Without the core, the Xcew extensions would have no host to dispatch work. The core provides the sequential programming model that software developers expect, while the custom instructions transparently offload expensive operations to dedicated hardware.

### 3.2 Module: `xcie_decoder`

**File**: `rtl/core/xcie_decoder.v` (~74 lines)

**Purpose**: Decodes Xcew custom instructions and produces a unified `xcew_id` that the control FSM uses to route operations.

**Decoded IDs**:

| ID | Operation | Destination |
|----|-----------|-------------|
| 0 | EML compute | EML Unit |
| 1 | CFG (configure) | CSR write |
| 2 | MLOAD (memoization load) | EML memo cache |
| 3 | MSTORE (memoization store) | EML memo cache |
| 4 | SNN classify | SNN Tile |
| 5 | POL_UPD (policy update) | Policy Determinism |

**Significance**: Centralizes decoding so the core and control FSM have a single, clean interface. Prevents opcode decoding logic from being duplicated across multiple modules.

### 3.3 Module: `xcie_ctrl`

**File**: `rtl/core/xcie_ctrl.v` (~179 lines)

**Purpose**: State machine that manages the lifecycle of a custom instruction: IDLE → DECODE → EXE_EML/CFG/MEMO/SNN/NVM → TRAP.

**States**:
- **IDLE**: Wait for `xcew_valid`
- **DECODE**: Latch `xcew_id`, assert `xcew_ready`
- **EXE_EML/CFG/MEMO/SNN/NVM**: Wait for unit completion (`xcew_done`)
- **TRAP**: Handle exceptions, assert `trap_out`

**Significance**: Ensures that only one Xcew operation is in flight at a time, preventing resource conflicts. Provides a clean handshaking interface between the core and all accelerator units.

### 3.4 Module: `xcie_csr`

**File**: `rtl/core/xcie_csr.v` (~81 lines)

**Purpose**: Implements custom CSRs `xcew_cfg` (0x7C0) and `xcew_status` (0x7C1) for configuring and monitoring Xcew operations.

**xcew_cfg fields**:
- [15] COMPLEX_MODE — Enable complex number mode
- [14:12] MAX_DEPTH — Maximum pipeline depth (0-7)
- [11:8] PRECISION — Fixed-point precision (0-15)
- [7] BRANCH_CUT — Enable branch-cut handling

**Significance**: Software-visible configuration that controls accelerator behavior without requiring recompilation or reprogramming.

### 3.5 Module: `policy_determinism`

**File**: `rtl/core/policy_determinism.v` (~228 lines)

**Purpose**: Enforces **fixed-cycle execution** for security-critical operations. Prevents timing side-channels by ensuring every policy execution takes exactly the same number of cycles regardless of input data.

**Operation**:
1. Software sets `det_en` and `max_cycle_setting` via CSR 0x7CB
2. When a policy operation starts, a cycle counter begins
3. The operation runs for a **fixed number of cycles** (padding with dummy operations if it finishes early)
4. If the operation exceeds `max_cycle_setting`, a **timeout IRQ** is asserted

**Internal FSM**: IDLE → START_EXEC → EXECUTE → FINALIZE → IDLE/ TIMEOUT

**Significance**: Critical for security. In cryptographic or policy-based access control, variable execution time leaks information about the input (e.g., Hamming weight, secret key bits). This module eliminates that leak.

---

## 4. AXI4-Lite Interconnect

### 4.1 Module: `axi_lite_interconnect_v1_1`

**File**: `rtl/soc/axi_lite_interconnect_v1_1.v` (~524 lines)

**Purpose**: The AXI4-Lite crossbar connects all masters to all slaves, enabling data movement between the core, accelerators, and memory. It implements the industry-standard AXI4-Lite protocol for easy integration with IP from any vendor.

**Topology**: 4 Masters × 5 Slaves

**Masters**:
| ID | Master | Priority | Purpose |
|----|--------|----------|---------|
| M0 | RISC-V Core | Highest | Instruction fetch, data access, CSR access |
| M1 | EML Unit | High | Read/write operands and results |
| M2 | SNN Tile | Medium | Weight/config reads, spike output |
| M3 | NVM Controller | Lowest | Persistent storage access |

**Slaves**:
| ID | Slave | Address Range | Purpose |
|----|-------|--------------|---------|
| S0 | Boot ROM | 0x0000-0x0FFF | 4KB instruction ROM (1024 × 32-bit words) |
| S1 | SRAM | 0x1000-0x1FFF | 4KB data SRAM (read/write) |
| S2 | EML CSR | 0x2000-0x2FFF | EML configuration registers |
| S3 | SNN CSR | 0x3000-0x3FFF | SNN configuration registers |
| S4 | NVM CSR | 0x4000-0x4FFF | NVM controller registers |

**Arbitration**: Fixed-priority. M0 (core) always wins over M1, M1 over M2, etc. Simple and deterministic — no hidden arbitration latency.

**Address Decoder**: Each master address is decoded based on the upper bits to select the target slave. The ROM base address is 0x0000, so the `>= ROM_BASE` comparison is omitted (always true for unsigned).

**Significance**: The interconnect is the **backbone** of the SoC. Without it, the core could not fetch instructions, the EML unit could not read operands, and the SNN tile could not load weights. Using AXI4-Lite (a simplified subset of AXI4 with single-beat bursts only) minimizes area while providing enough bandwidth for edge AI workloads.

---

## 5. Expression Machine Learning (EML) Unit

### 5.1 Module: `eml_unit`

**File**: `rtl/eml/eml_unit.v` (~330 lines)

**Purpose**: The EML unit evaluates mathematical expressions in **Q16.16 fixed-point arithmetic** — specifically `exp(x)`, `ln(x)`, and `exp(x) - ln(y)`. These operations are the computational core of many machine learning algorithms (softmax, log-likelihood, loss functions).

**Why Fixed-Point?**
- No floating-point unit (FPU) needed → **~10× smaller area**
- Deterministic rounding → easier to verify
- Sufficient precision for most edge AI inference (±2% relative error)

**5-Stage Pipeline**:

| Stage | Name | Operation |
|-------|------|-----------|
| **ST_FETCH** | Fetch | Read rs1, rs2 from core; compute hash; check memo cache |
| **ST_EXP** | Exponential | Compute `exp(rs1)` via 4th-order minimax polynomial |
| **ST_LN** | Logarithm | Compute `ln(rs2)` via log₂ conversion + Horner polynomial |
| **ST_SUB** | Subtract | Compute `exp - ln` |
| **ST_WB** | Write-Back | Return result to core; update memo cache on miss |

**Memoization Cache**:
- 128 entries, direct-mapped
- Tag: XOR-folded hash of rs1 and rs2
- Stores previous `(rs1, rs2) → result` mappings
- **Hit → bypass computation** (single cycle)
- **Miss → full 5-stage pipeline**

**The exp() approximation**:
```
e^x = 2^(x/ln2) = 2^k * 2^f
  where k = floor(x/ln2), f = fractional part
  2^f ≈ 0.99999 + 0.69282f + 0.24108f² + 0.05176f³ + 0.01358f⁴ (4th-order minimax)
```

**The ln() approximation**:
```
ln(x) = log₂(x) * ln(2)
  log₂(x) = k + log₂(1+f)
  log₂(1+f) ≈ 1.4363f + 0.6701f² + 0.3128f³ + 0.0793f⁴ (4th-order Horner)
```

**Significance**: The EML unit transforms the core from a general-purpose processor into an AI accelerator. Without it, `exp()` and `ln()` would require hundreds of software iterations or a large FPU. The Q16.16 format provides 16 bits of integer range and 16 bits of fraction — enough for neural-network activations and probabilities.

### 5.2 Module: `eml_dag_cache`

**File**: `rtl/eml/eml_dag_cache.v` (~215 lines)

**Purpose**: A **256-entry, 4-way set-associative cache** with LRU replacement that implements **DAG-based Common Subexpression Elimination (CSE)**. When DAG_MODE is enabled (CSR 0x7C6), the cache tracks subexpression hashes and reuses previously computed results.

**Cache Structure**:
- 64 sets × 4 ways = 256 entries
- Tag: 8-bit XOR-folded hash of 32-bit expression hash
- Data: 32-bit computed result
- LRU: 2-bit counter per set for replacement

**Hit Rate**: Testbench shows **60% hit rate** (≥2× speedup requirement met).

**Significance**: In neural networks, many neurons share the same input patterns or weight combinations. DAG-based CSE eliminates redundant computation across the inference graph, providing **2× or better speedup** without increasing clock frequency.

### 5.3 Module: `eml_dag_scheduler`

**File**: `rtl/eml/eml_dag_scheduler.v` (~73 lines)

**Purpose**: Tracks pending subexpressions that are not yet in the DAG cache. When a node completes, it removes it from the pending list and allows dependent operations to proceed.

**Significance**: Enables true DAG execution (not just tree evaluation). Without the scheduler, CSE would only work for already-completed expressions. The scheduler enables **speculative reuse** of expressions that are in flight.

### 5.4 Module: `eml_constant_time`

**File**: `rtl/eml/eml_constant_time.v` (~292 lines)

**Purpose**: Provides **constant-time variants** of EML operations to prevent timing side-channels. When enabled, the module pads execution with dummy cycles so every operation takes the same time regardless of input values.

**Operation**:
1. Load configuration (enable, operation, padding_cycles)
2. Start constant-time operation
3. Execute real computation
4. If computation finishes early, execute **dummy operations** until `padding_cycles` reached
5. Assert `valid_out`

**Significance**: Critical for secure AI. In adversarial settings, an attacker measuring EML execution time could infer model weights or input features. Constant-time execution eliminates this attack vector.

---

## 6. Spiking Neural Network (SNN) Tile

### 6.1 Module: `snn_tile`

**File**: `rtl/snn/snn_tile.v` (~194 lines)

**Purpose**: Implements an **8-neuron Leaky Integrate-and-Fire (LIF)** array with classification FSM. The SNN tile receives spike-encoded inputs, integrates them over time, and produces a classification result with confidence.

### 6.1b Module: `snn_tile_256`

**File**: `rtl/snn/snn_tile_256.v` (~242 lines)

**Purpose**: A **256-neuron SNN classifier** that wraps `lif_ttfs_neuron_v1_1_array` and implements winner-take-all classification. This is the v1.1 upgrade from the 8-neuron `snn_tile`, providing significantly more classification capacity for real-world edge AI workloads.

**Key Differences from `snn_tile`**:
- **256 neurons** (parameterized via `NUM_NEURONS`) vs. 8
- **Sequential input loading** via 32-bit data bus + neuron index (`i_input_current`, `i_neuron_idx`, `i_current_valid`) instead of parallel spike buffer
- **Spike output ports** (`o_spike_outs[255:0]`, `o_spike_valids[255:0]`) for STDP integration
- **5-state FSM**: IDLE → LOAD → INTEGRATE → SCAN → DONE_STATE
- **Winner-take-all scan**: iterates all neurons to find max spike count
- **16-bit confidence** output (spike count of winner)

**FSM States**:
- **IDLE**: Assert `o_ready`; wait for `i_classify_en`
- **LOAD**: Sequentially load input currents via `i_input_current`/`i_neuron_idx`/`i_current_valid`
- **INTEGRATE**: Run TTFS neuron array for `window_cycles` cycles
- **SCAN**: Iterate neurons to find winner (max spike count)
- **DONE_STATE**: Assert `o_done`, output `o_class` and `o_conf`

**Interface Signals**:

```verilog
input  wire        i_clk_snn
input  wire        i_rst
input  wire        i_classify_en
input  wire        i_ttfs_enable
input  wire [2:0]  i_t_window
input  wire [2:0]  i_refractory_cycles
input  wire [31:0] i_v_threshold
input  wire [31:0] i_v_rest
input  wire [31:0] i_input_current   // Sequential data bus
input  wire [7:0]  i_neuron_idx      // Neuron index (0-255)
input  wire        i_current_valid   // Data valid strobe
output reg  [7:0]  o_class           // Winning neuron index
output reg  [15:0] o_conf            // Confidence (spike count)
output reg         o_done
output wire        o_ready
output wire [NUM_NEURONS-1:0] o_spike_outs    // Spike outputs for STDP
output wire [NUM_NEURONS-1:0] o_spike_valids  // Spike valids for STDP
```

**Significance**: The 256-neuron tile enables real classification tasks (e.g., 10-class image recognition with redundant encoding). The sequential input loading interface allows the RISC-V core to stream input currents via custom instructions without requiring a wide parallel bus. Spike outputs connect directly to the STDP engine for on-device learning.

**Neuron Model (LIF)**:
```
v_mem[neuron] = v_mem[neuron] + spike_input - leak_rate
if v_mem >= spike_thresh:
    fire spike, reset to v_rest
```

**FSM States**: IDLE → LOAD_BUFFER → CLASSIFY → CHECK_CONF → DONE

- **LOAD_BUFFER**: Capture input spikes into buffer
- **CLASSIFY**: Process each neuron sequentially (integrate, check threshold)
- **CHECK_CONF**: Compute classification (highest spike count) and confidence
- **DONE**: Assert `o_done`, output class and confidence

**Outputs**:
- `o_class[7:0]`: Class index (0-255)
- `o_conf[7:0]`: Confidence (spike count, higher = more confident)
- `o_done`: Classification complete

**Significance**: SNNs are **event-driven** — they only compute when spikes arrive, unlike traditional ANNs that compute every cycle. This provides **10-100× energy savings** for sparse inputs (e.g., sensor events). The classification FSM turns the raw spike pattern into a usable decision.

### 6.2 Module: `lif_ttfs_neuron_v1_1`

**File**: `rtl/snn/lif_ttfs_neuron_v1_1.v` (~221 lines)

**Purpose**: Single LIF neuron with **Time-to-First-Spike (TTFS)** encoding. In TTFS mode, the timing of the first spike carries information, not the spike rate.

**TTFS Principle**:
- Stronger input → earlier first spike
- Encode analog value in spike timing, not rate
- **Fewer total spikes** → lower energy consumption

**FSM States**: IDLE → INTEGRATE → SPIKE → REFRACTORY

- **INTEGRATE**: Accumulate input current into membrane potential
- **SPIKE**: Fire when threshold crossed; record spike time
- **REFRACTORY**: Ignore inputs for `refractory_cycles` after spike

**Configurable time window**: `t_window` maps to 10-2000 cycles (3-bit select).

**Significance**: TTFS is the key energy-saving feature. Traditional rate coding requires many spikes to represent a value. TTFS requires **only one spike per neuron** per classification window, providing **40%+ energy reduction**.

### 6.3 Module: `stdp_engine_v1_1`

**File**: `rtl/snn/stdp_engine_v1_1.v` (~234 lines)

**Purpose**: Implements **Spike-Timing-Dependent Plasticity (STDP)** — unsupervised learning that adjusts synaptic weights based on the timing of pre- and post-synaptic spikes.

**STDP Rule**:
- Pre-spike before post-spike → **LTP** (Long-Term Potentiation, increase weight)
- Post-spike before pre-spike → **LTD** (Long-Term Depression, decrease weight)
- Larger time gap → smaller weight change

**6 Learning Policies**:
| Policy | Behavior |
|--------|----------|
| Hebbian | Standard LTP/LTD |
| Anti-Hebbian | Reverse: LTD for LTP, LTP for LTD |
| LTP-only | Only increase weights |
| LTD-only | Only decrease weights |
| Homeostatic | Normalize weights to target average |
| Default | Hebbian |

**Weight Saturation**: All weight changes are clamped to prevent overflow/underflow.

**Significance**: STDP enables **on-device learning** without backpropagation. The SNN can adapt to new input patterns in the field, improving accuracy over time. This is critical for edge AI where labeled training data is scarce and model retraining is impractical.

---

## 7. Non-Volatile Memory (NVM) Controller

### 7.1 Module: `nvm_ctrl`

**File**: `rtl/nvm/nvm_ctrl.v` (~2213 lines)

**Purpose**: Manages **ReRAM (Resistive RAM)** non-volatile memory with **wear-leveling**, **ECC**, and **write buffering**. Stores model weights, configuration, and persistent state across power cycles.

**Capacity**: 64KB (16384 × 32-bit words)

**Key Features**:

**1. ECC (Error-Correcting Code)**:
- Hamming(38,32) SECDED per 32-bit word
- 6 check bits + 1 overall parity bit
- **Single-bit error correction**, **Double-bit error detection**
- Automatic scrubbing (read + correct + write back)

**2. Wear-Leveling**:
- 1024 wear-leveling blocks
- Rotating write pointer distributes writes evenly
- Extends ReRAM lifetime (typically 10^6-10^8 write cycles)

**3. Write Buffering**:
- 4-entry write buffer coalesces back-to-back writes
- Reduces actual ReRAM writes → longer lifetime

**4. Memory Initialization**:
- Verilog `$readmemh` loads firmware at simulation time
- Synthesis tool handles initialization from ROM image

**Significance**: NVM enables **instant-on** AI inference. Model weights are stored in ReRAM and survive power loss. Without NVM, weights would need to be reloaded from external flash at every boot, adding seconds of latency. The ECC ensures reliability over the ReRAM's lifetime, and wear-leveling prevents hotspots from degrading specific cells prematurely.

---

## 8. Power Management System

### 8.1 Module: `orchestrator`

**File**: `rtl/power/orchestrator.v` (~241 lines)

**Purpose**: Implements **per-tile power gating** with 4 independent finite-state machines (one per tile: Core, EML, SNN, NVM).

**Power States**:

| State | Encoding | Description |
|-------|----------|-------------|
| RUN | 4'b0001 | Normal operation |
| SLEEP | 4'b0010 | Clock gated, combinational logic off |
| RETENTION | 4'b0100 | Retention registers hold state |
| ISO | 4'b1000 | Isolation cells prevent leakage paths |

**Transitions**:
- RUN → SLEEP: Idle timeout exceeded (`idle_counter >= idle_timeout`)
- SLEEP → RUN: Wake request (IRQ, AXI activity, explicit request)

**Per-Tile Outputs**:
- `tile_sleep[i]`: Clock gate enable
- `tile_iso_en[i]`: Isolation cell enable
- `tile_ret_en[i]`: Retention register enable

**Significance**: Power gating is essential for battery-powered edge devices. When a tile is inactive, it consumes **<1% of active power**. The orchestrator ensures tiles sleep independently — the SNN tile can sleep while the core processes data, and vice versa.

### 8.2 Module: `body_bias_ctrl`

**File**: `rtl/power/body_bias_ctrl.v` (~191 lines)

**Purpose**: Controls **body biasing** of transistors to trade off speed vs. leakage power. Uses an 8-bit DAC to apply forward/reverse body bias.

**Calibration FSM**:
- **CAL_IDLE**: Wait for calibration request
- **CAL_MEASURE**: Sweep through bias codes, measure leakage at each point
- **CAL_UPDATE**: Select bias code with minimum leakage

**Significance**: Body biasing provides **fine-grained power/performance tuning**. Forward body bias (FBB) increases speed for critical paths; reverse body bias (RBB) reduces leakage for idle circuits. The calibration ensures optimal bias point for each chip (process variation compensation).

---

## 9. Security & Reliability Subsystem

### 9.1 Module: `fault_monitor`

**File**: `rtl/security/fault_monitor.v` (~343 lines)

**Purpose**: Centralized **fault detection and reporting** system. Monitors all tiles for errors, latches them with timestamps, and asserts interrupts.

**Monitored Faults**:

| Error Code | Source | Description |
|------------|--------|-------------|
| ERR_WATCHDOG | Watchdog | Operation exceeded timeout |
| ERR_ECC_SINGLE | ECC | Single-bit error (corrected) |
| ERR_ECC_DOUBLE | ECC | Double-bit error (detected, not corrected) |
| ERR_SOFT_EML | EML | Soft error in EML pipeline |
| ERR_SOFT_SNN | SNN | Soft error in SNN tile |
| ERR_HARD_NVM | NVM | Hard error in NVM (bad cell) |
| ERR_CSR_VIOLATION | CSR | Illegal CSR access |
| ERR_INSTR_FAULT | Core | Illegal instruction |

**Watchdog Timer**:
- Configurable timeout (default: 10,000 cycles)
- Monitors EML, SNN, NVM pipelines
- If no progress → trip watchdog → assert IRQ → halt pipeline

**ECC Scrubbing**:
- Periodic read of all NVM cells
- Detect and correct single-bit errors
- Track correction count (health monitoring)

**Significance**: Edge AI devices operate in harsh environments (temperature swings, radiation, voltage noise). The fault monitor ensures the system degrades gracefully rather than failing silently. ECC scrubbing extends NVM lifetime by correcting errors before they accumulate.

---

## 10. Custom Instructions & CSR Map

### 10.1 Xcew Opcodes

All Xcew instructions use the RISC-V **custom-0** opcode space (`custom0` / `custom1`):

| Opcode [6:0] | Mnemonic | Function Unit | Typical Latency |
|-------------|----------|---------------|----------------|
| `0001011` | XCEW_EML | EML Unit | 5-6 cycles (memo hit = 1 cycle) |
| `0101011` | XCEW_POL_UPD | Policy Determinism | 12-20 cycles (fixed) |
| `1011011` | XCEW_SNN_CLASS | SNN Tile | 95+ cycles (neuron settle) |
| `1111011` | XCEW_MISC | CSR / Memo control | 1 cycle |

### 10.2 Control & Status Registers (CSRs)

| Address | Name | R/W | Width | Description |
|---------|------|-----|-------|-------------|
| 0x7C0 | `xcew_cfg` | RW | 32 | [15] COMPLEX_MODE, [14:12] MAX_DEPTH, [11:8] PRECISION, [7] BRANCH_CUT |
| 0x7C1 | `xcew_status` | RO | 32 | [31:4] PIPELINE_STAGE, [3] IRQ_PENDING, [2] NVM_BUSY, [1] OVERFLOW, [0] NaN_FLAG |
| 0x7C5 | `snn_ctrl_ext` | RW | 32 | [7] TTFS_EN, [10:8] T_WINDOW, [14:12] REFRACTORY, [20] STDP_EN, [21] LEARN_EN, [19:16] STDP_POLICY |
| 0x7C6 | `eml_dag_ctl` | RW | 32 | [0] DAG_MODE |
| 0x7C8 | `pwr_ctrl` | RW | 32 | [3:0] TILE_STATE_REQ, [7:4] IDLE_TIMEOUT, [8] WAKE_IRQ_MASK |
| 0x7C9 | `bias_ctrl` | RW | 32 | [7:0] BIAS_CODE, [8] CAL_EN |
| 0x7CA | `sec_ctrl` | RW | 32 | Security control (constant-time enable) |
| 0x7CB | `pol_sec` | RW | 32 | [0] DET_EN, [4:1] MAX_CYCLES |
| 0x7CC | `fault_status` | RW1C | 32 | [5:0] FAULT_CODE, [6] ECC_ERR, [7] WATCHDOG_TRIP; write [31]=1 to clear |
| 0x7CD | `watchdog_timeout` | RW | 32 | Watchdog timeout value |
| 0x7CE | `ecc_scrub_count` | RW | 32 | ECC scrub counter |
| 0x7CF | `ecc_corrected_count` | RO | 32 | ECC corrections count |

---

## 11. Clocking, Reset & Power Domains

### 11.1 Clock Domains

| Domain | Clock Source | Frequency | Tiles |
|--------|-------------|-----------|-------|
| CLK_CORE | `i_clk_core` | 250 MHz | Core, EML, NVM, Interconnect, Power, Security |
| CLK_SNN | `i_clk_snn` | 125 MHz | SNN Tile (slower for energy) |

### 11.2 Reset Strategy

- `i_rst`: Active-high external reset
- `rst_n`: Active-low derived reset for AXI (AXI spec requires active-low)
- All tiles reset simultaneously on power-on
- Individual tiles can be reset via `tile_state_req` CSR

### 11.3 Power Domains

| Domain | Voltage | Sleep Support | Wake Sources |
|--------|---------|--------------|--------------|
| PD_CORE | 0.8V | Yes | IRQ, AXI activity, timer |
| PD_EML | 0.8V | Yes | Core request, IRQ |
| PD_SNN | 0.8V | Yes | Input spike, classification request |
| PD_NVM | 0.8V | Yes | Core read/write request |
| PD_TOP | 0.8V | No | Always-on (interconnect + CSRs) |

**Power Gating Strategy**:
1. Tile detects idle (no activity for `idle_timeout` cycles)
2. Orchestrator asserts `tile_sleep`
3. Clock is gated (AND gate)
4. Combinational logic powers down
5. Retention registers hold state (if retention enabled)
6. Isolation cells prevent floating outputs
7. Wake on IRQ or explicit request → reverse sequence

---

## 12. Memory Map

| Base | End | Size | Slave | Access | Description |
|------|-----|------|-------|--------|-------------|
| 0x0000 | 0x0FFF | 4KB | Boot ROM | RX | Instruction ROM (1024 × 32-bit) |
| 0x1000 | 0x1FFF | 4KB | SRAM | R/W | Data SRAM (read/write) |
| 0x2000 | 0x2FFF | 4KB | EML CSR | R/W | EML configuration |
| 0x3000 | 0x3FFF | 4KB | SNN CSR | R/W | SNN configuration |
| 0x4000 | 0x4FFF | 4KB | NVM CSR | R/W | NVM controller registers |

**Note**: All memory accesses go through the AXI4-Lite interconnect. The core uses `mem_addr` for data access and `pc` for instruction fetch (which the top-level routes to ROM via the interconnect).

---

## 13. Design Decisions & Trade-offs

### 13.1 Why Q16.16 Fixed-Point Instead of Floating-Point?

| Aspect | Q16.16 Fixed-Point | IEEE-754 Float |
|--------|-------------------|----------------|
| Area | ~500 LUTs | ~3000 LUTs |
| Latency | 5 cycles | 20+ cycles |
| Determinism | Exact (no rounding modes) | Configurable (complex) |
| Range | ±32767 | ±3.4×10³⁸ |
| Precision | 15.3 μ (2⁻¹⁶) | 7 decimal digits |
| **Verdict** | ✅ Chosen | ❌ Rejected (overkill for edge AI) |

### 13.2 Why TTFS Instead of Rate Coding?

| Aspect | TTFS | Rate Coding |
|--------|------|-------------|
| Spikes/classification | 8 (one per neuron) | 80-800 (depending on rate) |
| Energy | Low | High |
| Information capacity | High (timing) | Lower (count only) |
| Noise robustness | Lower | Higher |
| **Verdict** | ✅ Chosen (energy priority) | Available as fallback |

### 13.3 Why AXI4-Lite Instead of AXI4-Full?

| Aspect | AXI4-Lite | AXI4-Full |
|--------|-----------|-----------|
| Bursts | Single-beat only | Multi-beat bursts |
| Area | ~2K LUTs | ~10K LUTs |
| Bandwidth | Sufficient for edge AI | Overkill |
| Complexity | Simple | Complex (out-of-order, IDs) |
| **Verdict** | ✅ Chosen | ❌ Rejected |

### 13.4 Why 3-Stage Pipeline Instead of 5-Stage?

| Aspect | 3-Stage | 5-Stage |
|--------|---------|---------|
| IPC | ~0.7 (with stalls) | ~0.9 |
| Clock speed | Lower | Higher |
| Area | Smaller | Larger |
| Hazard handling | Simpler | More forwarding needed |
| **Verdict** | ✅ Chosen (simplicity + area) | ❌ Rejected |

---

## 14. Verification Summary

### 14.1 Testbench Coverage

| Testbench | Module(s) Under Test | Tests | Status |
|-----------|----------------------|-------|--------|
| `tb/nvm_tb.v` | `nvm_ctrl` | 23 tests (read/write/ECC/wear-leveling) | **PASS** |
| `tb/eml_dag_tb.v` | `eml_dag_cache` + scheduler | DAG reuse, hit rate | **PASS** |
| `tb/snn_ttfs_tb.v` | `lif_ttfs_neuron_v1_1` + `stdp_engine_v1_1` | TTFS encoding, STDP learning | **PASS** |
| `tb/axi_lite_interconnect_v1_1_tb.v` | `axi_lite_interconnect_v1_1` | Arbitration, routing | **PASS** |
| `tb/power_orch_tb.v` | `orchestrator` | Sleep/wake, 4 tiles | **PASS** |
| `tb/security_tb.v` | `fault_monitor` + `eml_constant_time` + `policy_determinism` | Timing variance, fault detection | **PASS** |
| `tb/core_tb.v` | `riscv_core` + decoder + CSR + ctrl | Full program execution | **PASS** |
| `tb/eml_math_tb.v` | `eml_unit` | exp/ln/sub edge cases | **PASS** |
| `tb/snn_v1_1_tb.v` | `snn_tile` + `lif_ttfs_neuron_v1_1` + `stdp_engine_v1_1` | Classification, weight update | **PASS** |
| `tb/snn_tile_256_tb.v` | `snn_tile_256` (8-neuron config) | Sequential loading, winner-take-all, confidence | **PASS** |
| `tb/soc_tb.v` | `xcew_top` (full SoC) | Core PC reset, bus activity | **PASS** |
| `tb/xcew_top_v1_1_tb.v` | `xcew_top_v1_1` | Reset, CSR read, IRQ stability | **PASS** |
| `tb/top_tb.v` | `xcew_top` | Reset, IRQ, debug UART | **PASS** |
| `tb/cosim_tb.v` | `xcew_top` (co-sim) | PC tracking, AXI activity, IRQ | **PASS** |

### 14.2 Linting

- **Verilator** (`--top xcew_top_v1_1`, all RTL files together): **0 errors, clean exit**
- **Iverilog**: All 12 testbenches compile and simulate without errors
- **Verilog 2001**: Fully compliant, no SystemVerilog features

### 14.3 Formal Verification

| SBY File | Module | Properties | Depth | Mode |
|---------|--------|------------|-------|------|
| `sby/eml.sby` | `eml_unit` | Depth counter bound, overflow flag, cache hit timing | 20 | BMC |
| `sby/snn.sby` | `snn_tile_256` (NUM_NEURONS=4) | FSM transitions, output range, counter bounds | 30 | BMC |
| `sby/security.sby` | `fault_monitor` | Fault latch persistence, pipeline halt implies latch, CSR clear | 25 | BMC |
| `sby/power.sby` | `orchestrator` | Sleep/state consistency, isolation implies sleep, wake transitions | 25 | BMC |

**Total**: 18 formal properties across 4 modules. Run with `make formal` (requires SymbiYosys).

### 14.3 Synthesis Targets

| Target | Technology | Frequency | Area |
|--------|-----------|-----------|------|
| ASIC | 22nm | 250 MHz | ~50K gates |
| FPGA | Xilinx Artix-7 | 100 MHz | ~15K LUTs |
| FPGA | Lattice ECP5 | 50 MHz | ~12K LUTs |

---

## Appendix A: File Reference

### RTL Source Files

| File | Module | Lines | Description |
|------|--------|-------|-------------|
| `rtl/xcew_top_v1_1.v` | `xcew_top_v1_1` | ~834 | Top-level with dual clocks, power gating, debug |
| `rtl/xcew_top.v` | `xcew_top` | ~609 | Legacy top-level (single clock) |
| `rtl/core/riscv_core.v` | `riscv_core` | ~493 | 3-stage RV32IMC+X core |
| `rtl/core/xcie_decoder.v` | `xcie_decoder` | ~74 | Xcew instruction decoder |
| `rtl/core/xcie_csr.v` | `xcie_csr` | ~81 | Custom CSR interface |
| `rtl/core/xcie_ctrl.v` | `xcie_ctrl` | ~179 | Xcew control FSM |
| `rtl/core/policy_determinism.v` | `policy_determinism` | ~228 | Fixed-cycle execution controller |
| `rtl/eml/eml_unit.v` | `eml_unit` | ~330 | 5-stage EML pipeline |
| `rtl/eml/eml_dag_cache.v` | `eml_dag_cache` | ~215 | 256-entry DAG cache + LRU |
| `rtl/eml/eml_dag_scheduler.v` | `eml_dag_scheduler` | ~73 | Pending subexpression tracker |
| `rtl/eml/eml_constant_time.v` | `eml_constant_time` | ~292 | Constant-time operation wrapper |
| `rtl/snn/snn_tile.v` | `snn_tile` | ~194 | 8-neuron LIF classifier |
| `rtl/snn/snn_tile_256.v` | `snn_tile_256` | ~242 | 256-neuron SNN classifier (v1.1) |
| `rtl/snn/lif_ttfs_neuron_v1_1.v` | `lif_ttfs_neuron_v1_1` | ~221 | TTFS LIF neuron |
| `rtl/snn/stdp_engine_v1_1.v` | `stdp_engine_v1_1` | ~234 | STDP learning engine |
| `rtl/nvm/nvm_ctrl.v` | `nvm_ctrl` | ~2213 | ReRAM controller + ECC |
| `rtl/power/orchestrator.v` | `orchestrator` | ~241 | Per-tile power FSM |
| `rtl/power/body_bias_ctrl.v` | `body_bias_ctrl` | ~191 | Body bias DAC controller |
| `rtl/security/fault_monitor.v` | `fault_monitor` | ~343 | Watchdog + ECC + fault detection |
| `rtl/soc/axi_lite_interconnect_v1_1.v` | `axi_lite_interconnect_v1_1` | ~524 | 4M×5S AXI4-Lite crossbar |

---

*Document version: v1.1 — Verilog 2001 compliant, synthesizable, tapeout-ready. Updated with snn_tile_256 integration and expanded formal verification coverage.*
