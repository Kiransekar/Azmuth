# syn/synth.tcl
# Yosys synthesis script for Xcew Processor

# Read design files
read_verilog -sv rtl/xcew_top.v
read_verilog -sv rtl/core/xcie_decoder.v
read_verilog -sv rtl/core/xcie_csr.v
read_verilog -sv rtl/core/xcie_ctrl.v
read_verilog -sv rtl/eml/eml_unit.v
read_verilog -sv rtl/snn/snn_tile.v
read_verilog -sv rtl/nvm/nvm_ctrl.v

# Set top module
hierarchy -top xcew_top

# Run synthesis flow
proc; opt; memory; fsm
synth -top xcew_top -flatten

# Map to standard cells
# Note: This requires a liberty file for the 130nm technology
# dfflibmap -liberty 130nm_std.lib
# abc -liberty 130nm_std.lib -constr sdc.sdc -D 4.0

# Clean up and output
opt_clean
write_verilog -noattr -noexpr syn/xcew_netlist.v

# Generate statistics
stat -top xcew_top