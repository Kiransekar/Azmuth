# pnr/signoff_postpr.tcl
# Post-Physical Implementation Signoff Verification
# Timing Analysis, DRC, and LVS checks for Xcew Processor

# Initialize tools for signoff
puts "Loading design for post-P&R signoff verification..."

# Read design with parasitics
read_liberty "../syn/130nm_std.lib"  ;# TSMC 130nm liberty file
read_def "xcew_final.def"
read_spef "xcew_parasitics.spef"

link_design xcew_top

# Set operating conditions for analysis
set_operating_conditions -analysis_type on_chip_variation \
    -library_cell_delay_temperature 25 \
    -library_cell_delay_voltage 1.2 \
    -library_cell_delay_process "TT"

# Timing Analysis at post-P&R with parasitics
puts "Running Static Timing Analysis (STA) with parasitics..."

# Core clock (250MHz - 4.0ns period)
create_clock -name clk_core -period 4.0 [get_ports i_clk]
set_clock_uncertainty -setup 0.2 [get_clocks clk_core]
set_clock_uncertainty -hold 0.1 [get_clocks clk_core]

# SNN clock (125MHz - 8.0ns period)
create_clock -name clk_snn -period 8.0 [get_ports i_clk_snn]
set_clock_uncertainty -setup 0.2 [get_clocks clk_snn]
set_clock_uncertainty -hold 0.1 [get_clocks clk_snn]

# Perform setup and hold analysis
puts "Analyzing setup timing..."
report_timing -setup -max_paths 100 -file sta_setup.rpt
set setup_paths [get_timing_paths -setup -max_paths 100]
set setup_slack [get_attribute $setup_paths slack]

puts "Analyzing hold timing..."
report_timing -hold -max_paths 100 -file sta_hold.rpt
set hold_paths [get_timing_paths -hold -max_paths 100]
set hold_slack [get_attribute $hold_paths slack]

# Calculate WNS (Worst Negative Slack) and TNS (Total Negative Slack)
set wns_setup [get_attribute [get_timing_paths -setup -max_slack] slack]
set wns_hold [get_attribute [get_timing_paths -hold -max_slack] slack]

set wns [min $wns_setup $wns_hold]

# Calculate TNS
set total_negative_slack_setup 0
foreach_in_collection path $setup_paths {
    set slack_val [get_attribute $path slack]
    if {$slack_val < 0} {
        set total_negative_slack_setup [expr $total_negative_slack_setup + $slack_val]
    }
}

set total_negative_slack_hold 0
foreach_in_collection path $hold_paths {
    set slack_val [get_attribute $path slack]
    if {$slack_val < 0} {
        set total_negative_slack_hold [expr $total_negative_slack_hold + $slack_val]
    }
}

set tns [expr $total_negative_slack_setup + $total_negative_slack_hold]

# Clock skew analysis
puts "Analyzing clock skew..."
set clk_core_skew [get_clock_skew -setup clk_core]
set clk_snn_skew [get_clock_skew -setup clk_snn]

# Output delay analysis
puts "Analyzing I/O delays..."
set_input_delay -clock clk_core 1.0 [remove_from_collection [all_inputs] [get_port_names "i_clk* i_rst"]]
set_output_delay -clock clk_core 1.0 [all_outputs]

puts "Post-P&R STA Summary:"
puts "  Setup WNS: $wns_setup ns"
puts "  Hold WNS: $wns_hold ns"
puts "  Overall WNS: $wns ns"
puts "  Setup TNS: $total_negative_slack_setup ns"
puts "  Hold TNS: $total_negative_slack_hold ns"
puts "  Overall TNS: $tns ns"
puts "  Core Clock Skew: $clk_core_skew ns"
puts "  SNN Clock Skew: $clk_snn_skew ns"

# Write comprehensive STA report
set f [open "sta_postpr.rpt" w]
puts $f "POST-P&R STATIC TIMING ANALYSIS REPORT"
puts $f "======================================="
puts $f "Design: xcew_top"
puts $f "Date: [date]"
puts $f ""
puts $f "1. TIMING ANALYSIS SUMMARY"
puts $f "   Setup WNS: $wns_setup ns"
puts $f "   Hold WNS: $wns_hold ns"
puts $f "   Overall WNS: $wns ns"
puts $f "   Setup TNS: $total_negative_slack_setup ns"
puts $f "   Hold TNS: $total_negative_slack_hold ns"
puts $f "   Overall TNS: $tns ns"
puts $f ""
puts $f "2. CLOCK ANALYSIS"
puts $f "   Core Clock (250MHz): Skew = $clk_core_skew ns"
puts $f "   SNN Clock (125MHz): Skew = $clk_snn_skew ns"
puts $f ""
puts $f "3. CONSTRAINT CHECKS"
puts $f "   WNS Target: >= -0.1ns"
puts $f "   TNS Target: >= -0.5ns"
puts $f "   Skew Target: < 0.2ns"
puts $f ""
puts $f "4. RESULT"
set wns_ok [expr {$wns >= -0.1 ? "PASS" : "FAIL"}]
set tns_ok [expr {$tns >= -0.5 ? "PASS" : "FAIL"}]
set skew_ok [expr {($clk_core_skew < 0.2 && $clk_snn_skew < 0.2) ? "PASS" : "FAIL"}]
puts $f "   WNS Check: $wns_ok (Actual: $wns ns)"
puts $f "   TNS Check: $tns_ok (Actual: $tns ns)"
puts $f "   Skew Check: $skew_ok"
puts $f ""
puts $f "5. STATUS: [expr {$wns_ok == "PASS" && $tns_ok == "PASS" && $skew_ok == "PASS" ? "PASSED" : "FAILED"}]"
close $f

# Run DRC check with Magic
puts "Running DRC check with Magic..."
set drc_cmd "magic -dnull -noconsole -rcfile tsmc130nm.magicrc << EOF
gds read xcew_final.gds
tech tsmc130nm
drc euclidean on
drc style drc(full)
drc check
drc report drc_clean.log
drc stats
quit
EOF"

set magic_result [catch {exec sh -c $drc_cmd} magic_output]
if {$magic_result == 0} {
    puts "Magic DRC completed successfully"

    # Check DRC violations
    set drc_file [open "drc_clean.log" r]
    set drc_content [read $drc_file]
    close $drc_file

    # Extract violation count
    if {[regexp {violations = ([0-9]+)} $drc_content match count]} {
        set drc_violations $count
    } else {
        set drc_violations -1
    }

    puts "DRC Violations Found: $drc_violations"
} else {
    puts "ERROR: Magic DRC failed with output: $magic_output"
    set drc_violations -1
}

# Run LVS check with Netgen
puts "Running LVS check with Netgen..."
set lvs_cmd "netgen -batch << EOF
readnet spice xcew_final.pex xcew_extracted
readnet verilog ../syn/reports/xcew_netlist.v xcew_schematic
compare xcew_extracted xcew_schematic
quit
EOF"

set netgen_result [catch {exec sh -c $lvs_cmd} netgen_output]
if {$netgen_result == 0} {
    puts "Netgen LVS completed"

    # Check if LVS passes
    set lvs_passed [string match "*match*" $netgen_output]
    puts "LVS Match Status: [expr {$lvs_passed ? "PASS" : "FAIL"}]"
} else {
    puts "ERROR: Netgen LVS failed with output: $netgen_output"
    set lvs_passed false
}

# Write DRC/LVS summary
set g [open "drc_lvs_summary.rpt" w]
puts $g "DRC/LVS SIGNOFF SUMMARY"
puts $g "======================="
puts $g "Design: xcew_top"
puts $g "Date: [date]"
puts $g ""
puts $g "1. DRC CHECK"
puts $g "   Tool: Magic"
puts $g "   Violations: $drc_violations (Target: 0)"
puts $g "   Status: [expr {$drc_violations == 0 ? "PASS" : "FAIL"}]"
puts $g ""
puts $g "2. LVS CHECK"
puts $g "   Tool: Netgen"
puts $g "   Schematic vs Layout: [expr {$lvs_passed ? "MATCH" : "MISMATCH"}]"
puts $g "   Status: [expr {$lvs_passed ? "PASS" : "FAIL"}]"
puts $g ""
puts $g "3. OVERALL SIGNOFF STATUS: [expr {$drc_violations == 0 && $lvs_passed ? "PASS" : "FAIL"}]"
close $g

# Create final signoff summary
set h [open "signoff_postpr_summary.rpt" w]
puts $h "XCEW PROCESSOR POST-P&R SIGNOFF VERIFICATION"
puts $h "============================================"
puts $h "Design: xcew_top"
puts $h "Process: TSMC 130nm"
puts $h "Date: [date]"
puts $h ""
puts $h "TIMING RESULTS:"
puts $h "  WNS: $wns ns (Target: >= -0.1ns) -> [expr {$wns >= -0.1 ? "PASS" : "FAIL"}]"
puts $h "  TNS: $tns ns (Target: >= -0.5ns) -> [expr {$tns >= -0.5 ? "PASS" : "FAIL"}]"
puts $h "  Clock Skew (Core): $clk_core_skew ns (Target: < 0.2ns) -> [expr {$clk_core_skew < 0.2 ? "PASS" : "FAIL"}]"
puts $h "  Clock Skew (SNN): $clk_snn_skew ns (Target: < 0.2ns) -> [expr {$clk_snn_skew < 0.2 ? "PASS" : "FAIL"}]"
puts $h ""
puts $h "PHYSICAL VERIFICATION RESULTS:"
puts $h "  DRC Violations: $drc_violations (Target: 0) -> [expr {$drc_violations == 0 ? "PASS" : "FAIL"}]"
puts $h "  LVS Match: [expr {$lvs_passed ? "YES" : "NO"}] (Target: YES) -> [expr {$lvs_passed ? "PASS" : "FAIL"}]"
puts $h ""
puts $h "OVERALL STATUS: [expr {$wns >= -0.1 && $tns >= -0.5 && $clk_core_skew < 0.2 && $clk_snn_skew < 0.2 && $drc_violations == 0 && $lvs_passed ? "SIGNOFF PASSED" : "SIGNOFF FAILED"}]"
close $h

puts "Post-P&R signoff verification completed!"
puts "Reports saved to pnr/ directory:"
puts "  - sta_postpr.rpt (Timing Analysis)"
puts "  - drc_clean.log (DRC Report)"
puts "  - drc_lvs_summary.rpt (DRC/LVS Summary)"
puts "  - signoff_postpr_summary.rpt (Overall Summary)"