// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// snn_fv.sv — formal property wrapper for snn_tile_256 (tapeout audit §1.3c).
// NUM_NEURONS=4 keeps BMC tractable (as the original snn.sby intended).
// Immediate-assertion style; temporal properties use $past. SVA lives HERE,
// not in the Verilog-2001 RTL; not in rtl/rtl_list.f.
//
// Properties (5):
//   P1  o_ready is asserted only in the IDLE state.
//   P2  o_done is asserted exactly the cycle after the DONE state.
//   P3  classify_en in IDLE advances to LOAD next cycle.
//   P4  the winning class index is in range (< NUM_NEURONS) when done.
//   P5  the neuron scan counter never exceeds NUM_NEURONS.
module snn_fv (
    input  wire        i_clk_snn,
    input  wire        i_rst,
    input  wire        i_classify_en,
    input  wire        i_ttfs_enable,
    input  wire [2:0]  i_t_window,
    input  wire [2:0]  i_refractory_cycles,
    input  wire [31:0] i_v_threshold,
    input  wire [31:0] i_v_rest,
    input  wire [31:0] i_input_current,
    input  wire [7:0]  i_neuron_idx,
    input  wire        i_current_valid
);
    localparam NN = 4;
    wire [7:0]    o_class;
    wire [15:0]   o_conf;
    wire          o_done;
    wire          o_ready;
    wire [2:0]    o_dbg_state;
    wire [8:0]    o_dbg_scan_counter;
    wire [NN-1:0] o_spike_outs;
    wire [NN-1:0] o_spike_valids;

    snn_tile_256 #(.NUM_NEURONS(NN)) dut (
        .i_clk_snn(i_clk_snn), .i_rst(i_rst), .i_classify_en(i_classify_en),
        .i_ttfs_enable(i_ttfs_enable), .i_t_window(i_t_window),
        .i_refractory_cycles(i_refractory_cycles), .i_v_threshold(i_v_threshold),
        .i_v_rest(i_v_rest), .i_input_current(i_input_current),
        .i_neuron_idx(i_neuron_idx), .i_current_valid(i_current_valid),
        .o_class(o_class), .o_conf(o_conf), .o_done(o_done), .o_ready(o_ready),
        .o_dbg_state(o_dbg_state), .o_dbg_scan_counter(o_dbg_scan_counter),
        .o_spike_outs(o_spike_outs), .o_spike_valids(o_spike_valids)
    );

    // Power-on reset: pin the initial state to the documented reset state
    // (smtbmc leaves async-reset FF init free).
    initial begin
        assume (i_rst);
        assume (o_dbg_state == 3'b000);
        assume (o_dbg_scan_counter == 9'b0);
        assume (!o_done);
        assume (o_class == 8'd0);
    end

    always @(posedge i_clk_snn) begin
        if (!i_rst) begin
            p_ready_in_idle:       assert (!o_ready || (o_dbg_state == 3'b000));
            p_class_in_range:      assert (!o_done  || (o_class < 8'd4));
            p_scan_counter_bounded: assert (o_dbg_scan_counter <= 9'd4);
            if (!$past(i_rst)) begin
                p_done_after_done_state: assert (!o_done ||
                    ($past(o_dbg_state) == 3'b100));
                p_idle_to_load: assert (
                    !($past(i_classify_en) && ($past(o_dbg_state) == 3'b000)) ||
                    (o_dbg_state == 3'b001));
            end
        end
    end
endmodule
