// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// dm_trigger.v
// Trigger Module — 2 hardware breakpoints (mcontrol type 2)
// RISC-V Debug Spec 0.13.2, Section 5.2
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module dm_trigger (
    input  wire        clk,
    input  wire        rst,
    // Trigger register write interface (from debug abstract command)
    input  wire        treg_wr,
    input  wire        treg_rd,  // Read enable
    input  wire [11:0] treg_addr,  // Trigger CSR address
    input  wire [31:0] treg_wdata,
    output reg  [31:0] treg_rdata,
    // Trigger hit output
    output wire        trigger_hit,
    // Instruction fetch observation
    input  wire [31:0] if_pc,
    input  wire        if_valid
);

    // Trigger CSRs (RISC-V Debug Spec)
    localparam CSR_TSELECT  = 12'h7A0;
    localparam CSR_TDATA1   = 12'h7A1;
    localparam CSR_TDATA2   = 12'h7A2;
    localparam CSR_TDATA3   = 12'h7A3;

    // Number of hardware triggers
    localparam NUM_TRIGGERS = 2;

    // mcontrol field definitions
    // tdata1[31:28] = type (2 = mcontrol)
    // tdata1[2] = m (match in M-mode)
    // tdata1[1] = s (match in S-mode)
    // tdata1[0] = u (match in U-mode)
    // tdata1[6] = execute (match on instruction fetch)
    // tdata1[7] = store (match on store)
    // tdata1[8] = load (match on load)
    // tdata1[11:7] = match type (0 = address equal)
    // tdata1[12] = chain
    // tdata1[20] = action (0 = breakpoint exception, 1 = enter debug mode)

    reg [31:0] tdata1 [0:NUM_TRIGGERS-1];
    reg [31:0] tdata2 [0:NUM_TRIGGERS-1];
    reg [31:0] tdata3 [0:NUM_TRIGGERS-1];
    reg [1:0]  tselect;

    // Trigger select register
    always @(posedge clk or posedge rst) begin
        if (rst)
            tselect <= 2'b00;
        else if (treg_wr && treg_addr == CSR_TSELECT)
            tselect <= treg_wdata[1:0];
    end

    // Trigger data registers (write via tselect)
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < NUM_TRIGGERS; i = i + 1) begin
                tdata1[i] <= 32'h20001000;  // type=2 (mcontrol), m=1 (M-mode match)
                tdata2[i] <= 32'h00000000;
                tdata3[i] <= 32'h00000000;
            end
        end else if (treg_wr) begin
            case (treg_addr)
                CSR_TDATA1: tdata1[tselect] <= treg_wdata;
                CSR_TDATA2: tdata2[tselect] <= treg_wdata;
                CSR_TDATA3: tdata3[tselect] <= treg_wdata;
                CSR_TSELECT: tselect <= treg_wdata[1:0];
            endcase
        end
    end

    // Read interface (updated to use treg_rd enable)
    always @(*) begin
        if (treg_rd) begin
            case (treg_addr)
                CSR_TSELECT: treg_rdata = {30'b0, tselect};
                CSR_TDATA1:  treg_rdata = tdata1[tselect];
                CSR_TDATA2:  treg_rdata = tdata2[tselect];
                CSR_TDATA3:  treg_rdata = tdata3[tselect];
                default:     treg_rdata = 32'h0;
            endcase
        end else begin
            treg_rdata = 32'h0;
        end
    end

    // Trigger match logic
    reg [NUM_TRIGGERS-1:0] match;
    integer j;
    always @(*) begin
        for (j = 0; j < NUM_TRIGGERS; j = j + 1) begin
            // Match if: type==2, execute==1, m==1, and PC matches tdata2
            match[j] = (tdata1[j][31:28] == 4'd2) &&  // type=mcontrol
                       tdata1[j][2] &&                  // M-mode match
                       tdata1[j][6] &&                  // execute match
                       if_valid &&
                       (if_pc == tdata2[j]);             // address match
        end
    end

    assign trigger_hit = |match;

endmodule
