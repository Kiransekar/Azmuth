// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/top_tb.v
// Top-level testbench for Xcew processor (xcew_top)

`timescale 1ns/1ps

module top_tb();

    // Clock and reset
    reg i_clk = 0;
    reg i_rst = 1;

    // Outputs
    wire [3:0]  o_irq;
    wire [7:0]  o_debug_uart;

    // Instantiate the top module
    xcew_top uut_top (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_irq(o_irq),
        .o_debug_uart(o_debug_uart)
    );

    // Clock generation
    always #5 i_clk = ~i_clk;

    // Test sequence
    initial begin
        $display("Starting Xcew Top-Level Testbench");
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        // Hold reset (NVM init takes time in simulation)
        #1000;
        i_rst = 0;
        $display("Reset released at t=%0t", $time);

        // Run for 20 cycles
        repeat (20) begin
            @(posedge i_clk);
        end
        $display("Ran 20 cycles at t=%0t", $time);

        // Verify IRQ and debug outputs are stable (no spurious interrupts)
        if (o_irq == 4'b0000)
            $display("PASS: No spurious interrupts after reset");
        else
            $display("FAIL: Spurious IRQ detected: %b", o_irq);

        if (o_debug_uart == 8'h00)
            $display("PASS: Debug UART quiet after reset");
        else
            $display("FAIL: Unexpected debug UART output: %h", o_debug_uart);

        $display("Top-level testbench completed at t=%0t", $time);
        #100;
        $finish;
    end

endmodule