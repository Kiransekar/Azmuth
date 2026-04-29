# Configuration for Xcew Processor Design
# Based on Sky130 process technology

# Design name and top module
export DESIGN_NICKNAME = xcew
export DESIGN_NAME = xcew_top_v1_1
export PLATFORM = sky130hd

# Source files
export VERILOG_FILES = /work/syn/reports/xcew_netlist.v
export SDC_FILE = /work/syn/sdc_final.sdc

# Include files
export ADDITIONAL_LIBS =

# These values must be multiples of the site width and height
export DIE_AREA = 0 0 1000 1000
export CORE_AREA = 10 10 990 990

# Cell padding
export CELL_PAD_IN_SITES_X = 4
export CELL_PAD_IN_SITES_Y = 4

# Power specification
export VDD_PIN = VPWR
export GND_PIN = VGND
export VDD_NETS = {VPWR VDD}
export GND_NETS = {VGND VSS}

# Clock specification
export CLOCK_PERIOD = 4.0
export CLOCK_PORT = i_clk
export CLOCK_NET = i_clk

# IO Placement
export PLACE_PINS_TOP = 0
export PLACE_PINS_BOTTOM = 1
export PLACE_PINS_LEFT = 0
export PLACE_PINS_RIGHT = 0

# Macro placement
export MACRO_PLACEMENT_CFG =

# CTS Options
export CTS_SINK_CLUSTERING_SIZE = 16
export CTS_SINK_CLUSTERING_MAX_DIAMETER = 50

# Routing layer specifications
export MIN_ROUTING_LAYER = met1
export MAX_ROUTING_LAYER = met5

# Metal fill
export METAL_FILL = 1

# Power grid parameters
export ODB_PYTHON_POWER_GRID_TCL =

# Diode insertion
export DISABLE_DENSITY_CHECK = 1

# Synthesis options
export HLS_CATCH_UNCAUGHT_SIGNALS = 0

# Enable custom routing
export CUSTOM_ROUTE_LOWER_METAL_LIMIT = 2
export CUSTOM_ROUTE_UPPER_METAL_LIMIT = 5

# Additional parameters for the Xcew processor
export FP_PDN_CORE_RING = 1
export FP_PDN_CORE_RING_VWIDTH = 1.0
export FP_PDN_CORE_RING_HWIDTH = 1.0
export FP_PDN_RAIL_WIDTH = 0.2
export FP_PDN_RAIL_OFFSET = 0.0
export FP_PDN_VWIDTH = 1.2
export FP_PDN_HWIDTH = 1.2
export FP_PDN_VPITCH = 100.0
export FP_PDN_HPITCH = 100.0
export FP_PDN_VOFFSET = 5.0
export FP_PDN_HOFFSET = 5.0

# Double the default core utilization to account for neural processing units
export FP_CORE_UTIL = 50
export FP_ASPECT_RATIO = 1.0
export FP_ORIENTATION = N