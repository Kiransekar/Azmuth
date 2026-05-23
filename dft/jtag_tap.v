// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// dft/jtag_tap.v
// JTAG Test Access Port (TAP) controller for Xcew Processor
// Implements IEEE 1149.1 standard for boundary scan and device testing

`timescale 1ns/1ps

module jtag_tap (
    input wire tck,
    input wire tms,
    input wire tdi,
    output reg tdo,
    input wire trst,

    // System control
    output reg sys_rst,
    output reg sys_clk,

    // Instruction register outputs
    output reg [7:0] instruction_reg,
    output reg [31:0] data_register,

    // Data register control
    output reg [31:0] instruction_capture,
    output reg [31:0] instruction_shift,
    output reg [31:0] instruction_update,

    // Debug interface
    output reg debug_enable,
    output reg [31:0] debug_data_out,
    input wire [31:0] debug_data_in
);

    // TAP controller states (IEEE 1149.1)
    typedef enum reg [3:0] {
        TEST_LOGIC_RESET  = 4'b0000,
        RUN_TEST_IDLE     = 4'b0001,
        SELECT_DR_SCAN    = 4'b0010,
        CAPTURE_DR        = 4'b0011,
        SHIFT_DR          = 4'b0100,
        EXIT1_DR          = 4'b0101,
        PAUSE_DR          = 4'b0110,
        EXIT2_DR          = 4'b0111,
        UPDATE_DR         = 4'b1000,
        SELECT_IR_SCAN    = 4'b1010,
        CAPTURE_IR        = 4'b1011,
        SHIFT_IR          = 4'b1100,
        EXIT1_IR          = 4'b1101,
        PAUSE_IR          = 4'b1110,
        EXIT2_IR          = 4'b1111,
        UPDATE_IR         = 4'b0000  // Same as TEST_LOGIC_RESET
    } tap_state_t;

    tap_state_t current_state, next_state;

    // JTAG registers
    reg [3:0] instruction_register;  // 4-bit for basic instructions
    reg [31:0] bypass_register;      // Bypass register (always 1 bit in practice)
    reg [31:0] idcode_register;      // IDCODE register (32-bit)

    // Shift registers
    reg [31:0] dr_shift_reg;         // Data register shift
    reg [3:0] ir_shift_reg;          // Instruction register shift

    // TDO multiplexer control
    reg tdo_mux_select;
    reg [31:0] tdo_shift_reg;

    // IDCODE for Xcew Processor
    parameter XCEW_IDCODE = 32'h04ECE001;  // Example IDCODE for Xcew Processor

    // Instruction codes
    parameter IDCODE_INSTR = 4'b0001;
    parameter BYPASS_INSTR = 4'b1111;
    parameter EXTEST_INSTR = 4'b0000;
    parameter SAMPLE_INSTR = 4'b0010;
    parameter PRELOAD_INSTR = 4'b0011;
    parameter DEBUG_INSTR = 4'b0100;

    // TAP controller state machine
    always @(posedge tck or posedge trst) begin
        if (trst) begin
            current_state <= TEST_LOGIC_RESET;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case ({current_state, tms})
            {TEST_LOGIC_RESET, 1'b0}: next_state = RUN_TEST_IDLE;
            {TEST_LOGIC_RESET, 1'b1}: next_state = TEST_LOGIC_RESET;

            {RUN_TEST_IDLE, 1'b0}: next_state = RUN_TEST_IDLE;
            {RUN_TEST_IDLE, 1'b1}: next_state = SELECT_DR_SCAN;

            {SELECT_DR_SCAN, 1'b0}: next_state = CAPTURE_DR;
            {SELECT_DR_SCAN, 1'b1}: next_state = SELECT_IR_SCAN;

            {CAPTURE_DR, 1'b0}: next_state = SHIFT_DR;
            {CAPTURE_DR, 1'b1}: next_state = EXIT1_DR;

            {SHIFT_DR, 1'b0}: next_state = SHIFT_DR;
            {SHIFT_DR, 1'b1}: next_state = EXIT1_DR;

            {EXIT1_DR, 1'b0}: next_state = PAUSE_DR;
            {EXIT1_DR, 1'b1}: next_state = UPDATE_DR;

            {PAUSE_DR, 1'b0}: next_state = PAUSE_DR;
            {PAUSE_DR, 1'b1}: next_state = EXIT2_DR;

            {EXIT2_DR, 1'b0}: next_state = SHIFT_DR;
            {EXIT2_DR, 1'b1}: next_state = UPDATE_DR;

            {UPDATE_DR, 1'b0}: next_state = RUN_TEST_IDLE;
            {UPDATE_DR, 1'b1}: next_state = SELECT_DR_SCAN;

            {SELECT_IR_SCAN, 1'b0}: next_state = CAPTURE_IR;
            {SELECT_IR_SCAN, 1'b1}: next_state = TEST_LOGIC_RESET;

            {CAPTURE_IR, 1'b0}: next_state = SHIFT_IR;
            {CAPTURE_IR, 1'b1}: next_state = EXIT1_IR;

            {SHIFT_IR, 1'b0}: next_state = SHIFT_IR;
            {SHIFT_IR, 1'b1}: next_state = EXIT1_IR;

            {EXIT1_IR, 1'b0}: next_state = PAUSE_IR;
            {EXIT1_IR, 1'b1}: next_state = UPDATE_IR;

            {PAUSE_IR, 1'b0}: next_state = PAUSE_IR;
            {PAUSE_IR, 1'b1}: next_state = EXIT2_IR;

            {EXIT2_IR, 1'b0}: next_state = SHIFT_IR;
            {EXIT2_IR, 1'b1}: next_state = UPDATE_IR;

            {UPDATE_IR, 1'b0}: next_state = RUN_TEST_IDLE;
            {UPDATE_IR, 1'b1}: next_state = SELECT_DR_SCAN;

            default: next_state = TEST_LOGIC_RESET;
        endcase
    end

    // Shift register control
    always @(posedge tck or posedge trst) begin
        if (trst) begin
            ir_shift_reg <= 4'b0001;  // Default to IDCODE instruction
            dr_shift_reg <= 0;
            tdo_shift_reg <= 0;
            instruction_reg <= 0;
            data_register <= 0;
            debug_enable <= 1'b0;
        end else begin
            case (current_state)
                CAPTURE_IR: begin
                    ir_shift_reg <= instruction_register;
                end

                SHIFT_IR: begin
                    ir_shift_reg <= {tdi, ir_shift_reg[3:1]};
                    tdo <= ir_shift_reg[0];
                end

                UPDATE_IR: begin
                    instruction_register <= ir_shift_reg;
                    instruction_reg <= {24'b0, ir_shift_reg};
                end

                CAPTURE_DR: begin
                    case (instruction_register)
                        IDCODE_INSTR: dr_shift_reg <= XCEW_IDCODE;
                        BYPASS_INSTR: dr_shift_reg <= bypass_register;
                        DEBUG_INSTR: dr_shift_reg <= debug_data_in;
                        default: dr_shift_reg <= 32'hDEADBEEF;  // Unknown instruction
                    endcase
                end

                SHIFT_DR: begin
                    dr_shift_reg <= {tdi, dr_shift_reg[31:1]};
                    tdo <= dr_shift_reg[0];
                end

                UPDATE_DR: begin
                    data_register <= dr_shift_reg;
                    case (instruction_register)
                        DEBUG_INSTR: debug_data_out <= dr_shift_reg;
                        default: /* Do nothing */;
                    endcase
                end

                default: begin
                    // TDO output based on current instruction
                    case (instruction_register)
                        IDCODE_INSTR: tdo <= dr_shift_reg[0];
                        BYPASS_INSTR: tdo <= tdi;
                        DEBUG_INSTR: tdo <= dr_shift_reg[0];
                        default: tdo <= 1'bz;
                    endcase
                end
            endcase

            // Enable debug mode when DEBUG instruction is selected
            debug_enable <= (instruction_register == DEBUG_INSTR);
        end
    end

    // Bypass register (simple pass-through)
    always @(posedge tck) begin
        if (current_state == SHIFT_DR && instruction_register == BYPASS_INSTR) begin
            bypass_register <= {tdi, bypass_register[31:1]};
        end
    end

    // System control outputs
    assign sys_rst = trst;
    assign sys_clk = tck;

    // Instruction callbacks for different operations
    always @(posedge tck) begin
        if (current_state == UPDATE_IR) begin
            case (instruction_register)
                EXTEST_INSTR: /* External test mode */;
                SAMPLE_INSTR: /* Sample data */;
                PRELOAD_INSTR: /* Preload data */;
                DEBUG_INSTR: /* Debug mode */;
                default: /* Reserved/unknown */;
            endcase
        end
    end

    // Capture and update callbacks for data register operations
    always @(posedge tck) begin
        if (current_state == CAPTURE_DR) begin
            instruction_capture <= {28'b0, instruction_register};
        end

        if (current_state == UPDATE_DR) begin
            instruction_update <= {28'b0, instruction_register};
            instruction_shift <= dr_shift_reg;
        end
    end

endmodule

// JTAG instruction decoder for extended functionality
module jtag_instruction_decoder (
    input wire [7:0] instruction,
    output reg inst_extest,
    output reg inst_sample,
    output reg inst_preload,
    output reg inst_debug,
    output reg inst_idcode,
    output reg inst_bypass,
    output reg inst_user1,
    output reg inst_user2
);

    always @(*) begin
        inst_extest = 1'b0;
        inst_sample = 1'b0;
        inst_preload = 1'b0;
        inst_debug = 1'b0;
        inst_idcode = 1'b0;
        inst_bypass = 1'b0;
        inst_user1 = 1'b0;
        inst_user2 = 1'b0;

        case (instruction[3:0])  // Using lower 4 bits for standard instructions
            4'b0000: inst_extest = 1'b1;      // EXTEST
            4'b0010: inst_sample = 1'b1;      // SAMPLE
            4'b0011: inst_preload = 1'b1;     // PRELOAD
            4'b0100: inst_debug = 1'b1;       // DEBUG
            4'b0001: inst_idcode = 1'b1;      // IDCODE
            4'b1111: inst_bypass = 1'b1;      // BYPASS
            4'b1000: inst_user1 = 1'b1;       // USER1
            4'b1001: inst_user2 = 1'b1;       // USER2
            default: inst_bypass = 1'b1;       // Default to bypass
        endcase
    end

endmodule