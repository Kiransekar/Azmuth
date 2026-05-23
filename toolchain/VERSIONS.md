<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Toolchain Versions (locally provisioned)

Software audit §S0.2. Snapshot of the tools installed on the build host as of
2026-05-23. `source toolchain/env.sh` to put them on PATH. (Full reproducible
pinning via Docker — §S0.3 — is still TODO; this records the working set.)

## Verification / compliance (installed, in use)

| Component | Version | Location | Used for |
|-----------|---------|----------|----------|
| Icarus Verilog | (system) | `/usr/bin/iverilog` | unit/integration sim |
| Verilator | 5.047 devel | `/usr/local/bin/verilator` | lint, cosim |
| Yosys | (system) | `/usr/bin/yosys` | synthesis |
| SymbiYosys | (system) | `~/.local/bin/sby` | formal (harness WIP, §1.3c) |
| Spike | 1.1.1-dev | system | RISCOF reference model |
| Sail RISC-V | present | system | RISCOF alt reference |
| riscof | 1.25.3 | `~/.venvs/azmuth/bin/riscof` | §2.4 compliance |
| riscv-config | 3.18.3 | venv | riscof dep |
| riscv-isac | 0.18.0 | venv | riscof dep |
| riscv-arch-test | ctp-release `281d71e` (2025-12-28) | `~/azmuth-deps` | §2.4 test suite |
| riscv64-unknown-elf-gcc | 13 (cross) | `/usr/bin` | firmware/test assembly |
| binutils (objcopy/as/objdump) | linux-gnu prefix | `/usr/bin/riscv64-linux-gnu-*` | extract/objcopy |

## Physical design (NOT installed — deferred to §5–6 PnR phase)

OpenROAD, OpenLane, Magic, KLayout, Netgen are not installed. They are available
via the **`openroad/orfs` Docker image** (`docker` IS present) and pulled when
PnR work begins (`flow/pnr.sh`). No need to pull the multi-GB image before then.

## Notes
- `riscof` is in a venv because system Python 3.12 is PEP-668 externally managed.
- `objcopy` is only present under the `riscv64-linux-gnu-` prefix (the elf-prefix
  package ships gcc + objdump but not objcopy/as); `tools/asm-to-hex.sh` uses
  gcc + objdump and so does not need objcopy.
