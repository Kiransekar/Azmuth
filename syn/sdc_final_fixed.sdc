# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# syn/sdc_final_fixed.sdc
# Simplified Synopsys Design Constraints for Xcew Processor - Fixed for OpenROAD
# Sky130 process, 250MHz target (4.0ns period)

# Clock definitions
create_clock -name clk_core -period 4.0 [get_ports i_clk]
create_clock -name clk_snn -period 8.0 [get_ports i_clk_snn]

# Basic timing constraints
set_input_delay -clock clk_core 1.0 [remove_from_collection [all_inputs] [get_ports {i_clk i_clk_snn i_rst}]]
set_output_delay -clock clk_core 1.0 [all_outputs]

# Basic timing margins
set_clock_uncertainty 0.1 [get_clocks]
set_clock_latency 0.2 [get_clocks]

# Area constraint
set_max_area 18000000

# Max transition time
set_max_transition 1.0 [current_design]

puts "Fixed SDC constraints loaded for Xcew Processor"