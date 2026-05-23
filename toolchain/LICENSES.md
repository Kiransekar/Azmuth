<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Toolchain License Inventory

Software audit §S0.4. Records the license of every external toolchain component
Azmuth depends on or patches, so an adopter can assess obligations. Azmuth's own
contributions (e.g. `toolchain/XcewOptPass.cpp`) are proprietary per
`../LICENSE` (DECISION-007).

## Project-authored toolchain contributions

| File | Purpose | License |
|------|---------|---------|
| `XcewOptPass.cpp` | LLVM MachineFunctionPass: CSE + Xcew DAG emission | Proprietary (`LicenseRef-Azmuth-Proprietary`) |

> When patches are added (audit §S1), each upstream component gets a subdirectory
> with `patches/`, `upstream.txt` (pinned SHA), and `build.sh` per §S0.1. The
> patches inherit the upstream license below; only original new files carry the
> proprietary header.

## Upstream components (status: not yet vendored)

| Component | Role | Upstream license | Adopter-link concern? |
|-----------|------|------------------|------------------------|
| LLVM / Clang | Primary compiler (DECISION-003) | Apache-2.0 WITH LLVM-exception | No (permissive) |
| GCC | Secondary compiler | GPL-3.0 + GCC Runtime Library Exception | Runtime exception avoids contaminating linked output |
| binutils | Assembler/linker (`.insn`, Xcew mnemonics) | GPL-3.0 | Tooling only; not linked into adopter firmware |
| picolibc | C library (preferred over newlib) | BSD-3-Clause / MIT | No |
| newlib | Alt C library | Mixed BSD / GPL | Preferred to avoid; picolibc chosen |
| compiler-rt / libgcc | Soft-float runtime | Apache-2.0-exc / GPL-3-exc | Exception preserves proprietary linking |
| OpenOCD | Debug adapter | GPL-2.0-or-later | Host tool only |
| Yosys | Synthesis | ISC | No |
| OpenROAD / ORFS | PnR | BSD-3-Clause | No |
| Verilator | Lint / cosim | LGPL-3.0 / Artistic-2.0 | Dynamic-link / generated-code terms apply |
| Icarus Verilog | Simulation | GPL-2.0 | Tool only |
| SymbiYosys | Formal | ISC / MIT | No |

**Conclusion:** No AGPL or copyleft contamination on any path an adopter links
*against* in produced firmware (soft-float runtimes carry linking exceptions;
GPL items are host tools). picolibc is the chosen libc partly for its clean
BSD/MIT license. Pin exact SHAs and revisit on every toolchain bump (§S0.2).
