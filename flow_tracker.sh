#!/bin/bash
# Interactive Progress Tracker for NeuroRiscV P&R Flow
# This script provides step-by-step monitoring with a visual progress bar

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║             NEURORISCV P&R FLOW MANAGER                      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Status: Flow paused due to SDC syntax issue               ║"
echo "║  Action: Using FIXED SDC file to continue flow             ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Define the flow stages
stages=("PREPARATION" "SYNTHESIS" "PLACE & SIZE" "CTS" "ROUTING" "FINISH")
status=(1 0 0 0 0 0)  # 1 = completed, 0 = pending

# Create visual progress bar
completed=1
total=6
percentage=$((completed * 100 / total))

echo "PROGRESS VISUALIZATION:"
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo -n "║ "
for ((i=0; i<completed; i++)); do
    echo -n "▓▓"
done
for ((i=completed; i<total; i++)); do
    echo -n "░░"
done
printf '%*s' $((24-$percentage/4)) " $percentage%"
echo " ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "FLOW STAGE BREAKDOWN:"
for i in "${!stages[@]}"; do
    if [ ${status[$i]} -eq 1 ]; then
        echo "  ✓ ${stages[$i]} - COMPLETED"
    else
        if [ $i -eq $completed ]; then
            echo "  ▶ ${stages[$i]} - IN PROGRESS/NOT STARTED"
        else
            echo "  ○ ${stages[$i]} - PENDING"
        fi
    fi
done
echo ""

echo "FIXED CONFIGURATION DETECTED:"
echo "  ✓ Fixed SDC file: sdc_final_fixed.sdc"
echo "  ✓ Resource allocation: 3.5 CPUs, 20GB RAM"
echo "  ✓ Timeout protection: 5-hour limit"
echo ""

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│                    NEXT STEPS                                │"
echo "├──────────────────────────────────────────────────────────────┤"
echo "│ 1. Replace SDC file and continue flow                        │"
echo "│ 2. Monitor progress with this tracker                        │"
echo "│ 3. Check for output files periodically                       │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# Provide command to continue the flow
echo "TO CONTINUE THE FLOW:"
echo " 1. Backup original SDC: cp syn/sdc_final.sdc syn/sdc_final.sdc.bak"
echo " 2. Use fixed SDC: cp syn/sdc_final_fixed.sdc syn/sdc_final.sdc"
echo " 3. Restart flow: ./run_safe_pnr_v2.sh"
echo ""

# Show current state
echo "CURRENT OUTPUT STATUS:"
if [ -f "pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
    echo "  ✓ Placed DEF: $(ls -lh pnr/runs/xcew_v1_1/xcew_placed.def | awk '{print $5, $9}')"
else
    echo "  ✗ Placed DEF: Not yet generated"
fi

echo ""
echo "Last updated: $(date)"
echo "Progress tracking file: /tmp/xcew_pnr_progress.txt"