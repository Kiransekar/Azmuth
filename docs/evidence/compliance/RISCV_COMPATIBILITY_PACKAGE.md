<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# RISC-V Compatibility Package

**Audit reference:** Tapeout §7.1
**Date:** 2026-06-06

## Compatibility Statement

**Azmuth v1.1** implements the following RISC-V ISA profiles:

- **RV32I** (Base Integer Instruction Set, Version 2.1) — **verified**
- **Zicsr** (Control and Status Register Instructions) — **verified**
- **M Extension** (Integer Multiplication and Division) — **not implemented**
- **C Extension** (Compressed Instructions) — **not implemented**

> **Note:** The marketing claim of "RV32IMC" is currently inaccurate. The core
> implements RV32I + Zicsr. M and C extensions are planned for a future revision.
> The `misa` register correctly reports `0x40000100` (I extension only).

## RISCOF Compliance Results

### Test Suite
- **Suite:** `riscv-arch-test` rv32i_m/I
- **Reference model:** Spike (commit hash: see `toolchain/VERSIONS.md`)
- **DUT model:** Verilator-compiled `riscv_core.v`

### Results
```
Total:  38
PASS:   38
FAIL:   0
ERROR:  0
```

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

### Signature Verification Method

Byte-identical comparison of DUT signature files against Spike reference
signatures. Signatures dumped from `tohost` memory region at test completion.

## Custom Extension Declaration

Azmuth implements the **Xcew** (Cognitive Electronic Warfare) custom extension
using the standard RISC-V custom-0 through custom-3 opcode slots:

| Opcode | Slot | Mnemonic |
|--------|------|----------|
| 0x0B | custom-0 | xcew.eml |
| 0x2B | custom-1 | xcew.pol_upd |
| 0x5B | custom-2 | xcew.snn_cls |
| 0x7B | custom-3 | xcew.cfg / xcew.mload / xcew.mstore |

The Xcew extension is **out of scope** for RISC-V ISA compatibility testing
but is documented here for completeness.

## Known Limitations

1. **No M extension:** Integer multiply/divide instructions (MUL/MULH/DIV/REM)
   are not implemented. Software multiply/divide must be used.
2. **No C extension:** Compressed 16-bit instructions are not decoded. All
   instructions must be 32-bit aligned.
3. **No PMP/PMA:** Physical memory protection not implemented (single privilege mode).
4. **No performance counters:** `mcycle`, `minstret` not implemented.
5. **misa reports I only:** The M and C bits are not set, accurately reflecting
   the current implementation state.

## Submission Readiness

When RVI's formal core certification program opens for submissions, this
package — plus the full RISCOF log directory (`reports/latest/compliance/`) —
constitutes the submission material.
