// eml_tb.v
// Testbench for EML (Expression Machine Learning) unit

`timescale 1ns/1ps

module eml_tb();

    // Clock and reset
    reg clk;
    reg rst;

    // EML unit inputs
    reg [31:0] i_rs1;
    reg [31:0] i_rs2;
    reg [31:0] i_cfg;
    reg        i_valid;

    // EML unit outputs
    wire [31:0] o_rd;
    wire        o_valid;
    wire        o_ready;
    wire        o_exc;

    // Instantiate the EML unit
    eml_unit uut_eml (
        .i_clk(clk),
        .i_rst(rst),
        .i_rs1(i_rs1),
        .i_rs2(i_rs2),
        .i_cfg(i_cfg),
        .i_valid(i_valid),
        .o_rd(o_rd),
        .o_valid(o_valid),
        .o_ready(o_ready),
        .o_exc(o_exc)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period (100MHz)
    end

    // Test sequence
    initial begin
        $display("Starting EML Unit Testbench");
        $dumpfile("eml_tb.vcd");
        $dumpvars(0, eml_tb);

        // Initialize signals
        rst = 1;
        i_rs1 = 0;
        i_rs2 = 0;
        i_cfg = 0;
        i_valid = 0;

        #10;
        rst = 0;
        #10;

        // Test 1: Basic EML operation with simple inputs
        $display("\nTest 1: Basic EML operation");
        i_rs1 = 32'h4000_0000;  // 2.0 in IEEE 754 float
        i_rs2 = 32'h3F80_0000;  // 1.0 in IEEE 754 float
        i_cfg = 32'h0000_0000;  // Default config
        i_valid = 1;
        #20;
        i_valid = 0;
        #20;

        // Wait for output
        wait(o_valid);
        $display("Input: rs1=%h, rs2=%h, cfg=%h", i_rs1, i_rs2, i_cfg);
        $display("Output: rd=%h, exc=%b", o_rd, o_exc);

        // Test 2: EML operation with complex mode enabled
        $display("\nTest 2: EML with complex mode enabled");
        i_cfg = 32'h0000_8000;  // Enable complex mode
        i_rs1 = 32'h4000_0000;  // 2.0
        i_rs2 = 32'h3F80_0000;  // 1.0
        i_valid = 1;
        #20;
        i_valid = 0;
        #20;

        // Wait for output
        wait(o_valid);
        $display("Complex mode: rd=%h, exc=%b", o_rd, o_exc);

        // Test 3: Memoization cache test - same input as test 1
        $display("\nTest 3: Memoization cache test (same input as test 1)");
        i_cfg = 32'h0000_0000;  // Disable complex mode
        i_rs1 = 32'h4000_0000;  // Same as test 1
        i_rs2 = 32'h3F80_0000;  // Same as test 1
        i_valid = 1;
        #20;
        i_valid = 0;
        #20;

        // Wait for output - should potentially be faster if memoized
        wait(o_valid);
        $display("Memo test: rd=%h, exc=%b", o_rd, o_exc);

        // Test 4: High precision configuration
        $display("\nTest 4: High precision configuration");
        i_cfg = 32'h0000_0100;  // Set precision to FP16 (bits 11:8 = 4'b0001)
        i_rs1 = 32'h3F80_0000;  // 1.0
        i_rs2 = 32'h0000_0000;  // 0.0
        i_valid = 1;
        #20;
        i_valid = 0;
        #100;  // Wait longer for complex operation

        if (o_valid) begin
            $display("High precision: rd=%h, exc=%b", o_rd, o_exc);
        end else begin
            $display("High precision: No valid output within timeout");
        end

        $display("\nEML Testbench completed");
        $finish;
    end

endmodule