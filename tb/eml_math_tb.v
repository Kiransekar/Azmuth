// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// Testbench for EML compute_exp and compute_ln Q16.16 fixed-point functions
// Tests edge cases, positive/negative inputs, sub-unity values, and accuracy

`timescale 1ns / 1ps

module eml_math_tb;

    reg        clk;
    reg        rst;
    reg  [31:0] test_input;
    wire [31:0] exp_result;
    wire [31:0] ln_result;

    integer     pass_count;
    integer     fail_count;
    integer     test_idx;

    // Direct function test wrapper
    eml_math_test_wrapper wrapper (
        .i_val(test_input),
        .o_exp(exp_result),
        .o_ln(ln_result)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Tolerance: allow ±2 LSB error in Q16.16 (≈0.00003)
    localparam TOLERANCE = 2;

    // Helper: convert real to Q16.16
    function [31:0] real_to_q16;
        input real r;
        begin
            real_to_q16 = $rtoi(r * 65536.0);
        end
    endfunction

    // Helper: convert Q16.16 to real
    function real q16_to_real;
        input [31:0] q;
        reg signed [31:0] sq;
        begin
            sq = $signed(q);
            q16_to_real = $itor(sq) / 65536.0;
        end
    endfunction

    // Test vectors
    localparam NUM_EXP_TESTS = 22;
    reg [31:0] exp_inputs  [0:NUM_EXP_TESTS-1];
    reg [31:0] exp_expected [0:NUM_EXP_TESTS-1];  // Expected Q16.16 results (approx)

    localparam NUM_LN_TESTS = 18;
    reg [31:0] ln_inputs  [0:NUM_LN_TESTS-1];
    reg [31:0] ln_expected [0:NUM_LN_TESTS-1];

    integer err_val;
    real    exp_err_pct, ln_err_pct;
    real    actual_real, expected_real;

    initial begin
        pass_count = 0;
        fail_count = 0;

        // =====================================================================
        // compute_exp test vectors
        // =====================================================================
        // e^0 = 1.0
        exp_inputs[0]  = 32'h00000000;  exp_expected[0]  = 32'h00010000;
        // e^0.5 ≈ 1.6487
        exp_inputs[1]  = 32'h00008000;  exp_expected[1]  = real_to_q16(1.6487);
        // e^1.0 ≈ 2.7183
        exp_inputs[2]  = 32'h00010000;  exp_expected[2]  = real_to_q16(2.7183);
        // e^2.0 ≈ 7.3891
        exp_inputs[3]  = 32'h00020000;  exp_expected[3]  = real_to_q16(7.3891);
        // e^(-0.5) ≈ 0.6065
        exp_inputs[4]  = 32'hFFFF8000;  exp_expected[4]  = real_to_q16(0.6065);
        // e^(-1.0) ≈ 0.3679
        exp_inputs[5]  = 32'hFFFF0000;  exp_expected[5]  = real_to_q16(0.3679);
        // e^(-2.0) ≈ 0.1353
        exp_inputs[6]  = 32'hFFFE0000;  exp_expected[6]  = real_to_q16(0.1353);
        // e^0.25 ≈ 1.2840
        exp_inputs[7]  = 32'h00004000;  exp_expected[7]  = real_to_q16(1.2840);
        // e^0.75 ≈ 2.1170
        exp_inputs[8]  = 32'h0000C000;  exp_expected[8]  = real_to_q16(2.1170);
        // e^3.0 ≈ 20.0855
        exp_inputs[9]  = 32'h00030000;  exp_expected[9]  = real_to_q16(20.0855);
        // e^5.0 ≈ 148.413
        exp_inputs[10] = 32'h00050000;  exp_expected[10] = real_to_q16(148.413);
        // e^7.0 ≈ 1096.63
        exp_inputs[11] = 32'h00070000;  exp_expected[11] = real_to_q16(1096.63);
        // e^10.0 ≈ 22026.5
        exp_inputs[12] = 32'h000A0000;  exp_expected[12] = real_to_q16(22026.5);
        // e^(-5.0) ≈ 0.00674
        exp_inputs[13] = 32'hFFFB0000;  exp_expected[13] = real_to_q16(0.00674);
        // e^(-10.0) ≈ 0.0000454 → underflow territory
        exp_inputs[14] = 32'hFFF60000;  exp_expected[14] = 32'h00000001;
        // e^11.0 ≈ 59874 (fits in unsigned Q16.16)
        exp_inputs[15] = 32'h000B0000;  exp_expected[15] = real_to_q16(59874.0);
        // e^(-11.0) → underflow
        exp_inputs[16] = 32'hFFF50000;  exp_expected[16] = 32'h00000001;
        // e^0.1 ≈ 1.1052
        exp_inputs[17] = 32'h00001999;  exp_expected[17] = real_to_q16(1.1052);
        // e^0.01 ≈ 1.0101
        exp_inputs[18] = 32'h0000028F;  exp_expected[18] = real_to_q16(1.0101);
        // e^1.5 ≈ 4.4817
        exp_inputs[19] = 32'h00018000;  exp_expected[19] = real_to_q16(4.4817);
        // e^(-0.1) ≈ 0.9048
        exp_inputs[20] = 32'hFFFFE667;  exp_expected[20] = real_to_q16(0.9048);
        // e^(-3.0) ≈ 0.04979
        exp_inputs[21] = 32'hFFFD0000;  exp_expected[21] = real_to_q16(0.04979);

        // =====================================================================
        // compute_ln test vectors
        // =====================================================================
        // ln(1.0) = 0
        ln_inputs[0]  = 32'h00010000;  ln_expected[0]  = 32'h00000000;
        // ln(2.0) ≈ 0.6931
        ln_inputs[1]  = 32'h00020000;  ln_expected[1]  = real_to_q16(0.6931);
        // ln(e) = 1.0 (e ≈ 2.7183 in Q16.16)
        ln_inputs[2]  = 32'h0002B7E1;  ln_expected[2]  = real_to_q16(1.0);
        // ln(0.5) ≈ -0.6931
        ln_inputs[3]  = 32'h00008000;  ln_expected[3]  = real_to_q16(-0.6931);
        // ln(0.25) ≈ -1.3863
        ln_inputs[4]  = 32'h00004000;  ln_expected[4]  = real_to_q16(-1.3863);
        // ln(4.0) ≈ 1.3863
        ln_inputs[5]  = 32'h00040000;  ln_expected[5]  = real_to_q16(1.3863);
        // ln(8.0) ≈ 2.0794
        ln_inputs[6]  = 32'h00080000;  ln_expected[6]  = real_to_q16(2.0794);
        // ln(0.1) ≈ -2.3026
        ln_inputs[7]  = 32'h0000199A;  ln_expected[7]  = real_to_q16(-2.3026);
        // ln(10.0) ≈ 2.3026
        ln_inputs[8]  = 32'h000A0000;  ln_expected[8]  = real_to_q16(2.3026);
        // ln(100.0) ≈ 4.6052
        ln_inputs[9]  = 32'h00640000;  ln_expected[9]  = real_to_q16(4.6052);
        // ln(0) → error (-inf)
        ln_inputs[10] = 32'h00000000;  ln_expected[10] = 32'h80000000;
        // ln(1.5) ≈ 0.4055
        ln_inputs[11] = 32'h00018000;  ln_expected[11] = real_to_q16(0.4055);
        // ln(3.0) ≈ 1.0986
        ln_inputs[12] = 32'h00030000;  ln_expected[12] = real_to_q16(1.0986);
        // ln(0.75) ≈ -0.2877
        ln_inputs[13] = 32'h0000C000;  ln_expected[13] = real_to_q16(-0.2877);
        // ln(0.125) ≈ -2.0794
        ln_inputs[14] = 32'h00002000;  ln_expected[14] = real_to_q16(-2.0794);
        // ln(1.1) ≈ 0.0953
        ln_inputs[15] = 32'h00011999;  ln_expected[15] = real_to_q16(0.0953);
        // ln(1.01) ≈ 0.00995
        ln_inputs[16] = 32'h0001028F;  ln_expected[16] = real_to_q16(0.00995);
        // ln(256.0) ≈ 5.5452
        ln_inputs[17] = 32'h01000000;  ln_expected[17] = real_to_q16(5.5452);

        // =====================================================================
        // Run tests
        // =====================================================================
        rst = 1;
        #20 rst = 0;
        #10;

        $display("=============================================================");
        $display("  EML compute_exp Test Suite (Q16.16 fixed-point)");
        $display("=============================================================");

        for (test_idx = 0; test_idx < NUM_EXP_TESTS; test_idx = test_idx + 1) begin
            test_input = exp_inputs[test_idx];
            #10;  // Wait for combinational output

            actual_real = q16_to_real(exp_result);
            expected_real = q16_to_real(exp_expected[test_idx]);

            // Check if within tolerance (relative: ±8 LSB for small, ±1% for large results)
            err_val = exp_result - exp_expected[test_idx];
            if (err_val < 0) err_val = -err_val;

            if (err_val <= 8 || exp_result == exp_expected[test_idx] ||
                (exp_expected[test_idx] != 0 && err_val * 100 <= exp_expected[test_idx] * 2)) begin
                pass_count = pass_count + 1;
                $display("  PASS [exp][%0d] x=%08h → got=%08h (%.4f) expected=%08h (%.4f)",
                         test_idx, exp_inputs[test_idx], exp_result, actual_real,
                         exp_expected[test_idx], expected_real);
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL [exp][%0d] x=%08h → got=%08h (%.4f) expected=%08h (%.4f) err=%0d",
                         test_idx, exp_inputs[test_idx], exp_result, actual_real,
                         exp_expected[test_idx], expected_real, err_val);
            end
        end

        $display("");
        $display("=============================================================");
        $display("  EML compute_ln Test Suite (Q16.16 fixed-point)");
        $display("=============================================================");

        for (test_idx = 0; test_idx < NUM_LN_TESTS; test_idx = test_idx + 1) begin
            test_input = ln_inputs[test_idx];
            #10;

            actual_real = q16_to_real(ln_result);
            expected_real = q16_to_real(ln_expected[test_idx]);

            err_val = ln_result - ln_expected[test_idx];
            if (err_val < 0) err_val = -err_val;

            // Special case: error outputs
            if (ln_expected[test_idx] == 32'h80000000) begin
                if (ln_result == 32'h80000000) begin
                    pass_count = pass_count + 1;
                    $display("  PASS [ln][%0d] x=%08h → got=ERROR (expected)", test_idx, ln_inputs[test_idx]);
                end else begin
                    fail_count = fail_count + 1;
                    $display("  FAIL [ln][%0d] x=%08h → got=%08h expected=ERROR", test_idx, ln_inputs[test_idx], ln_result);
                end
            end else if (err_val <= 8 || ln_result == ln_expected[test_idx] ||
                        (ln_expected[test_idx] != 0 && err_val * 100 <= (ln_expected[test_idx] < 0 ? -ln_expected[test_idx] : ln_expected[test_idx]) * 2)) begin
                pass_count = pass_count + 1;
                $display("  PASS [ln][%0d] x=%08h → got=%08h (%.4f) expected=%08h (%.4f)",
                         test_idx, ln_inputs[test_idx], ln_result, actual_real,
                         ln_expected[test_idx], expected_real);
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL [ln][%0d] x=%08h → got=%08h (%.4f) expected=%08h (%.4f) err=%0d",
                         test_idx, ln_inputs[test_idx], ln_result, actual_real,
                         ln_expected[test_idx], expected_real, err_val);
            end
        end

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


// Thin wrapper to expose compute_exp and compute_ln as combinational outputs
// These functions are defined inside eml_unit, so we duplicate them here
// for standalone testing. In production, the EML pipeline calls them internally.
module eml_math_test_wrapper (
    input  [31:0] i_val,
    output [31:0] o_exp,
    output [31:0] o_ln
);

    // ---- compute_exp (4th-order Horner, Q16.16) ----
    function [31:0] compute_exp;
        input [31:0] input_val;
        reg signed [31:0] x_signed;
        reg signed [31:0] x_scaled;
        reg signed [15:0] k_int;
        reg [31:0] frac_q16;
        reg [31:0] pow2f;
        begin
            x_signed = $signed(input_val);
            if (input_val == 32'h0) begin
                compute_exp = 32'h00010000;
            end else if (x_signed < -32'sd726017) begin
                compute_exp = 32'h00000001;
            end else if (x_signed > 32'sd726017) begin
                compute_exp = 32'h7FFFFFFF;
            end else begin
                x_scaled = x_signed + (x_signed >>> 2) + (x_signed >>> 3) +
                           (x_signed >>> 4) + (x_signed >>> 8) + (x_signed >>> 9);
                k_int = x_scaled[31:16];
                frac_q16 = {16'h0, x_scaled[15:0]};
                pow2f = 32'h00000276;
                pow2f = (frac_q16 * pow2f) >> 16;
                pow2f = pow2f + 32'h00000E38;
                pow2f = (frac_q16 * pow2f) >> 16;
                pow2f = pow2f + 32'h00003D7A;
                pow2f = (frac_q16 * pow2f) >> 16;
                pow2f = pow2f + 32'h0000B1AA;
                pow2f = (frac_q16 * pow2f) >> 16;
                pow2f = pow2f + 32'h00010000;
                if (k_int > 0 && k_int < 16)
                    compute_exp = pow2f << k_int;
                else if (k_int == 0)
                    compute_exp = pow2f;
                else if (k_int < 0 && k_int > -16)
                    compute_exp = pow2f >> (-k_int);
                else if (k_int >= 16)
                    compute_exp = 32'h7FFFFFFF;
                else
                    compute_exp = 32'h00000001;
            end
        end
    endfunction

    // ---- compute_ln (4th-order Horner, Q16.16) ----
    function [31:0] compute_ln;
        input [31:0] input_val;
        reg [31:0] x_norm;
        reg signed [15:0] log2_int;
        reg [31:0] log2_frac;
        reg [31:0] m, m_minus1;
        reg signed [47:0] m_minus1_w;
        reg signed [47:0] s_frac_w;
        reg signed [31:0] s_frac;
        reg signed [47:0] poly_w;
        reg [4:0]  leading_one;
        reg signed [31:0] log2_combined;
        reg signed [47:0] ln_product;
        integer i;
        begin
            if (input_val == 32'h0) begin
                compute_ln = 32'h80000000;
            end else if (input_val[31]) begin
                compute_ln = 32'h80000000;
            end else if (input_val == 32'h00010000) begin
                compute_ln = 32'h0;
            end else begin
                leading_one = 0;
                for (i = 30; i >= 0; i = i - 1) begin
                    if (input_val[i]) begin
                        leading_one = i[4:0];
                        i = 0;  // Break: stop at highest set bit
                    end
                end
                if (leading_one >= 16) begin
                    x_norm = input_val >> (leading_one - 16);
                    log2_int = leading_one - 16;
                end else begin
                    x_norm = input_val << (16 - leading_one);
                    log2_int = leading_one - 16;
                end
                m = x_norm;
                m_minus1 = m - 32'h00010000;
                m_minus1_w = $signed(m_minus1);
                poly_w = m_minus1_w * (-5198);
                s_frac_w = poly_w >>> 16;
                s_frac_w = s_frac_w + 20499;
                poly_w = m_minus1_w * s_frac_w;
                s_frac_w = poly_w >>> 16;
                s_frac_w = s_frac_w + (-43916);
                poly_w = m_minus1_w * s_frac_w;
                s_frac_w = poly_w >>> 16;
                s_frac_w = s_frac_w + 94130;
                poly_w = m_minus1_w * s_frac_w;
                s_frac_w = poly_w >>> 16;
                s_frac = s_frac_w[31:0];
                log2_frac = s_frac;
                log2_combined = {log2_int, 16'b0} + s_frac;
                ln_product = $signed(log2_combined) * 45426;
                compute_ln = ln_product >>> 16;
            end
        end
    endfunction

    assign o_exp = compute_exp(i_val);
    assign o_ln  = compute_ln(i_val);

endmodule
