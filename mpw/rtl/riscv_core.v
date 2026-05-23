// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// riscv_core.v
// In-order 3-stage RISC-V core with Xcew extension
// IF → ID/EX → WB pipeline

module riscv_core (
    input  wire        clk,
    input  wire        rst,

    // Instruction ROM interface
    output reg [31:0]  pc,
    input  wire [31:0] instr,

    // Data memory interface (not implemented in this basic version)
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        mem_we,
    output wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,

    // CSR interface
    output wire [11:0] csr_addr,
    output wire        csr_wr_en,
    output wire [31:0] csr_wr_data,
    input  wire [31:0] csr_rd_data,

    // Xcew custom interface
    output reg [31:0]  o_xcew_req,
    input  wire        i_xcew_ready,
    input  wire [31:0] i_xcew_resp,
    input  wire        i_xcew_done,

    // Control signals
    output reg         wb_stall,
    output wire        exception,
    output wire        interrupt
);

    // Instruction field definitions
    localparam OPCODE_RTYPE  = 7'b0110011;
    localparam OPCODE_ITYPE  = 7'b0010011;
    localparam OPCODE_LTYPE  = 7'b0000011;
    localparam OPCODE_STYPE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_AUIPC  = 7'b0010111;
    localparam OPCODE_LUI    = 7'b0110111;

    // Xcew custom opcodes
    localparam OPCODE_XCEW_EML      = 7'b0001011;  // 0b0001011
    localparam OPCODE_XCEW_POL_UPD  = 7'b0101011;  // 0b0101011
    localparam OPCODE_XCEW_SNN_CLASS = 7'b1011011;  // 0b1011011
    localparam OPCODE_XCEW_MISC     = 7'b1111011;  // 0b1111011

    // Funct3 definitions
    localparam FUNCT3_ADD_SUB = 3'b000;
    localparam FUNCT3_SLL     = 3'b001;
    localparam FUNCT3_SLT     = 3'b010;
    localparam FUNCT3_SLTU    = 3'b011;
    localparam FUNCT3_XOR     = 3'b100;
    localparam FUNCT3_SHR     = 3'b101;
    localparam FUNCT3_OR      = 3'b110;
    localparam FUNCT3_AND     = 3'b111;

    // Funct7 definitions
    localparam FUNCT7_ADD = 7'b0000000;
    localparam FUNCT7_SUB = 7'b0100000;

    // Register file parameters
    localparam REG_ADDR_WIDTH = 5;
    localparam REG_COUNT = 32;

    // Pipeline stages
    typedef enum reg [1:0] {
        IF_STAGE = 2'b00,
        ID_EX_STAGE = 2'b01,
        WB_STAGE = 2'b10
    } stage_t;

    // Internal signals
    reg [31:0] next_pc;
    reg [31:0] pc_reg;

    // IF stage signals
    reg [31:0] if_instr;
    reg [31:0] if_pc;

    // ID/EX stage signals
    reg [31:0] id_ex_instr;
    reg [31:0] id_ex_pc;
    reg        id_ex_valid;

    // Instruction fields
    reg [6:0]  id_opcode;
    reg [4:0]  id_rd;
    reg [2:0]  id_funct3;
    reg [4:0]  id_rs1;
    reg [4:0]  id_rs2;
    reg [6:0]  id_funct7;
    reg [31:0] id_imm;

    // ALU signals
    reg [31:0] alu_op1, alu_op2;
    reg [3:0]  alu_control;
    reg [31:0] alu_result;

    // Register file
    reg [31:0] regfile [0:REG_COUNT-1];

    // Register file signals
    reg [4:0]  rf_rs1_addr, rf_rs2_addr;
    reg [4:0]  rf_rd_addr;
    reg [31:0] rf_rs1_data, rf_rs2_data;
    reg        rf_we;
    reg [31:0] rf_wdata;

    // Xcew processing
    reg        xcew_pending;
    reg [4:0]  xcew_rd_reg;
    reg [31:0] xcew_result;
    reg        xcew_valid;

    // Stall control
    reg        stall_id_ex;
    reg        stall_if;
    reg        bubble_if;
    reg        bubble_id_ex;

    // ALU Control values
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;
    localparam ALU_SHL  = 4'b0110;
    localparam ALU_SHR  = 4'b0111;
    localparam ALU_PASS = 4'b1111;  // Pass operand directly

    // ALU implementation
    function [31:0] alu_compute;
        input [31:0] op1, op2;
        input [3:0]  control;
        begin
            case (control)
                ALU_ADD:  alu_compute = op1 + op2;
                ALU_SUB:  alu_compute = op1 - op2;
                ALU_AND:  alu_compute = op1 & op2;
                ALU_OR:   alu_compute = op1 | op2;
                ALU_XOR:  alu_compute = op1 ^ op2;
                ALU_SLT:  alu_compute = ($signed(op1) < $signed(op2)) ? 32'h1 : 32'h0;
                ALU_SHL:  alu_compute = op1 << op2[4:0];
                ALU_SHR:  alu_compute = op1 >> op2[4:0];
                default:  alu_compute = op1;
            endcase
        end
    endfunction

    // Immediate generation
    function [31:0] generate_imm;
        input [31:0] instr;
        input [6:0]  opcode;
        begin
            case (opcode)
                OPCODE_ITYPE:  // I-type immediate
                    generate_imm = { {20{instr[31]}}, instr[31:20] };
                OPCODE_STYPE:  // S-type immediate
                    generate_imm = { {20{instr[31]}}, instr[31:25], instr[11:7] };
                OPCODE_BRANCH: // B-type immediate
                    generate_imm = { {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 };
                OPCODE_JAL:    // J-type immediate
                    generate_imm = { {12{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 };
                OPCODE_AUIPC, OPCODE_LUI:  // U-type immediate
                    generate_imm = { instr[31:12], 12'h000 };
                default:
                    generate_imm = 32'h0;
            endcase
        end
    endfunction

    // PC Update Logic
    always @(*) begin
        next_pc = pc_reg + 4;  // Default sequential increment
        // In a more complete implementation, we would handle branches/jumps here
    end

    // IF Stage
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_reg <= 32'h00000000;
            if_instr <= 32'h00000000;
            if_pc <= 32'h00000000;
        end else if (!stall_if && !bubble_if) begin
            pc_reg <= next_pc;
            if_instr <= instr;
            if_pc <= next_pc;
        end
    end

    // Send PC to instruction ROM
    assign pc = pc_reg;

    // Register file read
    assign rf_rs1_data = (rf_rs1_addr == 5'b0) ? 32'h0 : regfile[rf_rs1_addr];
    assign rf_rs2_data = (rf_rs2_addr == 5'b0) ? 32'h0 : regfile[rf_rs2_addr];

    // ID/EX Stage
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_ex_instr <= 32'h00000000;
            id_ex_pc <= 32'h00000000;
            id_ex_valid <= 1'b0;

            // Initialize register file
            for (integer i = 0; i < REG_COUNT; i = i + 1) begin
                if (i != 0) regfile[i] <= 32'h0;
            end
            regfile[0] <= 32'h0;  // x0 is always 0

            // Reset control signals
            xcew_pending <= 1'b0;
            xcew_valid <= 1'b0;
            o_xcew_req <= 32'h00000000;

        end else if (!stall_id_ex && !bubble_id_ex) begin
            // Capture instruction from IF stage
            id_ex_instr <= if_instr;
            id_ex_pc <= if_pc;
            id_ex_valid <= 1'b1;

            // Decode instruction fields
            id_opcode <= if_instr[6:0];
            id_rd     <= if_instr[11:7];
            id_funct3 <= if_instr[14:12];
            id_rs1    <= if_instr[19:15];
            id_rs2    <= if_instr[24:20];
            id_funct7 <= if_instr[31:25];
            id_imm    <= generate_imm(if_instr, if_instr[6:0]);

            // Register file read addresses
            rf_rs1_addr <= if_instr[19:15];
            rf_rs2_addr <= if_instr[24:20];

            // Check if this is a Xcew instruction
            if (if_instr[6:0] inside {OPCODE_XCEW_EML, OPCODE_XCEW_POL_UPD, OPCODE_XCEW_SNN_CLASS, OPCODE_XCEW_MISC}) begin
                // Start Xcew operation
                xcew_pending <= 1'b1;
                xcew_rd_reg <= if_instr[11:7];
                o_xcew_req <= {if_instr[6:0], if_instr[31:7]};  // Encode the entire instruction
            end

        end else if (id_ex_valid && !stall_id_ex) begin
            // Advance valid instruction but update internal signals
            id_ex_valid <= 1'b1;

            // Continue updating register file reads for valid instruction
            rf_rs1_addr <= id_ex_instr[19:15];
            rf_rs2_addr <= id_ex_instr[24:20];
        end else begin
            // Invalidate the pipeline stage
            id_ex_valid <= 1'b0;
        end
    end

    // Xcew operation management
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            xcew_pending <= 1'b0;
            xcew_valid <= 1'b0;
            o_xcew_req <= 32'h00000000;
        end else begin
            if (id_ex_valid && (id_ex_instr[6:0] inside {OPCODE_XCEW_EML, OPCODE_XCEW_POL_UPD, OPCODE_XCEW_SNN_CLASS, OPCODE_XCEW_MISC})) begin
                xcew_pending <= 1'b1;
                xcew_rd_reg <= id_ex_instr[11:7];
                o_xcew_req <= id_ex_instr;  // Send the full instruction
            end

            if (i_xcew_done && xcew_pending) begin
                xcew_result <= i_xcew_resp;
                xcew_valid <= 1'b1;
                xcew_pending <= 1'b0;
            end else if (xcew_valid && rf_we) begin
                // Reset valid when result is written to regfile
                xcew_valid <= 1'b0;
            end
        end
    end

    // ALU operation setup for non-Xcew instructions
    always @(*) begin
        if (id_ex_valid && !(id_ex_instr[6:0] inside {OPCODE_XCEW_EML, OPCODE_XCEW_POL_UPD, OPCODE_XCEW_SNN_CLASS, OPCODE_XCEW_MISC})) begin
            alu_op1 = (id_ex_instr[6:0] == OPCODE_ITYPE || id_ex_instr[6:0] == OPCODE_LTYPE) ? rf_rs1_data : rf_rs1_data;
            alu_op2 = (id_ex_instr[6:0] == OPCODE_ITYPE || id_ex_instr[6:0] == OPCODE_LTYPE) ? id_ex_imm : rf_rs2_data;

            case (id_ex_instr[6:0])
                OPCODE_RTYPE: begin
                    case (id_ex_instr[14:12])  // funct3
                        FUNCT3_ADD_SUB: alu_control = (id_ex_instr[31:25] == FUNCT7_SUB) ? ALU_SUB : ALU_ADD;
                        FUNCT3_AND:     alu_control = ALU_AND;
                        FUNCT3_OR:      alu_control = ALU_OR;
                        FUNCT3_XOR:     alu_control = ALU_XOR;
                        FUNCT3_SLT:     alu_control = ALU_SLT;
                        FUNCT3_SLL:     alu_control = ALU_SHL;
                        FUNCT3_SHR:     alu_control = (id_ex_instr[31:25] == FUNCT7_SUB) ? ALU_SHR : ALU_SHR;  // SRA shares same funct3 as SRL
                        default:        alu_control = ALU_ADD;
                    endcase
                end
                OPCODE_ITYPE: begin
                    case (id_ex_instr[14:12])
                        FUNCT3_ADD_SUB: alu_control = ALU_ADD;
                        FUNCT3_AND:     alu_control = ALU_AND;
                        FUNCT3_OR:      alu_control = ALU_OR;
                        FUNCT3_XOR:     alu_control = ALU_XOR;
                        FUNCT3_SLT:     alu_control = ALU_SLT;
                        FUNCT3_SLL:     alu_control = ALU_SHL;
                        FUNCT3_SHR:     alu_control = (id_ex_instr[31:25] == FUNCT7_SUB) ? ALU_SHR : ALU_SHR;
                        default:        alu_control = ALU_ADD;
                    endcase
                end
                default: alu_control = ALU_ADD;
            endcase
        end else begin
            alu_op1 = 32'h0;
            alu_op2 = 32'h0;
            alu_control = ALU_ADD;
        end
    end

    // Compute ALU result
    assign alu_result = alu_compute(alu_op1, alu_op2, alu_control);

    // Determine writeback data (ALU result or Xcew result)
    wire [31:0] wb_data;
    assign wb_data = xcew_valid ? xcew_result : alu_result;

    // Register file writeback
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_we <= 1'b0;
            rf_wdata <= 32'h0;
            rf_rd_addr <= 5'h0;
        end else if (id_ex_valid) begin
            // For non-Xcew instructions, write ALU result immediately
            if (!(id_ex_instr[6:0] inside {OPCODE_XCEW_EML, OPCODE_XCEW_POL_UPD, OPCODE_XCEW_SNN_CLASS, OPCODE_XCEW_MISC})) begin
                if ((id_ex_instr[6:0] == OPCODE_RTYPE) || (id_ex_instr[6:0] == OPCODE_ITYPE) ||
                    (id_ex_instr[6:0] == OPCODE_LTYPE) || (id_ex_instr[6:0] == OPCODE_LUI) ||
                    (id_ex_instr[6:0] == OPCODE_AUIPC) || (id_ex_instr[6:0] == OPCODE_JAL) ||
                    (id_ex_instr[6:0] == OPCODE_JALR)) begin

                    if (id_ex_instr[11:7] != 5'h0) begin  // Don't write to x0
                        rf_we <= 1'b1;
                        rf_wdata <= wb_data;
                        rf_rd_addr <= id_ex_instr[11:7];

                        // Update register file
                        if (id_ex_instr[11:7] != 5'h0) begin
                            regfile[id_ex_instr[11:7]] <= wb_data;
                        end
                    end else begin
                        rf_we <= 1'b0;
                    end
                end else begin
                    rf_we <= 1'b0;
                end
            end
            // For Xcew instructions, wait for completion
            else if (xcew_valid && xcew_rd_reg != 5'h0) begin
                rf_we <= 1'b1;
                rf_wdata <= xcew_result;
                rf_rd_addr <= xcew_rd_reg;

                // Update register file
                if (xcew_rd_reg != 5'h0) begin
                    regfile[xcew_rd_reg] <= xcew_result;
                end
            end else begin
                rf_we <= 1'b0;
            end
        end else begin
            rf_we <= 1'b0;
        end
    end

    // Stall logic - stall pipeline when Xcew operation is pending
    assign stall_id_ex = xcew_pending & !i_xcew_done;
    assign stall_if = stall_id_ex;

    // Bubble insertion logic for hazard resolution
    assign bubble_if = 1'b0;  // Simplified - no bubbles needed for this basic implementation
    assign bubble_id_ex = stall_id_ex;  // When stalling ID/EX, insert bubble

    // Connect CSR signals (simple pass-through)
    assign csr_addr = 12'h0;  // Placeholder
    assign csr_wr_en = 1'b0;  // Placeholder
    assign csr_wr_data = 32'h0;  // Placeholder

    // Control outputs
    assign mem_addr = 32'h0;  // Placeholder
    assign mem_wdata = 32'h0;  // Placeholder
    assign mem_we = 1'b0;  // Placeholder
    assign mem_wstrb = 4'h0;  // Placeholder
    assign wb_stall = stall_id_ex;
    assign exception = 1'b0;  // Placeholder
    assign interrupt = 1'b0;  // Placeholder

endmodule