// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/isa_tb.v
// Directed RV32I ALU-completeness / load-use / branch test (tapeout audit §2.3).
// Loads assembled tb/asm/isa.hex; checks the register file.
`timescale 1ns/1ps

module isa_tb;
    reg clk = 0, rst = 1;
    wire [31:0] pc; reg [31:0] instr;
    wire [31:0] mem_addr, mem_wdata; wire mem_we; wire [3:0] mem_wstrb;
    reg  [31:0] mem_rdata;
    wire [11:0] csr_addr; wire csr_wr_en; wire [31:0] csr_wr_data;
    reg  [31:0] csr_rd_data = 0;
    wire [31:0] o_xcew_req; wire o_xcew_valid; wire [31:0] o_rs1, o_rs2;
    wire wb_stall, exception, interrupt;
    integer errors = 0;

    riscv_core uut (
        .clk(clk), .rst(rst), .pc(pc), .instr(instr),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_we(mem_we),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .csr_addr(csr_addr), .csr_wr_en(csr_wr_en), .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),
        .i_meip(1'b0), .i_mtip(1'b0), .i_msip(1'b0),
        .o_xcew_req(o_xcew_req), .o_xcew_valid(o_xcew_valid),
        .i_xcew_ready(1'b1), .i_xcew_resp(32'h0), .i_xcew_done(1'b0),
        .o_rs1_data(o_rs1), .o_rs2_data(o_rs2),
        .wb_stall(wb_stall), .exception(exception), .interrupt(interrupt)
    );
    always #5 clk = ~clk;

    reg [31:0] irom [0:255]; integer k;
    initial begin
        for (k = 0; k < 256; k = k + 1) irom[k] = 32'h00000013;
        $readmemh("tb/asm/isa.hex", irom);
    end
    always @(*) instr = irom[pc[31:2]];

    reg [31:0] dram [0:255]; wire [7:0] didx = mem_addr[9:2];
    initial for (k = 0; k < 256; k = k + 1) dram[k] = 32'h0;
    always @(*) mem_rdata = dram[didx];
    always @(posedge clk) if (mem_we) begin
        if (mem_wstrb[0]) dram[didx][7:0]   <= mem_wdata[7:0];
        if (mem_wstrb[1]) dram[didx][15:8]  <= mem_wdata[15:8];
        if (mem_wstrb[2]) dram[didx][23:16] <= mem_wdata[23:16];
        if (mem_wstrb[3]) dram[didx][31:24] <= mem_wdata[31:24];
    end

    task chk; input [88:0] nm; input [4:0] r; input [31:0] exp; begin
        if (uut.regfile[r] === exp) $display("PASS: x%0d %0s = 0x%08h", r, nm, exp);
        else begin $display("FAIL: x%0d %0s = 0x%08h (expected 0x%08h)", r, nm, uut.regfile[r], exp); errors=errors+1; end
    end endtask

    initial begin
        $dumpfile("isa_tb.vcd"); $dumpvars(0, isa_tb);
        #20 rst = 0;
        #800;
        $display("--- isa_tb: register checks ---");
        chk("sltu 1<u -1",   5,  32'd1);
        chk("sltu 0<u 1",    7,  32'd1);
        chk("sltiu 1<u 5",   11, 32'd1);
        chk("slt -1<s 1",    6,  32'd1);
        chk("srai -16>>a2",  8,  32'hFFFFFFFC);
        chk("srli -16>>l2",  9,  32'h3FFFFFFC);
        chk("sra -16>>a1",   10, 32'hFFFFFFF8);
        chk("xori ^-1",      13, 32'hFFFFFFFE);
        chk("load-use -16+1",15, 32'hFFFFFFF1);
        chk("BGE flush",     20, 32'h00000111);
        chk("BLTU flush",    21, 32'h00000222);
        chk("BGEU flush",    22, 32'h00000333);
        chk("auipc pc-rel d4",25, 32'd4);
        chk("jalr skip->P+16",29, 32'h00000077);
        chk("jalr skipped x28",28, 32'h00000000);
        if (exception) begin $display("FAIL: unexpected exception"); errors=errors+1; end
        $display("\n=== isa_tb: %0d error(s) ===", errors);
        if (errors != 0) $fatal(1, "isa test failed");
        $finish;
    end
endmodule
