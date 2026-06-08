// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// rtl/core/policy_determinism.v
// Deterministic Policy Execution Controller for Xcew Processor

`timescale 1ns/1ps

module policy_determinism (
    input wire clk,
    input wire rst,

    // Policy execution interface
    input wire policy_exec_start,     // Start policy execution
    input wire [31:0] policy_data,   // Policy parameters/data
    input wire policy_valid,         // Policy data is valid
    output reg policy_done,          // Policy execution done
    output reg [31:0] policy_result, // Policy result

    // Control signals
    input wire det_en,               // Deterministic execution enabled
    input wire [4:1] max_cycles,    // Maximum allowed cycles
    output reg timeout_irq,         // Timeout IRQ for exceeded cycles

    // CSR interface
    input wire [11:0] csr_addr,
    input wire csr_wr_en,
    input wire [31:0] csr_wr_data,
    output reg [31:0] csr_rd_data
);

    // Internal registers
    reg [31:0] pol_sec_reg;         // Policy security register
    reg [31:0] internal_policy_data;
    reg [31:0] temp_result;
    reg [15:0] cycle_counter;
    reg [15:0] max_cycle_setting;
    reg exec_active;
    reg timeout_occurred;
    reg [15:0] target_cycles;  // BUG-037: separate target from cycle counter

    // State encoding for policy execution
    parameter IDLE = 3'b000;
    parameter START_EXEC = 3'b001;
    parameter EXECUTE = 3'b010;
    parameter FINALIZE = 3'b011;
    parameter TIMEOUT = 3'b100;
    parameter DONE = 3'b101;  // BUG-037: holdoff state to keep policy_done=1

    reg [2:0] current_state, next_state;
    reg [3:0] timeout_wait_cnt;  // BUG-037: separate wait counter for TIMEOUT

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            cycle_counter <= 16'h0;
            exec_active <= 1'b0;
            timeout_irq <= 1'b0;
            policy_done <= 1'b0;
            timeout_occurred <= 1'b0;
            temp_result <= 32'h0;
            internal_policy_data <= 32'h0;
            pol_sec_reg <= 32'h0;
            max_cycle_setting <= 16'd12;  // Default 12 cycles
            policy_result <= 32'h0;
            timeout_wait_cnt <= 4'd0;  // BUG-037
            target_cycles <= 16'd12;   // BUG-037
        end
        else begin
            // Handle CSR writes
            if (csr_wr_en && csr_addr == 12'h7CB) begin
                pol_sec_reg <= csr_wr_data;
                max_cycle_setting <= {12'h0, csr_wr_data[4:1]};  // Extract max cycles
            end

            // State transitions
            case (current_state)
                IDLE: begin
                    policy_done <= 1'b0;
                    timeout_irq <= 1'b0;
                    timeout_occurred <= 1'b0;

                    if (policy_exec_start && det_en) begin
                        internal_policy_data <= policy_data;
                        exec_active <= 1'b1;
                        cycle_counter <= 16'h1;  // Start from 1
                        current_state <= START_EXEC;
                    end
                    else if (policy_exec_start && !det_en) begin
                        internal_policy_data <= policy_data;
                        exec_active <= 1'b1;
                        cycle_counter <= 16'h1;
                        current_state <= EXECUTE;
                    end
                end

                START_EXEC: begin
                    // Begin deterministic execution
                    temp_result <= 32'h0;  // Initialize result
                    cycle_counter <= 16'h1;  // Always start counting from 1

                    // Determine target cycle count based on policy type
                    // (capped by max_cycle_setting)
                    case (policy_data[7:0])
                        8'h01: target_cycles <= (16'd12 < max_cycle_setting) ? 16'd12 : max_cycle_setting;
                        8'h02: target_cycles <= (16'd24 < max_cycle_setting) ? 16'd24 : max_cycle_setting;
                        8'h03: target_cycles <= (16'd18 < max_cycle_setting) ? 16'd18 : max_cycle_setting;
                        default: target_cycles <= max_cycle_setting;
                    endcase

                    current_state <= EXECUTE;
                end

                EXECUTE: begin
                    cycle_counter <= cycle_counter + 1;

                    // Execute policy operations in fixed time
                    temp_result <= temp_result + {{16{1'b0}}, cycle_counter} + {{16{1'b0}}, internal_policy_data[15:0]};

                    if (det_en) begin
                        // BUG-037 fix: deterministic mode completes at
                        // target_cycles (normal) or max_cycle_setting (timeout)
                        if (cycle_counter >= max_cycle_setting) begin
                            // Past max: timeout
                            timeout_occurred <= 1'b1;
                            timeout_irq <= 1'b1;
                            current_state <= TIMEOUT;
                        end
                        else if (cycle_counter >= target_cycles) begin
                            // Reached target: normal completion
                            current_state <= FINALIZE;
                        end
                    end
                    else begin
                        // Non-deterministic: finish when computation complete
                        if (cycle_counter >= 16'd20) begin
                            current_state <= FINALIZE;
                        end
                    end
                end

                FINALIZE: begin
                    temp_result <= temp_result + {{16{1'b0}}, cycle_counter} + {{16{1'b0}}, internal_policy_data[15:0]};
                    policy_result <= temp_result ^ {16'h0, cycle_counter};
                    policy_done <= 1'b1;
                    exec_active <= 1'b0;
                    // BUG-037 fix: transition to DONE holdoff instead of
                    // jumping straight to IDLE (which would clear policy_done
                    // before the consumer could see it)
                    current_state <= DONE;
                end

                // BUG-037 fix: DONE state holds policy_done=1 for one full
                // cycle so the consumer is guaranteed to sample it.
                DONE: begin
                    policy_done <= 1'b0;
                    current_state <= IDLE;
                end

                TIMEOUT: begin
                    policy_result <= 32'hDEADBEEF;  // Error code
                    policy_done <= 1'b1;
                    exec_active <= 1'b0;
                    timeout_irq <= 1'b1;
                    // BUG-037 fix: use separate wait counter so we don't
                    // depend on cycle_counter which is already past max.
                    timeout_wait_cnt <= timeout_wait_cnt + 1;
                    if (timeout_wait_cnt >= 4'd2) begin
                        current_state <= DONE;
                        timeout_irq <= 1'b0;
                        timeout_wait_cnt <= 4'd0;
                    end
                end

                default: current_state <= IDLE;
            endcase
        end
    end

    // CSR read logic
    always @(*) begin
        case (csr_addr)
            12'h7CB: csr_rd_data = {16'h0, 1'b0, timeout_occurred, 1'b0, det_en, {8{1'b0}}, max_cycle_setting[4:1]};
            default: csr_rd_data = 32'h0;
        endcase
    end

endmodule

// Fixed-cycle arithmetic unit for deterministic operations
module fixed_cycle_arith #(
    parameter OPERATION_CYCLES = 12
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] op_a,
    input wire [31:0] op_b,
    input wire [3:0] op_type,  // Operation type
    output reg [31:0] result,
    output reg done
);

    reg [31:0] accumulator;
    reg [31:0] temp_a, temp_b;
    reg [4:0] cycle_counter;
    reg internal_start;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            accumulator <= 32'h0;
            temp_a <= 32'h0;
            temp_b <= 32'h0;
            cycle_counter <= 5'h0;
            done <= 1'b0;
            result <= 32'h0;
            internal_start <= 1'b0;
        end
        else begin
            if (start) begin
                temp_a <= op_a;
                temp_b <= op_b;
                cycle_counter <= 5'h1;
                internal_start <= 1'b1;
                accumulator <= 32'h0;
                done <= 1'b0;
            end

            if (internal_start && cycle_counter < OPERATION_CYCLES) begin
                cycle_counter <= cycle_counter + 1;

                // Perform operations each cycle regardless of actual computation need
                case (op_type)
                    4'b0001: accumulator <= accumulator + temp_a + {{27{1'b0}}, cycle_counter};  // ADD-like
                    4'b0010: accumulator <= accumulator ^ temp_b ^ {{27{1'b0}}, cycle_counter};  // XOR-like
                    4'b0011: accumulator <= (accumulator <<< 1) ^ temp_a;        // Shift-like
                    default: accumulator <= accumulator + 32'h1;                  // Default increment
                endcase
            end
            else if (internal_start && cycle_counter >= OPERATION_CYCLES) begin
                result <= accumulator ^ temp_a ^ temp_b;
                done <= 1'b1;
                internal_start <= 1'b0;
            end
        end
    end

endmodule