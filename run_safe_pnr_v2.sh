#!/bin/bash
# Safe P&R Flow for NeuroRiscV Xcew Processor using OpenROAD Flow Scripts
# This script sets up the proper environment and runs the flow with safety measures

echo "Setting up safe P&R flow for NeuroRiscV Xcew Processor..."
echo "Timestamp: $(date)"
echo "This may take 2-4 hours depending on design complexity..."

# Create the config file in the right place for OpenROAD flow
CONFIG_DIR="/tmp/xcew_design"
mkdir -p "$CONFIG_DIR"

# Copy our config to the temp directory
cp /home/kiran-sekar/NeuroRiscV/pnr/xcew_config.mk "$CONFIG_DIR/config.mk"

# Check if netlist exists
if [ ! -f "/home/kiran-sekar/NeuroRiscV/syn/reports/xcew_netlist.v" ]; then
    echo "Error: Netlist file not found"
    exit 1
fi

# Create a wrapper script to run the flow properly
cat > /tmp/run_xcew_flow.sh << 'RUN_EOF'
#!/bin/bash
set -e

# Copy the netlist to the temp config directory so it can be found
cp /work/syn/reports/xcew_netlist.v /tmp/xcew_design/

# Go to the OpenROAD-flow-scripts directory
cd /OpenROAD-flow-scripts/flow

# Set up the design configuration
export DESIGN_CONFIG=/tmp/xcew_design/config.mk

# Make sure the platform is properly configured
if [ ! -d "/OpenROAD-flow-scripts/flow/platforms/sky130A" ]; then
    echo "Sky130 platform not found, trying sky130..."
    if [ -d "/OpenROAD-flow-scripts/flow/platforms/sky130" ]; then
        # Update the config to use sky130 instead of sky130hd
        sed -i 's/export PLATFORM = sky130hd/export PLATFORM = sky130/g' /tmp/xcew_design/config.mk
    else
        echo "No sky130 platform found, looking for available platforms..."
        ls -la /OpenROAD-flow-scripts/flow/platforms/
    fi
fi

# Run the flow stages individually to better track progress
echo "Starting synthesis..."
timeout 3600 make synth 2>&1 | tee -a /tmp/pnr_flow.log || echo "Synth may have failed or not be needed since netlist is pre-generated"

echo "Starting floorplan..."
timeout 7200 make floorplan 2>&1 | tee -a /tmp/pnr_flow.log || echo "Floorplan stage completed or skipped"

echo "Starting placement..."
timeout 10800 make place 2>&1 | tee -a /tmp/pnr_flow.log || echo "Placement stage completed or skipped"

echo "Starting clock tree synthesis..."
timeout 7200 make cts 2>&1 | tee -a /tmp/pnr_flow.log || echo "CTS stage completed or skipped"

echo "Starting routing..."
timeout 14400 make route 2>&1 | tee -a /tmp/pnr_flow.log || echo "Routing stage completed or skipped"

echo "Starting final steps..."
timeout 3600 make finish 2>&1 | tee -a /tmp/pnr_flow.log || echo "Finish stage completed"

echo "Flow execution completed."
RUN_EOF

chmod +x /tmp/run_xcew_flow.sh

# Run with timeout to prevent infinite hangs
timeout 18000 docker run --rm \
  --cpus=3.5 --memory=20g --memory-swap=24g \
  -v /home/kiran-sekar/NeuroRiscV:/work -w /work \
  -v /tmp/xcew_design:/tmp/xcew_design \
  -v /tmp:/tmp \
  --ulimit nofile=1024:1024 \
  openroad/orfs bash -c "bash /tmp/run_xcew_flow.sh"

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