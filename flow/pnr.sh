#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Run OpenROAD place-and-route for xcew_top_v1_1 (SKY130A). Uses the
#             dockerized openroad/orfs flow with resource limits and a timeout;
#             falls back to a local OpenROAD install if Docker is unavailable.
#             Consolidates run_pnr_flow.sh / run_safe_pnr*.sh / robust_pnr_flow.sh /
#             check_and_run_pnr.sh / run_openroad.sh.
# INPUTS:     syn/reports/xcew_netlist.v (run flow/synth.sh first); pnr/ scripts.
# OUTPUTS:    pnr/runs/*/results (DEF/GDS/SPEF), timing/DRC/LVS reports.
# EXIT CODES: 0 = flow completed; 124 = timed out; other = flow error.
set -euo pipefail
cd "$(dirname "$0")/.."

NETLIST="syn/reports/xcew_netlist.v"
TIMEOUT="${PNR_TIMEOUT:-18000}"          # 5h cap to avoid silent hangs
CPUS="${PNR_CPUS:-6}"
MEM="${PNR_MEM:-24g}"

if [ ! -f "$NETLIST" ]; then
  echo "ERROR: $NETLIST not found. Run 'flow/synth.sh' first."
  exit 1
fi

if command -v docker >/dev/null 2>&1; then
  echo "== flow/pnr: dockerized OpenROAD (cpus=$CPUS mem=$MEM timeout=${TIMEOUT}s) =="
  timeout "$TIMEOUT" docker run --rm \
    --cpus="$CPUS" --memory="$MEM" --memory-swap="$MEM" \
    --ulimit nofile=1024:1024 \
    -v "$(pwd)":/work -w /work \
    openroad/orfs bash -c '
      export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A
      export PDK=sky130A
      export STD_CELL_LIBRARY=sky130_fd_sc_hd
      export DESIGN_NAME=xcew_top_v1_1
      cd /OpenROAD-flow-scripts
      ./flow.tcl -design "$DESIGN_NAME" -pdk "$PDK" -flow_path /work/pnr -threads '"$CPUS"'
    '
  rc=$?
elif command -v openroad >/dev/null 2>&1; then
  echo "== flow/pnr: local OpenROAD (pnr/openroad_flow.tcl) =="
  ( cd pnr && timeout "$TIMEOUT" openroad openroad_flow.tcl ); rc=$?
else
  echo "ERROR: neither Docker nor a local 'openroad' found."
  echo "  Docker:  docker pull openroad/orfs"
  echo "  Local:   build OpenROAD and re-run."
  exit 1
fi

[ "$rc" -eq 124 ] && echo "ERROR: PnR timed out after ${TIMEOUT}s (possible hang)."
exit "$rc"
