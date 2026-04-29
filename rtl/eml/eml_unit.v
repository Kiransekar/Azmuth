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
    // 2^f approximated by polynomial: 1 + f*(0.6+0.4*f) for f in [0,1)
    function [31:0] compute_exp;
        input [31:0] input_val;  // Q16.16 format
        reg [31:0] x_scaled;     // x / ln(2) in Q16.16
        reg [15:0] k_int;        // integer part of x/ln2
        reg [31:0] frac_q16;     // fractional part in Q16.16
        reg [31:0] pow2f;        // 2^f in Q16.16
        reg [31:0] temp;
        begin
            // Clamp negative inputs to avoid underflow
            if (input_val[31]) begin
                compute_exp = 32'h00010000;  // e^(negative) ≈ 0 in Q16.16 → return ~0.0039
            end else if (input_val > 32'h000B0000) begin
                // Large input: clamp to max representable
                compute_exp = 32'h7FFFFFFF;
            end else begin
                // x / ln(2) ≈ x * (1/0.6931) ≈ x * 1.4427 ≈ x + x*0.4427
                // In Q16.16: 1.4427 ≈ 0x170B3
                x_scaled = (input_val >> 1) + (input_val >> 2) + (input_val >> 4) +
                           (input_val >> 8) + (input_val >> 12);  // ≈ x * 1.4424

                // Extract integer and fractional parts
                k_int = x_scaled[31:16];
                frac_q16 = {16'h0, x_scaled[15:0]};

                // Approximate 2^f using polynomial: 1 + f*(0.6423 + 0.3577*f)
                // In Q16.16: 0.6423 ≈ 0xA4B8, 0.3577 ≈ 0x5B94
                temp = (frac_q16 * 32'h00005B94) >> 16;  // 0.3577 * f
                temp = temp + 32'h0000A4B8;               // + 0.6423
                pow2f = (frac_q16 * temp) >> 16;          // f * (0.6423 + 0.3577*f)
                pow2f = pow2f + 32'h00010000;             // + 1.0

                // Apply 2^k by shifting (k_int is the integer exponent)
                if (k_int < 16) begin
                    compute_exp = pow2f << k_int;
                end else begin
                    compute_exp = 32'h7FFFFFFF;  // Overflow
                end
            end
        end
    endfunction

    // Compute ln approximation using Q16.16 fixed-point
    // Uses ln(x) = log2(x) * ln(2)
    // log2(x) found by leading-zero count for integer part + polynomial for mantissa
    function [31:0] compute_ln;
        input [31:0] input_val;  // Q16.16 format
        reg [31:0] x_norm;       // Normalized to [1.0, 2.0) in Q16.16
        reg [15:0] log2_int;     // Integer part of log2
        reg [31:0] log2_frac;   // Fractional part of log2 in Q16.16
        reg [31:0] m;           // Mantissa in Q16.16
        reg [31:0] m_minus1;    // (m - 1) in Q16.16
        reg [4:0]  leading_one; // Position of highest set bit
        integer i;
        begin
            if (input_val == 0) begin
                compute_ln = 32'h80000000;  // -infinity (error)
            end else if (input_val[31]) begin
                compute_ln = 32'h80000000;  // Negative input → error
            end else begin
                // Find position of highest set bit using priority encoder
                // This is synthesizable as a fixed-bound for-loop
                leading_one = 0;
                for (i = 30; i >= 0; i = i - 1) begin
                    if (input_val[i]) begin
                        leading_one = i[4:0];
                    end
                end

                // Normalize: shift so bit 16 is the highest set bit
                // log2_int = leading_one - 16 (the exponent in Q16.16 representation)
                if (leading_one >= 16) begin
                    x_norm = input_val >> (leading_one - 16);
                    log2_int = leading_one - 16;
                end else begin
                    x_norm = input_val << (16 - leading_one);
                    log2_int = leading_one - 16;  // Will be negative for values < 1.0
                end

                // m = normalized value in [1.0, 2.0), m_minus1 = m - 1.0
                m = x_norm;
                m_minus1 = m - 32'h00010000;

                // Approximate log2(1+f) for f in [0,1) using polynomial
                // log2(1+f) ≈ f*(a0 + f*(a1 + f*a2))
                // a0 = 1.4427, a1 = -0.7213, a2 = 0.4150 (fitted for [0,1))
                // In Q16.16: a0=0x170B3, a1=-0xB8A4, a2=0x6A3D
                log2_frac = (m_minus1 * 32'h00006A3D) >> 16;  // a2 * f
                log2_frac = log2_frac + 32'hFFFF475C;          // + a1 (negative)
                log2_frac = (m_minus1 * log2_frac) >> 16;     // f * (a1 + a2*f)
                log2_frac = log2_frac + 32'h000170B3;          // + a0
                log2_frac = (m_minus1 * log2_frac) >> 16;     // f * (a0 + a1*f + a2*f^2)

                // Combine: log2(x) = log2_int + log2_frac
                // ln(x) = log2(x) * ln(2) ≈ log2(x) * 0.6931
                // In Q16.16: 0.6931 ≈ 0xB1AA
                compute_ln = (({16'h0, log2_int} + log2_frac) * 32'h0000B1AA) >> 16;
                // Adjust for log2_int sign (subtract 16 since Q16.16 has implicit 16-bit shift)
                if (log2_int[15]) begin
                    compute_ln = compute_ln - (32'h0000B1AA << 1);  // Compensation for negative log2_int
                end
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
    wire [7:0] memo_idx = current_hash[6:0];  // Use lower 7 bits as index

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
                        memo_tags[memo_idx] <= current_hash;
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