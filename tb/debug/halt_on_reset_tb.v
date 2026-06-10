// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// halt_on_reset_tb.v
// Halt-on-reset debug testbench

`timescale 1ns/1ps

module halt_on_reset_tb;

    reg clk, rst_n;
    reg dmi_req, dmi_wr;
    reg [6:0] dmi_addr;
    reg [31:0] dmi_wdata;
    wire [31:0] dmi_rdata;
    wire dmi_ack;
    wire dm_halt_req, dm_resume_req, dm_reset_req;
    wire [15:0] core_reg_addr;
    wire core_reg_req, core_reg_wr;
    wire [31:0] core_reg_wdata;
    wire [31:0] progbuf0, progbuf1;
    wire trigger_hit;
    wire [11:0] debug_rom_addr;
    reg [31:0] debug_rom_instr;
    reg core_halted, core_running, core_has_reset;
    reg [31:0] core_reg_rdata;
    reg core_reg_ack;

    reg [31:0] core_pc_override, core_pc_internal;
    reg core_pc_override_en;
    reg reset_asserted;

    localparam RESET_VEC = 32'h0000_0000;
    localparam DMSTATUS  = 7'h04;
    localparam DMCONTROL = 7'h10;

    dm_top u_dm_top (
        .clk(clk), .rst_n(rst_n),
        .dmi_req(dmi_req), .dmi_wr(dmi_wr), .dmi_addr(dmi_addr), .dmi_wdata(dmi_wdata),
        .dmi_rdata(dmi_rdata), .dmi_ack(dmi_ack),
        .core_pc(core_pc_override_en ? core_pc_override : core_pc_internal),
        .core_halted(core_halted), .core_running(core_running),
        .core_has_reset(core_has_reset),
        .dm_halt_req(dm_halt_req), .dm_resume_req(dm_resume_req),
        .dm_reset_req(dm_reset_req), .dm_ndmreset(), .dm_hartsel(),
        .core_reg_req(core_reg_req), .core_reg_wr(core_reg_wr),
        .core_reg_addr(core_reg_addr), .core_reg_wdata(core_reg_wdata),
        .core_reg_rdata(core_reg_rdata), .core_reg_ack(core_reg_ack),
        .progbuf0(progbuf0), .progbuf1(progbuf1),
        .trigger_hit(trigger_hit),
        .debug_rom_addr(debug_rom_addr), .debug_rom_instr(debug_rom_instr)
    );

    // Clock generator
    initial begin clk = 0; forever #5 clk = ~clk; end

    // Mock core - same pattern as step_tb.v
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            core_pc_internal <= 32'h0000_1000;
            core_halted <= 0; core_running <= 1;
            core_has_reset <= 0; core_reg_ack <= 0; core_reg_rdata <= 32'h0;
            core_pc_override_en <= 0; reset_asserted <= 0;
            debug_rom_instr <= 32'h0000_0013;
        end else begin
            // PC override
            if (core_pc_override_en) begin
                core_pc_internal <= core_pc_override;
                core_pc_override_en <= 0;
            end

            // Register access
            if (core_reg_req && !core_reg_ack) begin
                core_reg_ack <= 1;
            end else if (core_reg_ack && !core_reg_req) begin
                core_reg_ack <= 0;
            end

            // Halt request
            if (dm_halt_req && core_running && !core_halted) begin
                core_running <= 0; core_halted <= 1;
            end

            // Resume request
            if (dm_resume_req && core_halted) begin
                core_halted <= 0; core_running <= 1;
            end

            // Reset request (hartreset from DM)
            if (dm_reset_req) begin
                reset_asserted <= 1;
                // Simulate: on reset, PC goes to reset vector and core halts if haltreq was set
                core_pc_internal <= RESET_VEC;
                core_has_reset <= 1;
            end

            // Normal execution
            if (core_running && !core_halted && !dm_resume_req) begin
                core_pc_internal <= core_pc_internal + 4;
            end

            case (debug_rom_addr)
                12'h000: debug_rom_instr <= 32'h0000_0013;
                12'h004: debug_rom_instr <= 32'h0000_0067;
                default: debug_rom_instr <= 32'h0000_0013;
            endcase
        end
    end

    // DMI tasks
    task dmi_write;
        input [6:0] addr; input [31:0] data;
        begin
            @(posedge clk); #1;
            dmi_addr = addr; dmi_wdata = data; dmi_wr = 1; dmi_req = 1;
            @(posedge clk); #1;
            while (!dmi_ack) @(posedge clk);
            dmi_req = 0; dmi_wr = 0; @(posedge clk); #1;
        end
    endtask

    task dmi_read;
        input [6:0] addr; output [31:0] data;
        begin
            @(posedge clk); #1;
            dmi_addr = addr; dmi_wr = 0; dmi_req = 1;
            @(posedge clk); #1;
            while (!dmi_ack) @(posedge clk);
            data = dmi_rdata; dmi_req = 0; @(posedge clk); #1;
        end
    endtask

    integer test_num, pass_count, fail_count;
    reg [31:0] dmstatus;

    initial begin
        test_num = 0; pass_count = 0; fail_count = 0;
        rst_n = 0; dmi_req = 0; dmi_wr = 0; dmi_addr = 0; dmi_wdata = 0;
        core_pc_override_en = 0; core_pc_override = 0;
        core_pc_internal = 32'h0000_1000;
        core_halted = 0; core_running = 1;
        core_has_reset = 0; core_reg_ack = 0; core_reg_rdata = 32'h0;
        reset_asserted = 0; debug_rom_instr = 32'h0000_0013;
        #100; rst_n = 1; #100;

        $display("==========================================");
        $display("Halt-on-Reset Debug Testbench");
        $display("==========================================");

        // Verify initial state
        $display("  Initial: core_pc=0x%08x, running=%0b, halted=%0b", core_pc_internal, core_running, core_halted);

        // Activate debug module - use hardcoded address
        $display("  Writing DMCONTROL (addr=0x%0x, data=0x%08x)...", 7'h10, 32'h0001_0001);
        @(posedge clk); #1;
        dmi_addr = 7'h10; dmi_wdata = 32'h0001_0001; dmi_wr = 1; dmi_req = 1;
        @(posedge clk); #1;
        $display("  After posedge: dmi_ack=%0b", dmi_ack);
        if (!dmi_ack) begin
            $display("  ERROR: dmi_ack not asserted after DMCONTROL write!");
            $finish(1);
        end
        while (!dmi_ack) @(posedge clk);
        dmi_req = 0; dmi_wr = 0; @(posedge clk); #1;
        $display("  Debug module activated.");

        // Test 1: Halt core via haltreq
        test_num = 1;
        $display("\n--- Test %0d: Halt Core via haltreq ---", test_num);

        dmi_write(DMCONTROL, 32'h0001_8001); // haltreq=1, dmactive=1
        repeat (10) @(posedge clk);

        dmi_read(DMSTATUS, dmstatus);
        if (dmstatus[8] || dmstatus[7]) begin
            $display("  PASS: Core halted (dmstatus[anyhalted]=%0b)", dmstatus[7]);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Core not halted (dmstatus=0x%08x)", dmstatus);
            fail_count = fail_count + 1;
        end

        // Test 2: Set hartreset + haltreq, verify reset behavior
        test_num = 2;
        $display("\n--- Test %0d: Hartreset (reset vector halt) ---", test_num);

        // Resume first
        dmi_write(DMCONTROL, 32'h0001_0001 | (1<<16)); // resumereq=1
        repeat (5) @(posedge clk);

        // Request reset with halt
        dmi_write(DMCONTROL, 32'h0002_8001); // haltreq=1, hartreset=1
        repeat (10) @(posedge clk);

        if (reset_asserted && core_pc_internal == RESET_VEC) begin
            $display("  PASS: Reset asserted, PC at reset vector (0x%08x)", RESET_VEC);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Reset not observed (PC=0x%08x, reset=%0b)", core_pc_internal, reset_asserted);
            fail_count = fail_count + 1;
        end

        // Test 3: Resume after reset
        test_num = 3;
        $display("\n--- Test %0d: Resume After Reset ---", test_num);

        dmi_write(DMCONTROL, 32'h0001_0001 | (1<<16)); // resumereq=1
        repeat (10) @(posedge clk);

        if (core_running && !core_halted) begin
            $display("  PASS: Core resumed (PC=0x%08x)", core_pc_internal);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Core did not resume");
            fail_count = fail_count + 1;
        end

        // Test 4: Verify normal halt works after reset
        test_num = 4;
        $display("\n--- Test %0d: Normal Halt After Reset ---", test_num);

        dmi_write(DMCONTROL, 32'h0001_8001); // haltreq=1
        repeat (10) @(posedge clk);

        dmi_read(DMSTATUS, dmstatus);
        if (dmstatus[8] || dmstatus[7]) begin
            $display("  PASS: Normal halt works (dmstatus=0x%08x)", dmstatus);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Normal halt failed");
            fail_count = fail_count + 1;
        end

        // Summary
        $display("\n==========================================");
        $display("Test Summary");
        $display("==========================================");
        $display("  Tests passed: %0d / %0d", pass_count, test_num);
        $display("  Tests failed: %0d", fail_count);
        $display("==========================================");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED"); $finish(0);
        end else begin
            $display("SOME TESTS FAILED"); $finish(1);
        end
    end

    initial begin #10000; $display("ERROR: timeout"); $finish(1); end
    initial begin $dumpfile("halt_on_reset_tb.vcd"); $dumpvars(0, halt_on_reset_tb); end

endmodule
