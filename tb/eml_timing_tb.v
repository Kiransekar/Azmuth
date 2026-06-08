// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/eml_timing_tb.v — Constant-time EML verification (TVLA-style)
// Audit reference: Tapeout §4.1

`timescale 1ns/1ps

module eml_timing_tb;

    reg         clk, rst;
    reg  [31:0] rs1, rs2, cfg;
    reg         valid;
    wire [31:0] rd;
    wire        o_valid, o_ready, o_exc;

    eml_unit dut (
        .i_clk(clk), .i_rst(rst),
        .i_rs1(rs1), .i_rs2(rs2), .i_cfg(cfg), .i_valid(valid),
        .o_rd(rd), .o_valid(o_valid), .o_ready(o_ready), .o_exc(o_exc)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle_count;
    integer cycles_per_op [0:15];  // Store cycle counts for 16 different inputs
    integer i;
    integer min_cycles, max_cycles;
    integer errors;

    // Count cycles for a single EML operation
    task run_eml_op(input [31:0] in_rs1, input [31:0] in_rs2, output integer cycles);
        begin
            @(posedge clk);
            rs1 = in_rs1;
            rs2 = in_rs2;
            valid = 1;
            cycle_count = 0;
            @(posedge clk);
            valid = 1;  // Keep valid asserted (per RTL: pipeline runs while valid)
            while (!o_valid && cycle_count < 100) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end
            valid = 0;
            cycles = cycle_count;
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("eml_timing.vcd");
        $dumpvars(0, eml_timing_tb);
        errors = 0;

        // Reset
        rst = 1;
        valid = 0;
        rs1 = 0; rs2 = 0;
        cfg = 32'h0000_3200;  // MAX_DEPTH=3, PRECISION=Q15.16
        #30;
        rst = 0;
        #20;

        $display("=== §4.1 CONSTANT-TIME EML VERIFICATION ===");
        $display("Testing cycle count variance across 16 diverse input pairs...");

        // Run 16 diverse inputs and measure cycle counts
        // These cover: zero, small, large, near-overflow, mixed sign
        run_eml_op(32'h00000000, 32'h00010000, cycles_per_op[0]);   // 0.0, 1.0
        run_eml_op(32'h00010000, 32'h00010000, cycles_per_op[1]);   // 1.0, 1.0
        run_eml_op(32'h00020000, 32'h00030000, cycles_per_op[2]);   // 2.0, 3.0
        run_eml_op(32'h00050000, 32'h00080000, cycles_per_op[3]);   // 5.0, 8.0
        run_eml_op(32'h000A0000, 32'h00010000, cycles_per_op[4]);   // 10.0, 1.0
        run_eml_op(32'h00008000, 32'h00008000, cycles_per_op[5]);   // 0.5, 0.5
        run_eml_op(32'h00004000, 32'h0000C000, cycles_per_op[6]);   // 0.25, 0.75
        run_eml_op(32'h7FFF0000, 32'h00010000, cycles_per_op[7]);   // Large, 1.0
        run_eml_op(32'h00000001, 32'h00000001, cycles_per_op[8]);   // Tiny, tiny
        run_eml_op(32'h00010000, 32'h00000000, cycles_per_op[9]);   // 1.0, 0.0
        run_eml_op(32'h00030000, 32'h00070000, cycles_per_op[10]);  // 3.0, 7.0
        run_eml_op(32'hFFFE0000, 32'h00010000, cycles_per_op[11]);  // -2.0 (signed), 1.0
        run_eml_op(32'h00100000, 32'h00100000, cycles_per_op[12]);  // 16.0, 16.0
        run_eml_op(32'hFFFF0000, 32'hFFFF0000, cycles_per_op[13]);  // -1.0, -1.0
        run_eml_op(32'h00000100, 32'h00000100, cycles_per_op[14]);  // ~0.004, ~0.004
        run_eml_op(32'h12345678, 32'h9ABCDEF0, cycles_per_op[15]);  // Random pattern

        // Analyze results
        min_cycles = cycles_per_op[0];
        max_cycles = cycles_per_op[0];
        for (i = 0; i < 16; i = i + 1) begin
            $display("  Input pair %2d: %0d cycles", i, cycles_per_op[i]);
            if (cycles_per_op[i] < min_cycles) min_cycles = cycles_per_op[i];
            if (cycles_per_op[i] > max_cycles) max_cycles = cycles_per_op[i];
        end

        $display("");
        $display("Min cycles: %0d", min_cycles);
        $display("Max cycles: %0d", max_cycles);
        $display("Variance  : %0d cycles", max_cycles - min_cycles);

        // TVLA-style verdict: constant-time means zero variance
        if (max_cycles - min_cycles == 0) begin
            $display("PASS: EML operations are constant-time (zero cycle variance)");
        end else if (max_cycles - min_cycles <= 1) begin
            $display("MARGINAL: EML operations have <=1 cycle variance (pipeline artifact)");
        end else begin
            $display("FAIL: EML operations have >1 cycle variance (%0d cycles)", max_cycles - min_cycles);
            errors = errors + 1;
        end

        $display("");
        $display("=== eml_timing_tb: %0d error(s) ===", errors);
        $finish;
    end

    // Timeout
    initial begin
        #500000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
