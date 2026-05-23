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

    // Xcew custom opcode assignment.
    // DECISION-008: the four STANDARD RISC-V custom opcode slots are
    // authoritative (matching rtl/core/riscv_core.v). The previous map
    // (1111011..1111111) was non-compliant: 1111111 etc. fall in the space
    // reserved by the RISC-V spec for >=80-bit instruction encodings.
    // Resolves MICRO_ARCH_SPEC DEV-001 (opcode map disagreement).
    localparam XCEW_EML_OP     = 7'b0001011;  // custom-0  -> EML
    localparam XCEW_POL_UPD_OP = 7'b0101011;  // custom-1  -> policy update
    localparam XCEW_SNN_OP     = 7'b1011011;  // custom-2  -> SNN classify
    localparam XCEW_MISC_OP    = 7'b1111011;  // custom-3  -> CFG/MLOAD/MSTORE (by funct3)

    // MISC (custom-3) sub-function encoding in funct3
    localparam MISC_F3_CFG    = 3'b000;
    localparam MISC_F3_MLOAD  = 3'b001;
    localparam MISC_F3_MSTORE = 3'b010;

    // Xcew instruction IDs (consumed by xcie_ctrl FSM)
    localparam XCEW_ID_EML     = 4'h1;
    localparam XCEW_ID_CFG     = 4'h2;
    localparam XCEW_ID_MLOAD   = 4'h3;
    localparam XCEW_ID_MSTORE  = 4'h4;
    localparam XCEW_ID_SNN     = 4'h5;
    localparam XCEW_ID_POL_UPD = 4'h6;  // Policy update (DEV-002: now reachable)

    always @(*) begin
        o_is_xcew = 1'b0;
        o_xcew_id = 4'h0;
        o_illegal = 1'b0;

        case (i_opcode)
            XCEW_EML_OP: begin
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_EML;
            end

            XCEW_POL_UPD_OP: begin   // DEV-002: POL_UPD now decodes from custom-1
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_POL_UPD;
            end

            XCEW_SNN_OP: begin
                o_is_xcew = 1'b1;
                o_xcew_id = XCEW_ID_SNN;
            end

            XCEW_MISC_OP: begin
                o_is_xcew = 1'b1;
                case (i_funct3)
                    MISC_F3_CFG:    o_xcew_id = XCEW_ID_CFG;
                    MISC_F3_MLOAD:  o_xcew_id = XCEW_ID_MLOAD;
                    MISC_F3_MSTORE: o_xcew_id = XCEW_ID_MSTORE;
                    default: begin
                        o_xcew_id = XCEW_ID_CFG;  // unknown sub-func -> treat as CFG
                        o_illegal = 1'b1;          // and flag illegal
                    end
                endcase
            end

            default: begin
                o_is_xcew = 1'b0;
                o_xcew_id = 4'h0;
                o_illegal = 1'b0;  // Non-Xcew instructions are not illegal here
            end
        endcase
    end

endmodule