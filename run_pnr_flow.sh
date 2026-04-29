#!/bin/bash
# Script to run OpenROAD P&R for NeuroRiscV
# This script should be run from the NeuroRiscV directory

echo "Starting OpenROAD Physical Implementation for Xcew Processor..."
echo "Current directory: $(pwd)"
echo "Contents of syn/reports/:"
ls -la syn/reports/

# Check if we have the required netlist file
if [ ! -f "syn/reports/xcew_netlist.v" ]; then
    echo "Error: Netlist file not found at syn/reports/xcew_netlist.v"
    exit 1
fi

echo "Netlist file exists. Proceeding with Docker command..."

# The command to run OpenROAD with SkyWater 130nm PDK
docker_cmd="docker run --rm -v $(pwd):/work -w /work openroad/orfs bash -c \"
export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A
export PDK=sky130A
export STD_CELL_LIBRARY=sky130_fd_sc_hd
export DESIGN_NAME=xcew_top_v1_1
export FLOW_HOME=/OpenROAD-flow-scripts
cd \$FLOW_HOME
./flow.tcl -design \$DESIGN_NAME -pdk \$PDK -flow_path /work/pnr
\""

echo "Docker command prepared:"
echo "$docker_cmd"

# Save the command to a file for execution
echo "$docker_cmd" > run_openroad.sh
chmod +x run_openroad.sh

echo "Docker command saved to run_openroad.sh"
echo "To execute the P&R flow, run: ./run_openroad.sh"
echo ""
echo "Note: This requires Docker to be installed and the openroad/orfs image pulled with:"
echo "  docker pull openroad/orfs"
echo ""
echo "If Docker is not available, you can alternatively run the flow directly in an OpenROAD environment with:"
echo "  cd pnr && openroad openroad_flow.tcl"