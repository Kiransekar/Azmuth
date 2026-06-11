// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/irq_tb.v
// Directed test for M-mode external interrupt taking in riscv_core.
// REQ: REQ-IRQ-001, REQ-EXC-002. Exercises DEV-008 (IRQ wired) + trap path.
// Program enables MEIE + mstatus.MIE, spins; tb asserts i_meip; core must trap
// with mcause = 0x8000000B (machine external interrupt) and run the handler.
`timescale 1ns/1ps

module irq_tb;
    reg clk = 0, rst = 1;
    wire [31:0] pc; reg [31:0] instr;
    wire [31:0] mem_addr, mem_wdata; wire mem_we; wire [3:0] mem_wstrb;
    reg  [31:0] mem_rdata = 0;
    wire [11:0] csr_addr; wire csr_wr_en; wire [31:0] csr_wr_data;
    reg  [31:0] csr_rd_data = 0;
    wire [31:0] o_xcew_req; wire o_xcew_valid;
    wire [31:0] o_rs1_data, o_rs2_data;
    wire wb_stall, exception, interrupt;
    reg  meip = 0;
    integer errors = 0;

    riscv_core uut (
        .clk(clk), .rst(rst), .pc(pc), .instr(instr),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_we(mem_we),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .csr_addr(csr_addr), .csr_wr_en(csr_wr_en), .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),
        .i_meip(meip), .i_mtip(1'b0), .i_msip(1'b0),
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
        .o_rs1_data(o_rs1_data), .o_rs2_data(o_rs2_data),
        .wb_stall(wb_stall), .exception(exception), .interrupt(interrupt)
    );

    always #5 clk = ~clk;

    reg [31:0] rom [0:63]; integer k;
    initial begin
        for (k=0;k<64;k=k+1) rom[k] = 32'h00000013; // NOP
        rom[0] = 32'h04000093; // ADDI x1,x0,0x40    ; handler addr
        rom[1] = 32'h30509073; // CSRRW x0,mtvec,x1
        rom[2] = 32'h80000113; // ADDI x2,x0,0x800    ; (sign-ext) sets mie[11]=MEIE
        rom[3] = 32'h30411073; // CSRRW x0,mie,x2
        rom[4] = 32'h00800193; // ADDI x3,x0,8        ; mstatus.MIE bit
        rom[5] = 32'h30019073; // CSRRW x0,mstatus,x3 ; global interrupt enable
        rom[6] = 32'h05500293; // ADDI x5,x0,0x55     ; marker before spin
        rom[7] = 32'h0000006F; // JAL x0,0            ; spin (addr 0x1C) waiting for IRQ
        // handler @ idx16 (0x40)
        rom[16] = 32'h342023F3; // CSRRS x7,mcause,x0 ; x7 = mcause (expect 0x8000000B)
        rom[17] = 32'h09900313; // ADDI x6,x0,0x99    ; marker: interrupt serviced
        rom[18] = 32'h0000006F; // JAL x0,0           ; spin in handler
    end

    always @(*) instr = (pc[31:2] < 64) ? rom[pc[31:2]] : 32'h00000013;

    task chk; input [127:0] nm; input [31:0] got, exp; begin
        if (got === exp) $display("PASS: %0s = 0x%08h", nm, got);
        else begin $display("FAIL: %0s = 0x%08h (exp 0x%08h)", nm, got, exp); errors=errors+1; end
    end endtask

    initial begin
        $dumpfile("irq_tb.vcd"); $dumpvars(0, irq_tb);
        #20 rst = 0;
        #200;          // let the core enable interrupts and reach the spin loop
        $display("pre-IRQ: pc=0x%08h mstatus=0x%08h mie=0x%08h", pc, uut.csr_mstatus, uut.csr_mie);
        meip = 1;      // assert machine external interrupt
        #400;          // allow the handler to run to completion

        $display("--- irq_tb state ---");
        $display("mcause=0x%08h mepc=0x%08h", uut.csr_mcause, uut.csr_mepc);
        chk("x5 marker (pre-spin)",     uut.regfile[5], 32'h00000055);
        chk("mcause = M-ext IRQ",       uut.csr_mcause, 32'h8000000B);
        chk("x7 = mcause read",         uut.regfile[7], 32'h8000000B);
        chk("x6 marker (serviced)",     uut.regfile[6], 32'h00000099);
        chk("MIE cleared on trap",      {31'h0, uut.csr_mstatus[3]}, 32'h0);

        $display("\n=== irq_tb: %0d error(s) ===", errors);
        if (errors != 0) $fatal(1, "irq test failed");
        $finish;
    end
endmodule
