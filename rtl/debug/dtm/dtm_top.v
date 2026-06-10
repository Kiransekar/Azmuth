// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// dtm_top.v
// Debug Transport Module top-level (TAP + DR + DMI bridge)
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module dtm_top (
    input  wire        tck,
    input  wire        tms,
    input  wire        tdi,
    output wire        tdo,
    input  wire        trst_n,
    // DMI interface to Debug Module
    output wire        dmi_req,
    output wire        dmi_wr,
    output wire [6:0]  dmi_addr,
    output wire [31:0] dmi_wdata,
    input  wire [31:0] dmi_rdata,
    input  wire        dmi_ack,
    // Debug enable strap (sampled at POR)
    input  wire        debug_en
);

    // TAP outputs
    wire shift_dr, update_dr, capture_dr, select_dr_scan, run_test_idle;
    wire [4:0] ir_reg;
    wire tap_tdo;
    wire dr_tdo;

    // TAP controller
    jtag_tap u_tap (
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tap_tdo),
        .trst_n(trst_n & debug_en), // Gate TAP with DEBUG_EN
        .shift_dr(shift_dr),
        .update_dr(update_dr),
        .capture_dr(capture_dr),
        .select_dr_scan(select_dr_scan),
        .run_test_idle(run_test_idle),
        .ir_reg(ir_reg),
        .bypass_reg()
    );

    // Data register
    jtag_dr u_dr (
        .tck(tck),
        .trst_n(trst_n & debug_en),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
        .capture_dr(capture_dr),
        .select_dr_scan(select_dr_scan),
        .ir_reg(ir_reg),
        .tdi(tdi),
        .tdo(dr_tdo),
        .dmi_req(dmi_req),
        .dmi_wr(dmi_wr),
        .dmi_addr(dmi_addr),
        .dmi_wdata(dmi_wdata),
        .dmi_rdata(dmi_rdata),
        .dmi_ack(dmi_ack)
    );

    // TDO mux: DR outputs take priority when in Shift-DR for non-BYPASS instructions
    assign tdo = (shift_dr && (ir_reg != 5'h1F)) ? dr_tdo : tap_tdo;

endmodule