// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/hazard_tb.v
// Directed RV32I + Zicsr pipeline/hazard/ISA test (tapeout audit §2.3).
// Loads assembled tb/asm/hazard.hex; checks the register file against expected
// results. Validates RAW chains, ALU ops, branch flush, JAL link, load/store +
// byte-enables, and CSR read-after-write (the DECISION-009 pipeline/trap work).
`timescale 1ns/1ps

module hazard_tb;
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
        // Debug Interface
        .i_dm_halt_req(1'b0),
        .i_dm_resume_req(1'b0),
        .i_dm_reset_req(1'b0),
        .o_dm_halted(),
        .o_dm_running(),
        .o_dm_has_reset(),
        .o_dm_pc(),
        .i_debug_trigger_hit(1'b0),
        .o_csr_dcsr(),
        .o_csr_dpc(),
        .o_csr_dscratch0(),
        .o_csr_dscratch1(),
        .i_dbg_reg_req(1'b0),
        .i_dbg_reg_wr(1'b0),
        .i_dbg_reg_addr(12'h0),
        .i_dbg_reg_wdata(32'h0),
        .o_dbg_reg_rdata(),
        .o_dbg_reg_ack(),
        .o_rs1_data(o_rs1), .o_rs2_data(o_rs2),
        .wb_stall(wb_stall), .exception(exception), .interrupt(interrupt)
    );

    always #5 clk = ~clk;

    // Instruction ROM (loaded from assembled hex)
    reg [31:0] irom [0:255];
    integer k;
    initial begin
        for (k = 0; k < 256; k = k + 1) irom[k] = 32'h00000013; // NOP fill
        $readmemh("tb/asm/hazard.hex", irom);
    end
    always @(*) instr = irom[pc[31:2]];

    // Data RAM with byte-enable writes, combinational read
    reg [31:0] dram [0:255];
    initial for (k = 0; k < 256; k = k + 1) dram[k] = 32'h0;
    wire [7:0] didx = mem_addr[9:2];
    always @(*) mem_rdata = dram[didx];
    always @(posedge clk) begin
        if (mem_we) begin
            if (mem_wstrb[0]) dram[didx][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) dram[didx][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) dram[didx][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) dram[didx][31:24] <= mem_wdata[31:24];
        end
    end

    task chk; input [80:0] nm; input [4:0] r; input [31:0] exp; begin
        if (uut.regfile[r] === exp) $display("PASS: x%0d %0s = 0x%08h", r, nm, exp);
        else begin $display("FAIL: x%0d %0s = 0x%08h (expected 0x%08h)", r, nm, uut.regfile[r], exp); errors=errors+1; end
    end endtask

    initial begin
        $dumpfile("hazard_tb.vcd"); $dumpvars(0, hazard_tb);
        #20 rst = 0;
        #1000;  // run to the spin loop

        $display("--- hazard_tb: register checks ---");
        chk("add 10+20",        5,  32'd30);
        chk("sub 20-10",        6,  32'd10);
        chk("slt 10<20",        19, 32'd1);
        chk("slli 10<<2",       18, 32'd40);
        chk("lui",              14, 32'h12345000);
        chk("lw word",          11, 32'h12345678);
        chk("sb byte-enable",   12, 32'hFFFFFFAB);
        chk("csr mscratch r/w", 16, 32'h0000CAFE);
        chk("BEQ flush",        7,  32'h00000111);
        chk("BNE not-taken",    8,  32'h00000222);
        chk("BLT flush",        9,  32'h00000444);
        chk("JAL flush",        17, 32'h00000333);
        chk("JAL link addr",    10, 32'h00000088);

        if (exception) begin $display("FAIL: unexpected exception"); errors=errors+1; end
        $display("\n=== hazard_tb: %0d error(s) ===", errors);
        if (errors != 0) $fatal(1, "hazard test failed");
        $finish;
    end
endmodule
