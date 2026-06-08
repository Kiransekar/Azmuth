<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# ABI Compliance Statement

**Audit reference:** Software §S7.4
**Date:** 2026-06-06

## Target ABI

Azmuth follows the **RISC-V psABI** (Processor Supplement to the System V ABI)
for ILP32 (RV32):

- **ABI name:** `ilp32` (soft-float; no F/D extension)
- **Data model:** ILP32 (int=32, long=32, pointer=32)
- **Endianness:** Little-endian
- **Stack alignment:** 16-byte aligned at function entry (per psABI §2.1)

## Calling Convention

| Register | ABI Name | Role | Saver |
|----------|----------|------|-------|
| x0 | zero | Hardwired zero | — |
| x1 | ra | Return address | Caller |
| x2 | sp | Stack pointer | Callee |
| x3 | gp | Global pointer | — |
| x4 | tp | Thread pointer | — |
| x5–x7 | t0–t2 | Temporaries | Caller |
| x8 | s0/fp | Saved / frame pointer | Callee |
| x9 | s1 | Saved register | Callee |
| x10–x11 | a0–a1 | Arguments / return values | Caller |
| x12–x17 | a2–a7 | Arguments | Caller |
| x18–x27 | s2–s11 | Saved registers | Callee |
| x28–x31 | t3–t6 | Temporaries | Caller |

## Xcew Extension ABI

Xcew custom instructions follow standard R-type register usage:
- **Input registers (rs1, rs2):** caller-saved; the caller must ensure valid
  values before issuing an Xcew instruction
- **Output register (rd):** written by the Xcew hardware; follows normal
  writeback path
- **CSR side-effects:** Xcew instructions may read/modify custom CSRs
  (0x7C0–0x7CF) as documented in the programming model

No additional callee-saved state is introduced by Xcew. The trap handler
(`firmware/trap_handler.S`) saves only caller-saved registers, which is
sufficient because Xcew instructions are blocking (no async state change).

## Compiler Flags

Recommended compilation flags for Azmuth:

```
-march=rv32i -mabi=ilp32 -mcmodel=medlow -fno-pic
-Wl,--build-id=none -nostdlib
```

- `-march=rv32i`: base integer only (M/C not yet verified)
- `-mabi=ilp32`: soft-float ABI
- `-mcmodel=medlow`: addresses within ±2GB of zero (appropriate for 20KB address space)
- `-fno-pic`: no position-independent code (fixed ROM/SRAM layout)
- `-Wl,--build-id=none`: prevent GNU build-id note from occupying reset vector

## Struct Layout & Alignment

Per the RISC-V psABI, structs are naturally aligned:
- `char`: 1-byte aligned
- `short`: 2-byte aligned
- `int`, `long`, pointers: 4-byte aligned
- `long long`: 8-byte aligned (split across two registers for function args)

## Verification

ABI compliance is verified by:
1. RISCOF arch-tests pass with standard GCC-compiled test programs (§2.4)
2. Trap handler correctly saves/restores caller-saved registers (§S2.5)
3. crt0 sets up sp with 16-byte alignment (§S2.4)
4. Linker scripts produce correctly-sectioned ELF output (§S2.3)
