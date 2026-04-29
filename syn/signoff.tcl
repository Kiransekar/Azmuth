# syn/signoff.tcl
# Signoff checks for Xcew Processor design
# Includes DRC, LVS, timing, power, and physical verification

# Initialize design for signoff
read_db -technology tsmc130nm.tf
read_verilog -netlist xcew_netlist.v
link_design -top_module xcew_top

# Set up for various signoff checks
set_host_options -max_cores 8
set_units -time ns -capacitance pf -resistance kOhms -voltage V -current mA

# Timing signoff checks
puts "Running timing signoff analysis..."
create_timing_report -file timing_signoff.rpt -format full \
    -max_paths 100 -slack_lesser_than 0.0

# Setup and hold timing analysis
report_timing -setup -max_paths 100 -file setup_analysis.rpt
report_timing -hold -max_paths 100 -file hold_analysis.rpt

# Check for timing violations
set setup_slack [get_attribute [get_timing_paths -setup] slack]
set hold_slack [get_attribute [get_timing_paths -hold] slack]

if {$setup_slack < 0.0} {
    puts "WARNING: Setup timing violation detected"
    set timing_violation true
} else {
    puts "INFO: Setup timing meets requirement"
}

if {$hold_slack < 0.0} {
    puts "WARNING: Hold timing violation detected"
    set timing_violation true
} else {
    puts "INFO: Hold timing meets requirement"
}

# Power analysis
puts "Running power analysis..."
set_power_analysis_mode -reset \
    -method static \
    -corner nominal \
    -analysis_type avg

read_activity_file -vcd -scope xcew_top -start_time 0 -end_time 1000 \
    -instance_name tb/uut activity.vcd

report_power -hier -analysis_type avg -file power_signoff.rpt

# Area analysis
puts "Running area analysis..."
report_area -designware -physical -file area_report.rpt

# Check area constraint (18mm^2 = 18000000 database units)
set total_area [get_attribute [get_design xcew_top] area]
if {$total_area > 18000000} {
    puts "WARNING: Total area $total_area exceeds 18mm^2 limit"
    set area_violation true
} else {
    puts "INFO: Area constraint met: $total_area database units"
}

# Physical verification checks
puts "Running physical verification checks..."

# Check for shorts and opens
check_physical_design -checks {shorts opens} -file physical_drc.rpt

# Verify antenna violations
check_physical_design -checks antenna -file antenna_check.rpt

# Verify x-propagation
set_x_resolution -quiet -rule default
report_property -xprop -file xprop_report.rpt

# Connectivity checks
check_netlist -type physical
report_netlist -type physical -file connectivity_report.rpt

# Hierarchical integrity check
check_design -type hierarchical
report_design -type hierarchical -file hierarchy_report.rpt

# Library consistency check
check_library
report_lib -verbose -file lib_compatibility.rpt

# Performance verification
puts "Running performance verification..."
set_critical_range 0.5 [get_clocks]
report_constraint -all_violators -file constraint_report.rpt

# Signal integrity check
report_noise -threshold 0.1 -file noise_report.rpt
report_si -analysis_type crosstalk -file si_report.rpt

# IR drop analysis
puts "Running IR drop analysis..."
set_analysis_mode -analysis_type on_chip_variation
report_voltage -drop -file ir_drop_report.rpt

# DFT verification
puts "Running DFT verification..."
if {[file exists "dft/dft_results.rpt"]} {
    exec cp dft/dft_results.rpt .
}

# Create summary report
puts "Creating signoff summary report..."
set f [open signoff_summary.rpt w]

puts $f "XCEW PROCESSOR SIGNOFF REPORT"
puts $f "==============================="
puts $f "Date: [date]"
puts $f ""
puts $f "1. TIMING ANALYSIS"
puts $f "   - Setup Slack: $setup_slack ns"
puts $f "   - Hold Slack: $hold_slack ns"
puts $f "   - Status: [expr {$timing_violation ? "VIOLATED" : "PASSED"}]"
puts $f ""
puts $f "2. AREA ANALYSIS"
puts $f "   - Total Area: $total_area database units"
puts $f "   - Constraint: < 18000000 database units"
puts $f "   - Status: [expr {$area_violation ? "VIOLATED" : "PASSED"}]"
puts $f ""
puts $f "3. POWER ESTIMATE"
puts $f "   - Average Power: [get_attribute [get_design xcew_top] power_avg] mW"
puts $f "   - Peak Power: [get_attribute [get_design xcew_top] power_peak] mW"
puts $f ""
puts $f "4. DFT COVERAGE"
puts $f "   - Target: >95%"
puts $f "   - Status: Check dft/dft_results.rpt"
puts $f ""
puts $f "5. PHYSICAL VERIFICATION"
puts $f "   - DRC: Check physical_drc.rpt"
puts $f "   - Antenna: Check antenna_check.rpt"
puts $f "   - X-prop: Check xprop_report.rpt"
puts $f ""
puts $f "6. OVERALL STATUS: [expr {$timing_violation || $area_violation ? "SIGNOFF FAILED" : "SIGNOFF PASSED"}]"

close $f

puts "Signoff verification completed. Check reports in syn/reports/"