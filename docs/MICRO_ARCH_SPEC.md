<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth Micro-Architecture Specification

**Project:** Azmuth — Xcew RISC-V Processor v1.1
**Status:** REVIEWED (tapeout audit §1.1). Covers the **as-implemented** RTL at
current HEAD, top module `xcew_top_v1_1`.
**Convention:** every requirement has a unique ID. `REQ-*` = intended behavior
that the RTL implements; deviations (documented-but-unimplemented or stubbed)
are tracked in §10 with `DEV-*` ids and referenced from the relevant `REQ-*`.

> This spec is written **against the RTL as it exists**, not against the
> aspirational README. Where the README/architecture docs claim behavior the
> v1.1 RTL does not implement, that is recorded honestly in §10 rather than
> described as working. This is the artifact the 36-bug history (see
> `BUG_RETROSPECTIVE.md`) shows was missing.

---

## 1. Pipeline (`REQ-PIPE-*`)

`rtl/core/riscv_core.v` — 3-stage in-order pipeline.

| ID | Requirement |
|----|-------------|
| REQ-PIPE-001 | Three stages: **IF** (fetch from instruction port by PC), **ID/EX** (decode, register read, ALU compute, Xcew dispatch), **WB** (register-file writeback). |
| REQ-PIPE-002 | `next_pc` selects PC+4 by default; branch (BEQ/BNE/BLT/BGE/BLTU/BGEU) and jump (JAL/JALR) targets are computed in EX and muxed into the PC. Trap-taken redirects to `mtvec`; `mret` redirects to `mepc`. |
| REQ-PIPE-003 | On a decoded Xcew instruction the pipeline stalls until the Xcew unit asserts done (`i_xcew_done` / per-unit completion); see `xcie_ctrl` FSM (§4). |
| REQ-PIPE-004 | `x0` reads as zero; the register file (32×32) is reset to 0 via a for-loop initializer. |
| REQ-PIPE-005 | Writeback source mux selects ALU result, memory load data (`is_load`), CSR read data (`is_csr_read`), PC+4 (JAL/JALR), U-immediate (LUI), or PC+U-immediate (AUIPC). |
| REQ-PIPE-006 | Wrong-path flush: a taken control transfer (branch/jump/trap/mret) causes a 2-cycle flush (`redirect | redirect_r`) that squashes the two sequentially-fetched instructions in IF and ID/EX stages. |

Hazard handling is structural via the Xcew stall only; there is no forwarding
network and no load-use interlock beyond single-instruction sequencing — see
DEV-007.

## 2. Instruction Set (`REQ-ISA-*`)

### 2.1 RV32I Base Integer Instructions

Base: RV32I integer. M and C extensions **claimed** (RV32IMC) but M is not
implemented in ALU and C-extension decoding is absent. The `misa` register
reports `0x40000100` (MXL=32, ext I only).

#### Instruction Execution Semantics

| Instruction | Format | Opcode | Semantics | REQ |
|-------------|--------|--------|-----------|-----|
| ADD | R | 0110011 f3=000 f7=0000000 | rd = rs1 + rs2 | REQ-ISA-001 |
| SUB | R | 0110011 f3=000 f7=0100000 | rd = rs1 - rs2 | REQ-ISA-001 |
| SLL | R | 0110011 f3=001 | rd = rs1 << rs2[4:0] | REQ-ISA-001 |
| SLT | R | 0110011 f3=010 | rd = (signed(rs1) < signed(rs2)) ? 1 : 0 | REQ-ISA-001 |
| SLTU | R | 0110011 f3=011 | rd = (rs1 < rs2) ? 1 : 0 | REQ-ISA-001 |
| XOR | R | 0110011 f3=100 | rd = rs1 ^ rs2 | REQ-ISA-001 |
| SRL | R | 0110011 f3=101 f7=0000000 | rd = rs1 >> rs2[4:0] (logical) | REQ-ISA-001 |
| SRA | R | 0110011 f3=101 f7=0100000 | rd = rs1 >>> rs2[4:0] (arithmetic) | REQ-ISA-001 |
| OR | R | 0110011 f3=110 | rd = rs1 \| rs2 | REQ-ISA-001 |
| AND | R | 0110011 f3=111 | rd = rs1 & rs2 | REQ-ISA-001 |
| ADDI | I | 0010011 f3=000 | rd = rs1 + sext(imm[11:0]) | REQ-ISA-002 |
| SLTI | I | 0010011 f3=010 | rd = (signed(rs1) < signed(sext(imm))) ? 1 : 0 | REQ-ISA-002 |
| SLTIU | I | 0010011 f3=011 | rd = (rs1 < sext(imm)) ? 1 : 0 (unsigned compare) | REQ-ISA-002 |
| XORI | I | 0010011 f3=100 | rd = rs1 ^ sext(imm) | REQ-ISA-002 |
| ORI | I | 0010011 f3=110 | rd = rs1 \| sext(imm) | REQ-ISA-002 |
| ANDI | I | 0010011 f3=111 | rd = rs1 & sext(imm) | REQ-ISA-002 |
| SLLI | I | 0010011 f3=001 | rd = rs1 << imm[4:0] | REQ-ISA-002 |
| SRLI | I | 0010011 f3=101 f7=0000000 | rd = rs1 >> imm[4:0] (logical) | REQ-ISA-002 |
| SRAI | I | 0010011 f3=101 f7=0100000 | rd = rs1 >>> imm[4:0] (arithmetic) | REQ-ISA-002 |
| LB | I | 0000011 f3=000 | rd = sext(mem[rs1+sext(imm)][7:0]) | REQ-ISA-003 |
| LH | I | 0000011 f3=001 | rd = sext(mem[rs1+sext(imm)][15:0]) | REQ-ISA-003 |
| LW | I | 0000011 f3=010 | rd = mem[rs1+sext(imm)][31:0] | REQ-ISA-003 |
| LBU | I | 0000011 f3=100 | rd = zext(mem[rs1+sext(imm)][7:0]) | REQ-ISA-003 |
| LHU | I | 0000011 f3=101 | rd = zext(mem[rs1+sext(imm)][15:0]) | REQ-ISA-003 |
| SB | S | 0100011 f3=000 | mem[rs1+sext(imm)][7:0] = rs2[7:0] | REQ-ISA-004 |
| SH | S | 0100011 f3=001 | mem[rs1+sext(imm)][15:0] = rs2[15:0] | REQ-ISA-004 |
| SW | S | 0100011 f3=010 | mem[rs1+sext(imm)][31:0] = rs2[31:0] | REQ-ISA-004 |
| BEQ | B | 1100011 f3=000 | if (rs1 == rs2) PC = PC + sext(imm) | REQ-ISA-005 |
| BNE | B | 1100011 f3=001 | if (rs1 != rs2) PC = PC + sext(imm) | REQ-ISA-005 |
| BLT | B | 1100011 f3=100 | if (signed(rs1) < signed(rs2)) PC = PC + sext(imm) | REQ-ISA-005 |
| BGE | B | 1100011 f3=101 | if (signed(rs1) >= signed(rs2)) PC = PC + sext(imm) | REQ-ISA-005 |
| BLTU | B | 1100011 f3=110 | if (rs1 < rs2) PC = PC + sext(imm) | REQ-ISA-005 |
| BGEU | B | 1100011 f3=111 | if (rs1 >= rs2) PC = PC + sext(imm) | REQ-ISA-005 |
| JAL | J | 1101111 | rd = PC+4; PC = PC + sext(imm) | REQ-ISA-006 |
| JALR | I | 1100111 | rd = PC+4; PC = (rs1 + sext(imm)) & ~1 | REQ-ISA-006 |
| LUI | U | 0110111 | rd = imm << 12 | REQ-ISA-007 |
| AUIPC | U | 0010111 | rd = PC + (imm << 12) | REQ-ISA-007 |
| FENCE | I | 0001111 | NOP (single-hart, no cache) | REQ-ISA-009 |
| ECALL | I | 1110011 imm=0x000 | Raise environment-call exception (cause 11) | REQ-ISA-008 |
| EBREAK | I | 1110011 imm=0x001 | Raise breakpoint exception (cause 3) | REQ-ISA-008 |
| CSRRW | I | 1110011 f3=001 | rd = CSR[csr]; CSR[csr] = rs1 | REQ-ISA-008 |
| CSRRS | I | 1110011 f3=010 | rd = CSR[csr]; CSR[csr] = CSR[csr] \| rs1 | REQ-ISA-008 |
| CSRRC | I | 1110011 f3=011 | rd = CSR[csr]; CSR[csr] = CSR[csr] & ~rs1 | REQ-ISA-008 |
| CSRRWI | I | 1110011 f3=101 | rd = CSR[csr]; CSR[csr] = zext(uimm) | REQ-ISA-008 |
| CSRRSI | I | 1110011 f3=110 | rd = CSR[csr]; CSR[csr] = CSR[csr] \| zext(uimm) | REQ-ISA-008 |
| CSRRCI | I | 1110011 f3=111 | rd = CSR[csr]; CSR[csr] = CSR[csr] & ~zext(uimm) | REQ-ISA-008 |
| MRET | I | 1110011 imm=0x302 | PC = mepc; restore mstatus.MIE from MPIE | REQ-ISA-008 |

### 2.2 Xcew Custom Instructions

Per DECISION-008 the **standard RISC-V custom-0..3** opcodes are authoritative:

| ID | Mnemonic | Opcode | Xcew ID | Semantics |
|----|----------|--------|---------|-----------|
| REQ-ISA-010 | XCEW_EML | `0001011` (custom-0) | 1 | Dispatch EML compute; pipeline stalls until `i_eml_valid` |
| REQ-ISA-011 | XCEW_POL_UPD | `0101011` (custom-1) | 6 | Policy update via NVM controller path |
| REQ-ISA-012 | XCEW_SNN_CLASS | `1011011` (custom-2) | 5 | SNN classify; stalls until `i_snn_done` |
| REQ-ISA-013 | XCEW_MISC/CFG | `1111011` (custom-3) f3=0 | 2 | Single-cycle CSR configuration write |
| REQ-ISA-014 | XCEW_MLOAD/MSTORE | `1111011` f3=1/2 | 3/4 | Memo load/store (single-cycle, DEV-006) |

## 3. CSR Map (`REQ-CSR-*`)

### 3.1 Machine-Mode Standard CSRs (internal to `riscv_core.v`)

| ID | Addr | Name | R/W | Reset | Behavior |
|----|------|------|-----|-------|----------|
| REQ-CSR-M01 | 0x300 | mstatus | RW | 0 | [12:11] MPP (M-mode=11), [7] MPIE, [3] MIE. Other bits read 0. On trap: MPIE←MIE, MIE←0, MPP←11. On mret: MIE←MPIE, MPIE←1. |
| REQ-CSR-M02 | 0x301 | misa | RO | 0x40000100 | MXL=32 (bits[31:30]=01), Extensions=I (bit[8]=1). M-extension NOT reported. |
| REQ-CSR-M03 | 0x304 | mie | RW | 0 | [11] MEIE (ext interrupt enable), [7] MTIE (timer), [3] MSIE (software). Other bits read 0. |
| REQ-CSR-M04 | 0x305 | mtvec | RW | 0 | Direct mode only (BASE, no vectored). Trap-taking gated on mtvec≠0 (DECISION-009). |
| REQ-CSR-M05 | 0x340 | mscratch | RW | 0 | Scratch register for trap handler use. |
| REQ-CSR-M06 | 0x341 | mepc | RW | 0 | On trap: mepc←PC of trapped instruction. |
| REQ-CSR-M07 | 0x342 | mcause | RW | 0 | On trap: mcause←cause code. Bit[31]=1 for interrupts. Sync exception codes: 2=illegal, 3=breakpoint, 4=load-misalign, 6=store-misalign, 11=ecall. Interrupt codes: 0x8000000B=MEI, 0x80000007=MTI, 0x80000003=MSI. |
| REQ-CSR-M08 | 0x343 | mtval | RW | 0 | On trap: illegal→instruction word, ebreak→PC, misalign→faulting address, interrupt→0. |
| REQ-CSR-M09 | 0x344 | mip | RO | 0 | [11] MEIP=i_meip, [7] MTIP=i_mtip, [3] MSIP=i_msip. Read-only reflection of input pins. |
| REQ-CSR-M10 | 0xF14 | mhartid | RO | 0 | Always 0 (single hart). |

### 3.2 Xcew Custom CSRs

| ID | Addr | Name | R/W | Reset | Implemented in | Behavior |
|----|------|------|-----|-------|----------------|----------|
| REQ-CSR-001 | 0x7C0 | xcew_cfg | RW | 0 | `xcie_csr.v` | [15] COMPLEX_MODE, [14:12] MAX_DEPTH, [11:8] PRECISION, [7] BRANCH_CUT; [31:16],[6:0] reserved read-0 |
| REQ-CSR-002 | 0x7C1 | xcew_status | RO | 0 | `xcie_csr.v` | [31:4] PIPELINE_STAGE, [3] IRQ_PENDING, [2] NVM_BUSY, [1] OVERFLOW, [0] NaN_FLAG. Static in xcie_csr (DEV-003); top recomputes bit[3] |
| REQ-CSR-003 | 0x7C5 | snn_ctrl_ext | RW | 0 | top | SNN extended control, gated by `v1_1_en` |
| REQ-CSR-004 | 0x7C6 | eml_dag_ctl | RW | 0 | top | [0] DAG_MODE (0=tree, 1=DAG+CSE) |
| REQ-CSR-005 | 0x7C8 | pwr_ctrl | RW | 0 | top | Tile state request / idle timeout / wake mask |
| REQ-CSR-006 | 0x7C9 | bias_ctrl | RW | 0 | top | Bias code / calibration enable |
| REQ-CSR-007 | 0x7CA | sec_ctrl | RW | 0 | top | Constant-time / timing-variant enables |
| REQ-CSR-008 | 0x7CB | pol_sec | RW | 0 | top | DET_EN / MAX_CYCLES for policy determinism |
| REQ-CSR-009 | 0x7CC | fault_status | W1C | 0 | top | Cleared by `reg & ~wr_data`; W1C semantics |
| REQ-CSR-010 | 0x7CD–0x7CF | watchdog_timeout, ecc_scrub_count, ecc_corrected_count | — | — | **none** | Listed in README but **not decoded** at top (DEV-004) |

## 4. Xcew Control FSM (`REQ-FSM-*`)

`rtl/core/xcie_ctrl.v` — 8-state binary-encoded FSM.

| ID | Requirement |
|----|-------------|
| REQ-FSM-001 | States: IDLE(000), DECODE(001), EXE_EML(010), EXE_CFG(011), EXE_MEMO(100), EXE_SNN(101), EXE_NVM(110), TRAP(111). |
| REQ-FSM-002 | IDLE→DECODE on `i_valid`. DECODE routes by `i_xcew_id`: 1→EXE_EML, 2→EXE_CFG, 3/4→EXE_MEMO, 5→EXE_SNN, 6→EXE_NVM; `i_illegal`→TRAP. |
| REQ-FSM-003 | EXE_EML holds until `i_eml_valid`; EXE_SNN holds until `i_snn_done`; EXE_NVM holds until `!i_nvm_busy`. |
| REQ-FSM-004 | EXE_CFG completes in one cycle (single-cycle CSR write). |
| REQ-FSM-005 | TRAP asserts `o_ctrl_exc_gen` and `o_ctrl_irq_gen` for one cycle, then returns to IDLE. |
| REQ-FSM-006 | EXE_MEMO returns to IDLE in **one cycle** regardless of completion — the "wait for memo operation" comment is not implemented (DEV-006). |

## 5. Memory Map (`REQ-MEM-*`)

5 AXI4-Lite slaves (`s0..s4`) on `axi_lite_interconnect_v1_1`.

| ID | Region | Slave | Access | Size |
|----|--------|-------|--------|------|
| REQ-MEM-001 | 0x0000–0x0FFF | Boot ROM (s0) | Read-only | 4 KB |
| REQ-MEM-002 | 0x1000–0x1FFF | SRAM (s1) | R/W | 4 KB |
| REQ-MEM-003 | 0x2000–0x2FFF | EML CSR (s2) | R/W | 4 KB |
| REQ-MEM-004 | 0x3000–0x3FFF | SNN CSR (s3) | R/W | 4 KB |
| REQ-MEM-005 | 0x4000–0x4FFF | NVM CSR (s4) | R/W | 4 KB |

## 6. Interconnect & Arbitration (`REQ-AXI-*`)

| ID | Requirement |
|----|-------------|
| REQ-AXI-001 | `axi_lite_interconnect_v1_1` exposes **4 master ports (m0–m3) × 5 slave ports (s0–s4)** with fixed-priority arbitration (m0 highest). |
| REQ-AXI-002 | In `xcew_top_v1_1` only **m0 = the RISC-V core** is actively driven; m1–m3 are tied to quiescent signals (reserved for Debug Module). |
| REQ-AXI-003 | The interconnect reset is active-low (`aresetn = ~i_rst`), unlike the active-high `i_rst` used elsewhere. |

## 7. Interrupts & Exceptions (`REQ-IRQ-*`, `REQ-EXC-*`)

| ID | Requirement |
|----|-------------|
| REQ-IRQ-001 | Top-level IRQ outputs: `o_irq_eml`, `o_irq_snn`, `o_irq_nvm`, `o_irq_fault`, plus `timeout_irq` (policy). Sources currently tied 0 for eml/snn/nvm (DEV-008). |
| REQ-IRQ-002 | Core takes machine interrupts via `i_meip` (wired to aggregate fault/timeout), gated by `mstatus.MIE` & `mie[11]`. Priority: sync exception > MEI > MTI > MSI. |
| REQ-EXC-001 | Synchronous exceptions: illegal instruction (cause 2), ECALL (cause 11), EBREAK (cause 3), load address misaligned (cause 4), store address misaligned (cause 6). All taken to `mtvec` when `mtvec != 0`. |
| REQ-EXC-002 | M-mode trap CSRs + full Zicsr (CSRRW/S/C + imm variants) + `mret`. RS/RC write only if rs1/uimm ≠ 0. |

## 8. Reset & Power (`REQ-RST-*`, `REQ-PWR-*`)

| ID | Requirement |
|----|-------------|
| REQ-RST-001 | Active-high synchronous-style reset `i_rst`. Core resets to `RESET_PC` (parameter, default 0x00000000). AXI interconnect uses inverted `aresetn`. No documented reset synchronizer (DEV-010). |
| REQ-RST-002 | On reset: all registers zeroed, PC = RESET_PC, all CSRs = 0, pipeline flushed. |
| REQ-PWR-001 | `orchestrator.v`: per-tile (Core/EML/SNN/NVM) RUN↔SLEEP FSM with idle timeout; isolation + retention via `retention_reg` / `power_state_manager`. |
| REQ-PWR-002 | Gated clocks `clk_eml_gated`, `clk_snn_gated`, `clk_nvm_gated`; sleeping tile woken by `wake_irq_trigger` or AXI activity. |
| REQ-PWR-003 | `body_bias_ctrl.v`: 8-bit P/N-well bias DAC with calibration sweep FSM and leakage sensor. |

## 9. Clock Domains & CDC (`REQ-CDC-*`)

| ID | Requirement |
|----|-------------|
| REQ-CDC-001 | Two source clocks: `i_clk_core` (250 MHz target) and `i_clk_snn` (125 MHz target). |
| REQ-CDC-002 | Every signal crossing core↔SNN must be synchronized; CDC inventory documented in `CDC_ANALYSIS.md`. **No synchronizers exist in v1.1 RTL** (DEV-011). |

## 10. Specification Deviations Register (`DEV-*`)

| ID | Deviation | Evidence | Disposition |
|----|-----------|----------|-------------|
| DEV-001 | ~~Core and decoder disjoint opcode maps.~~ **CLOSED** (DECISION-008). | `xcie_decoder.v` | CLOSED |
| DEV-002 | ~~POL_UPD unreachable.~~ **CLOSED**: decodes from custom-1. | `xcie_decoder.v` | CLOSED |
| DEV-003 | `xcew_status` (0x7C1) static in xcie_csr.v. | `xcie_csr.v:72` | Wire real status. |
| DEV-004 | CSRs 0x7CD/0x7CE/0x7CF not decoded at top. | absent in top | Implement or strike. |
| DEV-005 | ~~exception hardwired to 0.~~ **CLOSED** (DECISION-009). | `riscv_core.v` | CLOSED |
| DEV-006 | EXE_MEMO no completion wait (vestigial). | `xcie_ctrl.v:88` | Add handshake. |
| DEV-007 | No data-forwarding network. Flush resolved; no RAW hazard in single-issue in-order. | `riscv_core.v` | PARTIAL |
| DEV-008 | Top-level eml/snn/nvm IRQ sources tied 0. Core takes i_meip. | `xcew_top_v1_1.v` | PARTIAL |
| DEV-009 | ~~No trap CSRs.~~ **CLOSED** (DECISION-009). | `riscv_core.v` | CLOSED |
| DEV-010 | No per-domain reset synchronizer documented. | audit §3.2 | Produce RESET_ARCH.md. |
| DEV-011 | No CDC synchronizers for core↔SNN crossings. | `CDC_ANALYSIS.md` | Insert synchronizers. |
| DEV-012 | ~~if_pc off-by-4.~~ **CLOSED** (DECISION-009). | `riscv_core.v` | CLOSED |

---

## Sign-off

| Role | Name | Date | Status |
|------|------|------|--------|
| Author | _Pair A_ | 2026-05-23 | DRAFT |
| Updated | _automated_ | 2026-06-06 | REVIEWED — per-instruction semantics, reset sequence, CSR field detail added |
| Reviewer (not RTL author) | _pending_ | — | — |
| Team lead | Kiransekar | — | — |

Audit §1.1 PASS requires sign-off by the team lead and at least one engineer who
did not write the RTL for the reviewed block.
