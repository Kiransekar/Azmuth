#!/bin/bash
# Real-time Progress Tracker for NeuroRiscV P&R Flow
# Monitors the flow with a status bar and real-time updates

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    NEURORISCV REAL-TIME P&R MONITOR              ║"
echo "╠════════════════════════════════════════════════════════════════════╣"

# Determine progress based on files
if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
    completed=3
    progress_desc="PLACEMENT COMPLETED - Waiting for CTS"
else
    completed=0
    progress_desc="INITIALIZING"
fi

percentage=$((completed * 100 / 6))

echo -n "║ PROGRESS: ["
bars=$((percentage * 25 / 100))
for ((i=0; i<bars; i++)); do
    echo -n "█"
done
for ((i=0; i<25-bars; i++)); do
    echo -n "░"
done
printf "] %3d%% %-15s ║\n" $percentage ""

echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║ CURRENT STAGE: $progress_desc"
printf '║%68s║\n' | tr ' ' ' '
echo -n "║ ACTIVE CONTAINERS: "
if [ -n "$(docker ps --filter ancestor=openroad/orfs --format '{{.Names}}' 2>/dev/null)" ]; then
    container=$(docker ps --filter ancestor=openroad/orfs --format '{{.Names}}' 2>/dev/null)
    echo -n "YES ($container)"
else
    echo -n "NO"
fi
printf '%28s║\n' | tr ' ' ' '

echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║ OUTPUT FILES:                                                     ║"
if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
    size=$(ls -sh "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_placed.def" | awk '{print $1}')
    echo "║   • xcew_placed.def ($size) ✓                                   ║"
else
    echo "║   • xcew_placed.def - PENDING                                   ║"
fi

if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_cts.def" ]; then
    size=$(ls -sh "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_cts.def" | awk '{print $1}')
    echo "║   • xcew_cts.def ($size) ✓                                      ║"
else
    echo "║   • xcew_cts.def - PENDING                                      ║"
fi

if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_routed.def" ]; then
    size=$(ls -sh "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_routed.def" | awk '{print $1}')
    echo "║   • xcew_routed.def ($size) ✓                                   ║"
else
    echo "║   • xcew_routed.def - PENDING                                   ║"
fi

if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_final.gds" ]; then
    size=$(ls -sh "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_final.gds" | awk '{print $1}')
    echo "║   • xcew_final.gds ($size) ✓                                    ║"
else
    echo "║   • xcew_final.gds - PENDING                                    ║"
fi

echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║ MONITORING COMMANDS:                                              ║"
echo "║   • Live tracking: watch -n 10 './live_tracker.sh'               ║"
echo "║   • Status check: ./status_tracker.sh                             ║"
echo "║   • Container stats: docker stats [container_name]                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"

echo ""
echo "Last updated: $(date)"
echo ""
echo "PROGRESS SUMMARY:"
echo "Stages completed: $completed/6 ($percentage%)"
echo "Next expected: Clock Tree Synthesis (CTS)"