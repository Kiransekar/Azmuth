#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Synthesize xcew_top_v1_1 with Yosys. Default is the quick netlist
#             flow; pass "full" for the SDC/UPF-constrained flow.
# INPUTS:     rtl/ sources; syn/synth_final.tcl, syn/sdc_final.sdc, syn/upf_v1.1*.tcl (full).
# OUTPUTS:    syn/reports/xcew_netlist.v and synthesis reports.
# EXIT CODES: 0 = synthesis completed; nonzero = Yosys error.
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-quick}" in
  full) exec make synth_full ;;
  quick|*) exec make synth ;;
esac
