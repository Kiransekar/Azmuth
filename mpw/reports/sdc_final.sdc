# syn/sdc_final.sdc
# Synopsys Design Constraints for Xcew Processor
# TSMC 130nm process, 250MHz target (4.0ns period)

# Clock definitions
create_clock -name clk_core -period 4.0 [get_ports i_clk]
create_clock -name clk_snn -period 8.0 [get_ports i_clk_snn]

# Clock relationships and uncertainties
set_clock_uncertainty -setup 0.2 [get_clocks clk_core clk_snn]
set_clock_uncertainty -hold 0.1 [get_clocks clk_core clk_snn]

# Set clock latencies if applicable
set_clock_latency -source -min 0.1 [get_clocks clk_core]
set_clock_latency -source -max 0.3 [get_clocks clk_core]

# Input/output delays
set_input_delay -clock clk_core 1.0 [remove_from_collection [all_inputs] [get_port_names "i_clk* i_rst"]]
set_output_delay -clock clk_core 1.0 [all_outputs]

# Input/output external delays (to account for board effects)
set_input_delay -clock clk_core 0.2 -max [remove_from_collection [all_inputs] [get_port_names "i_clk* i_rst"]]
set_input_delay -clock clk_core 0.1 -min [remove_from_collection [all_inputs] [get_port_names "i_clk* i_rst"]]
set_output_delay -clock clk_core 0.2 -max [all_outputs]
set_output_delay -clock clk_core 0.1 -min [all_outputs]

# Drive and load constraints
set_driving_cell -lib_cell BUFX2 [remove_from_collection [all_inputs] [get_port_names "i_clk* i_rst"]]
set_load [expr 5 * [load_of */BUF_X1/A]] [all_outputs]

# Area constraints
set_max_area 18000000 ;# 18mm^2 in database units

# Transition constraints
set_max_transition 0.5 [get_ports]

# Skew constraints
set_clock_skew -setup 0.1 [get_clocks clk_core]
set_clock_skew -hold 0.05 [get_clocks clk_core]

# False paths for asynchronous signals
set_false_path -from [get_ports i_rst]
set_false_path -to [get_ports o_debug_uart]

# Multicycle paths for slow interfaces
set_multicycle_path -setup 2 -from [get_cells -hierarchical -filter "name =~ *nvm*"] -to [get_cells -hierarchical -filter "name =~ *nvm*"]
set_multicycle_path -hold 1 -from [get_cells -hierarchical -filter "name =~ *nvm*"] -to [get_cells -hierarchical -filter "name =~ *nvm*"]

# Clock domain crossing constraints
set_clock_groups -asynchronous -group [get_clocks clk_core] -group [get_clocks clk_snn]

# Timing exceptions for internal structures
set_false_path -through [get_cells -hierarchical -filter "ref_name == RAM*"]
set_false_path -through [get_cells -hierarchical -filter "ref_name == ROM*"]

# Pin padding for IO cells (if applicable)
# set_pin_pad_physical_constraints -pins [get_ports *] -pad_edges {NORTH SOUTH EAST WEST}

puts "SDC constraints loaded for Xcew Processor timing closure"