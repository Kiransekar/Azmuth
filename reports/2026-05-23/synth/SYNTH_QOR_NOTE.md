<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Synthesis QoR Note — 2026-05-23

Repo commit `96a282a` (+ working-tree fixes). Tool: Yosys (generic, no PDK lib).
Relates to tapeout audit §5.1 (area estimate).

## Result: flat synthesis does not converge

`make synth` (`synth -top xcew_top_v1_1 -flatten`) was run with a 300 s timeout
and **did not complete**. The frontend parsed all modules successfully, but the
flow stalls when Yosys expands `nvm_ctrl`'s internal arrays:

```
17. Executing Verilog-2005 frontend: rtl/nvm/nvm_ctrl.v
Warning: Replacing memory \ecc_meta  with list of registers. See rtl/nvm/nvm_ctrl.v:149
Warning: Replacing memory \mem_array with list of registers. See rtl/nvm/nvm_ctrl.v:148
make: *** [Makefile:168: synth] Terminated
```

`mem_array` is the 65536-entry × 32-bit internal ReRAM model. With `-flatten`
and no memory inference target, Yosys lowers it to discrete registers
(~2 M flops), which makes `proc/opt/techmap` intractable in bounded time. This
matches the historical "45-minute synthesis freeze" referenced in the legacy
PnR scripts.

## Interpretation — empirically validates DECISION-005 Lever L1

The internal 64 KB NVM macro is the synthesis bottleneck. **Moving NVM to an
external QSPI device (DECISION-005 / audit §1.5.1) removes ~65k memory entries
from the synthesizable netlist** and is therefore not only an area lever but a
synthesis-tractability requirement. This is independent evidence for L1 beyond
the area-budget argument.

## Recommended next steps (to actually obtain a §5.1 area number)

1. Land §1.5.1 (external QSPI NVM) so `mem_array` leaves the netlist; OR
2. Interim: synthesize with the NVM as a black-box (`blackbox nvm_ctrl`) or keep
   memories (`memory -nomap` / `memory_bram`) to get a cell count for the rest
   of the design, and size the NVM macro separately from a memory compiler; OR
3. Run with a much larger timeout on a machine with adequate RAM (not advised —
   the register-lowered form is not representative of real silicon, which uses a
   memory macro).

§5.1 remains **OPEN** pending one of the above.
