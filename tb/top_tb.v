// tb/top_tb.v
// Top-level testbench for Xcew processor

`timescale 1ns/1ps

module top_tb();

    // Clock and reset
    reg i_clk;
    reg i_rst;

    // Instruction interface
    reg [31:0] i_inst;
    wire o_inst_req;
    wire o_inst_gnt;

    // Xcew instruction interface
    reg [31:0] i_xcew_rs1;
    reg [31:0] i_xcew_rs2;
    reg [4:0]  i_xcew_rd_addr;
    reg [6:0]  i_xcew_opcode;
    reg [2:0]  i_xcew_funct3;
    reg [6:0]  i_xcew_funct7;
    wire [31:0] o_xcew_rd;
    wire o_xcew_valid;
    wire o_xcew_exc;

    // CSR interface
    reg        i_csr_wr_en;
    reg [11:0] i_csr_addr;
    reg [31:0] i_csr_wr_data;
    wire [31:0] o_csr_rd_data;

    // SNN interface
    reg        i_snn_classify_en;
    reg [63:0] i_snn_spike_in;
    wire [7:0] o_snn_class;
    wire [7:0] o_snn_conf;
    wire o_snn_done;

    // NVM interface
    reg [15:0] i_nvm_addr;
    reg        i_nvm_wr_en;
    reg [31:0] i_nvm_wr_data;
    reg [15:0] i_nvm_weight_ptr;
    wire [31:0] o_nvm_rd_data;
    wire o_nvm_busy;
    wire o_nvm_ecc_err;

    // Interrupts
    wire o_irq;

    // Instantiate the top module
    xcew_top uut_top (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_inst(i_inst),
        .o_inst_req(o_inst_req),
        .o_inst_gnt(o_inst_gnt),
        .i_xcew_rs1(i_xcew_rs1),
        .i_xcew_rs2(i_xcew_rs2),
        .i_xcew_rd_addr(i_xcew_rd_addr),
        .i_xcew_opcode(i_xcew_opcode),
        .i_xcew_funct3(i_xcew_funct3),
        .i_xcew_funct7(i_xcew_funct7),
        .o_xcew_rd(o_xcew_rd),
        .o_xcew_valid(o_xcew_valid),
        .o_xcew_exc(o_xcew_exc),
        .i_csr_wr_en(i_csr_wr_en),
        .i_csr_addr(i_csr_addr),
        .i_csr_wr_data(i_csr_wr_data),
        .o_csr_rd_data(o_csr_rd_data),
        .i_snn_classify_en(i_snn_classify_en),
        .i_snn_spike_in(i_snn_spike_in),
        .o_snn_class(o_snn_class),
        .o_snn_conf(o_snn_conf),
        .o_snn_done(o_snn_done),
        .i_nvm_addr(i_nvm_addr),
        .i_nvm_wr_en(i_nvm_wr_en),
        .i_nvm_wr_data(i_nvm_wr_data),
        .i_nvm_weight_ptr(i_nvm_weight_ptr),
        .o_nvm_rd_data(o_nvm_rd_data),
        .o_nvm_busy(o_nvm_busy),
        .o_nvm_ecc_err(o_nvm_ecc_err),
        .o_irq(o_irq)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;  // 10ns period (100MHz)
    end

    // Test sequence
    initial begin
        $display("Starting Xcew Top-Level Testbench");
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        // Initialize signals
        i_rst = 1;
        i_inst = 0;
        i_xcew_rs1 = 0;
        i_xcew_rs2 = 0;
        i_xcew_rd_addr = 0;
        i_xcew_opcode = 0;
        i_xcew_funct3 = 0;
        i_xcew_funct7 = 0;
        i_csr_wr_en = 0;
        i_csr_addr = 0;
        i_csr_wr_data = 0;
        i_snn_classify_en = 0;
        i_snn_spike_in = 0;
        i_nvm_addr = 0;
        i_nvm_wr_en = 0;
        i_nvm_wr_data = 0;
        i_nvm_weight_ptr = 0;

        #10;
        i_rst = 0;
        #10;

        // Test 1: Read default CSR value
        $display("\nTest 1: Reading default CSR value");
        i_csr_addr = 12'h7C0;  // xcew_cfg
        i_csr_wr_en = 0;
        #10;
        $display("Default xcew_cfg: %h", o_csr_rd_data);

        // Test 2: Write to CSR
        $display("\nTest 2: Writing to CSR");
        i_csr_addr = 12'h7C0;  // xcew_cfg
        i_csr_wr_en = 1;
        i_csr_wr_data = 32'h0000_8120;  // Enable complex mode, set depth to 3
        #10;
        i_csr_wr_en = 0;
        #10;
        $display("After write, xcew_cfg: %h", o_csr_rd_data);

        // Test 3: Execute an EML instruction
        $display("\nTest 3: Executing EML instruction");
        i_xcew_opcode = 7'b1111011;  // XCEW_EML_OP
        i_xcew_funct3 = 3'b000;
        i_xcew_funct7 = 7'b0000000;
        i_xcew_rs1 = 32'h4000_0000;  // 2.0
        i_xcew_rs2 = 32'h3F80_0000;  // 1.0
        #20;

        // Wait for EML to complete
        wait(o_xcew_valid);
        $display("EML result: %h, exception: %b", o_xcew_rd, o_xcew_exc);

        // Test 4: SNN classification
        $display("\nTest 4: SNN Classification");
        i_snn_classify_en = 1;
        i_snn_spike_in = 64'hDEADBEEF_FEDCBA98;
        #50;  // Wait for classification to complete
        i_snn_classify_en = 0;
        wait(o_snn_done);
        $display("SNN Classification: %d, Confidence: %d", o_snn_class, o_snn_conf);

        // Test 5: NVM operation
        $display("\nTest 5: NVM Write Operation");
        i_nvm_addr = 16'h0010;
        i_nvm_wr_en = 1;
        i_nvm_wr_data = 32'hCAFE_BABE;
        #20;
        i_nvm_wr_en = 0;

        // Wait for write to complete
        wait(!o_nvm_busy);
        $display("NVM write complete, busy: %b, error: %b", o_nvm_busy, o_nvm_ecc_err);

        $display("\nTop-level testbench completed");
        $finish;
    end

endmodule