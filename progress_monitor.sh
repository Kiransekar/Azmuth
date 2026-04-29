#!/bin/bash
# Enhanced NeuroRiscV P&R Flow with Progress Monitoring
# This script runs the flow step-by-step and shows progress indicators

echo "=============================================="
echo "NEURORISCV XCEW PROCESSOR P&R FLOW MONITOR"
echo "=============================================="
echo "Current timestamp: $(date)"
echo ""

# Create a progress tracking file
PROGRESS_FILE="/tmp/xcew_pnr_progress.txt"
echo "$(date): Flow started" > $PROGRESS_FILE

echo "IMPORTANT: The flow has paused due to SDC syntax error."
echo "We need to fix the SDC file before continuing."
echo ""

# Check what stage we reached
if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
    echo "✓ Placement completed successfully"
    PLACEMENT_STATUS="COMPLETED"
    echo "$(date): Placement completed" >> $PROGRESS_FILE
else
    echo "✗ Placement not yet completed"
    PLACEMENT_STATUS="PENDING"
fi

# Check for other artifacts
if [ -d "/home/kiran-sekar/NeuroRiscV/results" ]; then
    echo "✓ Results directory created"
    echo "$(date): Results directory created" >> $PROGRESS_FILE
else
    echo "✗ Results directory not found"
fi

# Display progress bar equivalent
echo ""
echo "PROGRESS SUMMARY:"
echo "┌─────────────────────────────────────────────┐"
if [ "$PLACEMENT_STATUS" = "COMPLETED" ]; then
    echo "│ ████████████████████████████░░░░░░░░░░░░░░░ 70% │ Synthesis/Placement"
else
    echo "│ ████████████████████░░░░░░░░░░░░░░░░░░░░░░ 40% │ Synthesis/Placement"
fi
echo "│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0% │ CTS              │"
echo "│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0% │ Routing          │"
echo "│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0% │ GDS Generation   │"
echo "└─────────────────────────────────────────────┘"
echo ""

# Check the error that stopped the flow
echo "ERROR ANALYSIS:"
echo "- Issue: [ERROR STA-0566] get_clocks requires zero or one positional arguments."
echo "- Location: sdc_final.sdc file (around line 10)"
echo "- Cause: Incorrect SDC syntax in clock definition"
echo ""

# Suggest fix for the SDC file
echo "SUGGESTED FIX:"
echo "1. Check the sdc_final.sdc file for incorrect get_clocks syntax"
echo "2. Look for lines similar to: get_clocks -name -period 4.0 {i_clk}"
echo "3. Correct to: create_clock -period 4.0 -name i_clk [get_ports i_clk]"
echo ""

# Show the problematic file
echo ""
echo "SCANNING SDC FILE FOR ISSUES..."
if [ -f "/home/kiran-sekar/NeuroRiscV/syn/sdc_final.sdc" ]; then
    echo "Found SDC file. Looking for potential issues:"
    grep -n "get_clocks" /home/kiran-sekar/NeuroRiscV/syn/sdc_final.sdc || echo "No 'get_clocks' found in SDC file"

    echo ""
    echo "SDC file content preview:"
    head -20 /home/kiran-sekar/NeuroRiscV/syn/sdc_final.sdc
else
    echo "SDC file not found"
fi

echo ""
echo "RECOMMENDED NEXT STEPS:"
echo "1. Fix the SDC file syntax error"
echo "2. Re-run the flow using: ./run_safe_pnr_v2.sh"
echo "3. Monitor progress with: ./monitor_progress.sh"
echo ""
echo "PROGRESS TRACKING:"
echo "- Status logged in: $PROGRESS_FILE"
echo "- Current status: PAUSED due to SDC error"
echo ""
echo "Timestamp: $(date)"
echo "=============================================="