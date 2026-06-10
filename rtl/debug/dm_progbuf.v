// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// dm_progbuf.v
// Program buffer for Debug Module (2 words)
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module dm_progbuf (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [1:0]  index,
    input  wire [31:0] wr_data,
    output reg  [31:0] progbuf0,
    output reg  [31:0] progbuf1
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            progbuf0 <= 32'h00000013; // NOP
            progbuf1 <= 32'h00000013; // NOP
        end else if (wr_en) begin
            case (index)
                2'b00: progbuf0 <= wr_data;
                2'b01: progbuf1 <= wr_data;
                default: ;
            endcase
        end
    end

endmodule