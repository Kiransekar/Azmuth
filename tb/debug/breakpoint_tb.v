// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// breakpoint_tb.v
// Hardware breakpoint testbench — 2 mcontrol triggers
// Verifies breakpoint matching causes debug entry

`timescale 1ns/1ps

module breakpoint_tb;

    reg clk;
    reg rst_n;
    reg dmi_req;
    reg dmi_wr;
    reg [6:0] dmi_addr;
    reg [31:0] dmi_wdata;
    wire [31:0] dmi_rdata;
    wire dmi_ack;
    wire dm_halt_req;
    wire dm_resume_req;
    wire [15:0] core_reg_addr;
    wire core_reg_req;
    wire core_reg_wr;
    wire [31:0] core_reg_wdata;
    wire [31:0] progbuf0;
    wire [31:0] progbuf1;
    wire [11:0] debug_rom_addr;
    reg [31:0] debug_rom_instr;
    reg core_halted;
    reg core_running;
    reg core_has_reset;
    reg [31:0] core_reg_rdata;
    reg core_reg_ack;
    wire trigger_hit;
    reg trigger_hit_latched;
    
    always @(posedge clk) begin
        if (trigger_hit) trigger_hit_latched <= 1;
    end
    
    reg [31:0] core_pc_override;
    reg core_pc_override_en;
    reg [31:0] core_pc_internal;
    
    dm_top u_dm_top (
        .clk(clk), .rst_n(rst_n),
        .dmi_req(dmi_req), .dmi_wr(dmi_wr), .dmi_addr(dmi_addr), .dmi_wdata(dmi_wdata),
        .dmi_rdata(dmi_rdata), .dmi_ack(dmi_ack),
        .core_pc(core_pc_override_en ? core_pc_override : core_pc_internal),
        .core_halted(core_halted), .core_running(core_running),
        .core_has_reset(core_has_reset),
        .dm_halt_req(dm_halt_req), .dm_resume_req(dm_resume_req),
        .dm_reset_req(), .dm_ndmreset(), .dm_hartsel(),
        .core_reg_req(core_reg_req), .core_reg_wr(core_reg_wr),
        .core_reg_addr(core_reg_addr), .core_reg_wdata(core_reg_wdata),
        .core_reg_rdata(core_reg_rdata), .core_reg_ack(core_reg_ack),
        .progbuf0(progbuf0), .progbuf1(progbuf1),
        .trigger_hit(trigger_hit),
        .debug_rom_addr(debug_rom_addr), .debug_rom_instr(debug_rom_instr)
    );

    reg step_pending;
    integer exec_count;

    initial begin clk = 0; forever #5 clk = ~clk; end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            core_pc_internal <= 32'h00001000; core_halted <= 0; core_running <= 1;
            core_has_reset <= 1; core_reg_ack <= 0; core_reg_rdata <= 32'h0;
            step_pending <= 0; exec_count <= 0; debug_rom_instr <= 32'h0000_0013;
            core_pc_override_en <= 0;
        end else begin
            if (core_pc_override_en) begin
                core_pc_internal <= core_pc_override;
                core_pc_override_en <= 0;
            end
            
            if (core_reg_req && !core_reg_ack) begin
                core_reg_ack <= 1;
                if (core_reg_wr) begin
                    // Any abstract write goes to mock dcsr
                end
            end else if (core_reg_ack && !core_reg_req) begin
                core_reg_ack <= 0;
            end

            if (dm_halt_req && core_running && !core_halted) begin
                core_running <= 0; core_halted <= 1;
            end
            if (dm_resume_req && core_halted) begin
                core_halted <= 0; core_running <= 1; exec_count <= 1;
                step_pending <= 0;
            end
            if (core_running && !core_halted && !dm_resume_req && !core_pc_override_en) begin
                core_pc_internal <= core_pc_internal + 4; exec_count <= exec_count + 1;
                if (step_pending && exec_count == 1) begin
                    core_running <= 0; core_halted <= 1; step_pending <= 0;
                end
            end
            case (debug_rom_addr)
                12'h000: debug_rom_instr <= 32'h0000_0013;
                12'h004: debug_rom_instr <= 32'h0000_0067;
                default: debug_rom_instr <= 32'h0000_0013;
            endcase
        end
    end

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
    reg [31:0] tdata1, tdata2, dmstatus;

    initial begin
        test_num = 0; pass_count = 0; fail_count = 0;
        rst_n = 0; dmi_req = 0; dmi_wr = 0; dmi_addr = 0; dmi_wdata = 0;
        #100; rst_n = 1; #100;

        $display("==========================================");
        $display("Hardware Breakpoint Testbench");
        $display("==========================================");

        // Activate debug module
        dmi_write(7'h10, 32'h0001_0001); // dmcontrol: dmactive=1

        // Test 1: Set breakpoint 0 at address 0x00002000
        test_num = 1;
        $display("\n--- Test %0d: Set Breakpoint 0 at 0x2000 ---", test_num);

        // Select trigger 0
        dmi_write(7'h00, 32'h00000000); // TSELECT = 0
        // Set mcontrol: type=2, execute=1, m=1, match=0 (addr equal)
        // tdata1[31:28]=2, tdata1[6]=1, tdata1[2]=1, tdata1[11:7]=0
        tdata1 = (4'd2 << 28) | (1 << 6) | (1 << 2) | (5'd0 << 7);
        dmi_write(7'h01, tdata1); // TDATA1_0
        // Set match address
        dmi_write(7'h02, 32'h00002000); // TDATA2_0 = 0x2000

        $display("  Breakpoint 0 set at 0x2000, mcontrol=0x%08x", tdata1);

        // Run core from 0x1000 to 0x2000 (needs 1024 cycles at 4 bytes/cycle)
        core_pc_override = 32'h00001000;
        core_pc_override_en = 1;
        trigger_hit_latched = 0;
        @(posedge clk);
        repeat (1050) @(posedge clk);

        // Check if trigger_hit fired when PC reached 0x2000
        if (trigger_hit_latched) begin
            $display("  PASS: Trigger hit when PC reached breakpoint address");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Trigger did not fire (final PC=%0h)", core_pc_internal);
            fail_count = fail_count + 1;
        end

        // Test 2: Set second breakpoint at 0x00003000
        test_num = 2;
        $display("\n--- Test %0d: Set Breakpoint 1 at 0x3000 ---", test_num);

        // Select trigger 1
        dmi_write(7'h00, 32'h00000001); // TSELECT = 1
        dmi_write(7'h03, tdata1); // TDATA1_1 (same mcontrol config)
        dmi_write(7'h04, 32'h00003000); // TDATA2_1 = 0x3000

        $display("  Breakpoint 1 set at 0x3000");

        // Run core to 0x3000 (needs (0x3000-0x2800)/4 = 512 cycles)
        core_pc_override = 32'h00002800;
        core_pc_override_en = 1;
        trigger_hit_latched = 0;
        @(posedge clk);
        repeat (520) @(posedge clk);

        if (trigger_hit_latched) begin
            $display("  PASS: Trigger hit for second breakpoint");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Second trigger did not fire (final PC=%0h)", core_pc_internal);
            fail_count = fail_count + 1;
        end

        // Test 3: Clear breakpoint 0
        test_num = 3;
        $display("\n--- Test %0d: Clear Breakpoint 0 ---", test_num);

        dmi_write(7'h00, 32'h00000000); // TSELECT = 0
        dmi_write(7'h01, 32'h00000000); // Clear TDATA1_0

        // Run past 0x2000 (needs (0x2000-0x1800)/4 = 512 cycles)
        core_pc_override = 32'h00001800;
        core_pc_override_en = 1;
        trigger_hit_latched = 0;
        @(posedge clk);
        repeat (520) @(posedge clk);

        // Should NOT trigger at 0x2000 anymore (cleared)
        if (!trigger_hit_latched && core_pc_internal > 32'h00002000) begin
            $display("  PASS: Cleared breakpoint no longer fires");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Cleared breakpoint still triggered or PC didn't advance (PC=%0h, hit=%0b)", core_pc_internal, trigger_hit_latched);
            fail_count = fail_count + 1;
        end

        // Test 4: Verify mcontrol execute flag
        test_num = 4;
        $display("\n--- Test %0d: Verify mcontrol Execute Match ---", test_num);

        // Select trigger 1 (which still has breakpoint config from test 2)
        dmi_write(7'h00, 32'h00000001);
        dmi_read(7'h03, tdata1);

        if (tdata1[31:28] == 4'd2 && tdata1[6] == 1'b1) begin
            $display("  PASS: mcontrol type=2, execute=1 confirmed");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: mcontrol config incorrect (tdata1=0x%08x)", tdata1);
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

    initial begin #50000; $display("ERROR: timeout"); $finish(1); end
    initial begin $dumpfile("breakpoint_tb.vcd"); $dumpvars(0, breakpoint_tb); end

endmodule
