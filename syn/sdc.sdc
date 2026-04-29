# syn/sdc.sdc
# Synopsys Design Constraints for Xcew Processor

# Clock definitions
create_clock -name clk_core -period 4.0 [get_ports i_clk]
create_clock -name clk_snn -period 8.0 [get_ports i_clk_snn]

# Clock relationships
set_clock_uncertainty -setup 0.2 [get_clocks clk_core clk_snn]
set_clock_uncertainty -hold 0.1 [get_clocks clk_core clk_snn]

# Input/output delays
set_input_delay -clock clk_core 1.0 [remove_from_collection [all_inputs] [get_ports {i_clk*i_clk_snn*i_rst*}]]
set_output_delay -clock clk_core 1.0 [all_outputs]

# Timing exceptions
set_false_path -from [get_ports i_rst]
set_multicycle_path -setup 2 -from [get_cells -hierarchical -filter "name =~ *nvm*"] -to [get_cells -hierarchical -filter "name =~ *nvm*"]

# Area constraint
set_max_area 18000000

# Transition constraints
set_max_transition 0.5 [get_ports]

# Load and driving cell constraints
set_load [expr 5 * [load_of */buf/A]] [all_outputs]
set_driving_cell -lib_cell */buf [remove_from_collection [all_inputs] [get_ports {i_clk*i_rst*}]]

# Voltage domains (if needed for power analysis)
# Assuming 1.2V for core, 0.9V for some units, 1.8V for I/O