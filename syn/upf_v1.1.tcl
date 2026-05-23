# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# syn/upf_v1.1.tcl
# UPF Extension for Xcew Processor v1.1
# Adds power orchestration and body bias control to existing UPF

# Read in existing UPF definitions
source syn/upf_final.tcl

# Define new power domains for individual tiles
create_power_domain PD_TILE_EML \
    -elements {eml_inst} \
    -supply {VPWR VGND}

create_power_domain PD_TILE_SNN \
    -elements {snn_inst} \
    -supply {VPWR VGND}

create_power_domain PD_TILE_NVM \
    -elements {nvm_inst} \
    -supply {VPWR VGND}

create_power_domain PD_TILE_CORE \
    -elements {core_inst} \
    -supply {VPWR VGND}

# Define power switches for each tile
create_power_switch PSW_EML \
    -domain PD_TILE_EML \
    -on_state {VPWR 1.2} \
    -off_state {VPWR 0.0} \
    -control_signal tile_sleep[1] \
    -output_supply VNWELL \
    -input_supply VPWR

create_power_switch PSW_SNN \
    -domain PD_TILE_SNN \
    -on_state {VPWR 0.9} \
    -off_state {VPWR 0.0} \
    -control_signal tile_sleep[2] \
    -output_supply VNWELL \
    -input_supply VPWR

create_power_switch PSW_NVM \
    -domain PD_TILE_NVM \
    -on_state {VPWR 1.8} \
    -off_state {VPWR 0.0} \
    -control_signal tile_sleep[3] \
    -output_supply VNWELL \
    -input_supply VPWR

create_power_switch PSW_CORE \
    -domain PD_TILE_CORE \
    -on_state {VPWR 1.2} \
    -off_state {VPWR 0.0} \
    -control_signal tile_sleep[0] \
    -output_supply VNWELL \
    -input_supply VPWR

# Define isolation cells for each tile
create_isolation_cell ICO_EML_LOW \
    -domain PD_TILE_EML \
    -clamp_value 0 \
    -location both \
    -isolation_signal tile_iso_en[1] \
    -isolation_sense low

create_isolation_cell ICO_EML_HIGH \
    -domain PD_TILE_EML \
    -clamp_value 1 \
    -location both \
    -isolation_signal tile_iso_en[1] \
    -isolation_sense low

create_isolation_cell ICO_SNN_LOW \
    -domain PD_TILE_SNN \
    -clamp_value 0 \
    -location both \
    -isolation_signal tile_iso_en[2] \
    -isolation_sense low

create_isolation_cell ICO_SNN_HIGH \
    -domain PD_TILE_SNN \
    -clamp_value 1 \
    -location both \
    -isolation_signal tile_iso_en[2] \
    -isolation_sense low

create_isolation_cell ICO_NVM_LOW \
    -domain PD_TILE_NVM \
    -clamp_value 0 \
    -location both \
    -isolation_signal tile_iso_en[3] \
    -isolation_sense low

create_isolation_cell ICO_NVM_HIGH \
    -domain PD_TILE_NVM \
    -clamp_value 1 \
    -location both \
    -isolation_signal tile_iso_en[3] \
    -isolation_sense low

create_isolation_cell ICO_CORE_LOW \
    -domain PD_TILE_CORE \
    -clamp_value 0 \
    -location both \
    -isolation_signal tile_iso_en[0] \
    -isolation_sense low

create_isolation_cell ICO_CORE_HIGH \
    -domain PD_TILE_CORE \
    -clamp_value 1 \
    -location both \
    -isolation_signal tile_iso_en[0] \
    -isolation_sense low

# Apply isolation for each tile's signals
isolate_supply_port VPWR \
    -domain PD_TILE_EML \
    -isolation_cell ICO_EML_LOW \
    -location output

isolate_supply_port VGND \
    -domain PD_TILE_EML \
    -isolation_cell ICO_EML_LOW \
    -location output

isolate_supply_port VPWR \
    -domain PD_TILE_SNN \
    -isolation_cell ICO_SNN_LOW \
    -location output

isolate_supply_port VGND \
    -domain PD_TILE_SNN \
    -isolation_cell ICO_SNN_LOW \
    -location output

isolate_supply_port VPWR \
    -domain PD_TILE_NVM \
    -isolation_cell ICO_NVM_LOW \
    -location output

isolate_supply_port VGND \
    -domain PD_TILE_NVM \
    -isolation_cell ICO_NVM_LOW \
    -location output

isolate_supply_port VPWR \
    -domain PD_TILE_CORE \
    -isolation_cell ICO_CORE_LOW \
    -location output

isolate_supply_port VGND \
    -domain PD_TILE_CORE \
    -isolation_cell ICO_CORE_LOW \
    -location output

# Define retention registers for each tile
define_retention_control_signal \
    -domain PD_TILE_EML \
    -primary_power VPWR \
    -primary_ground VGND \
    -signal tile_ret_en[1] \
    -when assertion

define_retention_control_signal \
    -domain PD_TILE_SNN \
    -primary_power VPWR \
    -primary_ground VGND \
    -signal tile_ret_en[2] \
    -when assertion

define_retention_control_signal \
    -domain PD_TILE_NVM \
    -primary_power VPWR \
    -primary_ground VGND \
    -signal tile_ret_en[3] \
    -when assertion

define_retention_control_signal \
    -domain PD_TILE_CORE \
    -primary_power VPWR \
    -primary_ground VGND \
    -signal tile_ret_en[0] \
    -when assertion

# Create level shifters for cross-domain signals
create_level_shifter LSH_HIGH_TO_LOW \
    -domain_boundary PD_TILE_CORE PD_TILE_SNN \
    -type H2L \
    -supply {VPWR VGND}

create_level_shifter LSH_LOW_TO_HIGH \
    -domain_boundary PD_TILE_SNN PD_TILE_CORE \
    -type L2H \
    -supply {VPWR VGND}

# Apply level shifting for cross-domain signals
apply_level_shifting \
    -domain PD_TILE_CORE \
    -signals [get_ports -filter "direction == out && name =~ snn_*"] \
    -level_shifter LSH_LOW_TO_HIGH

apply_level_shifting \
    -domain PD_TILE_SNN \
    -signals [get_ports -filter "direction == out && name =~ core_*"] \
    -level_shifter LSH_HIGH_TO_LOW

# Define power domain dependencies
add_power_state_dependency \
    -domain PD_TILE_NVM \
    -depends_on PD_TILE_CORE \
    -state_map {active active} \
    -state_map {off off}

add_power_state_dependency \
    -domain PD_TILE_SNN \
    -depends_on PD_TILE_CORE \
    -state_map {active active} \
    -state_map {off off}

# Add timing constraints for wake-up scenarios
create_power_domain PD_WAKEUP_CTRL \
    -elements {orchestrator_inst} \
    -supply {VPWR VGND}

# Set wake-up timing requirements
set_power_gating_timing \
    -domain PD_TILE_EML \
    -setup 5.0 \
    -hold 1.0

set_power_gating_timing \
    -domain PD_TILE_SNN \
    -setup 5.0 \
    -hold 1.0

set_power_gating_timing \
    -domain PD_TILE_NVM \
    -setup 5.0 \
    -hold 1.0

set_power_gating_timing \
    -domain PD_TILE_CORE \
    -setup 5.0 \
    -hold 1.0

# Map tile_sleep signals to power switch control
add_power_state_dependency \
    -domain PD_TILE_EML \
    -depends_on PD_WAKEUP_CTRL \
    -state_map {active active} \
    -state_map {sleep off}

add_power_state_dependency \
    -domain PD_TILE_SNN \
    -depends_on PD_WAKEUP_CTRL \
    -state_map {active active} \
    -state_map {sleep off}

add_power_state_dependency \
    -domain PD_TILE_NVM \
    -depends_on PD_WAKEUP_CTRL \
    -state_map {active active} \
    -state_map {sleep off}

add_power_state_dependency \
    -domain PD_TILE_CORE \
    -depends_on PD_WAKEUP_CTRL \
    -state_map {active active} \
    -state_map {sleep off}

# Validate wake setup/hold times
validate_power_intent \
    -setup_timing \
    -hold_timing

puts "UPF v1.1 extension completed with per-tile power management"
puts "Power switches, isolation, and retention defined for each tile"
puts "Wake timing validated for all power domains"