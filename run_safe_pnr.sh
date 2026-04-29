#!/bin/bash
echo "Starting safe P&R flow for NeuroRiscV Xcew Processor..."
echo "Timestamp: $(date)"
echo "This may take 2-4 hours depending on design complexity..."

# Run with timeout to prevent infinite hangs
timeout 18000 docker run --rm \
  --cpus=3.5 --memory=20g --memory-swap=24g \
  -v $(pwd):/work -w /work \
  --ulimit nofile=1024:1024 \
  openroad/orfs bash -c "
    export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A
    export PDK=sky130A
    export STD_CELL_LIBRARY=sky130_fd_sc_hd
    export DESIGN_NAME=xcew_top_v1_1
    export FLOW_CONTROL_MAX_CORES=3
    export FLOW_CONTROL_MAX_MEM=20G
    cd /OpenROAD-flow-scripts
    ./flow.tcl -design \$DESIGN_NAME -pdk \$PDK -flow_path /work/pnr -threads 3
  "

RESULT=$?
if [ $RESULT -eq 124 ]; then
    echo "ERROR: P&R flow timed out after 5 hours (18000 seconds)"
    echo "This indicates a potential hang in the flow"
elif [ $RESULT -ne 0 ]; then
    echo "ERROR: P&R flow failed with exit code $RESULT"
else
    echo "SUCCESS: P&R flow completed successfully"
fi
echo "Timestamp: $(date)"
exit $RESULT
