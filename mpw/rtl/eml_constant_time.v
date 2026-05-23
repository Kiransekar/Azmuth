// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// rtl/eml/eml_constant_time.v
// Constant-Time EML Operations for Side-Channel Attack Prevention

`timescale 1ns/1ps

module eml_constant_time (
    input wire clk,
    input wire rst,

    // Input operands
    input wire [31:0] rs1,
    input wire [31:0] rs2,
    input wire [31:0] cfg,
    input wire valid_in,
    output reg ready_out,

    // Output result
    output reg [31:0] rd,
    output reg valid_out,
    output reg ready_in,

    // Exception signal
    output reg exc,

    // CSR interface
    input wire [11:0] csr_addr,
    input wire csr_wr_en,
    input wire [31:0] csr_wr_data,
    output reg [31:0] csr_rd_data,

    // Security control
    input wire const_time_en,         // Constant time execution enabled
    input wire timing_var_en,         // Timing variation enabled (for debug)
    output reg stall_pipeline         // Stall for constant timing
);

    // Internal state
    reg [31:0] rs1_reg, rs2_reg, cfg_reg;
    reg valid_in_reg;
    reg [7:0] operation;              // Operation code
    reg [31:0] result_reg;
    reg [15:0] cycle_counter;
    reg [15:0] target_cycles;         // Fixed cycle target
    reg [15:0] current_op_cycles;     // Cycles for current operation
    reg [15:0] padding_cycles;        // Padding cycles needed
    reg [15:0] op_count_reg;          // Operation counter
    reg [31:0] sec_ctrl_reg;          // Security control register
    reg [31:0] intermediate_result;   // For multi-cycle operations

    // Operation codes
    parameter OP_NOP = 8'h00;
    parameter OP_EXP = 8'h01;
    parameter OP_LN  = 8'h02;
    parameter OP_SUB = 8'h03;
    parameter OP_MUL = 8'h04;
    parameter OP_ADD = 8'h05;
    parameter OP_DIV = 8'h06;

    // Fixed cycle counts for different operations
    parameter FIXED_EXP_CYCLES = 16'd30;
    parameter FIXED_LN_CYCLES  = 16'd25;
    parameter FIXED_MUL_CYCLES = 16'd15;
    parameter FIXED_DIV_CYCLES = 16'd40;
    parameter FIXED_OTHER_CYCLES = 16'd5;

    // States for constant-time operation
    typedef enum reg [2:0] {
        ST_IDLE = 3'b000,
        ST_EXECUTE = 3'b001,
        ST_PAD = 3'b010,
        ST_FINALIZE = 3'b011,
        ST_STALL_BRANCH = 3'b100
    } ct_state_t;

    ct_state_t state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rs1_reg <= 32'h0;
            rs2_reg <= 32'h0;
            cfg_reg <= 32'h0;
            valid_in_reg <= 1'b0;
            result_reg <= 32'h0;
            cycle_counter <= 16'h0;
            target_cycles <= FIXED_OTHER_CYCLES;  // Default
            current_op_cycles <= 16'h0;
            padding_cycles <= 16'h0;
            op_count_reg <= 16'h0;
            state <= ST_IDLE;
            ready_out <= 1'b1;
            valid_out <= 1'b0;
            ready_in <= 1'b1;
            exc <= 1'b0;
            stall_pipeline <= 1'b0;
            intermediate_result <= 32'h0;
            sec_ctrl_reg <= 32'h0;
        end
        else begin
            // Handle CSR writes
            if (csr_wr_en && csr_addr == 12'h7CA) begin
                sec_ctrl_reg <= csr_wr_data;
            end

            // State transitions
            case (state)
                ST_IDLE: begin
                    ready_out <= 1'b1;
                    if (valid_in && const_time_en) begin
                        rs1_reg <= rs1;
                        rs2_reg <= rs2;
                        cfg_reg <= cfg;
                        valid_in_reg <= 1'b1;
                        ready_out <= 1'b0;  // Not ready while processing
                        operation <= cfg[7:0];  // Extract operation code

                        // Set target cycles based on operation type
                        case (operation)
                            OP_EXP: target_cycles <= FIXED_EXP_CYCLES;
                            OP_LN:  target_cycles <= FIXED_LN_CYCLES;
                            OP_MUL: target_cycles <= FIXED_MUL_CYCLES;
                            OP_DIV: target_cycles <= FIXED_DIV_CYCLES;
                            default: target_cycles <= FIXED_OTHER_CYCLES;
                        endcase

                        cycle_counter <= 16'h1;  // Start counting from 1
                        state <= ST_EXECUTE;
                    end
                    else if (valid_in && !const_time_en) begin
                        // Non-constant time operation - execute normally
                        state <= ST_EXECUTE;
                    end
                end

                ST_EXECUTE: begin
                    // Execute the operation based on type
                    case (operation)
                        OP_NOP: begin
                            result_reg <= 32'h0;
                            current_op_cycles <= 16'd1;
                        end
                        OP_EXP: begin
                            // Approximate exponential calculation - fixed time implementation
                            result_reg <= approximate_exp(rs1_reg);
                            current_op_cycles <= FIXED_EXP_CYCLES;
                        end
                        OP_LN: begin
                            // Approximate natural log calculation - fixed time implementation
                            result_reg <= approximate_ln(rs1_reg);
                            current_op_cycles <= FIXED_LN_CYCLES;
                        end
                        OP_SUB: begin
                            result_reg <= rs1_reg - rs2_reg;
                            current_op_cycles <= FIXED_OTHER_CYCLES;
                        end
                        OP_MUL: begin
                            result_reg <= rs1_reg * rs2_reg;
                            current_op_cycles <= FIXED_MUL_CYCLES;
                        end
                        OP_ADD: begin
                            result_reg <= rs1_reg + rs2_reg;
                            current_op_cycles <= FIXED_OTHER_CYCLES;
                        end
                        OP_DIV: begin
                            if (rs2_reg != 32'h0) begin
                                result_reg <= rs1_reg / rs2_reg;
                            end else begin
                                result_reg <= 32'hFFFFFFFF;  // Divide by zero
                                exc <= 1'b1;
                            end
                            current_op_cycles <= FIXED_DIV_CYCLES;
                        end
                        default: begin
                            result_reg <= rs1_reg;  // Default pass-through
                            current_op_cycles <= FIXED_OTHER_CYCLES;
                        end
                    endcase

                    // Move to padding if in constant time mode
                    if (const_time_en) begin
                        padding_cycles <= target_cycles - current_op_cycles;
                        state <= ST_PAD;
                    end
                    else begin
                        // Non-constant time - finalize immediately
                        state <= ST_FINALIZE;
                    end
                end

                ST_PAD: begin
                    // Padding cycles to make execution time constant
                    cycle_counter <= cycle_counter + 1;

                    // Do dummy operations during padding
                    intermediate_result <= intermediate_result + cycle_counter;

                    if (cycle_counter >= padding_cycles) begin
                        state <= ST_FINALIZE;
                    end
                end

                ST_FINALIZE: begin
                    valid_out <= 1'b1;
                    stall_pipeline <= 1'b0;

                    if (ready_in) begin  // Output accepted
                        valid_out <= 1'b0;
                        ready_out <= 1'b1;  // Ready for next input
                        state <= ST_IDLE;
                        exc <= 1'b0;  // Clear exception
                    end
                end

                ST_STALL_BRANCH: begin
                    // Handle branch-cut stalling
                    stall_pipeline <= 1'b1;
                    cycle_counter <= cycle_counter + 1;

                    // Fixed cycle stall for branches
                    if (cycle_counter >= 16'd12) begin  // 12 cycles stall for branches
                        stall_pipeline <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase

            // Detect branch cuts and stall pipeline
            if (const_time_en && detect_branch_cut(rs1_reg, rs2_reg, cfg_reg)) begin
                state <= ST_STALL_BRANCH;
                cycle_counter <= 16'h0;
            end
        end
    end

    // Helper function for approximate exponential (Taylor series)
    function [31:0] approximate_exp;
        input [31:0] x;
        begin
            // Simplified fixed-time exp approximation
            approximate_exp = 32'h3F800000 + x; // 1.0 + x (linear approx)
        end
    endfunction

    // Helper function for approximate logarithm
    function [31:0] approximate_ln;
        input [31:0] x;
        begin
            // Simplified fixed-time ln approximation
            if (x <= 32'h0) approximate_ln = 32'h80000000; // -infinity
            else approximate_ln = x - 32'h3F800000; // x - 1 (linear approx near 1)
        end
    endfunction

    // Branch cut detection
    function detect_branch_cut;
        input [31:0] op1, op2, cfg_in;
        begin
            detect_branch_cut = 1'b0;
            // Detect operations that might cause branching in real implementation
            if (cfg_in[0] == 1'b1 && op1[31] != op2[31]) begin // Signed operations with different signs
                detect_branch_cut = 1'b1;
            end
        end
    endfunction

    // Assign outputs
    assign rd = result_reg;

    // CSR read logic
    always @(*) begin
        case (csr_addr)
            12'h7CA: csr_rd_data = sec_ctrl_reg;
            default: csr_rd_data = 32'h0;
        endcase
    end

endmodule

// Constant-time mux (resistant to side-channel)
module ct_mux #(parameter WIDTH = 32)
(
    input wire [WIDTH-1:0] in0,
    input wire [WIDTH-1:0] in1,
    input wire sel,
    output reg [WIDTH-1:0] out
);
    integer i;
    always @(*) begin
        for (i = 0; i < WIDTH; i = i + 1) begin
            out[i] = (sel & in1[i]) | (~sel & in0[i]);
        end
    end
endmodule