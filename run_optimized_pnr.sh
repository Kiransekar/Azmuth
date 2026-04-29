#!/bin/bash
docker run --rm \
  --cpus=8 --memory=32g \
  -v $(pwd):/work -w /work \
  openroad/orfs bash -c "
    export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A
    export PDK=sky130A
    export STD_CELL_LIBRARY=sky130_fd_sc_hd
    export DESIGN_NAME=xcew_top_v1_1
    cd /OpenROAD-flow-scripts
    ./flow.tcl -design $DESIGN_NAME -pdk $PDK -flow_path /work/pnr -threads 8
  "
