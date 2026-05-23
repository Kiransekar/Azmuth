// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// rtl/security/fault_monitor.v
// Security Fault Monitor for Xcew Processor
// Includes watchdog, ECC, and fault detection

`timescale 1ns/1ps

module fault_monitor (
    input wire clk,
    input wire rst,

    // Pipeline interfaces to monitor
    input wire eml_pipe_active,
    input wire snn_pipe_active,
    input wire nvm_pipe_active,
    input wire csr_access_active,
    input wire instr_fetch_active,

    // Fault detection signals
    input wire [3:0] soft_error,        // Soft errors from monitored units
    input wire [3:0] hard_error,        // Hard errors from monitored units
    input wire ecc_error,               // ECC error signal
    input wire watchdog_trip,           // Watchdog trip signal
    input wire fault_detected,          // Generic fault signal

    // Control signals
    input wire fault_clr,               // Clear fault latch
    input wire irq_enable,              // Enable fault IRQ
    output reg irq_fault,              // Fault interrupt
    output reg pipeline_halt,          // Halt pipeline on fault
    output reg [3:0] error_code,       // Error code

    // CSR interface
    input wire [11:0] csr_addr,
    input wire csr_wr_en,
    input wire [31:0] csr_wr_data,
    output reg [31:0] csr_rd_data
);

    // Internal registers
    reg [31:0] fault_status_reg;
    reg [31:0] watchdog_timeout_reg;
    reg [31:0] ecc_scrub_count_reg;
    reg [31:0] ecc_corrected_count_reg;
    reg fault_latch;
    reg [3:0] latched_error_code;
    reg [31:0] last_csr_access;
    reg [31:0] last_instr_fetch;
    reg [31:0] fault_timestamp;

    // Watchdog timer
    reg [31:0] watchdog_counter;
    reg [31:0] watchdog_limit;
    reg watchdog_enabled;

    // ECC registers (72,64 SECDED)
    reg [71:0] ecc_data_reg;
    reg [7:0] ecc_syndrome_reg;
    reg ecc_correct_en;
    reg [63:0] ecc_corrected_data;

    // Cycle counter (replaces $time)
    reg [31:0] cycle_counter;

    // Internal watchdog trip register
    reg watchdog_internal_trip;

    // Error codes
    parameter ERR_NONE = 4'h0;
    parameter ERR_WATCHDOG = 4'h1;
    parameter ERR_ECC_SINGLE = 4'h2;
    parameter ERR_ECC_DOUBLE = 4'h3;
    parameter ERR_SOFT_EML = 4'h4;
    parameter ERR_SOFT_SNN = 4'h5;
    parameter ERR_HARD_NVM = 4'h6;
    parameter ERR_CSR_VIOLATION = 4'h7;
    parameter ERR_INSTR_FAULT = 4'h8;

    // Monitor state encoding (binary, no typedef enum)
    parameter MON_IDLE          = 3'b000;
    parameter MON_MONITOR       = 3'b001;
    parameter MON_FAULT_DETECTED = 3'b010;
    parameter MON_IRQ_ASSERT    = 3'b011;
    parameter MON_PIPELINE_HALT = 3'b100;

    reg [2:0] current_state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= MON_IDLE;
            fault_latch <= 1'b0;
            latched_error_code <= 4'h0;
            irq_fault <= 1'b0;
            pipeline_halt <= 1'b0;
            watchdog_counter <= 32'h0;
            watchdog_limit <= 32'h00FFFFFF;  // Default long timeout
            watchdog_enabled <= 1'b0;
            error_code <= 4'h0;
            fault_status_reg <= 32'h0;
            watchdog_timeout_reg <= 32'h0;
            ecc_scrub_count_reg <= 32'h0;
            ecc_corrected_count_reg <= 32'h0;
            last_csr_access <= 32'h0;
            last_instr_fetch <= 32'h0;
            fault_timestamp <= 32'h0;
            ecc_data_reg <= 72'h0;
            ecc_syndrome_reg <= 8'h0;
            ecc_correct_en <= 1'b0;
            ecc_corrected_data <= 64'h0;
        end
        else begin
            // Handle CSR writes
            if (csr_wr_en) begin
                case (csr_addr)
                    12'h7CC: begin
                        fault_status_reg <= csr_wr_data;
                        if (csr_wr_data[31]) begin  // Write 1 to clear fault latch
                            fault_latch <= 1'b0;
                            irq_fault <= 1'b0;
                            pipeline_halt <= 1'b0;
                        end
                    end
                    12'h7CD: watchdog_limit <= csr_wr_data;  // Watchdog timeout
                    12'h7CE: ecc_scrub_count_reg <= csr_wr_data;  // ECC control
                    default: ;  // Handle other CSRs
                endcase
            end

            // Update cycle counter
            cycle_counter <= cycle_counter + 1;

            // Update watchdog counter
            if (watchdog_enabled) begin
                if (eml_pipe_active || snn_pipe_active || nvm_pipe_active) begin
                    watchdog_counter <= 32'h0;  // Reset on activity
                end
                else begin
                    watchdog_counter <= watchdog_counter + 1;
                    if (watchdog_counter >= watchdog_limit) begin
                        watchdog_internal_trip <= 1'b1;
                    end
                    else begin
                        watchdog_internal_trip <= 1'b0;
                    end
                end
            end

            // Detect faults and latch
            if (soft_error[0] || soft_error[1] || soft_error[2] || soft_error[3] ||
                hard_error[0] || hard_error[1] || hard_error[2] || hard_error[3] ||
                ecc_error || watchdog_trip || fault_detected) begin

                // Determine error code based on fault type
                if (watchdog_trip) begin
                    latched_error_code <= ERR_WATCHDOG;
                end
                else if (ecc_error && (soft_error[0] || hard_error[0])) begin
                    latched_error_code <= ERR_ECC_SINGLE;
                end
                else if (ecc_error && (soft_error[1] || hard_error[1])) begin
                    latched_error_code <= ERR_ECC_DOUBLE;
                end
                else if (soft_error[0]) begin  // EML soft error
                    latched_error_code <= ERR_SOFT_EML;
                end
                else if (soft_error[1]) begin  // SNN soft error
                    latched_error_code <= ERR_SOFT_SNN;
                end
                else if (hard_error[2]) begin  // NVM hard error
                    latched_error_code <= ERR_HARD_NVM;
                end
                else if (csr_access_active && fault_detected) begin
                    latched_error_code <= ERR_CSR_VIOLATION;
                end
                else if (instr_fetch_active && fault_detected) begin
                    latched_error_code <= ERR_INSTR_FAULT;
                end
                else begin
                    latched_error_code <= ERR_NONE;
                end

                fault_latch <= 1'b1;
                fault_timestamp <= cycle_counter;

                // Update status register
                fault_status_reg[3:0] <= latched_error_code;
                fault_status_reg[4] <= watchdog_trip;
                fault_status_reg[5] <= ecc_error;
            end

            // State transitions
            case (current_state)
                MON_IDLE: begin
                    if (fault_latch && irq_enable) begin
                        current_state <= MON_IRQ_ASSERT;
                    end
                end

                MON_IRQ_ASSERT: begin
                    irq_fault <= 1'b1;
                    if (fault_clr) begin
                        current_state <= MON_PIPELINE_HALT;
                    end
                    else if (pipeline_halt) begin
                        current_state <= MON_PIPELINE_HALT;
                    end
                end

                MON_PIPELINE_HALT: begin
                    pipeline_halt <= 1'b1;
                    // Remain halted until handled by mtvec handler
                    if (fault_clr) begin
                        fault_latch <= 1'b0;
                        irq_fault <= 1'b0;
                        pipeline_halt <= 1'b0;
                        current_state <= MON_IDLE;
                    end
                end

                default: current_state <= MON_IDLE;
            endcase

            // Update error code output
            error_code <= latched_error_code;

            // Update fault status register bits
            fault_status_reg[3:0] <= latched_error_code;
            fault_status_reg[4] <= watchdog_trip;
            fault_status_reg[5] <= ecc_error;
        end
    end

    // ECC encoding - inline simple parity for synthesis compatibility
    wire [7:0] temp_parity;
    integer ecc_i, ecc_j;
    reg [7:0] ecc_parity_calc;

    always @(*) begin
        ecc_parity_calc = 8'h00;
        for (ecc_i = 0; ecc_i < 8; ecc_i = ecc_i + 1) begin
            ecc_parity_calc[ecc_i] = 1'b0;
            for (ecc_j = 0; ecc_j < 8; ecc_j = ecc_j + 1) begin
                ecc_parity_calc[ecc_i] = ecc_parity_calc[ecc_i] ^ ecc_data_reg[(ecc_i*8)+ecc_j];
            end
        end
    end

    assign temp_parity = ecc_parity_calc;

    // CSR read logic
    always @(*) begin
        case (csr_addr)
            12'h7CC: csr_rd_data = {24'h0, watchdog_trip, ecc_error, fault_status_reg[5:0]};
            12'h7CD: csr_rd_data = watchdog_timeout_reg;
            12'h7CE: csr_rd_data = ecc_scrub_count_reg;
            12'h7CF: csr_rd_data = ecc_corrected_count_reg;
            default: csr_rd_data = 32'h0;
        endcase
    end

endmodule

// ECC memory wrapper with SECDED protection
module ecc_memory #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 10
)(
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    output reg [DATA_WIDTH-1:0] rd_data,
    output reg ecc_error,
    output reg [1:0] error_type
);

    // Simple parity for SECDED (simplified)
    wire parity;
    assign parity = ^wr_data;
    wire overall_parity = ^{wr_data, parity};
    wire [65:0] wr_data_ecc = {wr_data, parity, overall_parity};
    reg [65:0] memory_array [0:(1<<ADDR_WIDTH)-1];
    wire [65:0] rd_data_ecc = memory_array[addr];
    wire rd_parity = ^rd_data_ecc[63:0];

    always @(posedge clk) begin
        if (wr_en) begin
            memory_array[addr] <= wr_data_ecc;
        end
        rd_data <= rd_data_ecc[63:0];

        // Determine error type from parity
        if (rd_data_ecc[65] != rd_parity) begin
            error_type <= 2'b01;
            ecc_error <= 1'b1;
        end else begin
            error_type <= 2'b00;
            ecc_error <= 1'b0;
        end
    end

endmodule

// Watchdog timer module
module watchdog_timer (
    input wire clk,
    input wire rst,
    input wire timer_en,
    input wire timer_rst,
    input wire [31:0] timeout_val,
    output reg timeout,
    output reg timeout_pulse
);

    reg [31:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 32'h0;
            timeout <= 1'b0;
            timeout_pulse <= 1'b0;
        end
        else begin
            if (timer_rst || !timer_en) begin
                counter <= 32'h0;
                timeout <= 1'b0;
                timeout_pulse <= 1'b0;
            end
            else if (timer_en) begin
                if (counter < timeout_val) begin
                    counter <= counter + 1;
                    timeout <= 1'b0;
                    timeout_pulse <= 1'b0;
                end
                else begin
                    timeout <= 1'b1;
                    timeout_pulse <= 1'b1;
                end
            end
        end
    end

endmodule