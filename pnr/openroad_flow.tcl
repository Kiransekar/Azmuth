# pnr/openroad_flow.tcl
# OpenROAD Physical Implementation Flow for Xcew Processor
# TSMC 130nm process, targeting 18mm² maximum area

# Initialize OpenROAD environment
set ::env(DESIGN_NAME) "xcew_top_v1_1"
set ::env(PDK) "sky130A"  ;# Using sky130 as proxy for 130nm
set ::env(STD_CELL_LIBRARY) "sky130_fd_sc_hd"
set ::env(CLOCK_PERIOD) 4.0  ;# 250MHz clock
set ::env(CLOCK_PORT) "i_clk"

# Set die area (4.2mm x 4.2mm = 17.64 mm², leaving margin under 18mm²)
set ::env(DIE_AREA) "0 0 4200 4200"  ;# in microns (µm)
set ::env(FP_SIZING) "absolute"
set ::env(FP_CORE_UTIL) 45  ;# Moderate utilization for routing
set ::env(FP_ASPECT_RATIO) 1.0
set ::env(FP_MERGE_ZERO_RC) 1

# Power grid configuration
set ::env(VDD_NETS) [list {VPWR VDD}]
set ::env(GND_NETS) [list {VGND VSS}]
set ::env(RT_MAX_LAYER) "met4"
set ::env(RT_MIN_LAYER) "met1"

# Power domain specifications
# Core/EML: 1.2V
# SNN: 0.9V (requires voltage island)
# IO/NVM: 1.8V (IO power)

# Floorplan stage
proc init_floorplan { } {
    global env

    # Create core and die areas
    set ::env(FP_SIZING) "absolute"
    set ::env(DIE_AREA) "0 0 4200 4200"

    # Core area with margin from die edge
    set ::env(CORE_MARGIN) 10
    set ::env(CORE_AREA) "10 10 4190 4190"

    # Define power domains
    # Core domain (1.2V)
    set core_bbox [list 50 50 3000 3000]

    # SNN domain (0.9V) - voltage island
    set snn_bbox [list 3050 50 4150 1500]

    # NVM domain (1.8V) - closer to IO
    set nvm_bbox [list 3050 1550 4150 4150]

    # Place macros in designated regions
    # SRAM macros in EML region within core
    set eml_region [list 100 100 1500 1500]

    # NVM macros in bottom right
    set nvm_region [list 3100 1600 4100 4100]

    # Set up power domain constraints
    puts "Setting up floorplan for Xcew Processor..."
}

# Power grid configuration
proc setup_power_grid { } {
    global env

    # Primary power rails
    set ::env(DESIGN_IS_CORE) 0
    set ::env(FP_PDN_CORE_RING) 1
    set ::env(FP_PDN_CORE_RING_VWIDTH) 1.0
    set ::env(FP_PDN_CORE_RING_HWIDTH) 1.0
    set ::env(FP_PDN_CORE_RING_VSPACING) 0.5
    set ::env(FP_PDN_CORE_RING_HSPACING) 0.5
    set ::env(FP_PDN_CORE_RING_VOFFSET) 5.0
    set ::env(FP_PDN_CORE_RING_HOFFSET) 5.0

    # Power straps (mesh) on higher metal layers
    set ::env(FP_PDN_VWIDTH) 1.2
    set ::env(FP_PDN_HWIDTH) 1.2
    set ::env(FP_PDN_VSPACING) 0.8
    set ::env(FP_PDN_HSPACING) 0.8
    set ::env(FP_PDN_PITCH) 100.0
    set ::env(FP_PDN_OFFSET) 0.0

    # Layer-specific power grid
    set ::env(FP_PDN_ENABLE_RAILS) 0

    puts "Setting up power grid for Xcew Processor..."
}

# IO placement
proc place_io { } {
    global env

    # Define IO placement constraints
    set ::env(FP_IO_MODE) "horizontal"
    set ::env(FP_IO_VTHICKNESS_MULT) 2
    set ::env(FP_IO_HTHICKNESS_MULT) 2

    # Define IO pins - clock, reset, JTAG, etc.
    set io_pins [list \
        "i_clk i_clk_snn i_rst" \
        "o_irq o_debug_uart" \
        "jtag_tck jtag_tms jtag_tdi jtag_tdo" \
        "spi_clk spi_mosi spi_miso spi_cs" \
        "adc_iq_p adc_iq_n rf_clk" \
    ]

    puts "Placing IO for Xcew Processor..."
}

# Macro placement
proc place_macros { } {
    global env

    # Place memory macros with proper spacing
    # SRAM macros for EML unit
    set_macro_placement_constraints -name "sram_eml" -orientation R0 -region {200 200 800 600}

    # SNN tile memories
    set_macro_placement_constraints -name "snn_mem" -orientation R0 -region {3100 100 3800 1400}

    # NVM macros
    set_macro_placement_constraints -name "nvm_array" -orientation R0 -region {3200 1600 4000 4000}

    # Macro utilization constraints (<75%)
    set ::env(FP_MACRO_HORIZONTAL_HALO) 10.0
    set ::env(FP_MACRO_VERTICAL_HALO) 10.0

    puts "Placing macros for Xcew Processor..."
}

# CTS (Clock Tree Synthesis) configuration
proc setup_cts { } {
    global env

    # Dual-clock tree for core (250MHz) and SNN (125MHz)
    set ::env(CLOCK_PERIOD) 4.0  ;# Core clock 250MHz
    set ::env(CLOCK_TREE_SYNTH) 1
    set ::env(CTS_SINK_CLUSTERING_SIZE) 20
    set ::env(CTS_SINK_CLUSTERING_MAX_DIAMETER) 100
    set ::env(CTS_CLK_MAX_WIRE_LENGTH) 1000
    set ::env(CTS_DISABLE_POST_PROCESSING) 0
    set ::env(CTS_DISTANCE_BETWEEN_BUFFERS) 200
    set ::env(CTS_CELLS) "sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_4"

    # SNN clock tree (125MHz) - separate
    set ::env(CLOCK_PERIOD_SNN) 8.0
    set ::env(CTS_ROOT_BUFFER) "sky130_fd_sc_hd__clkbuf_16"

    # Skew constraints
    set ::env(CTS_TARGET_SKEW) 0.2  ;# <0.2ns
    set ::env(CTS_MAX_CAP) 1.0

    puts "Setting up CTS for Xcew Processor dual-clock system..."
}

# Routing configuration
proc setup_routing { } {
    global env

    # Use minimum 4 metal layers
    set ::env(GLB_RT_ALLOW_CONGESTION) 0
    set ::env(GLB_RT_OVERFLOW_ITERS) 50
    set ::env(GLB_RT_L1_ADJUSTMENT) 0.9
    set ::env(GLB_RT_L2_ADJUSTMENT) 0.8
    set ::env(GLB_RT_L3_ADJUSTMENT) 0.7
    set ::env(GLB_RT_L4_ADJUSTMENT) 0.6
    set ::env(GLB_RT_MIN_LAYER) "met1"
    set ::env(GLB_RT_MAX_LAYER) "met4"

    # Antenna rule compliance
    set ::env(GLB_RT_ANT_ITERS) 5
    set ::env(GLB_RT_ANT_MARGIN) 10

    # DRC clean routing
    set ::env(GLB_RT_LAYER_ADJUSTMENTS) "0.99 0 0 0 0"

    puts "Setting up routing for Xcew Processor..."
}

# Execute the flow
puts "Starting OpenROAD Physical Implementation for Xcew Processor..."

# Read design
read_liberty "sky130_fd_sc_hd__tt_025C_1v80.lib"
read_lef "sky130_fd_sc_hd.lef"
read_verilog "../syn/reports/xcew_netlist.v"
link_design $::env(DESIGN_NAME)

# Floorplan
init_floorplan
place_io
place_macros

# Place
puts "Running global placement..."
global_placement -density 0.5
puts "Running detailed placement..."
detailed_placement

# Power grid
setup_power_grid

# Clock tree synthesis
setup_cts

puts "Running clock tree synthesis..."
clock_tree_synthesis -lut_file cts/cts_250MHz.lut -root_buf sky130_fd_sc_hd__clkbuf_16

puts "Running clock tree synthesis for SNN domain..."
clock_tree_synthesis -lut_file cts/cts_125MHz.lut -root_buf sky130_fd_sc_hd__clkbuf_16 -clk_nets i_clk_snn

# Route
puts "Running global route..."
global_route

puts "Running detailed route..."
detailed_route

# Parasitic extraction
puts "Extracting parasitics..."
extract_parasitics -ext_model_file rcx/sky130.ext -parameterized

# Generate outputs
puts "Writing DEF file..."
write_def "pnr/xcew_final.def"

puts "Writing LEF file..."
write_lef "pnr/xcew_final.lef"

puts "Writing SDC (post-P&R)..."
write_sdc "pnr/xcew_post_pnr.sdc"

puts "Writing SPEF (parasitics)..."
write_spef "pnr/xcew_parasitics.spef"

puts "Writing GDSII..."
write_gds "pnr/xcew_final.gds"

puts "OpenROAD Physical Implementation completed successfully!"
puts "Outputs saved to pnr/ directory:"
puts "  - xcew_final.def (Design Exchange Format)"
puts "  - xcew_final.lef (Library Exchange Format)"
puts "  - xcew_post_pnr.sdc (Post-P&R Timing Constraints)"
puts "  - xcew_parasitics.spef (Parasitic Extraction Format)"
puts "  - xcew_final.gds (GDSII Stream Format)"