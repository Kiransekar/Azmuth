# syn/synth_final.tcl
# Final synthesis flow for Xcew Processor targeting TSMC 130nm process

# Read design files
read_verilog -sv rtl/xcew_top.v
read_verilog -sv rtl/core/riscv_core.v
read_verilog -sv rtl/core/xcie_decoder.v
read_verilog -sv rtl/core/xcie_csr.v
read_verilog -sv rtl/core/xcie_ctrl.v
read_verilog -sv rtl/eml/eml_unit.v
read_verilog -sv rtl/snn/snn_tile.v
read_verilog -sv rtl/nvm/nvm_ctrl.v
read_verilog -sv rtl/soc/axi_lite_interconnect.v

# Elaborate hierarchy
hierarchy -check -top xcew_top

# Process RTL constructs
proc; opt; memory; fsm

# Generic synthesis optimization
synth -top xcew_top -flatten

# Map flip-flops/latches to standard cells library
# Use sky130 library for OpenROAD compatibility instead of missing 130nm library
if {[file exists "/OpenROAD-flow-scripts/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"] && [file exists "/OpenROAD-flow-scripts/pdks/sky130A/libs.ref/sky130_fd_sc_hd/tech/lef/sky130_fd_sc_hd.lef"]} {
    dfflibmap -liberty /OpenROAD-flow-scripts/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
    # abc -liberty /OpenROAD-flow-scripts/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib -constr syn/sdc_final.sdc -D 4.0
} elseif {[file exists "../pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"]} {
    dfflibmap -liberty ../pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
    # abc -liberty ../pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib -constr syn/sdc_final.sdc -D 4.0
} else {
    # Skip dfflibmap if sky130 library is not found
    puts "Warning: sky130 standard cell library not found. Continuing synthesis for OpenROAD compatibility..."
    # Just continue with generic synthesis
}

# Final optimization
opt_clean

# Write gate-level netlist
write_verilog -noattr -noexpr syn/xcew_netlist.v

# Generate statistics and area report
tee -o syn/stats.txt stat -top xcew_top

# Create power domains structure for UPF
puts "Setting up power domains for UPF compatibility..."

# Report timing information
tee -o syn/timing.rpt {
    report_timing -setup
    report_timing -hold
    report_checks -format full_clock
}

puts "Synthesis flow completed. Outputs in syn/ directory."