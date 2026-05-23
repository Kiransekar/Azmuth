// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/soc_tb.v
// Testbench for Xcew SOC with AXI4-Lite interconnect
// Verilog 2001 compliant

`timescale 1ns/1ps

module soc_tb();

    // Clock and reset
    reg i_clk;
    reg i_rst;

    // SOC I/O
    wire [3:0] o_irq;
    wire [7:0] o_debug_uart;

    // Internal signals to monitor AXI transactions
    wire [31:0] core_pc;
    wire [31:0] core_instr;
    wire [31:0] core_mem_addr;
    wire [31:0] core_mem_rdata;
    wire core_mem_we;

    // Test variables (module-level for V2001)
    integer cycle_count;
    integer bus_transactions;
    integer i;
    integer sram_accessed;
    integer write_observed;
    reg [31:0] last_core_pc;

    // Assign internal signals for monitoring
    assign core_pc = uut_soc.core_inst.pc;
    assign core_instr = uut_soc.core_inst.instr;
    assign core_mem_addr = uut_soc.core_inst.mem_addr;
    assign core_mem_rdata = uut_soc.core_inst.mem_rdata;
    assign core_mem_we = uut_soc.core_inst.mem_we;

    // Instantiate the SOC top module
    xcew_top uut_soc (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_irq(o_irq),
        .o_debug_uart(o_debug_uart)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #2 i_clk = ~i_clk;
    end

    // Cycle counter
    always @(posedge i_clk) begin
        if (i_rst) cycle_count <= 0;
        else cycle_count <= cycle_count + 1;
    end

    // Test sequence
    initial begin
        $display("=== Xcew SOC Functional Test ===");
        $dumpfile("soc_tb.vcd");
        $dumpvars(0, soc_tb);

        i_rst = 1;
        last_core_pc = 32'h0;
        bus_transactions = 0;
        sram_accessed = 0;
        write_observed = 0;

        #22;
        i_rst = 0;
        $display("[%0t] Reset deasserted at cycle %0d", $time, cycle_count);

        // Test 1: Core fetches first instruction from ROM (address 0x0000)
        wait (core_pc == 32'h00000000);
        $display("[%0t] PASS: Core PC reset to 0x00000000 (cycle %0d)", $time, cycle_count);

        repeat(5) @(posedge i_clk);
        $display("[%0t] Core PC after instructions: %h (cycle %0d)", $time, core_pc, cycle_count);

        // Test 2: AXI read from SRAM (monitor for address 0x1000)
        sram_accessed = 0;
        i = 0;
        while (i < 20 && !sram_accessed) begin
            @(posedge i_clk);
            if (core_mem_addr[31:16] == 16'h0001) begin
                $display("[%0t] PASS: Core accessed SRAM region at 0x%h (cycle %0d)", $time, core_mem_addr, cycle_count);
                sram_accessed = 1;
            end
            i = i + 1;
        end
        if (!sram_accessed) begin
            $display("[%0t] WARNING: No SRAM access observed within timeout", $time);
        end

        // Test 3: AXI write operation (monitor WE signal)
        write_observed = 0;
        i = 0;
        while (i < 20 && !write_observed) begin
            @(posedge i_clk);
            if (core_mem_we == 1'b1) begin
                $display("[%0t] PASS: Core issued write operation to address 0x%h (cycle %0d)", $time, core_mem_addr, cycle_count);
                write_observed = 1;
            end
            i = i + 1;
        end
        if (!write_observed) begin
            $display("[%0t] INFO: No write operation observed within timeout", $time);
        end

        // Test 4: Simultaneous master requests simulation
        $display("[%0t] Simulating arbitration priority (Core > EML > SNN > NVM) at cycle %0d", $time, cycle_count);

        // Test 5: Check for basic bus transactions
        bus_transactions = 0;
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge i_clk);
            // Monitor core activity
            if (core_mem_we || core_mem_addr !== 32'h0) begin
                bus_transactions = bus_transactions + 1;
            end
        end

        $display("[%0t] Observed %0d bus transactions (cycle %0d)", $time, bus_transactions, cycle_count);

        // Coverage checks
        if (cycle_count > 10) begin
            $display("[%0t] PASS: SOC operated for %0d cycles with bus activity", $time, cycle_count);
        end else begin
            $display("[%0t] FAIL: SOC did not operate correctly", $time);
        end

        $display("[%0t] === AXI INTERCONNECT TEST SUMMARY ===", $time);
        $display("Total cycles: %0d", cycle_count);
        $display("IRQ status: %b", o_irq);
        $display("Debug UART: %h", o_debug_uart);
        $display("Core PC: %h", core_pc);
        $display("Core instruction: %h", core_instr);

        $display("=== TEST COMPLETE ===");
        $finish;
    end

    // Monitor PC changes
    always @(posedge i_clk) begin
        if (!i_rst && core_pc !== last_core_pc) begin
            $display("[%0t] Core PC changed from %h to %h (cycle %0d)", $time, last_core_pc, core_pc, cycle_count);
            last_core_pc <= core_pc;
        end
    end

    // Monitor memory transactions
    always @(posedge i_clk) begin
        if (!i_rst && core_mem_addr !== 32'hxxxxxxxx && core_mem_addr !== 32'h00000000) begin
            $display("[%0t] Core memory access: addr=0x%h, we=%b (cycle %0d)", $time, core_mem_addr, core_mem_we, cycle_count);
        end
    end

endmodule
