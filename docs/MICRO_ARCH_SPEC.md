<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth Micro-Architecture Specification

**Project:** Azmuth — Xcew RISC-V Processor v1.1
**Status:** DRAFT (tapeout audit §1.1). Covers the **as-implemented** RTL at
commit `96a282a`, top module `xcew_top_v1_1`.
**Convention:** every requirement has a unique ID. `REQ-*` = intended behavior
that the RTL implements; deviations (documented-but-unimplemented or stubbed)
are tracked in §10 with `DEV-*` ids and referenced from the relevant `REQ-*`.

> This spec is written **against the RTL as it exists**, not against the
> aspirational README. Where the README/architecture docs claim behavior the
> v1.1 RTL does not implement, that is recorded honestly in §10 rather than
> described as working. This is the artifact the 27-bug history (see
> `BUG_RETROSPECTIVE.md`) shows was missing.

---

## 1. Pipeline (`REQ-PIPE-*`)

`rtl/core/riscv_core.v` — 3-stage in-order pipeline.

| ID | Requirement |
|----|-------------|
| REQ-PIPE-001 | Three stages: **IF** (fetch from instruction port by PC), **ID/EX** (decode, register read, ALU compute, Xcew dispatch), **WB** (register-file writeback). |
| REQ-PIPE-002 | `next_pc` selects PC+4 by default; branch (BEQ/BNE/BLT/BGE/BLTU/BGEU) and jump (JAL/JALR) targets are computed in EX and muxed into the PC. |
| REQ-PIPE-003 | On a decoded Xcew instruction the pipeline stalls until the Xcew unit asserts done (`i_xcew_done` / per-unit completion); see `xcie_ctrl` FSM (§4). |
| REQ-PIPE-004 | `x0` reads as zero; the register file (32×32) is reset to 0 via a for-loop initializer. |
| REQ-PIPE-005 | Writeback source mux selects ALU result, memory load data (`is_load`), CSR read data (`is_csr_read`), or PC+4 (JAL/JALR). |

Hazard handling is structural via the Xcew stall only; there is no forwarding
network and no load-use interlock beyond single-instruction sequencing — see
DEV-007.

## 2. Instruction set (`REQ-ISA-*`)

Base: RV32I integer with M and C **claimed** (RV32IMC). Decode opcodes in
`riscv_core.v`:

| ID | Opcode | localparam | Notes |
|----|--------|-----------|-------|
| REQ-ISA-001 | `0110011` | OPCODE_RTYPE | R-type ALU |
| REQ-ISA-002 | `0010011` | OPCODE_ITYPE | I-type ALU-imm |
| REQ-ISA-003 | `0000011` | OPCODE_LTYPE | loads (byte-enable per funct3) |
| REQ-ISA-004 | `0100011` | OPCODE_STYPE | stores (`mem_wstrb` per funct3, SB/SH/SW) |
| REQ-ISA-005 | `1100011` | OPCODE_BRANCH | conditional branches |
| REQ-ISA-006 | `1101111` / `1100111` | OPCODE_JAL / OPCODE_JALR | jumps, WB = PC+4 |
| REQ-ISA-007 | `0010111` / `0110111` | OPCODE_AUIPC / OPCODE_LUI | upper-immediate |
| REQ-ISA-008 | `1110011` | OPCODE_SYSTEM | CSR access (Zicsr subset) |

**Xcew custom instructions** — as of DECISION-008 the **standard RISC-V
custom-0..3** opcodes are authoritative and `xcie_decoder.v` has been aligned to
the core (DEV-001 CLOSED). The decoder column below now matches the core column;
historical divergence is kept for context:

| ID | Mnemonic | `riscv_core.v` opcode | `xcie_decoder.v` opcode (aligned) | Xcew ID |
|----|----------|----------------------|-----------------------------------|---------|
| REQ-ISA-010 | XCEW_EML | `0001011` (custom-0) | `0001011` | 1 |
| REQ-ISA-011 | XCEW_POL_UPD | `0101011` (custom-1) | `0101011` | 6 |
| REQ-ISA-012 | XCEW_SNN_CLASS | `1011011` (custom-2) | `1011011` | 5 |
| REQ-ISA-013 | XCEW_MISC/CFG | `1111011` (custom-3) | `1111011` funct3=0 | 2 |
| REQ-ISA-014 | XCEW_MLOAD / MSTORE | `1111011` + funct3 | `1111011` funct3=1/2 | 3 / 4 |

Per DECISION-008 the decoder is now aligned to the core's standard custom-0..3
map; POL_UPD (ID 6) decodes from custom-1 (DEV-002 CLOSED). `xcie_decoder.v`
itself remains vestigial (the core decodes inline). M and C extension coverage
is still unproven (no RISCOF run — tapeout audit §2.4).

## 3. CSR map (`REQ-CSR-*`)

Two implementation sites: `rtl/core/xcie_csr.v` (v1.0 set) and the v1.1 CSR
block inside `rtl/xcew_top_v1_1.v` (gated by `v1_1_en`).

| ID | Addr | Name | R/W | Reset | Implemented in | Behavior |
|----|------|------|-----|-------|----------------|----------|
| REQ-CSR-001 | 0x7C0 | xcew_cfg | RW | 0 | `xcie_csr.v` | Writable fields masked: [15] COMPLEX_MODE, [14:12] MAX_DEPTH, [11:8] PRECISION, [7] BRANCH_CUT; [31:16],[6:0] reserved read-0 |
| REQ-CSR-002 | 0x7C1 | xcew_status | RO | 0 | `xcie_csr.v` (+ rebuilt at top) | [31:4] PIPELINE_STAGE, [3] IRQ_PENDING, [2] NVM_BUSY, [1] OVERFLOW, [0] NaN_FLAG. In `xcie_csr.v` the register is static (DEV-003); top recomputes bit[3]=irq_eml\|irq_snn\|irq_fault |
| REQ-CSR-003 | 0x7C5 | snn_ctrl_ext | RW | 0 | top | gated by `v1_1_en` |
| REQ-CSR-004 | 0x7C6 | eml_dag_ctl | RW | 0 | top | [0] DAG_MODE |
| REQ-CSR-005 | 0x7C8 | pwr_ctrl | RW | 0 | top | tile state / idle timeout / wake mask |
| REQ-CSR-006 | 0x7C9 | bias_ctrl | RW | 0 | top | bias code / cal enable |
| REQ-CSR-007 | 0x7CA | sec_ctrl | RW | 0 | top | const-time / timing-var enables |
| REQ-CSR-008 | 0x7CB | pol_sec | RW | 0 | top | DET_EN / MAX_CYCLES |
| REQ-CSR-009 | 0x7CC | fault_status | **W1C** | 0 | top | cleared by `reg & ~wr_data` |
| REQ-CSR-010 | 0x7CD–0x7CF | watchdog_timeout, ecc_scrub_count, ecc_corrected_count | — | — | **none** | listed in README but **not decoded** at top (DEV-004) |

Illegal-write / read-only enforcement is by field masking only; there is no
illegal-CSR-access exception (ties to DEV-005).

## 4. Xcew control FSM (`REQ-FSM-*`)

`rtl/core/xcie_ctrl.v` — 8-state binary-encoded FSM.

| ID | Requirement |
|----|-------------|
| REQ-FSM-001 | States: IDLE(000), DECODE(001), EXE_EML(010), EXE_CFG(011), EXE_MEMO(100), EXE_SNN(101), EXE_NVM(110), TRAP(111). |
| REQ-FSM-002 | IDLE→DECODE on `i_valid`. DECODE routes by `i_xcew_id`: 1→EXE_EML, 2→EXE_CFG, 3/4→EXE_MEMO, 5→EXE_SNN, 6→EXE_NVM; `i_illegal`→TRAP. |
| REQ-FSM-003 | EXE_EML holds until `i_eml_valid`; EXE_SNN holds until `i_snn_done`; EXE_NVM holds until `!i_nvm_busy`. |
| REQ-FSM-004 | EXE_CFG completes in one cycle (single-cycle CSR write). |
| REQ-FSM-005 | TRAP asserts `o_ctrl_exc_gen` and `o_ctrl_irq_gen` for one cycle, then returns to IDLE. |
| REQ-FSM-006 | EXE_MEMO returns to IDLE in **one cycle** regardless of completion — the "wait for memo operation" comment is not implemented (DEV-006). |

## 5. Memory map (`REQ-MEM-*`)

5 AXI4-Lite slaves (`s0..s4`) on `axi_lite_interconnect_v1_1`. The README
documents a compact map; confirm against the top's address-decode constants
when implementing software.

| ID | Region (README) | Slave | Access |
|----|------------------|-------|--------|
| REQ-MEM-001 | 0x0000–0x0FFF | Boot ROM (s0) | read-only |
| REQ-MEM-002 | 0x1000–0x1FFF | SRAM (s1) | R/W |
| REQ-MEM-003 | 0x2000–0x2FFF | EML CSR (s2) | R/W |
| REQ-MEM-004 | 0x3000–0x3FFF | SNN CSR (s3) | R/W |
| REQ-MEM-005 | 0x4000–0x4FFF | NVM CSR (s4) | R/W |

## 6. Interconnect & arbitration (`REQ-AXI-*`)

| ID | Requirement |
|----|-------------|
| REQ-AXI-001 | `axi_lite_interconnect_v1_1` exposes **4 master ports (m0–m3) × 5 slave ports (s0–s4)** with fixed-priority arbitration. This resolves the README contradiction (audit §1.3a): the "4M×5S" structure is correct; the prose "1 master" was wrong. |
| REQ-AXI-002 | In `xcew_top_v1_1` only **m0 = the RISC-V core** is actively driven; m1–m3 are tied to dummy/quiescent signals (reserved — e.g. for the future Debug Module master, audit §3.5.8). |
| REQ-AXI-003 | The interconnect reset is active-low (`aresetn = ~i_rst`), unlike the active-high `i_rst` used elsewhere. |

## 7. Interrupts & exceptions (`REQ-IRQ-*`, `REQ-EXC-*`)

| ID | Requirement / status |
|----|----------------------|
| REQ-IRQ-001 | Top-level IRQ outputs: `o_irq_eml`, `o_irq_snn`, `o_irq_nvm`, `o_irq_fault`, plus `timeout_irq` (policy). |
| REQ-IRQ-002 | In v1.1 RTL only `o_irq_fault` is live (`= fault_irq_int`); `o_irq_eml`, `o_irq_snn`, `o_irq_nvm` are **tied to 1'b0** (DEV-008). `wake_irq_trigger` ORs the (stubbed) eml/snn/nvm IRQs for power wake. |
| REQ-EXC-001 | `riscv_core.exception` is **hardwired to 1'b0** — the core never raises a synchronous exception (DEV-005). |
| REQ-EXC-002 | The core has **no machine trap CSRs** (`mtvec`/`mepc`/`mcause`/`mstatus`/`mie`/`mip`). There is no trap vectoring, no `mret`, no privilege model (DEV-009). This blocks the `privilege`/`Zicsr` portions of RISCOF (audit §2.4) and the trap-handler firmware (software audit §S2.5) until implemented. |

## 8. Reset & power (`REQ-RST-*`, `REQ-PWR-*`)

| ID | Requirement |
|----|-------------|
| REQ-RST-001 | Active-high synchronous-style reset `i_rst` across core/units; AXI interconnect uses active-low `aresetn` (REQ-AXI-003). No documented reset synchronizer per domain yet (audit §3.2 / DEV-010). |
| REQ-PWR-001 | `rtl/power/orchestrator.v` provides a per-tile (Core/EML/SNN/NVM) RUN↔SLEEP FSM with idle timeout; isolation + retention via `retention_reg` / `power_state_manager`. |
| REQ-PWR-002 | Gated clocks `clk_eml_gated`, `clk_snn_gated`, `clk_nvm_gated` feed the switchable tiles; a sleeping tile can be woken by `wake_irq_trigger` or AXI activity. |
| REQ-PWR-003 | `rtl/power/body_bias_ctrl.v` drives an 8-bit P/N-well bias DAC with a calibration sweep FSM and a (simulated) leakage sensor. |

## 9. Clock domains & CDC (`REQ-CDC-*`)

| ID | Requirement |
|----|-------------|
| REQ-CDC-001 | Two source clocks: `i_clk_core` (250 MHz target) and `i_clk_snn` (125 MHz target). |
| REQ-CDC-002 | Every signal crossing core↔snn must be synchronized; a full CDC inventory is **not yet on file** (audit §3.1 / DEV-011). The SNN tile and its CSR/data path are the principal crossing. |

## 10. Specification Deviations Register (`DEV-*`)

Documented-but-unimplemented or stubbed behavior found while writing this spec.
Each is a candidate bug or a scope item for a later audit section. **None of
these should be presented to adopters as working until closed.**

| ID | Deviation | Evidence | Disposition |
|----|-----------|----------|-------------|
| DEV-001 | ~~Core and `xcie_decoder` use disjoint Xcew opcode maps.~~ **RESOLVED** (DECISION-008): decoder aligned to the standard custom-0..3 map (matches core). Test `tb/xcie_decoder_tb.v`. Note `xcie_decoder` remains vestigial (not instantiated). | `xcie_decoder.v:17-` | CLOSED |
| DEV-002 | ~~Xcew ID 6 (POL_UPD) decodes from no opcode.~~ **RESOLVED**: POL_UPD now decodes from custom-1 `0101011`. | `xcie_decoder.v` | CLOSED |
| DEV-003 | `xcew_status` (0x7C1) in `xcie_csr.v` is a static register, never driven by live status. | `xcie_csr.v:72` | Wire real status; top partially compensates for bit[3] only. |
| DEV-004 | CSRs 0x7CD/0x7CE/0x7CF (watchdog_timeout, ecc_scrub/corrected counts) are documented but not decoded at the top. | absent in `xcew_top_v1_1.v` write case | Implement or strike from README/CSR map. |
| DEV-005 | `riscv_core.exception` hardwired to 0. | `riscv_core.v:491` | No synchronous exceptions raised. |
| DEV-006 | `EXE_MEMO` returns to IDLE in 1 cycle; does not wait for memo completion. | `xcie_ctrl.v:88-91` | Add completion handshake if memo latency > 1 cycle. |
| DEV-007 | No data-forwarding / load-use interlock beyond Xcew stall. | `riscv_core.v` pipeline | Confirm hazards covered by directed tests (audit §2.3). |
| DEV-008 | `o_irq_eml/snn/nvm` tied to 0; only fault IRQ live. | `xcew_top_v1_1.v:801-804` | Connect unit IRQ sources. |
| DEV-009 | No machine trap CSRs / privilege model in core. | grep: none in `riscv_core.v` | Required for RISCOF privilege+Zicsr and trap-handler firmware. |
| DEV-010 | No per-domain reset synchronizer documented. | audit §3.2 | Produce `docs/RESET_ARCH.md`. |
| DEV-011 | No CDC inventory for core↔snn crossings. | audit §3.1 | Produce `docs/CDC_ANALYSIS.md`. |

---

## Sign-off

| Role | Name | Date | Status |
|------|------|------|--------|
| Author | _Pair A_ | 2026-05-23 | DRAFT |
| Reviewer (not RTL author of block) | _pending_ | — | — |
| Team lead | Kiransekar | — | — |

Audit §1.1 PASS requires sign-off by the team lead and at least one engineer who
did not write the RTL for the reviewed block.
