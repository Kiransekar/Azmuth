// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// xcie_ctrl.v
// Control logic for Xcew processor
// Implements the FSM described in the architecture document

module xcie_ctrl (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_valid,
    input  wire        i_decode_valid,
    input  wire [3:0]  i_xcew_id,
    input  wire        i_illegal,
    input  wire        i_eml_valid,
    input  wire        i_snn_done,
    input  wire        i_nvm_busy,

    output reg         o_ctrl_decode_valid,
    output reg         o_ctrl_csr_wr,
    output reg         o_ctrl_eml_valid,
    output reg         o_ctrl_memo_rd,
    output reg         o_ctrl_memo_wr,
    output reg         o_ctrl_snn_en,
    output reg         o_ctrl_nvm_wr,
    output reg         o_ctrl_irq_gen,
    output reg         o_ctrl_exc_gen
);

    // State encoding (binary)
    parameter IDLE      = 3'b000;
    parameter DECODE    = 3'b001;
    parameter EXE_EML   = 3'b010;
    parameter EXE_CFG   = 3'b011;
    parameter EXE_MEMO  = 3'b100;
    parameter EXE_SNN   = 3'b101;
    parameter EXE_NVM   = 3'b110;
    parameter TRAP      = 3'b111;

    reg [2:0] current_state, next_state;

    // Register state
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (i_valid)
                    next_state = DECODE;
                else
                    next_state = IDLE;
            end

            DECODE: begin
                if (i_illegal)
                    next_state = TRAP;
                else if (i_xcew_id == 4'h1)  // EML operation
                    next_state = EXE_EML;
                else if (i_xcew_id == 4'h2)  // CFG operation
                    next_state = EXE_CFG;
                else if (i_xcew_id == 4'h3 || i_xcew_id == 4'h4)  // MLOAD/MSTORE
                    next_state = EXE_MEMO;
                else if (i_xcew_id == 4'h5)  // SNN operation
                    next_state = EXE_SNN;
                else if (i_xcew_id == 4'h6)  // POL update
                    next_state = EXE_NVM;
                else
                    next_state = IDLE;
            end

            EXE_EML: begin
                if (i_eml_valid)
                    next_state = IDLE;
                else
                    next_state = EXE_EML;
            end

            EXE_CFG: begin
                next_state = IDLE;  // Single cycle for CSR write
            end

            EXE_MEMO: begin
                // Wait for memo operation to complete
                next_state = IDLE;
            end

            EXE_SNN: begin
                if (i_snn_done)
                    next_state = IDLE;
                else
                    next_state = EXE_SNN;
            end

            EXE_NVM: begin
                if (!i_nvm_busy)
                    next_state = IDLE;
                else
                    next_state = EXE_NVM;
            end

            TRAP: begin
                // Exception handling - return to IDLE after setting exception
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic based on current state
    always @(*) begin
        o_ctrl_decode_valid = 1'b0;
        o_ctrl_csr_wr = 1'b0;
        o_ctrl_eml_valid = 1'b0;
        o_ctrl_memo_rd = 1'b0;
        o_ctrl_memo_wr = 1'b0;
        o_ctrl_snn_en = 1'b0;
        o_ctrl_nvm_wr = 1'b0;
        o_ctrl_irq_gen = 1'b0;
        o_ctrl_exc_gen = 1'b0;

        case (current_state)
            IDLE: begin
                o_ctrl_decode_valid = 1'b0;
            end

            DECODE: begin
                o_ctrl_decode_valid = i_decode_valid;

                case (i_xcew_id)
                    4'h1: o_ctrl_eml_valid = 1'b1;  // EML operation
                    4'h2: o_ctrl_csr_wr = 1'b1;     // CFG operation
                    4'h3: o_ctrl_memo_rd = 1'b1;    // MLOAD operation
                    4'h4: o_ctrl_memo_wr = 1'b1;    // MSTORE operation
                    4'h5: o_ctrl_snn_en = 1'b1;     // SNN operation
                    4'h6: o_ctrl_nvm_wr = 1'b1;     // POL update operation
                    default: ;
                endcase
            end

            EXE_EML: begin
                o_ctrl_eml_valid = 1'b1;
            end

            EXE_CFG: begin
                o_ctrl_csr_wr = 1'b1;
            end

            EXE_MEMO: begin
                // Memo operation is ongoing
                if (i_xcew_id == 4'h3)  // MLOAD
                    o_ctrl_memo_rd = 1'b1;
                else if (i_xcew_id == 4'h4)  // MSTORE
                    o_ctrl_memo_wr = 1'b1;
            end

            EXE_SNN: begin
                o_ctrl_snn_en = 1'b1;
            end

            EXE_NVM: begin
                o_ctrl_nvm_wr = 1'b1;
            end

            TRAP: begin
                o_ctrl_exc_gen = 1'b1;
                o_ctrl_irq_gen = 1'b1;
            end

            default: begin
                // Default assignments remain 0
            end
        endcase
    end

endmodule