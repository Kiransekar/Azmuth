#!/bin/bash
# Monitor script for NeuroRiscV P&R flow progress
echo "Monitoring NeuroRiscV P&R Flow Progress..."
echo "Timestamp: $(date)"

echo ""
echo "Checking for output directories..."
if [ -d "/home/kiran-sekar/NeuroRiscV/pnr/runs" ]; then
    echo "Found PNR runs directory:"
    find /home/kiran-sekar/NeuroRiscV/pnr/runs -type d | head -20
else
    echo "No PNR runs directory found yet"
fi

echo ""
echo "Checking OpenROAD container status..."
docker ps --filter ancestor=openroad/orfs

echo ""
echo "Looking for results in the working directory structure..."
find /home/kiran-sekar/NeuroRiscV -type f -name "*.gds" -o -name "*.def" -o -name "*.spef" | head -10

echo ""
echo "Checking for results in expected OpenROAD flow structure..."
if [ -d "/home/kiran-sekar/NeuroRiscV/results" ]; then
    echo "Results directory contents:"
    find /home/kiran-sekar/NeuroRiscV/results -name "*.gds" -o -name "*.def" -o -name "*.spef" -o -name "*timing*" | head -20
else
    echo "No results directory found yet. May be in the OpenROAD container's internal structure."
fi

echo ""
echo "Check for floorplan visualization:"
find /home/kiran-sekar/NeuroRiscV -name "*floorplan*" -o -name "*.svg" -o -name "*.png" | grep -E "(floor|placement|placement|fp)" | head -10

echo ""
echo "Monitoring completed."
echo "Current timestamp: $(date)"
echo ""
echo "To continue monitoring, you can run:"
echo "  watch -n 30 './monitor_progress.sh'"
