// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/riscof/azmuth_riscof_tb.v
// RISCOF DUT harness: unified (von Neumann) word memory loaded from a flat-binary
// hex; runs riscv_core until the test stores to `tohost`, then dumps the
// signature region [begin_signature, end_signature) one 32-bit word per line.
// Plusargs: +hex=<file> +begin=<hex> +end=<hex> +tohost=<hex> +sig=<file>
`timescale 1ns/1ps

module azmuth_riscof_tb;
    localparam [31:0] BASE = 32'h80000000; // memory window base (matches link.ld)
    localparam MEMW = 1048576;  // 4 MB word memory: jal-01 links its signature
                                // ~1.7 MB above base (large JAL-range padding),
                                // so a 1 MB window wrapped its tohost write and
                                // the halt never fired (jal-01 ERROR(dut)).

    reg clk = 0, rst = 1;
    wire [31:0] pc; wire [31:0] instr;
    wire [31:0] mem_addr, mem_wdata; wire mem_we; wire [3:0] mem_wstrb;
    wire [31:0] mem_rdata;
    wire [11:0] csr_addr; wire csr_wr_en; wire [31:0] csr_wr_data;
    wire [31:0] o_xcew_req; wire o_xcew_valid; wire [31:0] o_rs1, o_rs2;
    wire wb_stall, exception, interrupt;

    reg [31:0] mem [0:MEMW-1];
    reg [1023:0] hexfile, sigfile;
    reg [31:0] begin_addr, end_addr, tohost_addr;
    integer i, fd;

    riscv_core #(.RESET_PC(BASE)) uut (
        .clk(clk), .rst(rst), .pc(pc), .instr(instr),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_we(mem_we),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .csr_addr(csr_addr), .csr_wr_en(csr_wr_en), .csr_wr_data(csr_wr_data),
        .csr_rd_data(32'h0),
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

    // Unified memory windowed at BASE: word index = (addr - BASE) >> 2
    wire [31:0] iidx = (pc - BASE) >> 2;
    wire [31:0] didx = (mem_addr - BASE) >> 2;
    assign instr     = mem[iidx[19:0]];
    assign mem_rdata = mem[didx[19:0]];
    always @(posedge clk) begin
        if (mem_we) begin
            if (mem_wstrb[0]) mem[didx[19:0]][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) mem[didx[19:0]][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) mem[didx[19:0]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) mem[didx[19:0]][31:24] <= mem_wdata[31:24];
        end
    end

    task dump_signature;
        integer a;
        begin
            fd = $fopen(sigfile, "w");
            for (a = begin_addr; a < end_addr; a = a + 4)
                $fwrite(fd, "%08x\n", mem[((a - BASE) >> 2)]);
            $fclose(fd);
            $display("RISCOF: signature [%08h,%08h) -> %0s", begin_addr, end_addr, sigfile);
        end
    endtask

    // Halt on a store to tohost
    always @(posedge clk) begin
        if (!rst && mem_we && (mem_addr == tohost_addr)) begin
            $display("RISCOF: tohost write detected at cycle, halting");
            dump_signature;
            $finish;
        end
    end

    initial begin
        for (i = 0; i < MEMW; i = i + 1) mem[i] = 32'h0;
        if (!$value$plusargs("hex=%s", hexfile))    begin $display("ERR: +hex= required"); $finish; end
        if (!$value$plusargs("sig=%s", sigfile))    begin $display("ERR: +sig= required"); $finish; end
        if (!$value$plusargs("begin=%h", begin_addr)) begin_addr = 32'h0;
        if (!$value$plusargs("end=%h", end_addr))     end_addr   = 32'h0;
        if (!$value$plusargs("tohost=%h", tohost_addr)) tohost_addr = 32'h0;
        $readmemh(hexfile, mem);
        #20 rst = 0;
    end

    // Safety timeout
    initial begin
        #200000000;  // 20,000,000 cycles (branch tests run many cases)
        $display("RISCOF: TIMEOUT (no tohost write) — dumping partial signature");
        dump_signature;
        $finish;
    end

endmodule
