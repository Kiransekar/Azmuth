#!/bin/bash
# Monitoring script for OpenROAD P&R flow
# This script provides various ways to monitor the progress of the P&R flow

echo "OpenROAD P&R Flow Monitoring Script"
echo "==================================="
echo ""

# Check if the required directories exist
if [ ! -d "pnr" ]; then
    echo "Error: pnr directory not found. Make sure you are in the NeuroRiscV directory."
    exit 1
fi

echo "Monitoring options for the Xcew Processor P&R flow:"
echo ""
echo "1. Container monitoring (when running in Docker):"
echo "   docker stats \$(docker ps -q -f ancestor=openroad/orfs)"
echo ""
echo "2. Log monitoring (when synthesis is running):"
echo "   # Check Yosys log for progress markers:"
echo "   tail -f logs/synth.log | grep -E \"Execut|Finished|ERROR\""
echo ""
echo "3. PNR log monitoring (when PNR flow is running):"
echo "   # Check OpenROAD log for stage transitions:"
echo "   tail -f logs/pnr.log | grep -E \"Running|Finished|ERROR\""
echo ""
echo "4. Disk usage monitoring:"
echo "   # Check GDSII growth during routing:"
echo "   watch -n 5 'ls -lh pnr/ 2>/dev/null || echo \"Waiting for pnr results\"'"
echo ""
echo "5. Alternative disk usage check:"
echo "   watch -n 10 'find . -name \"*.gds\" -o -name \"*.def\" -o -name \"*.spef\" 2>/dev/null | xargs ls -lh'"
echo ""
echo "6. Process monitoring:"
echo "   # Monitor running processes:"
echo "   watch -n 2 'ps aux | grep -E \"openroad|yosys|docker\"'"
echo ""
echo "Note: These commands should be run in separate terminals while the P&R flow"
echo "is executing. Make sure to run the P&R flow first using one of these methods:"
echo ""
echo "Docker method:"
echo "  docker run --rm -v \$(pwd):/work -w /work openroad/orfs bash -c \\"
echo "  \"export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A; \\"
echo "   export PDK=sky130A; \\"
echo "   export STD_CELL_LIBRARY=sky130_fd_sc_hd; \\"
echo "   export DESIGN_NAME=xcew_top_v1_1; \\"
echo "   export FLOW_HOME=/OpenROAD-flow-scripts; \\"
echo "   cd \\\$FLOW_HOME; \\"
echo "   ./flow.tcl -design \\\$DESIGN_NAME -pdk \\\$PDK -flow_path /work/pnr\\\""
echo ""
echo "Local method (if OpenROAD is installed):"
echo "  cd pnr && /home/kiran-sekar/OpenROAD/build/bin/openroad openroad_flow.tcl"