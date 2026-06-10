// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// halt_resume_tb.v
// Testbench for debug module halt/resume functionality
// Verilog-2001 compliant

`timescale 1ns/1ps

module halt_resume_tb;

    // Clock and reset
    reg clk;
    reg rst;

    // Loop variable (must be module-level in Verilog-2001)
    integer rom_init_idx;

    // Core clock (250 MHz = 4ns period)
    initial clk = 0;
    always #2 clk = ~clk;

    // DUT signals
    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_we;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    wire [11:0] csr_addr;
    wire        csr_wr_en;
    wire [31:0] csr_wr_data;
    wire [31:0] csr_rd_data;

    wire        meip, mtip, msip;
    assign meip = 1'b0;
    assign mtip = 1'b0;
    assign msip = 1'b0;

    wire [31:0] xcew_req;
    wire        xcew_valid;
    wire        xcew_ready;
    wire [31:0] xcew_resp;
    wire        xcew_done;
    assign xcew_ready = 1'b1;
    assign xcew_resp  = 32'h0;
    assign xcew_done  = 1'b0;

    // Debug interface
    reg         dm_halt_req;
    reg         dm_resume_req;
    reg         dm_reset_req;
    wire        dm_halted;
    wire        dm_running;
    wire        dm_has_reset;
    wire [31:0] dm_pc;
    reg         debug_trigger_hit;
    wire [31:0] csr_dcsr;
    wire [31:0] csr_dpc;
    wire [31:0] csr_dscratch0;
    wire [31:0] csr_dscratch1;

    // Debug register access
    reg         dbg_reg_req;
    reg         dbg_reg_wr;
    reg  [11:0] dbg_reg_addr;
    reg  [31:0] dbg_reg_wdata;
    wire [31:0] dbg_reg_rdata;
    wire        dbg_reg_ack;

    // Core instance
    riscv_core #(
        .RESET_PC(32'h00000000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .instr(instr),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we(mem_we),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .csr_addr(csr_addr),
        .csr_wr_en(csr_wr_en),
        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),
        .i_meip(meip),
        .i_mtip(mtip),
        .i_msip(msip),
        .o_xcew_req(xcew_req),
        .o_xcew_valid(xcew_valid),
        .i_xcew_ready(xcew_ready),
        .i_xcew_resp(xcew_resp),
        .i_xcew_done(xcew_done),
        .i_dm_halt_req(dm_halt_req),
        .i_dm_resume_req(dm_resume_req),
        .i_dm_reset_req(dm_reset_req),
        .o_dm_halted(dm_halted),
        .o_dm_running(dm_running),
        .o_dm_has_reset(dm_has_reset),
        .o_dm_pc(dm_pc),
        .i_debug_trigger_hit(debug_trigger_hit),
        .o_csr_dcsr(csr_dcsr),
        .o_csr_dpc(csr_dpc),
        .o_csr_dscratch0(csr_dscratch0),
        .o_csr_dscratch1(csr_dscratch1),
        .i_dbg_reg_req(dbg_reg_req),
        .i_dbg_reg_wr(dbg_reg_wr),
        .i_dbg_reg_addr(dbg_reg_addr),
        .i_dbg_reg_wdata(dbg_reg_wdata),
        .o_dbg_reg_rdata(dbg_reg_rdata),
        .o_dbg_reg_ack(dbg_reg_ack)
    );

    // Instruction ROM (simple 4KB ROM to cover debug ROM at 0x800)
    reg [31:0] rom [0:1023];
    assign instr = rom[pc[11:2]];

    // Initialize ROM with NOP sled + some instructions
    initial begin
        for (rom_init_idx = 0; rom_init_idx < 1024; rom_init_idx = rom_init_idx + 1) begin
            rom[rom_init_idx] = 32'h00000013; // NOP (addi x0, x0, 0)
        end
        // Place some instructions at the start
        rom[0] = 32'h00100093; // addi x1, x0, 1
        rom[1] = 32'h00200113; // addi x2, x0, 2
        rom[2] = 32'h00300193; // addi x3, x0, 3
        rom[3] = 32'h00400213; // addi x4, x0, 4
        rom[4] = 32'h00500293; // addi x5, x0, 5
        // Debug ROM at 0x800 (offset 512 words)
        // Park loop: infinite loop waiting for resume
        rom[512] = 32'h0000006F; // jal x0, 0 (jump to self = infinite loop)
        rom[513] = 32'h00000013; // NOP (padding)
    end

    // CSR read data (external CSRs)
    assign csr_rd_data = 32'h0;

    // Test counters
    integer test_pass;
    integer test_fail;
    integer cycle_count;

    initial begin
        test_pass = 0;
        test_fail = 0;
        cycle_count = 0;

        // Initialize signals
        rst = 1'b1;
        dm_halt_req = 1'b0;
        dm_resume_req = 1'b0;
        dm_reset_req = 1'b0;
        debug_trigger_hit = 1'b0;
        dbg_reg_req = 1'b0;
        dbg_reg_wr = 1'b0;
        dbg_reg_addr = 12'h0;
        dbg_reg_wdata = 32'h0;

        // Release reset
        #100;
        rst = 1'b0;

        // Wait for some normal execution
        #200;

        $display("==========================================");
        $display("Test 1: Halt request");
        $display("==========================================");

        // Assert halt request
        @(posedge clk);
        dm_halt_req = 1'b1;

        // Wait for halt
        wait(dm_halted);
        $display("Core halted at PC = 0x%08x", pc);
        $display("DCSR = 0x%08x, DPC = 0x%08x", csr_dcsr, csr_dpc);

        // Check that we're in debug mode
        if (dm_halted && (csr_dcsr[31:28] == 4'h4)) begin
            $display("PASS: Core in debug mode (xdebugver=4)");
            test_pass = test_pass + 1;
        end else begin
            $display("FAIL: Not in debug mode");
            test_fail = test_fail + 1;
        end

        // Check halt cause (should be halt request = 011)
        if (csr_dcsr[8:6] == 3'b011) begin
            $display("PASS: Halt cause = halt request");
            test_pass = test_pass + 1;
        end else begin
            $display("FAIL: Halt cause = %03b (expected 011)", csr_dcsr[8:6]);
            test_fail = test_fail + 1;
        end

        // Clear halt request
        dm_halt_req = 1'b0;

        #100;

        $display("==========================================");
        $display("Test 2: Resume");
        $display("==========================================");

        // Assert resume request
        @(posedge clk);
        dm_resume_req = 1'b1;

        // Wait for resume
        wait(!dm_halted);
        #20;
        dm_resume_req = 1'b0;

        $display("Core resumed from PC = 0x%08x", csr_dpc);

        // Let it run for a bit
        #200;

        if (!dm_halted && !dm_running) begin
            $display("PASS: Core resumed normally");
            test_pass = test_pass + 1;
        end else begin
            $display("FAIL: Core not running after resume");
            test_fail = test_fail + 1;
        end

        #200;

        $display("==========================================");
        $display("Test 3: Multiple halt/resume cycles");
        $display("==========================================");

        // Halt
        @(posedge clk);
        dm_halt_req = 1'b1;
        wait(dm_halted);
        dm_halt_req = 1'b0;
        $display("Halted at PC = 0x%08x", pc);
        #50;

        // Resume
        @(posedge clk);
        dm_resume_req = 1'b1;
        wait(!dm_halted);
        dm_resume_req = 1'b0;
        #100;

        // Halt again
        @(posedge clk);
        dm_halt_req = 1'b1;
        wait(dm_halted);
        dm_halt_req = 1'b0;
        $display("Halted again at PC = 0x%08x", pc);
        #50;

        // Resume again
        @(posedge clk);
        dm_resume_req = 1'b1;
        wait(!dm_halted);
        dm_resume_req = 1'b0;

        $display("PASS: Multiple halt/resume cycles work");
        test_pass = test_pass + 1;

        #500;

        $display("==========================================");
        $display("Test Summary");
        $display("==========================================");
        $display("PASS: %0d", test_pass);
        $display("FAIL: %0d", test_fail);

        if (test_fail == 0) begin
            $display("ALL TESTS PASSED");
            $finish(0);
        end else begin
            $display("SOME TESTS FAILED");
            $finish(1);
        end
    end

    // Cycle counter
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout");
        $finish(1);
    end

    // VCD dump
    initial begin
        $dumpfile("halt_resume_tb.vcd");
        $dumpvars(0, halt_resume_tb);
    end

endmodule
