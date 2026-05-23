// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// nvm_tb.v
// Testbench for NVM controller (nvm_ctrl.v)
// Tests: reset init, write+read, ECC single-bit correction,
//        double-bit detection, busy flag, ECC function verification
//
// Read pipeline: 2 cycles from i_rd_en to valid o_rd_data
//   Cycle T:   i_rd_en=1 → read_data/read_ecc captured, read_valid=1
//   Cycle T+1: read_valid=1 → corrected_data computed, o_rd_data <= corrected_data
//   Cycle T+2: o_rd_data valid for sampling
//
// Write: 1 cycle, o_busy=1 during write, wear_ptr increments (non-blocking)
// Wear leveling: effective_addr = i_addr ^ (wear_ptr << 6)
// Physical addr = logical_addr ^ (wear_ptr_at_write_time << 6)

`timescale 1ns/1ps

module nvm_tb();

    reg        i_clk_nvm;
    reg        i_rst;
    reg [15:0] i_addr;
    reg        i_wr_en;
    reg [31:0] i_wr_data;
    reg        i_rd_en;

    wire [31:0] o_rd_data;
    wire        o_busy;
    wire        o_ecc_err;

    nvm_ctrl uut (
        .i_clk_nvm(i_clk_nvm),
        .i_rst(i_rst),
        .i_addr(i_addr),
        .i_wr_en(i_wr_en),
        .i_wr_data(i_wr_data),
        .i_rd_en(i_rd_en),
        .o_rd_data(o_rd_data),
        .o_busy(o_busy),
        .o_ecc_err(o_ecc_err)
    );

    initial begin
        i_clk_nvm = 0;
        forever #5 i_clk_nvm = ~i_clk_nvm;
    end

    integer pass_count, fail_count, test_idx;

    // Track wear pointer and physical addresses for each write
    reg [9:0] tracked_wear_ptr;

    // Storage for physical addresses of key test data
    reg [15:0] phys_deadbeef;
    reg [15:0] phys_12345678;
    reg [15:0] phys_abcdef01;
    reg [15:0] phys_cafebabe;
    reg [15:0] phys_allzeros;
    reg [15:0] phys_allones;
    reg [15:0] phys_55555555;
    reg [15:0] phys_aaaaaaaa;
    reg [15:0] phys_11111111;
    reg [15:0] phys_44444444;
    reg [15:0] phys_beefcafe;

    // Compute physical address for a write at the current wear_ptr
    function [15:0] compute_phys;
        input [15:0] logical_addr;
        input [9:0]  wptr;
        begin
            compute_phys = logical_addr ^ ({6'b0, wptr} << 6);
        end
    endfunction

    // Compute logical address for a read at the current wear_ptr
    // We want: logical ^ (cur_wptr << 6) = phys
    // So: logical = phys ^ (cur_wptr << 6)
    function [15:0] compute_logical;
        input [15:0] phys_addr;
        input [9:0]  wptr;
        begin
            compute_logical = phys_addr ^ ({6'b0, wptr} << 6);
        end
    endfunction

    task check_result;
        input [31:0] actual;
        input [31:0] expected;
        input [80*8:1] name;
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("  PASS [%0d] %0s: 0x%08h", test_idx, name, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL [%0d] %0s: got=0x%08h expected=0x%08h", test_idx, name, actual, expected);
            end
            test_idx = test_idx + 1;
        end
    endtask

    task check_flag;
        input actual;
        input expected;
        input [80*8:1] name;
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("  PASS [%0d] %0s: %0b", test_idx, name, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL [%0d] %0s: got=%0b expected=%0b", test_idx, name, actual, expected);
            end
            test_idx = test_idx + 1;
        end
    endtask

    // Task: write one word, record physical address, track wear_ptr
    task do_write;
        input [15:0]  addr;
        input [31:0]  data;
        output [15:0] phys;
        begin
            while (o_busy) #10;
            phys = compute_phys(addr, tracked_wear_ptr);
            i_addr = addr;
            i_wr_data = data;
            i_wr_en = 1;
            #10;
            i_wr_en = 0;
            tracked_wear_ptr = tracked_wear_ptr + 1;
            #10;
        end
    endtask

    // Task: read from physical address, sample result after pipeline
    task do_read;
        input [15:0] phys_addr;
        output [31:0] result;
        output       ecc_result;
        reg [15:0]   logical_addr;
        begin
            while (o_busy) #10;
            logical_addr = compute_logical(phys_addr, tracked_wear_ptr);
            i_addr = logical_addr;
            i_rd_en = 1;
            #10;  // Cycle T: capture read_data, set read_valid
            i_rd_en = 0;
            #10;  // Cycle T+1: compute corrected_data, o_rd_data <= corrected_data
            #10;  // Cycle T+2: o_rd_data valid
            result = o_rd_data;
            ecc_result = o_ecc_err;
        end
    endtask

    initial begin
        $dumpfile("nvm_tb.vcd");
        $dumpvars(0, nvm_tb);

        pass_count = 0;
        fail_count = 0;
        test_idx = 0;
        tracked_wear_ptr = 0;

        i_rst = 1;
        i_addr = 0; i_wr_en = 0; i_wr_data = 0; i_rd_en = 0;
        #50;
        i_rst = 0;
        #20;

        $display("=============================================================");
        $display("  NVM Controller Test Suite");
        $display("=============================================================");

        // Test 1: Read after reset (wear_ptr=0, phys=0x0000)
        begin : t1
            reg [31:0] rdata; reg err;
            do_read(16'h0000, rdata, err);
            check_result(rdata, 32'h00000000, "Read addr 0 after reset");
            check_flag(err, 1'b0, "No ECC error after reset");
        end

        // Test 2: Write and read back
        begin : t2
            reg [31:0] rdata; reg err;
            do_write(16'h0100, 32'hDEADBEEF, phys_deadbeef);
            do_read(phys_deadbeef, rdata, err);
            check_result(rdata, 32'hDEADBEEF, "Write/read 0x0100");
            check_flag(err, 1'b0, "No ECC error on clean read");
        end

        // Test 3: Multiple writes to different addresses
        begin : t3
            reg [31:0] rdata; reg err;
            do_write(16'h0200, 32'h12345678, phys_12345678);
            do_write(16'h0300, 32'hABCDEF01, phys_abcdef01);
            do_read(phys_12345678, rdata, err);
            check_result(rdata, 32'h12345678, "Read addr 0x0200");
            do_read(phys_abcdef01, rdata, err);
            check_result(rdata, 32'hABCDEF01, "Read addr 0x0300");
        end

        // Test 4: Overwrite same logical address
        begin : t4
            reg [31:0] rdata; reg err;
            do_write(16'h0100, 32'hCAFEBABE, phys_cafebabe);
            do_read(phys_cafebabe, rdata, err);
            check_result(rdata, 32'hCAFEBABE, "Overwrite addr 0x0100");
        end

        // Test 5: All zeros and all ones
        begin : t5
            reg [31:0] rdata; reg err;
            do_write(16'h0700, 32'h00000000, phys_allzeros);
            do_write(16'h0800, 32'hFFFFFFFF, phys_allones);
            do_read(phys_allzeros, rdata, err);
            check_result(rdata, 32'h00000000, "Write/read all zeros");
            do_read(phys_allones, rdata, err);
            check_result(rdata, 32'hFFFFFFFF, "Write/read all ones");
        end

        // Test 6: ECC single-bit error correction
        begin : t6
            reg [31:0] rdata; reg err;
            do_write(16'h0500, 32'h55555555, phys_55555555);
            // Inject single-bit error: flip bit 3
            uut.mem_array[phys_55555555] = 32'h5555555D;
            do_read(phys_55555555, rdata, err);
            check_result(rdata, 32'h55555555, "ECC single-bit correction");
            check_flag(err, 1'b0, "No double-bit flag for single error");
        end

        // Test 7: ECC double-bit error detection
        begin : t7
            reg [31:0] rdata; reg err;
            do_write(16'h0600, 32'hAAAAAAAA, phys_aaaaaaaa);
            // Inject double-bit error: flip bits 1 and 3 (both are 1 in 0xAA)
            uut.mem_array[phys_aaaaaaaa] = 32'hAAAAAAAA ^ 32'h0000000A;
            do_read(phys_aaaaaaaa, rdata, err);
            check_flag(err, 1'b1, "ECC double-bit error flag");
        end

        // Test 8: Busy flag during write
        begin : t8
            reg [15:0] tmp_phys;
            while (o_busy) #10;
            i_addr = 16'h0900;
            i_wr_data = 32'h11111111;
            i_wr_en = 1;
            #10;
            check_flag(o_busy, 1'b1, "Busy flag during write");
            i_wr_en = 0;
            phys_11111111 = compute_phys(16'h0900, tracked_wear_ptr);
            tracked_wear_ptr = tracked_wear_ptr + 1;
            while (o_busy) #10;
            #10;
            check_flag(o_busy, 1'b0, "Busy flag cleared after write");
        end

        // Test 9: ECC check bit error (metadata only, data intact)
        begin : t9
            reg [31:0] rdata; reg err;
            // Use addr 0x1000 to avoid physical address collision with all-ones at 0x0940
            do_write(16'h1000, 32'h44444444, phys_44444444);
            // Flip one bit in ECC metadata only
            uut.ecc_meta[phys_44444444] = uut.ecc_meta[phys_44444444] ^ 7'h01;
            do_read(phys_44444444, rdata, err);
            check_result(rdata, 32'h44444444, "ECC check bit error - data intact");
            check_flag(err, 1'b0, "No double-bit flag for check bit error");
        end

        // Test 10: High address boundary
        begin : t10
            reg [31:0] rdata; reg err;
            do_write(16'hFFFE, 32'hBEEFCAFE, phys_beefcafe);
            do_read(phys_beefcafe, rdata, err);
            check_result(rdata, 32'hBEEFCAFE, "High address boundary");
        end

        // Test 11: ECC calc_ecc function verification
        begin : t11
            reg [6:0] ecc_val;
            ecc_val = uut.calc_ecc(32'h00000000);
            check_result(ecc_val, 7'h00, "ECC for all-zeros");
            ecc_val = uut.calc_ecc(32'hFFFFFFFF);
            $display("  INFO: ECC for all-ones = 0x%07h", ecc_val);
            if (ecc_val != 7'h00) begin
                pass_count = pass_count + 1;
                $display("  PASS [%0d] ECC for all-ones non-zero", test_idx);
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL [%0d] ECC for all-ones is zero", test_idx);
            end
            test_idx = test_idx + 1;
        end

        // Test 12: Single-bit error on all-ones data
        begin : t12
            reg [31:0] rdata; reg err;
            // Flip bit 5: 0xFFFFFFFF ^ 0x00000020 = 0xFFFFFFDF
            uut.mem_array[phys_allones] = 32'hFFFFFFDF;
            do_read(phys_allones, rdata, err);
            check_result(rdata, 32'hFFFFFFFF, "ECC correct all-ones single-bit");
            check_flag(err, 1'b0, "No double-bit flag for all-ones single error");
        end

        // Test 13: Single-bit error on all-zeros data
        begin : t13
            reg [31:0] rdata; reg err;
            // Flip bit 4: 0x00000000 ^ 0x00000010 = 0x00000010
            uut.mem_array[phys_allzeros] = 32'h00000010;
            do_read(phys_allzeros, rdata, err);
            check_result(rdata, 32'h00000000, "ECC correct all-zeros single-bit");
            check_flag(err, 1'b0, "No double-bit flag for all-zeros single error");
        end

        // Summary
        $display("");
        $display("=============================================================");
        $display("  Summary: %0d passed, %0d failed out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("=============================================================");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");

        $finish;
    end

endmodule
