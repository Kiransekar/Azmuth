#!/bin/bash
# Script to run OpenROAD P&R for NeuroRiscV
# This script provides both Docker and local execution options

echo "Starting OpenROAD Physical Implementation for Xcew Processor..."
echo "Current directory: $(pwd)"
echo "Checking for netlist file..."
if [ ! -f "syn/reports/xcew_netlist.v" ]; then
    echo "Error: Netlist file not found at syn/reports/xcew_netlist.v"
    exit 1
fi

echo "Netlist file exists. Checking for OpenROAD installation..."

# Check if OpenROAD is available locally
if command -v /home/kiran-sekar/OpenROAD/build/bin/openroad &> /dev/null; then
    OPENROAD_PATH="/home/kiran-sekar/OpenROAD/build/bin/openroad"
    echo "OpenROAD found locally: $OPENROAD_PATH"
    LOCAL_OPENROAD_AVAILABLE=1
else
    echo "Local OpenROAD not found or not in PATH"
    LOCAL_OPENROAD_AVAILABLE=0
fi

echo ""
echo "Two execution methods are available:"

echo ""
echo "METHOD 1: Using Docker (recommended for consistent results)"
echo "1. Pull the OpenROAD Docker image: docker pull openroad/orfs"
echo "2. Run the following command from the NeuroRiscV directory:"
echo ""
echo "   docker run --rm -v $(pwd):/work -w /work openroad/orfs bash -c \""
echo "   export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A"
echo "   export PDK=sky130A"
echo "   export STD_CELL_LIBRARY=sky130_fd_sc_hd"
echo "   export DESIGN_NAME=xcew_top_v1_1"
echo "   export FLOW_HOME=/OpenROAD-flow-scripts"
echo "   cd \$FLOW_HOME"
echo "   ./flow.tcl -design \$DESIGN_NAME -pdk \$PDK -flow_path /work/pnr"
echo "   \""

echo ""
echo "METHOD 2: Using Local OpenROAD Installation"
if [ $LOCAL_OPENROAD_AVAILABLE -eq 1 ]; then
    echo "OpenROAD is available locally at: $OPENROAD_PATH"
    echo "To run locally, execute from the pnr directory:"
    echo ""
    echo "   cd pnr && $OPENROAD_PATH openroad_flow.tcl"
    echo ""
    echo "Note: For local execution, you'll need to ensure SkyWater 130nm PDK is installed"
    echo "and environment variables are set appropriately."
else
    echo "Local OpenROAD installation not found. Install OpenROAD or use Docker method."
fi

echo ""
echo "The design netlist (syn/reports/xcew_netlist.v) is ready for P&R."
echo "Both methods will process the xcew_top_v1_1 design for the Xcew Processor."