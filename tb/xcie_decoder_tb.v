// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// xcie_decoder_tb.v
// Directed test for the Xcew instruction decoder.
// REQ: REQ-ISA-010, REQ-ISA-011, REQ-ISA-012, REQ-ISA-013, REQ-ISA-014
// Verifies DECISION-008 (standard custom-0..3 opcode map) and that POL_UPD
// is reachable (closes MICRO_ARCH_SPEC DEV-001, DEV-002).
`timescale 1ns/1ps

module xcie_decoder_tb;
    reg  [6:0] opcode;
    reg  [2:0] funct3;
    reg  [6:0] funct7;
    wire       is_xcew;
    wire [3:0] xcew_id;
    wire       illegal;

    integer pass = 0;
    integer fail = 0;

    xcie_decoder dut (
        .i_opcode (opcode),
        .i_funct3 (funct3),
        .i_funct7 (funct7),
        .o_is_xcew(is_xcew),
        .o_xcew_id(xcew_id),
        .o_illegal(illegal)
    );

    task check;
        input [127:0] name;
        input [6:0]   op;
        input [2:0]   f3;
        input         exp_xcew;
        input [3:0]   exp_id;
        input         exp_ill;
        begin
            opcode = op; funct3 = f3; funct7 = 7'b0; #1;
            if (is_xcew === exp_xcew && xcew_id === exp_id && illegal === exp_ill) begin
                $display("PASS: %0s (op=%b f3=%b -> xcew=%b id=%h ill=%b)",
                         name, op, f3, is_xcew, xcew_id, illegal);
                pass = pass + 1;
            end else begin
                $display("FAIL: %0s (op=%b f3=%b) got xcew=%b id=%h ill=%b; exp xcew=%b id=%h ill=%b",
                         name, op, f3, is_xcew, xcew_id, illegal, exp_xcew, exp_id, exp_ill);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        // custom-0..3 authoritative map
        check("EML custom-0",     7'b0001011, 3'b000, 1'b1, 4'h1, 1'b0);
        check("POL_UPD custom-1", 7'b0101011, 3'b000, 1'b1, 4'h6, 1'b0); // DEV-002
        check("SNN custom-2",     7'b1011011, 3'b000, 1'b1, 4'h5, 1'b0);
        check("CFG  (misc f3=0)", 7'b1111011, 3'b000, 1'b1, 4'h2, 1'b0);
        check("MLOAD(misc f3=1)", 7'b1111011, 3'b001, 1'b1, 4'h3, 1'b0);
        check("MSTORE(misc f3=2)",7'b1111011, 3'b010, 1'b1, 4'h4, 1'b0);
        check("misc illegal f3=7",7'b1111011, 3'b111, 1'b1, 4'h2, 1'b1);
        // non-Xcew opcodes must not assert is_xcew
        check("R-type not xcew",  7'b0110011, 3'b000, 1'b0, 4'h0, 1'b0);
        check("SYSTEM not xcew",  7'b1110011, 3'b000, 1'b0, 4'h0, 1'b0);
        // legacy non-compliant opcode (1111111) must NOT decode (DEV-001 fixed)
        check("0x7F not xcew",    7'b1111111, 3'b000, 1'b0, 4'h0, 1'b0);

        $display("\n=== xcie_decoder_tb: PASS=%0d FAIL=%0d ===", pass, fail);
        if (fail != 0) $fatal(1, "decoder test failed");
        $finish;
    end
endmodule
