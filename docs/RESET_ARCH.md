<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Reset Architecture

**Audit reference:** Tapeout §3.2
**Date:** 2026-06-06

## Reset Sources

| Signal | Type | Polarity | Domain | Source |
|--------|------|----------|--------|--------|
| `i_rst` | Primary | Active-high | Core, EML, NVM, Security, Power | External pin |
| `aresetn` | Derived | Active-low | AXI interconnect | `~i_rst` in `xcew_top_v1_1.v` |

## Reset Architecture per Domain

### Core Domain (`i_clk_core`, 250 MHz)
- **Reset style:** Asynchronous assert, synchronous release (via `always @(posedge clk or posedge rst)`)
- **Affected modules:** `riscv_core`, `xcie_csr`, `xcie_ctrl`, `xcie_decoder`, `policy_determinism`
- **Reset state:** PC = `RESET_PC` (parameter), all registers = 0, all CSRs = 0, pipeline empty

### SNN Domain (`i_clk_snn`, 125 MHz)
- **Reset style:** Asynchronous assert, synchronous release
- **Affected modules:** `snn_tile_256`, `lif_ttfs_neuron_v1_1`, `stdp_engine_v1_1`
- **Reset state:** All neuron membrane potentials = 0, FSM = IDLE, spike outputs = 0
- **⚠ DEV-011:** No reset synchronizer between core and SNN clock domains

### EML Domain (`i_clk_core`, gated)
- **Reset style:** Same as core (shared clock, gated)
- **Affected modules:** `eml_unit`, `eml_dag_cache`, `eml_constant_time`
- **Reset state:** Pipeline empty, cache invalidated, no pending operations

### NVM Domain (`i_clk_core`, gated)
- **Reset style:** Same as core
- **Affected modules:** `nvm_ctrl`
- **Reset state:** Write buffer empty, scrub counter = 0, no pending operations

### AXI Interconnect
- **Reset style:** Active-low `aresetn = ~i_rst`
- **Affected modules:** `axi_lite_interconnect_v1_1`
- **Reset state:** All bus signals deasserted, arbitration reset

### Power Domain
- **Reset style:** Same as core
- **Affected modules:** `orchestrator`, `body_bias_ctrl`, `retention_reg`, `power_state_manager`
- **Reset state:** All tiles in RUN state, no isolation/retention, bias DAC = 0

## Reset Sequencing

```
1. External i_rst asserted (power-on or warm reset)
   ├── Core domain: all FFs reset asynchronously
   ├── SNN domain: all FFs reset asynchronously
   ├── AXI domain: aresetn = 0, bus quiesced
   └── Power domain: all tiles forced to RUN

2. i_rst deasserted (synchronous release within each domain)
   ├── Core: PC begins fetching from RESET_PC
   ├── Body-bias DAC: calibration sweep begins (est. ~1000 cycles)
   ├── AXI: bus ready for transactions
   └── Power orchestrator: idle timers begin

3. Body-bias calibration complete
   └── Normal operation begins
```

## Known Gaps (DEV-010)

1. **No explicit reset synchronizer** between `i_clk_core` and `i_clk_snn`.
   The same `i_rst` feeds both domains without a 2-FF synchronizer chain in the
   SNN domain. In practice this works because `i_rst` is typically held for many
   cycles, but it is technically a metastability risk on the reset deassertion edge.

2. **Recommended fix:** Add a standard async-assert, sync-deassert reset
   synchronizer in the SNN domain:
   ```verilog
   reg [1:0] rst_snn_sync;
   always @(posedge i_clk_snn or posedge i_rst) begin
       if (i_rst) rst_snn_sync <= 2'b11;
       else       rst_snn_sync <= {rst_snn_sync[0], 1'b0};
   end
   wire rst_snn = rst_snn_sync[1]; // synchronized reset for SNN domain
   ```

3. **POR vs warm reset:** Currently no distinction. A warm-reset path that
   preserves NVM state while resetting the pipeline is not implemented.
