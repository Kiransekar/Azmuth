// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/trap_tb.v
// Directed test for M-mode trap / exception / CSR support in riscv_core.
// REQ: REQ-EXC-001, REQ-EXC-002, REQ-CSR (machine), REQ-IRQ-001.
// Closes MICRO_ARCH_SPEC DEV-005 / DEV-009 (exceptions + trap CSRs).
//
// Program: program mtvec, set a marker, ECALL (-> trap), handler reads
// mcause/mepc, advances mepc by 4, MRET back; then a post-return marker.
`timescale 1ns/1ps

module trap_tb;
    reg clk = 0, rst = 1;
    wire [31:0] pc;
    reg  [31:0] instr;
    wire [31:0] mem_addr, mem_wdata; wire mem_we; wire [3:0] mem_wstrb;
    reg  [31:0] mem_rdata = 0;
    wire [11:0] csr_addr; wire csr_wr_en; wire [31:0] csr_wr_data;
    reg  [31:0] csr_rd_data = 0;
    wire [31:0] o_xcew_req; wire o_xcew_valid;
    wire [31:0] o_rs1_data, o_rs2_data;
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
        .o_rs1_data(o_rs1_data), .o_rs2_data(o_rs2_data),
        .wb_stall(wb_stall), .exception(exception), .interrupt(interrupt)
    );

    always #5 clk = ~clk;

    reg [31:0] rom [0:63];
    integer k;
    initial begin
        for (k=0;k<64;k=k+1) rom[k] = 32'h00000013; // NOP (ADDI x0,x0,0)
        // --- main ---
        rom[0] = 32'h04000093; // ADDI x1, x0, 0x40      ; x1 = handler addr (0x40)
        rom[1] = 32'h30509073; // CSRRW x0, mtvec, x1     ; mtvec = 0x40
        rom[2] = 32'h11100293; // ADDI x5, x0, 0x111      ; marker before ecall
        rom[3] = 32'h00000073; // ECALL                   ; -> trap to 0x40, mcause=11
        rom[4] = 32'h22200313; // ADDI x6, x0, 0x222      ; post-return marker (addr 0x10)
        rom[5] = 32'h33300493; // ADDI x9, x0, 0x333
        rom[6] = 32'h0000006F; // JAL x0, 0               ; spin
        // --- handler @ index 16 (addr 0x40) ---
        rom[16] = 32'h342023F3; // CSRRS x7, mcause, x0   ; x7 = mcause (expect 11)
        rom[17] = 32'h34102473; // CSRRS x8, mepc, x0     ; x8 = mepc
        rom[18] = 32'h00440413; // ADDI  x8, x8, 4        ; mepc + 4
        rom[19] = 32'h34141073; // CSRRW x0, mepc, x8     ; mepc = mepc+4
        rom[20] = 32'h30200073; // MRET                   ; -> return to mepc
        rom[21] = 32'h0000006F; // JAL x0,0 (guard)
    end

    always @(*) begin
        if (pc[31:2] < 64) instr = rom[pc[31:2]];
        else               instr = 32'h00000013;
    end

    task chk; input [127:0] nm; input [31:0] got, exp; begin
        if (got === exp) $display("PASS: %0s = 0x%08h", nm, got);
        else begin $display("FAIL: %0s = 0x%08h (expected 0x%08h)", nm, got, exp); errors=errors+1; end
    end endtask

    initial begin
        $dumpfile("trap_tb.vcd"); $dumpvars(0, trap_tb);
        #20 rst = 0;
        #1000;  // run

        $display("--- trap_tb state ---");
        $display("mtvec =0x%08h mcause=0x%08h mepc=0x%08h mstatus=0x%08h",
                 uut.csr_mtvec, uut.csr_mcause, uut.csr_mepc, uut.csr_mstatus);
        chk("mtvec programmed",       uut.csr_mtvec,      32'h00000040);
        chk("mcause = ECALL(11)",     uut.csr_mcause,     32'd11);
        chk("x5 marker (pre-ecall)",  uut.regfile[5],     32'h00000111);
        chk("x7 = mcause read",       uut.regfile[7],     32'd11);
        chk("x6 marker (post-mret)",  uut.regfile[6],     32'h00000222);
        chk("x9 reached",             uut.regfile[9],     32'h00000333);

        $display("\n=== trap_tb: %0d error(s) ===", errors);
        if (errors != 0) $fatal(1, "trap test failed");
        $finish;
    end
endmodule
