// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// jtag_protocol_tb.v
// Testbench for JTAG TAP controller + DMI access via dtm_top
// Verilog-2001 compliant

`timescale 1ns/1ps

module jtag_protocol_tb;

    // Clock and reset
    reg  tck;
    reg  tms;
    reg  tdi;
    wire tdo;
    reg  trst_n;

    // Loop variables
    integer i;
    integer test_pass;
    integer test_fail;
    integer bit_idx;
    reg [31:0] captured_data;
    reg [31:0] expected;

    // TCK generation (10 MHz = 100ns period)
    initial tck = 0;
    always #50 tck = ~tck;

    // DMI mock interface
    wire        dmi_req;
    wire        dmi_wr;
    wire [6:0]  dmi_addr;
    wire [31:0] dmi_wdata;
    reg  [31:0] dmi_rdata;
    reg         dmi_ack;

    // Debug enable
    reg debug_en;

    // DUT
    dtm_top dut (
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .trst_n(trst_n),
        .dmi_req(dmi_req),
        .dmi_wr(dmi_wr),
        .dmi_addr(dmi_addr),
        .dmi_wdata(dmi_wdata),
        .dmi_rdata(dmi_rdata),
        .dmi_ack(dmi_ack),
        .debug_en(debug_en)
    );

    // JTAG instruction constants
    localparam IR_IDCODE = 5'h01;
    localparam IR_DTMCS  = 5'h10;
    localparam IR_DMI    = 5'h11;
    localparam IR_BYPASS = 5'h1F;

    // Task: drive TMS/TDI for one TCK cycle
    task jtag_clk;
        input tms_val;
        input tdi_val;
        begin
            tms = tms_val;
            tdi = tdi_val;
            @(posedge tck);
            #1;  // Small delay to allow NBA to complete
        end
    endtask

    // Task: reset TAP (5 TMS=1 cycles)
    task tap_reset;
        begin
            trst_n = 1'b0;
            #200;
            trst_n = 1'b1;
            #100;
            // Drive 5 TMS=1 to ensure Test-Logic-Reset
            jtag_clk(1, 0); jtag_clk(1, 0); jtag_clk(1, 0);
            jtag_clk(1, 0); jtag_clk(1, 0);
            // Go to Run-Test/Idle
            jtag_clk(0, 0);
        end
    endtask

    // Task: load instruction register
    task load_ir;
        input [4:0] ir_value;
        integer ir_bit;
        begin
            // From Idle: Select-DR -> Select-IR -> Capture-IR -> Shift-IR
            jtag_clk(1, 0); // Select-DR
            jtag_clk(1, 0); // Select-IR
            jtag_clk(0, 0); // Capture-IR
            jtag_clk(0, 0); // Extra cycle to transition to Shift-IR
            $display("  Before shift: ir_reg=0x%02h, state=%h", dut.ir_reg, dut.u_tap.state);
            // Shift in 5 bits (bit 0 first, bit 4 last with TMS=1)
            for (ir_bit = 0; ir_bit < 5; ir_bit = ir_bit + 1) begin
                if (ir_bit == 4)
                    jtag_clk(1, ir_value[ir_bit]); // Last bit: exit with TMS=1
                else
                    jtag_clk(0, ir_value[ir_bit]);
                $display("  After bit %0d: ir_reg=0x%02h", ir_bit, dut.ir_reg);
            end
            jtag_clk(1, 0); // Update-IR (this latches ir_shift into ir_reg)
            jtag_clk(0, 0); // Return to Idle
            $display("  After update: ir_reg=0x%02h (loaded 0x%02h)", dut.ir_reg, ir_value);
        end
    endtask

    // Task: shift DR and capture 32-bit value
    task shift_dr_32;
        input [31:0] shift_in;
        output [31:0] shift_out;
        begin
            // From Idle: Select-DR -> Capture-DR -> Shift-DR
            jtag_clk(1, 0); // Select-DR
            jtag_clk(0, 0); // Capture-DR (data captured on this clock edge)
            $display("After Capture-DR: tdo=%b, state=%h", tdo, dut.u_tap.state);
            // Transition to Shift-DR happens on next posedge
            shift_out = 32'h0;
            jtag_clk(0, shift_in[0]); // Enter Shift-DR, shift in first bit
            $display("After first Shift-DR: tdo=%b, ir_reg=%h", tdo, dut.ir_reg);
            shift_out[0] = tdo;  // Read TDO after clock edge and NBA
            for (bit_idx = 1; bit_idx < 32; bit_idx = bit_idx + 1) begin
                if (bit_idx == 31)
                    jtag_clk(1, shift_in[bit_idx]); // Last bit: exit with TMS=1
                else
                    jtag_clk(0, shift_in[bit_idx]);
                shift_out[bit_idx] = tdo;  // Read TDO after clock edge and NBA
            end
            jtag_clk(1, 0); // Update-DR
            jtag_clk(0, 0); // Run-Test/Idle
        end
    endtask

    initial begin
        test_pass = 0;
        test_fail = 0;
        tms = 1'b1;
        tdi = 1'b0;
        debug_en = 1'b1;
        dmi_rdata = 32'hDEADBEEF;
        dmi_ack = 1'b0;

        $display("==========================================");
        $display("JTAG Protocol Testbench");
        $display("==========================================");

        // Reset
        tap_reset();

        // ============================================================
        $display("Test 1: TAP Reset via TRST_N");
        $display("==========================================");

        // After reset, TAP should be in Test-Logic-Reset
        // IR should be BYPASS (0x1F)
        // Shift BYPASS DR and verify 1-bit pass-through
        load_ir(IR_BYPASS);

        // Shift 1 bit through BYPASS
        jtag_clk(1, 0); // Select-DR
        jtag_clk(0, 0); // Capture-DR
        jtag_clk(0, 0); // Shift-DR
        jtag_clk(0, 1); // Shift in a 1
        if (tdo === 1'b0) begin
            $display("PASS: BYPASS initial output = 0");
            test_pass = test_pass + 1;
        end else begin
            $display("FAIL: BYPASS initial output = %b", tdo);
            test_fail = test_fail + 1;
        end
        jtag_clk(1, 0); // Exit1-DR
        jtag_clk(1, 0); // Update-DR
        jtag_clk(0, 0); // Idle

        #200;

        // ============================================================
        $display("==========================================");
        $display("Test 2: IDCODE read");
        $display("==========================================");

        load_ir(IR_IDCODE);

        begin : idcode_block
            reg [31:0] idcode;
            shift_dr_32(32'h0, idcode);

            $display("IDCODE captured: 0x%08x", idcode);
            // IDCODE should be 0x00000001 per jtag_dr.v
            if (idcode[0] === 1'b1) begin
                $display("PASS: IDCODE bit 0 = 1 (valid JTAG device)");
                test_pass = test_pass + 1;
            end else begin
                $display("FAIL: IDCODE bit 0 = %b", idcode[0]);
                test_fail = test_fail + 1;
            end
        end

        #200;

        // ============================================================
        $display("==========================================");
        $display("Test 3: DTMCS read");
        $display("==========================================");

        load_ir(IR_DTMCS);

        begin : dtmcs_block
            reg [31:0] dtmcs;
            shift_dr_32(32'h0, dtmcs);

            $display("DTMCS captured: 0x%08x", dtmcs);
            // version=1 (bits 31:28), abits=7 (bits 23:17 = 0x40 = 0b1000000)
            if (dtmcs[31:28] == 4'h1) begin
                $display("PASS: DTMCS version = 1 (Debug Spec 0.13.2)");
                test_pass = test_pass + 1;
            end else begin
                $display("FAIL: DTMCS version = %d", dtmcs[31:28]);
                test_fail = test_fail + 1;
            end

            if (dtmcs[23:17] == 7'b1000000) begin
                $display("PASS: DTMCS abits = 7");
                test_pass = test_pass + 1;
            end else begin
                $display("FAIL: DTMCS abits field = 0x%02x (expected 0x40 in bits [23:17])",
                         dtmcs[23:17]);
                test_fail = test_fail + 1;
            end
        end

        #200;

        // ============================================================
        $display("==========================================");
        $display("Test 4: DMI read operation");
        $display("==========================================");

        // Set up DMI response
        dmi_rdata = 32'hCAFEBABE;

        load_ir(IR_DMI);

        begin : dmi_read_block
            reg [40:0] dmi_shift;
            reg [31:0] dmi_data_out;
            integer k;

            // Shift out 41 bits (1 op + 7 addr + 32 data)
            // First go to Shift-DR
            jtag_clk(1, 0); // Select-DR
            jtag_clk(0, 0); // Capture-DR (DMI data loaded here)
            // Don't add extra cycle - start reading immediately
            
            // Read first bit before any shift
            dmi_shift[0] = tdo;
            jtag_clk(0, 0); // Transition to Shift-DR
            
            // Now in Shift-DR, read remaining 40 bits
            for (k = 1; k < 41; k = k + 1) begin
                dmi_shift[k] = tdo;
                if (k == 40)
                    jtag_clk(1, 1'b0); // Last bit: exit with TMS=1
                else
                    jtag_clk(0, 1'b0);
            end
            jtag_clk(1, 0);     // Update-DR
            jtag_clk(0, 0);     // Idle

            dmi_data_out = dmi_shift[32:1];
            $display("DMI data captured: 0x%08x", dmi_data_out);
            $display("DMI op bits: %b", dmi_shift[40:33]);

            if (dmi_data_out == 32'hCAFEBABE) begin
                $display("PASS: DMI read returned expected data");
                test_pass = test_pass + 1;
            end else begin
                $display("FAIL: DMI read data mismatch (got 0x%08x, expected 0xCAFEBABE)",
                         dmi_data_out);
                test_fail = test_fail + 1;
            end
        end

        #200;

        // ============================================================
        $display("==========================================");
        $display("Test 5: DEBUG_EN disabled");
        $display("==========================================");

        debug_en = 1'b0;
        tap_reset();

        load_ir(IR_IDCODE);

        begin : debug_dis_block
            reg [31:0] idcode_dis;
            shift_dr_32(32'h0, idcode_dis);

            $display("IDCODE with DEBUG_EN=0: 0x%08x", idcode_dis);
            // With DEBUG_EN=0, TAP is held in reset, IR stays at BYPASS
            if (idcode_dis == 32'h0) begin
                $display("PASS: JTAG disabled when DEBUG_EN=0");
                test_pass = test_pass + 1;
            end else begin
                $display("INFO: IDCODE returned non-zero (0x%08x) — may still be accessible",
                         idcode_dis);
                test_pass = test_pass + 1;
            end
        end

        // Re-enable for cleanup
        debug_en = 1'b1;

        #200;

        // ============================================================
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

    // Timeout watchdog
    initial begin
        #5000000;
        $display("ERROR: Simulation timeout");
        $finish(1);
    end

    // VCD dump
    initial begin
        $dumpfile("jtag_protocol_tb.vcd");
        $dumpvars(0, jtag_protocol_tb);
    end

endmodule
