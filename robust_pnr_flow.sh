#!/bin/bash
# Robust NeuroRiscV P&R Flow with Monitoring and Safety Measures
# Addresses potential freezes during synthesis by implementing timeouts and proper resource management

echo "Robust NeuroRiscV P&R Flow - GDSII, Routing and Floorplanning"
echo "============================================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if [ ! -f "syn/reports/xcew_netlist.v" ]; then
    echo "Error: Gate-level netlist not found at syn/reports/xcew_netlist.v"
    echo "Please ensure synthesis has been completed successfully."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

echo "✓ Prerequisites OK"
echo ""

echo "SAFETY MEASURES IMPLEMENTED:"
echo "============================"
echo "1. Synthesis is already completed (avoiding the 45-minute freeze issue)"
echo "2. Timeout protection will be applied to prevent hanging"
echo "3. Resource limits will prevent system overload"
echo "4. Monitoring will track progress in real-time"
echo ""

echo "EXECUTION COMMAND (with safety measures):"
echo "========================================="
echo "docker run --rm \\"
echo "  --cpus=6 --memory=24g --memory-swap=32g \\"
echo "  -v \$(pwd):/work -w /work \\"
echo "  --ulimit nofile=1024:1024 \\"
echo "  openroad/orfs bash -c \""
echo "    export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A"
echo "    export PDK=sky130A"
echo "    export STD_CELL_LIBRARY=sky130_fd_sc_hd"
echo "    export DESIGN_NAME=xcew_top_v1_1"
echo "    export FLOW_CONTROL_MAX_CORES=6"
echo "    export FLOW_CONTROL_MAX_MEM=24G"
echo "    cd /OpenROAD-flow-scripts"
echo "    timeout 18000 ./flow.tcl -design \$DESIGN_NAME -pdk \$PDK -flow_path /work/pnr -threads 6"
echo "  \""
echo ""

# Create the actual execution script with timeout
cat > run_safe_pnr.sh << 'EOF'
#!/bin/bash
echo "Starting safe P&R flow for NeuroRiscV Xcew Processor..."
echo "Timestamp: $(date)"
echo "This may take 2-4 hours depending on design complexity..."

# Run with timeout to prevent infinite hangs
timeout 18000 docker run --rm \
  --cpus=6 --memory=24g --memory-swap=32g \
  -v $(pwd):/work -w /work \
  --ulimit nofile=1024:1024 \
  openroad/orfs bash -c "
    export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A
    export PDK=sky130A
    export STD_CELL_LIBRARY=sky130_fd_sc_hd
    export DESIGN_NAME=xcew_top_v1_1
    export FLOW_CONTROL_MAX_CORES=6
    export FLOW_CONTROL_MAX_MEM=24G
    cd /OpenROAD-flow-scripts
    ./flow.tcl -design \$DESIGN_NAME -pdk \$PDK -flow_path /work/pnr -threads 6
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
EOF

chmod +x run_safe_pnr.sh

echo "MONITORING COMMANDS:"
echo "==================="
echo "Terminal 1: ./run_safe_pnr.sh  # Run the flow"
echo ""
echo "Terminal 2: docker stats \$(docker ps -q --filter ancestor=openroad/orfs)  # Resource usage"
echo ""
echo "Terminal 3: watch -n 10 'ls -lh pnr/ 2>/dev/null | grep -E \"\\.def|\\.gds|\\.spef\" || echo \"Waiting for output files...\"'"
echo ""
echo "Terminal 4: tail -f logs/pnr.log | grep -E \"Running|Finished|ERROR|DRC|LVS|Placement|Route\"  # Progress"
echo ""
echo "Terminal 5: docker exec \$(docker ps -q --filter ancestor=openroad/orfs) ps aux | grep -E \"openroad|yosys|magic\" | grep -v grep  # Health check"
echo ""

# Create a status monitoring script
cat > monitor_progress.sh << 'EOF'
#!/bin/bash
echo "Monitoring P&R progress for NeuroRiscV Xcew Processor..."
echo "Starting timestamp: $(date)"

while true; do
    if [ -n "$(docker ps -q --filter ancestor=openroad/orfs)" ]; then
        echo "[$(date)] OpenROAD container is running"

        # Check container stats
        if [ -n "$(docker ps -q --filter ancestor=openroad/orfs)" ]; then
            STATS=$(docker stats --no-stream $(docker ps -q --filter ancestor=openroad/orfs) 2>/dev/null | tail -n +2)
            echo "Container stats: $STATS"
        fi

        # Check for output files
        if [ -d "pnr/runs" ]; then
            echo "Output files generated:"
            find pnr/runs -name "*.gds" -o -name "*.def" -o -name "*.spef" -o -name "*.v" 2>/dev/null | xargs ls -lh
        fi

        # Check log files if they exist
        if [ -f "pnr/runs/*/logs/*" ]; then
            echo "Recent log entries:"
            find pnr/runs -name "*.log" -exec tail -n 5 {} \; 2>/dev/null | head -20
        fi
    else
        echo "[$(date)] No OpenROAD container found - flow may be complete or failed"
        break
    fi

    sleep 60  # Wait 1 minute before next check
done

echo "Final status check:"
echo "GDS files: $(find pnr/ -name "*.gds" 2>/dev/null | wc -l)"
echo "DEF files: $(find pnr/ -name "*.def" 2>/dev/null | wc -l)"
echo "SPEF files: $(find pnr/ -name "*.spef" 2>/dev/null | wc -l)"
echo "Timing reports: $(find pnr/ -name "*timing*" -o -name "*sdf*" 2>/dev/null | wc -l)"
echo "Final timestamp: $(date)"
EOF

chmod +x monitor_progress.sh

echo "ADDITIONAL SAFETY FEATURES:"
echo "==========================="
echo "- Timeout set to 5 hours (18000 seconds) to prevent infinite hangs"
echo "- Reduced resource allocation (6 CPUs, 24GB RAM) to prevent system overload"
echo "- ULIMIT restrictions to prevent file descriptor exhaustion"
echo "- Memory swap limits to prevent system thrashing"
echo "- Dedicated monitoring script to track progress safely"
echo ""

echo "TO RUN THE SAFE P&R FLOW:"
echo "========================="
echo "1. Pull the Docker image: docker pull openroad/orfs"
echo "2. Run the flow: ./run_safe_pnr.sh"
echo "3. Monitor in parallel: ./monitor_progress.sh"
echo "4. Track progress: Use the terminal commands shown above"
echo ""
echo "EXPECTED RESULTS:"
echo "After completion, you will have:"
echo "- GDSII file for manufacturing (pnr/runs/*/results/final/gds_*.gds)"
echo "- Routing DEF file (pnr/runs/*/results/final/def_*.def)"
echo "- Floorplan information (in various report files)"
echo "- Timing reports (pnr/runs/*/reports/timing/*)"
echo "- DRC/LVS verification results"
echo ""
echo "The safe flow avoids the synthesis step since it's already completed, focusing only on P&R."
echo "This should complete in 2-4 hours instead of getting stuck in synthesis like before."