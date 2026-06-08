<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Compliance run provenance — RISC-V arch-test (audit §2.4)

- **Date:** 2026-05-24
- **Base commit:** 36a7dbe (+ working-tree fixes BUG-035/036 and harness changes)
- **Command:** `source toolchain/env.sh && bash flow/compliance_archtest.sh rv32i_m/I`
- **Result:** `rv32i_m/I` — **PASS=38 FAIL=0 ERROR=0** (byte-identical to Spike)

## Toolchain

| Tool | Version | Role |
|------|---------|------|
| Spike | 1.1.1-dev | reference (golden) model |
| riscv64-unknown-elf-gcc | 13.3.0 | assemble/link tests |
| Icarus Verilog (iverilog/vvp) | 12.0 | Azmuth DUT simulation |
| riscv64-linux-gnu-objcopy | (binutils 2.42) | ELF → flat binary |

## Method

Differential: each `*.S` is assembled with `-march=rv32i_zicsr -mabi=ilp32
-mcmodel=medany -fno-pic -Wl,--build-id=none` against `toolchain/riscof/azmuth/env`
(`link.ld`, `model_test.h`), run on Spike (`+signature`) and on the Azmuth core via
`tb/riscof/azmuth_riscof_tb.v` (tohost-halt + signature dump), and the two signatures
are diffed. `*.signature` files in this directory are the DUT outputs that matched the
reference.

## What this run unblocked vs. the prior 24/4/10 state

- Core fixes: BUG-035 (SB/SH byte-lane), BUG-036 (sub-word load extract+extend).
- Harness fixes: `-fno-pic -Wl,--build-id=none` (entry lands at 0x80000000 = DUT
  reset = Spike `--pc`; also lets `jalr`/load-`*-align` assemble); DUT memory grown
  to 4 MB so `jal-01`'s ~1.7 MB-high signature/tohost no longer wrap.

Note: covers the base integer set (`I`). M/C/Zicsr-privilege suites are future work
(C-extension decode and a broader privileged campaign remain open per §2.4 scope).
