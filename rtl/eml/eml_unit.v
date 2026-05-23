// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// eml_unit.v
// Expression Machine Learning unit for Xcew processor
// Implements the 5-stage pipeline described in the architecture document

module eml_unit (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [31:0] i_rs1,
    input  wire [31:0] i_rs2,
    input  wire [31:0] i_cfg,
    input  wire        i_valid,

    output reg [31:0]  o_rd,
    output reg         o_valid,
    output wire        o_ready,
    output reg         o_exc
);

    // Configuration bit assignments
    localparam COMPLEX_MODE_BIT = 15;
    localparam MAX_DEPTH_START = 12;
    localparam MAX_DEPTH_END = 14;
    localparam PRECISION_START = 8;
    localparam PRECISION_END = 11;
    localparam BRANCH_CUT_BIT = 7;

    // Pipeline stage indicators
    localparam ST_FETCH = 3'b001;
    localparam ST_EXP   = 3'b010;
    localparam ST_LN    = 3'b011;
    localparam ST_SUB   = 3'b100;
    localparam ST_WB    = 3'b101;

    // Internal signals
    reg [31:0] stage1_hash_out;
    reg        stage1_memo_hit;
    reg [31:0] stage1_memo_data;
    reg [2:0]  current_stage;
    reg [2:0]  depth_cnt;
    reg        overflow_flag;
    reg        nan_flag;
    reg        exc_depth;

    // Memo cache parameters
    localparam MEMO_SIZE = 7;  // 128 entries (2^7)
    localparam MEMO_WIDTH = 32;

    // Memo cache arrays
    reg [7:0]  memo_tags [0:127];
    reg [31:0] memo_data [0:127];
    reg        memo_valid [0:127];

    // Calculate hash from inputs (simple XOR-based hash)
    function [7:0] calculate_hash;
        input [31:0] rs1, rs2;
        begin
            calculate_hash = rs1[7:0] ^ rs1[15:8] ^ rs1[23:16] ^ rs1[31:24] ^
                            rs2[7:0] ^ rs2[15:8] ^ rs2[23:16] ^ rs2[31:24];
        end
    endfunction

    // Compute exp approximation using Q16.16 fixed-point
    // Uses e^x = 2^(x/ln2) = 2^k * 2^f where k = floor(x/ln2), f = frac(x/ln2)
    // 2^f approximated by 4th-order minimax polynomial for f in [0,1)
    // Handles negative x via right-shift (2^k for k<0 = pow2f >> |k|)
    function [31:0] compute_exp;
        input [31:0] input_val;  // Q16.16 format (signed)
        reg signed [31:0] x_signed;  // Signed interpretation
        reg signed [31:0] x_scaled;  // x / ln(2) in Q16.16 signed
        reg signed [15:0] k_int;     // signed integer part of x/ln2
        reg [31:0] frac_q16;         // fractional part in Q16.16 (always >= 0)
        reg [31:0] pow2f;            // 2^f in Q16.16
        begin
            x_signed = $signed(input_val);

            if (input_val == 32'h0) begin
                compute_exp = 32'h00010000;  // e^0 = 1.0
            end else if (x_signed < -32'sd726017) begin
                // x < ~-11.09 → e^x < 1/65536 → underflow to 0 in Q16.16
                compute_exp = 32'h00000001;  // Smallest positive Q16.16
            end else if (x_signed > 32'sd726017) begin
                // x > ~11.09 → e^x > 65535 → overflow in Q16.16
                compute_exp = 32'h7FFFFFFF;
            end else begin
                // x / ln(2) ≈ x * 1.4427 via shift-add (avoids multiply overflow)
                // 1.4427 ≈ 1 + 1/4 + 1/8 + 1/16 + 1/256 + 1/512 = 1.4434 (error < 0.05%)
                x_scaled = x_signed + (x_signed >>> 2) + (x_signed >>> 3) +
                           (x_signed >>> 4) + (x_signed >>> 8) + (x_signed >>> 9);

                // Extract integer and fractional parts (signed)
                k_int = x_scaled[31:16];
                frac_q16 = {16'h0, x_scaled[15:0]};  // Fractional part is always positive

                // 4th-order Horner polynomial for 2^f, f in [0,1)
                // 2^f ≈ 1 + f*(c1 + f*(c2 + f*(c3 + f*c4)))
                //   c1 = 0.693147  Q16.16: 0xB1AA
                //   c2 = 0.240226  Q16.16: 0x3D7A
                //   c3 = 0.055504  Q16.16: 0x0E38
                //   c4 = 0.009618  Q16.16: 0x0276
                pow2f = 32'h00000276;                          // c4
                pow2f = (frac_q16 * pow2f) >> 16;             // f*c4
                pow2f = pow2f + 32'h00000E38;                  // c3 + f*c4
                pow2f = (frac_q16 * pow2f) >> 16;             // f*(c3 + f*c4)
                pow2f = pow2f + 32'h00003D7A;                  // c2 + f*(c3 + f*c4)
                pow2f = (frac_q16 * pow2f) >> 16;             // f*(c2 + f*(c3 + f*c4))
                pow2f = pow2f + 32'h0000B1AA;                  // c1 + f*(c2 + f*(c3 + f*c4))
                pow2f = (frac_q16 * pow2f) >> 16;             // f*(c1 + f*(c2 + f*(c3 + f*c4)))
                pow2f = pow2f + 32'h00010000;                  // 1 + f*(c1 + f*(c2 + f*(c3 + f*c4)))

                // Apply 2^k: left-shift for k>0, right-shift for k<0
                if (k_int > 0 && k_int < 16) begin
                    compute_exp = pow2f << k_int;           // 2^k * 2^f, k positive
                end else if (k_int == 0) begin
                    compute_exp = pow2f;                     // 2^f only
                end else if (k_int < 0 && k_int > -16) begin
                    compute_exp = pow2f >> (-k_int);        // 2^k * 2^f, k negative
                end else if (k_int >= 16) begin
                    compute_exp = 32'h7FFFFFFF;              // Overflow
                end else begin
                    compute_exp = 32'h00000001;              // Underflow
                end
            end
        end
    endfunction

    // Compute ln approximation using Q16.16 fixed-point
    // Uses ln(x) = log2(x) * ln(2)
    // log2(x) found by leading-zero count for integer part + 4th-order polynomial for mantissa
    // Handles values < 1.0 (sub-unity) via signed log2_int
    function [31:0] compute_ln;
        input [31:0] input_val;  // Q16.16 format (unsigned interpretation)
        reg [31:0] x_norm;       // Normalized to [1.0, 2.0) in Q16.16
        reg signed [15:0] log2_int;  // Signed integer part of log2
        reg [31:0] m;           // Mantissa in Q16.16
        reg [31:0] m_minus1;    // (m - 1) in Q16.16
        reg signed [47:0] m_minus1_w;  // Widened m_minus1 for safe multiply
        reg signed [47:0] s_frac_w;    // Widened signed intermediate for polynomial
        reg signed [31:0] s_frac;  // Signed intermediate for polynomial (32-bit result)
        reg signed [47:0] poly_w;  // Wide intermediate for signed polynomial multiplies
        reg [4:0]  leading_one; // Position of highest set bit
        reg signed [31:0] log2_combined;  // log2_int + log2_frac in Q16.16 signed
        reg signed [47:0] ln_product;     // Wide intermediate for log2*ln2 multiply
        integer i;
        begin
            if (input_val == 32'h0) begin
                compute_ln = 32'h80000000;  // -infinity (error)
            end else if (input_val[31]) begin
                compute_ln = 32'h80000000;  // Negative input → error
            end else if (input_val == 32'h00010000) begin
                compute_ln = 32'h0;  // ln(1.0) = 0
            end else begin
                // Find position of highest set bit using priority encoder
                leading_one = 0;
                for (i = 30; i >= 0; i = i - 1) begin
                    if (input_val[i]) begin
                        leading_one = i[4:0];
                        i = 0;  // Break: stop at highest set bit
                    end
                end

                // Normalize: shift so bit 16 is the highest set bit
                // log2_int = leading_one - 16 (signed: negative for values < 1.0)
                if (leading_one >= 16) begin
                    x_norm = input_val >> (leading_one - 5'd16);
                    log2_int = {{11{1'b0}}, leading_one - 5'd16};  // Positive
                end else begin
                    x_norm = input_val << (5'd16 - leading_one);
                    log2_int = {{11{1'b0}}, leading_one - 5'd16};  // Negative for values < 1.0
                end

                // m = normalized value in [1.0, 2.0), m_minus1 = m - 1.0
                m = x_norm;
                m_minus1 = m - 32'h00010000;

                // 4th-order Horner polynomial for log2(1+f), f in [0,1)
                // log2(1+f) ≈ f*(a0 + f*(a1 + f*(a2 + f*a3)))
                // Least-squares minimax coefficients (max error < 0.2%):
                //   a0 =  1.4363  →  94130
                //   a1 = -0.6701  → -43916
                //   a2 =  0.3128  →  20499
                //   a3 = -0.0793  →  -5198
                // Use decimal signed constants (hex two's complement breaks 48-bit multiply)
                m_minus1_w = {{16{m_minus1[31]}}, m_minus1};
                poly_w = m_minus1_w * (-5198);            // a3 * f
                s_frac_w = poly_w >>> 16;
                s_frac_w = s_frac_w + 20499;              // + a2
                poly_w = m_minus1_w * s_frac_w;           // f * (a2 + a3*f)
                s_frac_w = poly_w >>> 16;
                s_frac_w = s_frac_w + (-43916);           // + a1
                poly_w = m_minus1_w * s_frac_w;           // f * (a1 + a2*f + a3*f^2)
                s_frac_w = poly_w >>> 16;
                s_frac_w = s_frac_w + 94130;              // + a0
                poly_w = m_minus1_w * s_frac_w;           // f * (a0 + a1*f + a2*f^2 + a3*f^3)
                s_frac_w = poly_w >>> 16;
                s_frac = s_frac_w[31:0];

                // Combine: log2(x) = log2_int + log2(1+f)
                // log2_int is signed Q16.0 (in Q16.16: {log2_int, 16'b0})
                // log2_frac is the full log2(1+f) in Q16.16 (range 0 to ~1.44)
                log2_combined = {log2_int, 16'b0} + s_frac;

                // ln(x) = log2(x) * ln(2) ≈ log2(x) * 0.693147
                // Use 48-bit intermediate to avoid signed 32-bit overflow
                // ln2 in Q16.16 = 45426
                ln_product = $signed(log2_combined) * 48'sd45426;
                compute_ln = ln_product[47:16];
            end
        end
    endfunction

    // Fetch stage: decode inputs, compute hash, check memo cache
    reg [31:0] fetch_rs1, fetch_rs2;
    reg [7:0]  fetch_hash;
    reg        fetch_valid;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            fetch_rs1 <= 0;
            fetch_rs2 <= 0;
            fetch_hash <= 0;
            fetch_valid <= 1'b0;
        end else begin
            if (i_valid) begin
                fetch_rs1 <= i_rs1;
                fetch_rs2 <= i_rs2;
                fetch_hash <= calculate_hash(i_rs1, i_rs2);
                fetch_valid <= 1'b1;
            end else begin
                fetch_valid <= 1'b0;
            end
        end
    end

    // Check memo cache
    wire [7:0] current_hash = fetch_hash;
    wire memo_check_valid = fetch_valid;
    wire [6:0] memo_idx = current_hash[6:0];  // Use lower 7 bits as index

    wire memo_hit_comb = memo_check_valid &
                         memo_valid[memo_idx] &
                         (memo_tags[memo_idx] == current_hash);
    reg memo_hit_d1, memo_hit_d2;
    reg [31:0] memo_data_out;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            memo_hit_d1 <= 1'b0;
            memo_hit_d2 <= 1'b0;
            memo_data_out <= 0;
            current_stage <= 3'b000;
            depth_cnt <= 0;
            overflow_flag <= 1'b0;
            nan_flag <= 1'b0;
            exc_depth <= 1'b0;
            o_valid <= 1'b0;
            o_rd <= 0;
            o_exc <= 1'b0;
        end else begin
            // Pipeline register updates
            memo_hit_d1 <= memo_hit_comb;
            memo_data_out <= memo_data[memo_idx];

            // Handle depth counter
            if (i_valid) begin
                depth_cnt <= depth_cnt + 1;
            end else if (current_stage == ST_WB) begin
                depth_cnt <= 0;  // Reset on completion
            end

            // Check depth limit
            exc_depth <= (depth_cnt > (i_cfg[MAX_DEPTH_END:MAX_DEPTH_START] + 1)) ? 1'b1 : 1'b0;

            // Execute pipeline stages
            if (i_valid) begin
                current_stage <= ST_FETCH;

                // Stage 1: Fetch and check memo cache
                if (current_stage == ST_FETCH) begin
                    memo_hit_d2 <= memo_hit_d1;
                    if (memo_hit_d1) begin
                        // Memo hit: return cached value
                        o_rd <= memo_data_out;
                        o_valid <= 1'b1;
                        current_stage <= ST_WB;
                    end else begin
                        // Memo miss: proceed with computation
                        current_stage <= ST_EXP;
                    end
                end
                // Stage 2: EXP calculation
                else if (current_stage == ST_EXP) begin
                    current_stage <= ST_LN;
                end
                // Stage 3: LN calculation
                else if (current_stage == ST_LN) begin
                    current_stage <= ST_SUB;
                end
                // Stage 4: SUB and complex operations
                else if (current_stage == ST_SUB) begin
                    current_stage <= ST_WB;
                end
                // Stage 5: Write back
                else if (current_stage == ST_WB) begin
                    // Final result
                    o_rd <= compute_exp(fetch_rs1) - compute_ln(fetch_rs2);

                    // Update memo cache on miss
                    if (!memo_hit_comb) begin
                        memo_tags[memo_idx] <= current_hash[7:0];
                        memo_data[memo_idx] <= o_rd;
                        memo_valid[memo_idx] <= 1'b1;
                    end

                    o_valid <= 1'b1;

                    // Check for exceptions
                    o_exc <= exc_depth;
                end
            end
            else begin
                // Clear outputs when not valid
                o_valid <= 1'b0;
                o_exc <= 1'b0;
            end
        end
    end

    assign o_ready = ~o_valid;  // Ready when output is not valid

endmodule