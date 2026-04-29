// tb/core_tb.v
// Testbench for the 3-stage RISC-V core with Xcew extensions

`timescale 1ns/1ps

module core_tb();

    // Clock and reset
    reg clk;
    reg rst;

    // Instruction ROM interface
    wire [31:0] pc;
    reg [31:0] instr;

    // Data memory interface (placeholder)
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire mem_we;
    wire [3:0] mem_wstrb;
    reg [31:0] mem_rdata;

    // CSR interface (placeholder)
    wire [11:0] csr_addr;
    wire csr_wr_en;
    wire [31:0] csr_wr_data;
    reg [31:0] csr_rd_data;

    // Xcew custom interface
    wire [31:0] o_xcew_req;
    reg i_xcew_ready;
    reg [31:0] i_xcew_resp;
    reg i_xcew_done;

    // Control signals
    wire wb_stall;
    wire exception;
    wire interrupt;

    // Register file access for verification
    integer regs [0:31];
    integer i;

    // Instantiate the core
    riscv_core uut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .instr(instr),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we(mem_we),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .csr_addr(csr_addr),
        .csr_wr_en(csr_wr_en),
        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),
        .o_xcew_req(o_xcew_req),
        .i_xcew_ready(i_xcew_ready),
        .i_xcew_resp(i_xcew_resp),
        .i_xcew_done(i_xcew_done),
        .wb_stall(wb_stall),
        .exception(exception),
        .interrupt(interrupt)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period (100MHz)
    end

    // Simple instruction ROM with our test program
    reg [31:0] instr_rom [0:63];
    integer rom_size = 16;

    // Initialize the instruction ROM with our test program
    initial begin
        // Test program that executes: ADD, LUI, EML, SNN.CLASS, POL.UPDATE
        // Address 0: ADDI x1, x0, 10 (x1 = 0 + 10 = 10)
        instr_rom[0] = 32'h00A00093; // ADDI x1, x0, 10 (rd=x1(1), rs1=x0(0), imm=10)

        // Address 4: ADDI x2, x0, 20 (x2 = 0 + 20 = 20)
        instr_rom[1] = 32'h01400113; // ADDI x2, x0, 20 (rd=x2(2), rs1=x0(0), imm=20)

        // Address 8: ADD x3, x1, x2 (x3 = x1 + x2 = 10 + 20 = 30)
        instr_rom[2] = 32'h002081B3; // ADD x3, x1, x2 (rd=x3(3), rs1=x1(1), rs2=x2(2), funct3=0, funct7=0)

        // Address 12: LUI x4, 0x12345 (Load Upper Immediate)
        instr_rom[3] = 32'h12345237; // LUI x4, 0x12345 (rd=x4(4), imm=0x12345)

        // Address 16: EML operation (custom opcode 0b0001011 = 7'b0001011 = 11 decimal)
        instr_rom[4] = 32'h00B00293; // Custom EML instruction with opcode 0001011

        // Address 20: SNN.CLASS operation (custom opcode 0b1011011 = 7'b1011011 = 91 decimal)
        instr_rom[5] = 32'h5BB00313; // Custom SNN.CLASS instruction with opcode 1011011

        // Address 24: POL.UPDATE operation (custom opcode 0b0101011 = 7'b0101011 = 43 decimal)
        instr_rom[6] = 32'h2BB00393; // Custom POL.UPDATE instruction with opcode 0101011

        // Address 28: ADD x5, x3, x4 (x5 = x3 + x4 = 30 + 0x12345000)
        instr_rom[7] = 32'h004182B3; // ADD x5, x3, x4 (rd=x5(5), rs1=x3(3), rs2=x4(4))

        // Address 32: ADDI x6, x0, 0 (Simple termination indicator)
        instr_rom[8] = 32'h00000313; // ADDI x6, x0, 0

        // Address 36: Infinite loop
        instr_rom[9] = 32'h0000006F; // JAL x0, 0 (Jump to current address - infinite loop)

        // Pad the rest with NOPs
        for (i = 10; i < 64; i = i + 1) begin
            instr_rom[i] = 32'h00000013; // ADDI x0, x0, 0 (effectively a NOP)
        end
    end

    // Fetch from ROM based on PC
    always @(*) begin
        if (pc[31:2] < rom_size) begin
            instr = instr_rom[pc[31:2]];  // Use upper bits for addressing
        end else begin
            instr = 32'h00000013; // ADDI x0, x0, 0 (effectively a NOP)
        end
    end

    // Initialize registers for monitoring
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 0;
        end
    end

    // Track register changes
    always @(posedge clk) begin
        if (!rst) begin
            // This is simplified - in a real testbench we would monitor writes to the register file
            // For this demonstration, we just track when PC reaches certain points
            if (pc == 32'h00000000) $display("[%0t] PC: %h, Instruction: %h (%h)", $time, pc, instr_rom[0], instr);
            if (pc == 32'h00000004) $display("[%0t] PC: %h, Instruction: %h (%h)", $time, pc, instr_rom[1], instr);
            if (pc == 32'h00000008) $display("[%0t] PC: %h, Instruction: %h (%h)", $time, pc, instr_rom[2], instr);
            if (pc == 32'h0000000C) $display("[%0t] PC: %h, Instruction: %h (%h)", $time, pc, instr_rom[3], instr);
            if (pc == 32'h00000010) $display("[%0t] PC: %h, Instruction: %h (%h)", $time, pc, instr_rom[4], instr);
            if (pc == 32'h00000014) $display("[%0t] PC: %h, Instruction: %h (%h)", $time, pc, instr_rom[5], instr);
            if (pc == 32'h00000018) $display("[%0t] PC: %h, Instruction: %h (%h)", $time, pc, instr_rom[6], instr);
        end
    end

    // Simulate Xcew responses
    initial begin
        i_xcew_ready = 1;
        i_xcew_resp = 32'hDEADBEEF;
        i_xcew_done = 0;

        // Wait for reset to complete
        wait(rst == 0);
        #50;

        // When the first Xcew instruction is issued, simulate response
        wait(o_xcew_req != 0 && o_xcew_req != 32'hDEADBEEF);
        $display("[%0t] First Xcew request issued: %h", $time, o_xcew_req);

        // Simulate processing time for Xcew operations
        #100;
        i_xcew_done = 1;
        i_xcew_resp = 32'hCAFEBABE;

        #20; // Hold done for a few cycles
        i_xcew_done = 0;
        i_xcew_resp = 32'hDEADBEEF;

        // Wait for second Xcew instruction
        wait(o_xcew_req != 0 && o_xcew_req != 32'hDEADBEEF && o_xcew_req != 32'hCAFEBABE);
        $display("[%0t] Second Xcew request issued: %h", $time, o_xcew_req);

        #100;
        i_xcew_done = 1;
        i_xcew_resp = 32'hFEEDFACE;

        #20;
        i_xcew_done = 0;
        i_xcew_resp = 32'hDEADBEEF;

        // Wait for third Xcew instruction
        wait(o_xcew_req != 0 && o_xcew_req != 32'hDEADBEEF && o_xcew_req != 32'hFEEDFACE);
        $display("[%0t] Third Xcew request issued: %h", $time, o_xcew_req);

        #100;
        i_xcew_done = 1;
        i_xcew_resp = 32'h12345678;

        #20;
        i_xcew_done = 0;
    end

    // Test sequence
    initial begin
        $display("Starting RISC-V Core Testbench");
        $dumpfile("core_tb.vcd");
        $dumpvars(0, core_tb);

        // Initialize signals
        rst = 1;
        instr = 32'h00000013; // NOP during reset
        mem_rdata = 32'h0;
        csr_rd_data = 32'h0;

        #20;
        rst = 0;
        $display("[%0t] Release reset", $time);

        // Run for sufficient cycles to execute all instructions
        #2000;

        $display("[%0t] Testbench completed", $time);
        $display("Pipeline stall status: %b", wb_stall);
        $display("Exception status: %b", exception);
        $display("Interrupt status: %b", interrupt);
        $display("Final PC: %h", pc);

        // Verify Xcew interface behavior
        if (o_xcew_req != 32'h0) begin
            $display("Last Xcew request: %h", o_xcew_req);
        end

        $finish;
    end

    // Monitor pipeline stalls
    always @(posedge clk) begin
        if (wb_stall) begin
            $display("[%0t] Pipeline stall detected - core waiting for Xcew operation", $time);
        end
    end

endmodule