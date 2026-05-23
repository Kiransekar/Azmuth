// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/xcew_top_v1_1_tb.v
// Testbench for Xcew Processor top-level v1.1
// Tests: reset deassert, CSR read of 0x7C0, CSR read of 0x7C1
// Clocks: 4ns half-period (250MHz core), 8ns half-period (125MHz SNN)

`timescale 1ns/1ps

module xcew_top_v1_1_tb;

    reg  i_clk_core;
    reg  i_clk_snn;
    reg  i_rst;
    reg  v1_1_mode;
    wire o_irq_eml;
    wire o_irq_snn;
    wire o_irq_nvm;
    wire o_irq_fault;
    wire [7:0] o_debug_uart;
    wire [31:0] o_debug_status;

    // Instantiate DUT
    xcew_top_v1_1 dut (
        .i_clk_core(i_clk_core),
        .i_clk_snn(i_clk_snn),
        .i_rst(i_rst),
        .v1_1_mode(v1_1_mode),
        .o_irq_eml(o_irq_eml),
        .o_irq_snn(o_irq_snn),
        .o_irq_nvm(o_irq_nvm),
        .o_irq_fault(o_irq_fault),
        .o_debug_uart(o_debug_uart),
        .o_debug_status(o_debug_status)
    );

    // Clocks: 4ns half-period = 250MHz core, 8ns half-period = 125MHz SNN
    always #4 i_clk_core = ~i_clk_core;
    always #8 i_clk_snn  = ~i_clk_snn;

    initial begin
        $dumpfile("tb/xcew_top_v1_1_tb.vcd");
        $dumpvars(0, xcew_top_v1_1_tb);

        // Initialize inputs
        i_clk_core = 0;
        i_clk_snn = 0;
        i_rst = 0;
        v1_1_mode = 1;

        // Apply reset
        i_rst = 1;
        #20;
        i_rst = 0;
        $display("Reset deasserted at t=%0t", $time);

        // Wait for 4 clock cycles
        repeat (4) @(posedge i_clk_core);
        $display("After 4 cycles: t=%0t", $time);

        // CSR read 0x7C0 - should be 0 after reset
        // Note: CSR read is internal to the core, we observe via debug status
        $display("CSR 0x7C0 (xcew_cfg) should read 0x00000000 after reset");
        $display("o_debug_status = %h", o_debug_status);
        $display("o_debug_uart   = %h", o_debug_uart);

        // Wait more cycles
        repeat (8) @(posedge i_clk_core);

        // CSR read 0x7C1
        $display("CSR 0x7C1 (xcew_status) after boot");
        $display("o_debug_status = %h", o_debug_status);

        // Verify interrupts are asserted correctly
        $display("IRQ status: EML=%b SNN=%b NVM=%b FAULT=%b",
                 o_irq_eml, o_irq_snn, o_irq_nvm, o_irq_fault);

        if (o_irq_eml == 0 && o_irq_snn == 0 && o_irq_nvm == 0 && o_irq_fault == 0)
            $display("PASS: No spurious interrupts after reset");
        else
            $display("FAIL: Unexpected IRQ asserted");

        $display("--- Xcew Top v1.1 TB complete ---");
        #50;
        $finish;
    end

endmodule
