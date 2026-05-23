# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
# syn/upf_final.tcl
# Unified Power Format (UPF) script for Xcew Processor
# Power intent definition for TSMC 130nm process implementation

# Define power domains and supplies
create_supply_set VDD_VSS
add_primary_power_pad VDD
add_primary_ground_pad VSS

# Create power domains
create_power_domain PD_CORE \
    -supply {VPWR VGND} \
    -default_state active

create_power_domain PD_SNN \
    -supply {VPWR VGND} \
    -default_state active

create_power_domain PD_NVM \
    -supply {VPWR VGND} \
    -default_state retention

# Define voltage states
create_voltage_state VS_ACTIVE \
    -domain PD_CORE \
    -state on \
    -supply VPWR {1.2 1.2} \
    -supply VGND {0.0 0.0}

create_voltage_state VS_RETENTION \
    -domain PD_NVM \
    -state retention \
    -supply VPWR {0.8 0.8} \
    -supply VGND {0.0 0.0}

# Define power switches for power gating
create_power_switch SW_NVM_PWR \
    -domain PD_NVM \
    -on_state {VPWR 1.2} \
    -off_state {VPWR 0.0} \
    -control_signal i_pwr_gate_nvm \
    -output_supply VNWELL \
    -input_supply VPWR

# Define isolation cells
create_isolation_cell ICBUF_LOW \
    -domain PD_NVM \
    -clamp_value 0 \
    -location both \
    -isolation_signal i_iso_en_nvm \
    -isolation_sense low

create_isolation_cell ICBUF_HIGH \
    -domain PD_NVM \
    -clamp_value 1 \
    -location both \
    -isolation_signal i_iso_en_nvm \
    -isolation_sense low

# Apply isolation for signals going from NVM domain to other domains
isolate_supply_port VPWR \
    -domain PD_NVM \
    -isolation_cell ICBUF_LOW \
    -location output

isolate_supply_port VGND \
    -domain PD_NVM \
    -isolation_cell ICBUF_LOW \
    -location output

# Define retention registers for NVM domain
define_retention_control_signal \
    -domain PD_NVM \
    -primary_power VPWR \
    -primary_ground VGND \
    -signal i_retain_nvm \
    -when assertion

# Level shifters for crossing voltage domains
create_level_shifter LS_H2L \
    -domain_boundary PD_CORE PD_NVM \
    -type H2L \
    -supply {VPWR VGND}

create_level_shifter LS_L2H \
    -domain_boundary PD_NVM PD_CORE \
    -type L2H \
    -supply {VPWR VGND}

# Apply level shifters for cross-domain signals
apply_level_shifting \
    -domain PD_CORE \
    -signals [get_ports -filter "direction == out && name =~ nvm_*"] \
    -level_shifter LS_L2H

apply_level_shifting \
    -domain PD_NVM \
    -signals [get_ports -filter "direction == out && name =~ core_*"] \
    -level_shifter LS_H2L

# Power domain dependencies
add_power_state_dependency \
    -domain PD_NVM \
    -depends_on PD_CORE \
    -state_map {active active} \
    -state_map {off off}

# Clock gating power reduction
create_clock_gating_check \
    -setup 0.5 \
    -hold 0.1 \
    -control_pin clk_enable

puts "UPF constraints loaded for Xcew Processor power optimization"