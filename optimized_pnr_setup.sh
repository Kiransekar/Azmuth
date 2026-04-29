#!/bin/bash
# Optimized OpenROAD P&R flow for NeuroRiscV with resource allocation
# This script implements the suggested Docker command with CPU and memory limits

echo "Starting Optimized OpenROAD Physical Implementation for Xcew Processor..."
echo "Current directory: $(pwd)"

# Check if we have the required netlist file
if [ ! -f "syn/reports/xcew_netlist.v" ]; then
    echo "Error: Netlist file not found at syn/reports/xcew_netlist.v"
    echo "Please run synthesis first."
    exit 1
fi

echo "Netlist file exists. Preparing optimized Docker command..."

# Create the optimized Docker command
cat > run_optimized_pnr.sh << 'EOF'
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
EOF

chmod +x run_optimized_pnr.sh

echo "Optimized Docker command prepared:"
echo ""
echo "docker run --rm \\"
echo "  --cpus=8 --memory=32g \\"
echo "  -v $(pwd):/work -w /work \\"
echo "  openroad/orfs bash -c \""
echo "    export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A"
echo "    export PDK=sky130A"
echo "    export STD_CELL_LIBRARY=sky130_fd_sc_hd"
echo "    export DESIGN_NAME=xcew_top_v1_1"
echo "    cd /OpenROAD-flow-scripts"
echo "    ./flow.tcl -design \$DESIGN_NAME -pdk \$PDK -flow_path /work/pnr -threads 8"
echo "  \""
echo ""
echo "The command has been saved to run_optimized_pnr.sh"
echo ""
echo "To execute the P&R flow:"
echo "  1. Pull the OpenROAD Docker image: docker pull openroad/orfs"
echo "  2. Run: ./run_optimized_pnr.sh"
echo ""
echo "To monitor the process:"
echo "  Terminal 1: ./run_optimized_pnr.sh"
echo "  Terminal 2: docker stats \$(docker ps -q -f ancestor=openroad/orfs)"
echo "  Terminal 3: watch -n 5 'find pnr/ -name \"*.gds\" -o -name \"*.def\" 2>/dev/null | xargs ls -lh'"
echo ""
echo "Note: This command allocates 8 CPUs and 32GB of memory for optimal performance"
echo "of the Xcew Processor P&R flow."