// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// debug_rom.v
// Debug ROM containing park loop and abstract command handler
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module debug_rom (
    input  wire        clk,
    input  wire [11:0] addr,
    output reg  [31:0] instr
);

    always @(*) begin
        case (addr[11:2])
            // Park loop (executed when hart is halted, waits for resume)
            10'h000: instr = 32'h0000006F; // JAL x0, 0 (infinite loop at 0x800)

            // Abstract command handler entry points
            // These are filled by the DM via program buffer
            // progbuf[0] = 0x804, progbuf[1] = 0x808
            default: instr = 32'h00000013; // NOP (ADDI x0, x0, 0)
        endcase
    end

endmodule