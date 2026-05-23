// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/riscv_core_stub.v
// Stub for riscv_core (uses SV 'inside' expressions that iverilog can't handle)

module riscv_core (
    input  wire        clk,
    input  wire        rst,
    output reg [31:0]  pc,
    input  wire [31:0] instr,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        mem_we,
    output wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,
    output wire [11:0] csr_addr,
    output wire        csr_wr_en,
    output wire [31:0] csr_wr_data,
    input  wire [31:0] csr_rd_data,
    output reg [31:0]  o_xcew_req,
    input  wire        i_xcew_ready,
    input  wire [31:0] i_xcew_resp,
    input  wire        i_xcew_done,
    output reg         wb_stall,
    output wire        exception,
    output wire        interrupt
);

    // Simple fetch-loop: increment PC, fetch instruction
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'h0;
            o_xcew_req <= 32'h0;
            wb_stall <= 1'b0;
        end else begin
            pc <= pc + 32'h4;
            o_xcew_req <= 32'h0;
            wb_stall <= 1'b0;
        end
    end

    assign mem_addr    = pc;
    assign mem_wdata   = 32'h0;
    assign mem_we      = 1'b0;
    assign mem_wstrb   = 4'h0;
    assign csr_addr    = 12'h7C0;
    assign csr_wr_en   = 1'b0;
    assign csr_wr_data = 32'h0;
    assign exception   = 1'b0;
    assign interrupt   = 1'b0;

endmodule
