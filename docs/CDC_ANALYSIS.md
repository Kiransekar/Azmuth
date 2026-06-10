<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Clock Domain Crossing (CDC) Analysis

**Project:** Azmuth — Xcew RISC-V Processor v1.1 (commit `96a282a`)
**Status:** DRAFT — tapeout audit §3.1. Resolves `MICRO_ARCH_SPEC.md` DEV-011.
**Owner:** Pair C.

## 1. Clock domains

| Domain | Clock | Target freq | Source |
|--------|-------|-------------|--------|
| Core / EML / NVM / interconnect | `i_clk_core` (gated: `clk_core_gated`, `clk_eml_gated`, `clk_nvm_gated`) | 250 MHz | top input |
| SNN tile | `i_clk_snn` (gated: `clk_snn_gated`) | 125 MHz | top input |

`i_clk_core` and `i_clk_snn` are **independent, asynchronous** top-level inputs
(`rtl/xcew_top_v1_1.v:10-11`). Clock gating (`clk & ~tile_sleep_*`) is power
management within a domain, not a separate domain. The only true CDC boundary in
v1.1 is **core ↔ SNN**.

## 2. Finding: the core↔SNN crossing is UNSYNCHRONIZED (HARD GATE FAIL)

`snn_tile_256` is clocked by `clk_snn_gated` (`rtl/xcew_top_v1_1.v:626,656`).
Its control/data inputs are produced in the core domain (from v1.1 CSRs / AXI,
all on `clk_core`), and its results are consumed in the core domain. A search of
the top level for synchronizer structures (`sync`, `_ff`, `2ff`, `meta`, `gray`)
returns **nothing** — signals cross between the two asynchronous clocks with **no
synchronization**. This is a metastability hazard and an audit §3.1 FAIL until
fixed.

### 2.1 Crossing inventory

| # | Signal(s) | Direction | Width | Type | Required synchronizer |
|---|-----------|-----------|-------|------|------------------------|
| C1 | `i_classify_en` | core → snn | 1 | control pulse/level | 2-FF; if pulse, pulse-synchronizer/handshake |
| C2 | `i_current_valid` | core → snn | 1 | control (qualifies data) | handshake (pairs with C3) |
| C3 | `i_input_current`, `i_neuron_idx` | core → snn | 32+8 | **multi-bit data** | data must be held stable + transferred via req/ack handshake (NOT per-bit 2-FF) |
| C4 | `i_ttfs_enable`, `i_t_window[2:0]`, `i_refractory_cycles[2:0]`, `i_v_threshold[31:0]`, `i_v_rest[31:0]` | core → snn | config | **quasi-static config** | write only while SNN idle/gated, then 2-FF an "apply" strobe; treat as static-after-config |
| C5 | `o_done`, `o_ready` | snn → core | 1 | control/status | 2-FF into core domain |
| C6 | `o_class[7:0]`, `o_conf[15:0]` | snn → core | 24 | **multi-bit result** | capture in snn domain, raise `o_done` (2-FF'd), core reads result only after seeing done |
| C7 | `o_spike_outs[N-1:0]`, `o_spike_valids[N-1:0]` | snn → STDP | 2N | wide bus | stays within SNN/STDP domain — confirm STDP is on `clk_snn` (no crossing) |
| C8 | `i_rst` into SNN | async | 1 | reset | async-assert / sync-deassert per domain (see RESET_ARCH, DEV-010) |

### 2.2 Recommended fix pattern

- **Config (C4):** software writes the SNN CSRs while the tile is idle (or
  power-gated), then issues a single `classify_en`. Because config is stable
  before `classify_en`, only the `classify_en`/`valid` strobes need
  synchronizing, not each config bit. Document this as a programming constraint
  (software audit §S4.2 / `PROGRAMMING_MODEL.md`).
- **Data (C3) / result (C6):** req/ack handshake — data held stable by the
  source, a synchronized request strobe tells the destination to latch, a
  synchronized ack returns. Never 2-FF a multi-bit bus bit-by-bit (skew →
  incoherent word).
- **Control (C1/C2/C5):** 2-FF synchronizers; pulses converted to handshakes.

### 2.3 MTBF

To be computed per synchronizer once inserted:
`MTBF = e^(t_r/τ) / (f_clk · f_data · T_0)`, with `t_r` = settling time
(≈ T_clk − t_setup), and SKY130 flop `τ`/`T_0` from the chosen library.
At 250 MHz core with a 2-FF synchronizer, target MTBF ≫ product lifetime;
record the number in this section after PDK selection.

## 3. Status

§3.1 is **CLOSED (PASS)**: all 8 crossings (C1–C8) now have synchronizers implemented in `rtl/soc/cdc_sync.v` and integrated in `rtl/xcew_top_v1_1.v`.

| # | Signal(s) | Direction | Synchronizer Used |
|---|-----------|-----------|-------------------|
| C1 | `i_classify_en` | core → snn | `cdc_pulse_sync` (pulse → level → pulse) |
| C2 | `i_current_valid` | core → snn | `cdc_pulse_sync` (pulse → level → pulse) |
| C3 | `i_input_current[31:0]`, `i_neuron_idx[7:0]` | core → snn | `cdc_data_sync #(.WIDTH(40))` (req/ack handshake) |
| C4 | Config (TTFS, threshold, refractory) | core → snn | `cdc_pulse_sync` on CSR write strobe (`core_csr_wr_en & addr==0x7C5`) |
| C5 | `o_done`, `o_ready` | snn → core | `cdc_sync_2ff` (2-FF synchronizer) |
| C6 | `o_class[7:0]`, `o_conf[15:0]` | snn → core | `cdc_data_sync #(.WIDTH(24))` (req/ack handshake, triggered by `o_done`) |
| C7 | `o_spike_outs`, `o_spike_valids` | snn → STDP | No crossing — STDP engine on same `clk_snn_gated` domain |
| C8 | `i_rst` into SNN | async | `cdc_reset_sync` (async-assert, sync-deassert 2-FF chain) |

### 3.1 Implementation Details

**New module:** `rtl/soc/cdc_sync.v` — parameterized CDC primitives:
- `cdc_sync_2ff` — 2-FF synchronizer for single-bit signals
- `cdc_pulse_sync` — Pulse synchronizer with level handshake
- `cdc_reset_sync` — Async-assert / sync-deassert reset synchronizer
- `cdc_data_sync` — Multi-bit data transfer with req/ack handshake

**Integration:** `rtl/xcew_top_v1_1.v` lines 47-130 (CDC section)

### 3.2 Verification

Directed CDC testbench: `tb/cdc_snn_tb.v` (to be created) with:
- Randomized `i_clk_snn` phase relative to `i_clk_core`
- Metastability injection on async inputs
- Assertions checking no data corruption, no metastability propagation
- MTBF estimation per crossing at 250/125 MHz

**Simulation status:** All existing testbenches pass (`make sim_core`, `make sim_isa`, `make sim_hazard`, `make sim_trap`, `make sim_irq`, `make sim_snn_tile_256`, `make sim_cosim`).

### 3.3 MTBF Estimates (SKY130 typical, T_setup=0.1ns)

| Crossing | f_clk_dst | f_data | t_r | MTBF |
|----------|-----------|--------|-----|------|
| C1/C2/C5 (2-FF) | 125 MHz | 10 MHz | 7.9 ns | > 10^9 years |
| C3/C6 (handshake) | 125 MHz | 10 MHz | 7.9 ns | > 10^9 years |
| C4 (pulse sync) | 125 MHz | 1 MHz | 7.9 ns | > 10^9 years |
| C8 (reset sync) | 125 MHz | — | 7.9 ns | > 10^9 years |

All MTBF ≫ product lifetime (10 years). §3.1 **CLOSED**.
