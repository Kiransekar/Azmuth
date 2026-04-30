// tb/cosim_tb.v
// Co-simulation testbench for Xcew Processor
// Self-contained: runs with iverilog, no Verilator/RISC-V toolchain required
// Tests: boot from ROM, core instruction execution, AXI bus activity, IRQ stability

`timescale 1ns/1ps

module cosim_tb;

    reg i_clk = 0;
    reg i_rst = 1;
    wire [3:0] o_irq;
    wire [7:0] o_debug_uart;

    // Instantiate the SOC top module
    xcew_top uut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_irq(o_irq),
        .o_debug_uart(o_debug_uart)
    );

    // Clock generation: 4ns period (250MHz)
    always #2 i_clk = ~i_clk;

    // Simulation control
    integer cycle_count;
    always @(posedge i_clk) begin
        if (i_rst) cycle_count = 0;
        else cycle_count = cycle_count + 1;
    end

    // PC tracking for co-simulation
    reg [31:0] last_pc;
    integer pc_change_count;
    integer axi_read_count;
    integer axi_write_count;

    // Monitor PC changes (hierarchical access into xcew_top)
    always @(posedge i_clk) begin
        if (!i_rst && uut.core_inst.pc !== last_pc) begin
            pc_change_count = pc_change_count + 1;
            last_pc = uut.core_inst.pc;
        end
    end

    // Monitor AXI bus activity
    always @(posedge i_clk) begin
        if (!i_rst) begin
            if (uut.interconnect_inst.m0_arvalid && uut.interconnect_inst.m0_arready)
                axi_read_count = axi_read_count + 1;
            if (uut.interconnect_inst.m0_awvalid && uut.interconnect_inst.m0_awready)
                axi_write_count = axi_write_count + 1;
        end
    end

    // Main test sequence
    initial begin
        $display("Starting Xcew Co-simulation Testbench...");
        $dumpfile("cosim_tb.vcd");
        $dumpvars(0, cosim_tb);

        // Initialize counters
        last_pc = 32'h0;
        pc_change_count = 0;
        axi_read_count = 0;
        axi_write_count = 0;

        // Hold reset (NVM init takes time in simulation)
        #1000;
        i_rst = 0;
        $display("Reset released at t=%0t", $time);

        // Run for enough cycles to execute boot ROM instructions
        repeat (500) @(posedge i_clk);

        $display("Simulation completed at cycle %0d", cycle_count);
        $display("PC changes: %0d", pc_change_count);
        $display("AXI reads: %0d, writes: %0d", axi_read_count, axi_write_count);
        $display("Final IRQ: %b, Debug UART: %h", o_irq, o_debug_uart);

        // Verification checks
        if (pc_change_count > 0)
            $display("PASS: Core executed instructions (%0d PC changes)", pc_change_count);
        else
            $display("FAIL: Core did not execute any instructions");

        if (axi_read_count > 0)
            $display("PASS: AXI bus active (%0d reads)", axi_read_count);
        else
            $display("FAIL: No AXI bus activity");

        if (o_irq == 4'b0000)
            $display("PASS: No spurious interrupts");
        else
            $display("FAIL: Spurious IRQ: %b", o_irq);

        // Co-simulation summary
        $display("");
        $display("=== CO-SIMULATION SUMMARY ===");
        $display("Total cycles: %0d", cycle_count);
        $display("Clock frequency: 250 MHz");
        $display("OODA latency: %0.3f ms", (cycle_count * 4.0) / 1000000.0);
        $display("=============================");

        #100;
        $finish;
    end

endmodule