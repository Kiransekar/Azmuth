// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// xcie_decoder.v
// Instruction decoder for Xcew custom instructions
// Based on the specifications in the architecture document

module xcie_decoder (
    input  wire [6:0]  i_opcode,
    input  wire [2:0]  i_funct3,
    input  wire [6:0]  i_funct7,

    output reg         o_is_xcew,
    output reg [3:0]   o_xcew_id,
    output reg         o_illegal
);

    // Xcew custom opcode assignment (using custom opcode space)
    localparam XCEW_EML_OP    = 7'b1111011;  // Custom EML operation
    localparam XCEW_CFG_OP    = 7'b1111100;  // Configuration operation
    localparam XCEW_MLOAD_OP  = 7'b1111101;  // Memo load
    localparam XCEW_MSTORE_OP = 7'b1111110;  // Memo store
    localparam XCEW_SNN_OP    = 7'b1111111;  // SNN classification

    // Xcew instruction IDs
    localparam XCEW_ID_EML     = 4'h1;
    localparam XCEW_ID_CFG     = 4'h2;
    localparam XCEW_ID_MLOAD   = 4'h3;
    localparam XCEW_ID_MSTORE  = 4'h4;
    localparam XCEW_ID_SNN     = 4'h5;
    localparam XCEW_ID_POL_UPD = 4'h6;  // Policy update

    always @(*) begin
        o_is_xcew = 1'b0;
        o_xcew_id = 4'h0;
        o_illegal = 1'b0;

        case (i_opcode)
            XCEW_EML_OP: begin
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_EML;
                o_illegal = 1'b0;
            end

            XCEW_CFG_OP: begin
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_CFG;
                o_illegal = 1'b0;
            end

            XCEW_MLOAD_OP: begin
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_MLOAD;
                o_illegal = 1'b0;
            end

            XCEW_MSTORE_OP: begin
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_MSTORE;
                o_illegal = 1'b0;
            end

            XCEW_SNN_OP: begin
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_SNN;
                o_illegal = 1'b0;
            end

            default: begin
                o_is_xcew = 1'b0;
                o_xcew_id = 4'h0;
                o_illegal = 1'b0;  // Non-Xcew instructions are not illegal, just not handled here
            end
        endcase
    end

endmodule