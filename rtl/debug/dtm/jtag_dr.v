// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// jtag_dr.v
// JTAG Data Register for DMI access
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module jtag_dr (
    input  wire        tck,
    input  wire        trst_n,
    input  wire        shift_dr,
    input  wire        update_dr,
    input  wire        capture_dr,
    input  wire        select_dr_scan,
    input  wire [4:0]  ir_reg,
    input  wire        tdi,
    output wire        tdo,
    // DMI interface
    output reg         dmi_req,
    output reg         dmi_wr,
    output reg  [6:0]  dmi_addr,
    output reg  [31:0] dmi_wdata,
    input  wire [31:0] dmi_rdata,
    input  wire        dmi_ack
);

    // JTAG instruction encodings (per RISC-V Debug Spec 0.13.2)
    localparam IR_IDCODE    = 5'h01;
    localparam IR_DTMCS     = 5'h10;
    localparam IR_DMI       = 5'h11;
    localparam IR_BYPASS    = 5'h1F;

    // DTMCS register fields
    localparam DTMCS_VERSION_OFFSET  = 28;
    localparam DTMCS_ABITS_OFFSET    = 4;
    localparam DTMCS_DMISTAT_OFFSET  = 0;

    reg [31:0] idcode_reg;
    reg [31:0] idcode_shift;
    reg [31:0] dtmcs_reg;
    reg [31:0] dtmcs_shift;
    reg [40:0] dmi_shift_reg; // 1 bit op + 7 bits addr + 32 bits data
    reg [6:0]  bit_count;
    reg        dmi_op_started;

    // IDCODE: placeholder value
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            idcode_reg <= 32'h00000001;
            idcode_shift <= 32'h00000000;
        end else if (capture_dr && (ir_reg == IR_IDCODE)) begin
            idcode_shift <= idcode_reg;
        end else if (shift_dr && (ir_reg == IR_IDCODE)) begin
            idcode_shift <= {tdi, idcode_shift[31:1]};
        end
    end

    // DTMCS: version=1 (0.13.2), abits=7, dmistat=0
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dtmcs_reg <= {4'h1, 4'h0, 7'h40, 17'h0}; // version=1, abits=7 (0x40), dmistat=0
            dtmcs_shift <= 32'h0;
        end else if (capture_dr && (ir_reg == IR_DTMCS)) begin
            dtmcs_shift <= dtmcs_reg;
        end else if (shift_dr && (ir_reg == IR_DTMCS)) begin
            dtmcs_shift <= {tdi, dtmcs_shift[31:1]};
        end
    end

    // Bit counter for DMI shift register (41 bits = 1+7+32)
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            bit_count <= 7'h0;
        end else if (select_dr_scan || capture_dr) begin
            bit_count <= 7'h0;
        end else if (shift_dr) begin
            bit_count <= bit_count + 1;
        end
    end

    // DMI shift register
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dmi_shift_reg <= 41'h0;
            dmi_op_started <= 1'b0;
        end else if (capture_dr && (ir_reg == IR_DMI)) begin
            // Capture: load DMI read response
            dmi_shift_reg <= {1'b1, 7'h0, dmi_rdata}; // resp=1 (success), addr=0, data=dmi_rdata
            dmi_op_started <= 1'b0;
        end else if (shift_dr && (ir_reg == IR_DMI)) begin
            dmi_shift_reg <= {tdi, dmi_shift_reg[40:1]};
        end else if (update_dr && (ir_reg == IR_DMI) && !dmi_op_started) begin
            // Update: issue DMI request
            dmi_op_started <= 1'b1;
        end
    end

    // DMI request generation on update_dr
    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dmi_req   <= 1'b0;
            dmi_wr    <= 1'b0;
            dmi_addr  <= 7'h0;
            dmi_wdata <= 32'h0;
        end else begin
            dmi_req <= 1'b0; // default, pulse on update
            if (update_dr && (ir_reg == IR_DMI) && !dmi_op_started) begin
                dmi_req        <= 1'b1;
                dmi_wr         <= dmi_shift_reg[40];     // bit 40 = op (1=write, 0=read)
                dmi_addr       <= dmi_shift_reg[39:33];  // bits 39:33 = address
                dmi_wdata      <= dmi_shift_reg[32:1];   // bits 32:1 = write data
                dmi_op_started <= 1'b1;
            end else if (capture_dr && (ir_reg == IR_DMI)) begin
                dmi_op_started <= 1'b0;  // Reset flag on capture
            end
        end
    end

    // TDO mux
    wire tdo_mux;
    assign tdo_mux = (ir_reg == IR_IDCODE) ? idcode_shift[0] :
                     (ir_reg == IR_DTMCS)  ? dtmcs_shift[0] :
                     (ir_reg == IR_DMI)    ? dmi_shift_reg[0] :
                     1'b0; // BYPASS handled by TAP

    assign tdo = tdo_mux;

endmodule