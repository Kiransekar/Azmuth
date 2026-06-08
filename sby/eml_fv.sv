// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// eml_fv.sv — formal property wrapper for eml_unit (tapeout audit §1.3c).
// SVA lives HERE, never in the Verilog-2001 RTL; this file is intentionally
// NOT listed in rtl/rtl_list.f. Used by sby/eml.sby only.
// Immediate-assertion style (open-source Yosys has no concurrent-assertion
// frontend); temporal properties use $past.
//
// Properties (3, matching the audit's eml property budget):
//   P1  o_ready is the strict complement of o_valid (handshake invariant).
//   P2  the exception output is only raised on a completing (valid) result.
//   P3  one cycle after reset the unit presents no valid/exception output.
module eml_fv (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [31:0] i_rs1,
    input  wire [31:0] i_rs2,
    input  wire [31:0] i_cfg,
    input  wire        i_valid
);
    wire [31:0] o_rd;
    wire        o_valid;
    wire        o_ready;
    wire        o_exc;

    eml_unit dut (
        .i_clk(i_clk), .i_rst(i_rst), .i_rs1(i_rs1), .i_rs2(i_rs2),
        .i_cfg(i_cfg), .i_valid(i_valid),
        .o_rd(o_rd), .o_valid(o_valid), .o_ready(o_ready), .o_exc(o_exc)
    );

    // Power-on reset so BMC starts from the defined reset state.
    initial assume (i_rst);

    always @(posedge i_clk) begin
        if (!i_rst) begin
            p_ready_complement:  assert (o_ready == ~o_valid);
            p_exc_implies_valid: assert (!o_exc || o_valid);
        end
        // One cycle after reset deasserts, outputs must be quiescent.
        if (!i_rst && $past(i_rst)) begin
            p_reset_clears_outputs: assert (!o_valid && !o_exc);
        end
    end
endmodule
