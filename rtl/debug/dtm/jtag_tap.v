// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// jtag_tap.v
// IEEE 1149.1 TAP Controller for Debug Module
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module jtag_tap (
    input  wire        tck,
    input  wire        tms,
    input  wire        tdi,
    output wire        tdo,
    input  wire        trst_n,
    // TAP state outputs
    output reg         shift_dr,
    output reg         update_dr,
    output reg         capture_dr,
    output reg         select_dr_scan,
    output reg         run_test_idle,
    // IR register
    output reg  [4:0]  ir_reg,
    // Bypass register
    output reg         bypass_reg
);

    // TAP state encoding
    localparam S_RESET         = 4'h0,
               S_IDLE          = 4'h1,
               S_SELECT_DR     = 4'h2,
               S_CAPTURE_DR    = 4'h3,
               S_SHIFT_DR      = 4'h4,
               S_EXIT1_DR      = 4'h5,
               S_PAUSE_DR      = 4'h6,
               S_EXIT2_DR      = 4'h7,
               S_UPDATE_DR     = 4'h8,
               S_SELECT_IR     = 4'h9,
               S_CAPTURE_IR    = 4'hA,
               S_SHIFT_IR      = 4'hB,
               S_EXIT1_IR      = 4'hC,
               S_PAUSE_IR      = 4'hD,
               S_EXIT2_IR      = 4'hE,
               S_UPDATE_IR     = 4'hF;

    reg [3:0] state, next_state;
    reg [4:0] ir_shift_reg;
    reg       tdo_reg;

    // TAP state machine
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            state <= S_RESET;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_RESET:       next_state = tms ? S_RESET : S_IDLE;
            S_IDLE:        next_state = tms ? S_SELECT_DR : S_IDLE;
            S_SELECT_DR:   next_state = tms ? S_SELECT_IR : S_CAPTURE_DR;
            S_CAPTURE_DR:  next_state = tms ? S_EXIT1_DR : S_SHIFT_DR;
            S_SHIFT_DR:    next_state = tms ? S_EXIT1_DR : S_SHIFT_DR;
            S_EXIT1_DR:    next_state = tms ? S_UPDATE_DR : S_PAUSE_DR;
            S_PAUSE_DR:    next_state = tms ? S_EXIT2_DR : S_PAUSE_DR;
            S_EXIT2_DR:    next_state = tms ? S_UPDATE_DR : S_SHIFT_DR;
            S_UPDATE_DR:   next_state = tms ? S_SELECT_DR : S_IDLE;
            S_SELECT_IR:   next_state = tms ? S_RESET : S_CAPTURE_IR;
            S_CAPTURE_IR:  next_state = tms ? S_EXIT1_IR : S_SHIFT_IR;
            S_SHIFT_IR:    next_state = tms ? S_EXIT1_IR : S_SHIFT_IR;
            S_EXIT1_IR:    next_state = tms ? S_UPDATE_IR : S_PAUSE_IR;
            S_PAUSE_IR:    next_state = tms ? S_EXIT2_IR : S_PAUSE_IR;
            S_EXIT2_IR:    next_state = tms ? S_UPDATE_IR : S_SHIFT_IR;
            S_UPDATE_IR:   next_state = tms ? S_SELECT_DR : S_IDLE;
            default:       next_state = S_RESET;
        endcase
    end

    // Output control signals
    always @(*) begin
        shift_dr       = (state == S_SHIFT_DR);
        update_dr      = (state == S_UPDATE_DR);
        capture_dr     = (state == S_CAPTURE_DR);
        select_dr_scan = (state == S_SELECT_DR);
        run_test_idle  = (state == S_IDLE);
    end

    // IR shift register
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            ir_reg     <= 5'h1F; // BYPASS
            ir_shift_reg <= 5'h1F;
        end else begin
            if (state == S_CAPTURE_IR) begin
                ir_shift_reg <= 5'h01; // Capture IDCODE instruction
            end else if (state == S_SHIFT_IR) begin
                ir_shift_reg <= {tdi, ir_shift_reg[4:1]};
            end else if (state == S_UPDATE_IR) begin
                ir_reg <= ir_shift_reg;
            end
        end
    end

    // Bypass register (1-bit)
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            bypass_reg <= 1'b0;
        end else if (state == S_SHIFT_DR && ir_reg == 5'h1F) begin
            bypass_reg <= tdi;
        end
    end

    // TDO output mux
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tdo_reg <= 1'b0;
        end else begin
            case (state)
                S_SHIFT_IR: tdo_reg <= ir_shift_reg[0];
                S_SHIFT_DR: begin
                    case (ir_reg)
                        5'h1F: tdo_reg <= bypass_reg; // BYPASS
                        default: tdo_reg <= 1'b0;     // Other DRs handled by jtag_dr
                    endcase
                end
                default: tdo_reg <= 1'b0;
            endcase
        end
    end

    assign tdo = tdo_reg;

endmodule