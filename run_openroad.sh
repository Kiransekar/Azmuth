docker run --rm -v /home/kiran-sekar/NeuroRiscV:/work -w /work openroad/orfs bash -c "
export PDK_ROOT=/OpenROAD-flow-scripts/pdks/sky130A
export PDK=sky130A
export STD_CELL_LIBRARY=sky130_fd_sc_hd
export DESIGN_NAME=xcew_top_v1_1
export FLOW_HOME=/OpenROAD-flow-scripts
cd $FLOW_HOME
./flow.tcl -design $DESIGN_NAME -pdk $PDK -flow_path /work/pnr
"
