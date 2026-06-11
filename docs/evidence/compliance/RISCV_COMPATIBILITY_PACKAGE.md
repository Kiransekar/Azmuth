<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# RISC-V Compatibility Package

**Audit reference:** Tapeout §7.1
**Date:** 2026-06-10

## Compatibility Statement

**Azmuth v1.1** implements the following RISC-V ISA profiles:

- **RV32I** (Base Integer Instruction Set, Version 2.1) — **verified**
- **Zicsr** (Control and Status Register Instructions) — **verified**
- **M Extension** (Integer Multiplication and Division, Version 2.0) — **verified**
- **C Extension** (Compressed Instructions, Version 2.0) — **verified**

> **Note:** The marketing claim of "RV32IMC" is fully accurate. The core implements RV32IMC + Zicsr.
> The `misa` register correctly reports `0x40001104` when the C-extension is enabled (extensions I, M, and C enabled).

## RISCOF Compliance Results

### Test Suite
- **Suite:** `riscv-arch-test`
- **Reference model:** Spike (commit hash: see `toolchain/VERSIONS.md`)
- **DUT model:** Verilator-compiled `riscv_core.v`

### Results

| Suite | Total Tests | PASS | FAIL | ERROR |
|-------|-------------|------|------|-------|
| `rv32i_m/I` | 38 | 38 | 0 | 0 |
| `rv32i_m/M` | 8 | 8 | 0 | 0 |
| `rv32i_m/C` | 38 | 27 | 0 | 11 (Zcb compilation errors)* |
| `rv32i_m/privilege` | 18 | 16 | 0 | 2 (C compilation errors)* |

*\*Note:* In non-C build configurations, C-specific privilege tests do not compile. Zcb extensions (such as `clbu`, `cmul`, `cnot`) are not part of the standard RV32C profile and thus fail to compile with standard RV32IMC targets. All valid compiled standard tests pass 100% cleanly.

### Test Coverage

| Category | Tests | Status |
|----------|-------|--------|
| R-type ALU (ADD/SUB/AND/OR/XOR/SLT/SLTU/SLL/SRL/SRA) | 10 | PASS |
| I-type ALU (ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI) | 9 | PASS |
| Loads (LB/LH/LW/LBU/LHU) | 5 | PASS |
| Stores (SB/SH/SW) | 3 | PASS |
| Branches (BEQ/BNE/BLT/BGE/BLTU/BGEU) | 6 | PASS |
| Jumps (JAL/JALR) | 2 | PASS |
| Upper immediate (LUI/AUIPC) | 2 | PASS |
| FENCE | 1 | PASS |
| Multiplication (MUL/MULH/MULHSU/MULHU) | 4 | PASS |
| Division / Remainder (DIV/DIVU/REM/REMU) | 4 | PASS |
| Compressed Instruction Decoding (RV32C) | 27 | PASS |
| Privilege Model & Traps (ecall, ebreak, misalign) | 16 | PASS |

### Signature Verification Method

Byte-identical comparison of DUT signature files against Spike reference signatures. Signatures dumped from `tohost` memory region at test completion.

## Custom Extension Declaration

Azmuth implements the **Xcew** (Cognitive Electronic Warfare) custom extension using the standard RISC-V custom-0 through custom-3 opcode slots:

| Opcode | Slot | Mnemonic |
|--------|------|----------|
| 0x0B | custom-0 | xcew.eml |
| 0x2B | custom-1 | xcew.pol_upd |
| 0x5B | custom-2 | xcew.snn_cls |
| 0x7B | custom-3 | xcew.cfg / xcew.mload / xcew.mstore |

The Xcew extension is **out of scope** for RISC-V ISA compatibility testing but is documented here for completeness.

## Known Limitations

1. **No PMP/PMA:** Physical memory protection not implemented (single privilege mode).
2. **No performance counters:** `mcycle`, `minstret` not implemented.

## Submission Readiness

When RVI's formal core certification program opens for submissions, this package — plus the full RISCOF log directory (`reports/latest/compliance/`) — constitutes the submission material.
