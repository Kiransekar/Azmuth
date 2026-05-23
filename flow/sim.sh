#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Run RTL simulations (Icarus Verilog). With no argument, runs the
#             full unit + integration set; with an argument, runs one target.
# INPUTS:     tb/*.v, rtl/ sources. Optional $1 = a sim target name
#             (core|eml|soc|top|snn_tile_256|cosim).
# OUTPUTS:    Per-testbench PASS/FAIL on stdout; *.vcd waveforms in repo dirs.
# EXIT CODES: 0 = all requested sims ran; nonzero = make/sim failure.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ge 1 ]; then
  exec make "sim_$1"
fi
make sim_core sim_decoder sim_trap sim_irq sim_hazard sim_eml sim_soc sim_top sim_snn_tile_256 sim_cosim
