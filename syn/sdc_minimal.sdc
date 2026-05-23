# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# syn/sdc_minimal.sdc
# Minimal Synopsys Design Constraints for Xcew Processor - Compatible with OpenROAD
# Sky130 process, 250MHz target (4.0ns period)

# Clock definitions
create_clock -name clk_core -period 4.0 [get_ports i_clk]
create_clock -name clk_snn -period 8.0 [get_ports i_clk_snn]

# Basic timing constraints
set_input_delay -clock clk_core 1.0 [get_ports {i_inst[*]}]
set_output_delay -clock clk_core 1.0 [get_ports {o_rd_data[*]}]

# Area constraint
set_max_area 18000000

puts "Minimal SDC constraints loaded for Xcew Processor"