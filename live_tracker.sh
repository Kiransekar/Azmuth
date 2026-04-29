#!/bin/bash
# Continuous Progress Tracker for NeuroRiscV P&R Flow
# Monitors the flow in real-time with visual indicators

TRACKING_FILE="/tmp/xcew_pnr_tracking.txt"

show_progress() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                  NEURORISCV P&R LIVE TRACKER                    ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"

    # Determine current progress based on generated files
    PREPARATION=1
    SYNTHESIS=0
    PLACEMENT=0
    CTS=0
    ROUTING=0
    FINISH=0

    if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
        SYNTHESIS=1
        PLACEMENT=1
    fi

    if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_cts.def" ]; then
        CTS=1
    fi

    if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_routed.def" ]; then
        ROUTING=1
    fi

    if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_final.gds" ]; then
        FINISH=1
    fi

    # Calculate percentage
    completed=0
    if [ $PREPARATION -eq 1 ]; then ((completed++)); fi
    if [ $SYNTHESIS -eq 1 ]; then ((completed++)); fi
    if [ $PLACEMENT -eq 1 ]; then ((completed++)); fi
    if [ $CTS -eq 1 ]; then ((completed++)); fi
    if [ $ROUTING -eq 1 ]; then ((completed++)); fi
    if [ $FINISH -eq 1 ]; then ((completed++)); fi

    percentage=$((completed * 100 / 6))

    # Visual progress bar
    echo -n "║ "
    filled=$((percentage / 4))
    for ((i=0; i<filled; i++)); do
        echo -n "█"
    done
    for ((i=filled; i<25; i++)); do
        echo -n "░"
    done
    printf ' %3d%% ║\n' $percentage

    echo "╠══════════════════════════════════════════════════════════════════╣"

    # Stage indicators
    if [ $PREPARATION -eq 1 ]; then echo "║ ✓ PREPARATION ........................................ COMPLETED ║"; else echo "║ ○ PREPARATION ........................................ PENDING   ║"; fi
    if [ $SYNTHESIS -eq 1 ]; then echo "║ ✓ SYNTHESIS .......................................... COMPLETED ║"; else echo "║ ○ SYNTHESIS .......................................... PENDING   ║"; fi
    if [ $PLACEMENT -eq 1 ]; then echo "║ ✓ PLACE & SIZE ....................................... COMPLETED ║"; else echo "║ ○ PLACE & SIZE ....................................... PENDING   ║"; fi
    if [ $CTS -eq 1 ]; then echo "║ ✓ CTS (Clock Tree Synthesis) ......................... COMPLETED ║"; else echo "║ ○ CTS (Clock Tree Synthesis) ......................... PENDING   ║"; fi
    if [ $ROUTING -eq 1 ]; then echo "║ ✓ ROUTING ............................................ COMPLETED ║"; else echo "║ ○ ROUTING ............................................ PENDING   ║"; fi
    if [ $FINISH -eq 1 ]; then echo "║ ✓ FINISH (GDS Generation) ............................ COMPLETED ║"; else echo "║ ○ FINISH (GDS Generation) ............................ PENDING   ║"; fi

    echo "╠══════════════════════════════════════════════════════════════════╣"

    # Current status
    if [ $FINISH -eq 1 ]; then
        echo "║                    🎉 FLOW COMPLETED! 🎉                       ║"
    elif [ $ROUTING -eq 1 ]; then
        echo "║                    🟠 ROUTING FINISHED                         ║"
    elif [ $CTS -eq 1 ]; then
        echo "║                    🟡 CTS FINISHED                            ║"
    elif [ $PLACEMENT -eq 1 ]; then
        echo "║                    🟢 PLACEMENT FINISHED                      ║"
    elif [ $SYNTHESIS -eq 1 ]; then
        echo "║                    🔵 SYNTHESIS COMPLETED                     ║"
    else
        echo "║                    🔴 FLOW INITIALIZING                       ║"
    fi

    echo "╠══════════════════════════════════════════════════════════════════╣"

    # Generated files
    echo -n "║ GDS: "
    if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_final.gds" ]; then
        size=$(ls -sh /home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_final.gds | awk '{print $1}')
        echo -n "✅ ($size)                                    ║"
    else
        echo -n "⏳ Not generated yet                              ║"
    fi
    echo ""

    echo -n "║ DEF: "
    if [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_routed.def" ]; then
        echo -n "✅ (Routing complete)                           ║"
    elif [ -f "/home/kiran-sekar/NeuroRiscV/pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
        echo -n "✅ (Placement complete)                         ║"
    else
        echo -n "⏳ Not generated yet                              ║"
    fi
    echo ""

    echo -n "║ Status: "
    if [ -n "$(docker ps --filter ancestor=openroad/orfs --format '{{.Names}}')" ]; then
        container_name=$(docker ps --filter ancestor=openroad/orfs --format '{{.Names}}')
        echo -n "Container '$container_name' running              ║"
    else
        echo -n "No active containers                               ║"
    fi
    echo ""

    echo "╚══════════════════════════════════════════════════════════════════╝"

    # Timestamp
    echo "Current time: $(date)"

    # Log progress
    echo "$(date): Stage $completed/6 complete ($percentage%)" >> $TRACKING_FILE
}

# If called with 'watch' argument, run in a loop
if [ "$1" = "watch" ]; then
    while true; do
        clear
        show_progress
        echo ""
        echo "Press Ctrl+C to stop monitoring"
        sleep 10
    done
else
    show_progress
fi