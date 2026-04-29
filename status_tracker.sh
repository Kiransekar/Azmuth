#!/bin/bash
# Step-by-step P&R Flow for NeuroRiscV with Real-time Progress Tracking

echo "=========================================="
echo "NEURORISCV STEP-BY-STEP P&R FLOW"
echo "=========================================="
echo "Timestamp: $(date)"
echo ""

# Define stages
declare -A stages
stages[prep]="PREPARATION"
stages[synth]="SYNTHESIS"
stages[place]="PLACEMENT"
stages[cts]="CTS"
stages[route]="ROUTING"
stages[finish]="FINISH"

# Status tracking
completed_stages=()

# Check what's already completed
if [ -f "pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
    completed_stages+=("prep" "synth" "place")
    echo "✓ Preparation, Synthesis, and Placement already completed"
fi

echo "Current progress: ${#completed_stages[@]}/6 stages completed"
echo ""

# Show visual progress
echo "PROGRESS:"
echo "┌──────────────────────────────────────────────────────────────┐"
for stage_key in prep synth place cts route finish; do
    stage_name=${stages[$stage_key]}
    if [[ " ${completed_stages[@]} " =~ " ${stage_key} " ]]; then
        echo "│ ✓ $stage_name $(printf '%*s' $((30-${#stage_name})) | tr ' ' ' ') │ COMPLETED │"
    else
        echo "│ ○ $stage_name $(printf '%*s' $((30-${#stage_name})) | tr ' ' ' ') │ PENDING   │"
    fi
done
progress=$(( (${#completed_stages[@]} * 100) / 6 ))
echo "├──────────────────────────────────────────────────────────────┤"
echo -n "│ PROGRESS: ["
fill=$((progress/4))
for ((i=0; i<fill; i++)); do echo -n "█"; done
for ((i=fill; i<25; i++)); do echo -n "░"; done
printf '] %3d%% │\n' $progress
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# Check for any running containers
running_container=$(docker ps --filter ancestor=openroad/orfs --format "{{.Names}}" 2>/dev/null)
if [ -n "$running_container" ]; then
    echo "📊 CONTAINER STATUS:"
    echo "   Running container: $running_container"
    docker stats --no-stream $running_container 2>/dev/null | tail -n +2
    echo ""
fi

# Check output files
echo "💾 GENERATED FILES:"
if [ -f "pnr/runs/xcew_v1_1/xcew_placed.def" ]; then
    size=$(ls -sh "pnr/runs/xcew_v1_1/xcew_placed.def" | awk '{print $1}')
    echo "   ✅ xcew_placed.def ($size)"
else
    echo "   📄 xcew_placed.def (pending)"
fi

# Show next action
if [ ${#completed_stages[@]} -lt 6 ]; then
    next_stage="UNKNOWN"
    if [[ " ${completed_stages[@]} " =~ " place " ]] && [[ ! " ${completed_stages[@]} " =~ " cts " ]]; then
        next_stage="CTS (Clock Tree Synthesis)"
    elif [[ " ${completed_stages[@]} " =~ " cts " ]] && [[ ! " ${completed_stages[@]} " =~ " route " ]]; then
        next_stage="ROUTING"
    elif [[ " ${completed_stages[@]} " =~ " route " ]] && [[ ! " ${completed_stages[@]} " =~ " finish " ]]; then
        next_stage="FINISH"
    fi

    echo ""
    echo "⏭️  NEXT STAGE: $next_stage"
    echo ""
    echo "🔄 TO CONTINUE FLOW:"
    echo "   Run: ./run_safe_pnr_v2.sh"
    echo "   Monitor with: watch -n 5 './live_tracker.sh'"
else
    echo ""
    echo "🎉 FLOW COMPLETED!"
    echo "   GDSII file: pnr/runs/xcew_v1_1/xcew_final.gds (if generated)"
    echo "   Final DEF: pnr/runs/xcew_v1_1/xcew_routed.def (if generated)"
fi

echo ""
echo "📋 STATUS LOGGED TO: /tmp/xcew_pnr_progress.txt"
echo "$(date): Status - ${#completed_stages[@]}/6 stages completed" >> /tmp/xcew_pnr_progress.txt

echo "=========================================="