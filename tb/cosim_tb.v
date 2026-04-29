// tb/cosim_tb.v
// Co-simulation testbench for Xcew Processor
// Interfaces with Verilator C++ model

`timescale 1ns/1ps

module cosim_tb;

    reg i_clk;
    reg i_rst;
    wire [3:0] o_irq;
    wire [7:0] o_debug_uart;

    // Instantiate the SOC top module
    xcew_top uut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_irq(o_irq),
        .o_debug_uart(o_debug_uart)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #2 i_clk = ~i_clk;  // 4ns period (250MHz)
    end

    // Simulation control
    integer cycle_count;
    always @(posedge i_clk) begin
        if (i_rst) cycle_count = 0;
        else cycle_count = cycle_count + 1;
    end

    // Memory initialization for firmware loading
    reg [31:0] firmware_mem [0:1023];  // Simulated ROM with firmware
    integer i;

    initial begin
        // Initialize with sample firmware (NOPs for now, would be actual firmware)
        for (i = 0; i < 1024; i = i + 1) begin
            firmware_mem[i] = 32'h00000013; // ADDI x0, x0, 0 (NOP)
        end

        // Add a few test instructions to exercise the system
        firmware_mem[0] = 32'h00000093; // ADDI x1, x0, 0
        firmware_mem[1] = 32'h00A00093; // ADDI x1, x0, 10 (x1 = 10)
        firmware_mem[2] = 32'h00B000B3; // ADD x1, x1, x0 (x1 = x1 + 0)
        firmware_mem[3] = 32'h0000006F; // JAL x0, 0 (infinite loop)
    end

    // Co-simulation specific monitoring
    reg [31:0] last_pc = 32'h0;
    always @(posedge i_clk) begin
        if (!i_rst) begin
            if (uut.core_inst.pc !== last_pc) begin
                $display("Time: %0t, Cycle: %0d, PC: %h", $time, cycle_count, uut.core_inst.pc);
                last_pc = uut.core_inst.pc;

                // Special events for co-simulation
                if (uut.core_inst.pc == 32'h00000004) begin
                    $display("INFO: Firmware execution started");
                end

                if (uut.core_inst.pc == 32'h00000008) begin
                    $display("INFO: EML configuration instruction executed");
                end

                if (uut.core_inst.pc == 32'h0000000C) begin
                    $display("INFO: EML execution instruction executed");
                end
            end

            // Monitor AXI transactions to track memory accesses
            if (uut.interconnect_inst.m0_arvalid && uut.interconnect_inst.m0_arready) begin
                $display("INFO: AXI read from master 0 to address %h",
                         uut.interconnect_inst.m0_araddr);
            end

            if (uut.interconnect_inst.m0_awvalid && uut.interconnect_inst.m0_awready) begin
                $display("INFO: AXI write from master 0 to address %h",
                         uut.interconnect_inst.m0_awaddr);
            end
        end
    end

    // UART output monitoring
    reg [7:0] last_uart = 8'h00;
    always @(posedge i_clk) begin
        if (o_debug_uart !== last_uart && o_debug_uart !== 8'hxx) begin
            $display("UART OUTPUT: %02x at cycle %0d", o_debug_uart, cycle_count);
            last_uart = o_debug_uart;
        end
    end

    // Main test sequence
    initial begin
        $display("Starting Xcew Co-simulation Testbench...");
        $dumpfile("cosim_tb.vcd");
        $dumpvars(0, cosim_tb);

        // Initialize
        i_rst = 1;
        #22;
        i_rst = 0;
        $display("Reset released at time %0t", $time);

        // Run for sufficient cycles to execute firmware
        #50000;  // 50,000 cycles should be enough for our tests

        $display("Simulation completed at cycle %0d", cycle_count);
        $display("Final UART output: 0x%02x", o_debug_uart);
        $display("Final IRQ status: %b", o_irq);

        // Provide summary for co-simulation harness
        $display("");
        $display("=== CO-SIMULATION SUMMARY ===");
        $display("Total cycles simulated: %0d", cycle_count);
        $display("Clock frequency: 250 MHz");
        $display("Expected OODA latency: %0.3f ms", (cycle_count * 4.0) / 1000000.0);
        $display("=============================");

        $finish;
    end

endmodule