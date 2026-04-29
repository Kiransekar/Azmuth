// riscv_core.v
// In-order 3-stage RISC-V core with Xcew extension
// IF -> ID/EX -> WB pipeline
// Verilog-2001 compliant, no SV features

`timescale 1ns/1ps

module riscv_core (
    input  wire        clk,
    input  wire        rst,

    // Instruction ROM interface
    output wire [31:0] pc,
    input  wire [31:0] instr,

    // Data memory interface
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
    output reg  [31:0] o_xcew_req,
    output wire        o_xcew_valid,
    input  wire        i_xcew_ready,
    input  wire [31:0] i_xcew_resp,
    input  wire        i_xcew_done,

    // Register file read data outputs (for Xcew unit)
    output wire [31:0] o_rs1_data,
    output wire [31:0] o_rs2_data,

    // Control signals
    output wire        wb_stall,
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
    localparam OPCODE_XCEW_EML       = 7'b0001011;
    localparam OPCODE_XCEW_POL_UPD   = 7'b0101011;
    localparam OPCODE_XCEW_SNN_CLASS = 7'b1011011;
    localparam OPCODE_XCEW_MISC      = 7'b1111011;
    localparam OPCODE_SYSTEM          = 7'b1110011;

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

    // FSM state encoding (binary, no typedef enum)
    parameter IF_STAGE    = 2'b00;
    parameter ID_EX_STAGE = 2'b01;
    parameter WB_STAGE    = 2'b10;

    // Internal signals
    reg [31:0] next_pc;
    reg [31:0] pc_reg;

    // Loop variable for initialization
    integer init_idx;

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

    // Register file
    reg [31:0] regfile [0:REG_COUNT-1];

    // Register file signals
    reg [4:0]  rf_rs1_addr, rf_rs2_addr;
    reg [4:0]  rf_rd_addr;
    wire [31:0] rf_rs1_data, rf_rs2_data;
    reg        rf_we;
    reg [31:0] rf_wdata;

    // Xcew processing
    reg        xcew_pending;
    reg [4:0]  xcew_rd_reg;
    reg [31:0] xcew_result;
    reg        xcew_valid;

    // Stall control
    wire       stall_id_ex;
    wire       stall_if;
    wire       bubble_if;
    wire       bubble_id_ex;

    // ALU result wire
    wire [31:0] alu_result;

    // Xcew opcode detect helper wires
    wire is_xcew_instr;
    wire id_ex_is_xcew;

    assign is_xcew_instr =
        (if_instr[6:0] == OPCODE_XCEW_EML)        ||
        (if_instr[6:0] == OPCODE_XCEW_POL_UPD)    ||
        (if_instr[6:0] == OPCODE_XCEW_SNN_CLASS)  ||
        (if_instr[6:0] == OPCODE_XCEW_MISC);

    assign id_ex_is_xcew =
        (id_ex_instr[6:0] == OPCODE_XCEW_EML)        ||
        (id_ex_instr[6:0] == OPCODE_XCEW_POL_UPD)    ||
        (id_ex_instr[6:0] == OPCODE_XCEW_SNN_CLASS)  ||
        (id_ex_instr[6:0] == OPCODE_XCEW_MISC);

    // ALU Control values
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;
    localparam ALU_SHL  = 4'b0110;
    localparam ALU_SHR  = 4'b0111;
    localparam ALU_PASS = 4'b1111;

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

    // Branch condition evaluation (combinational)
    wire branch_taken;
    wire [31:0] branch_target;
    wire [31:0] jump_target;

    assign branch_taken = id_ex_valid && (id_ex_instr[6:0] == OPCODE_BRANCH) &&
        ((id_ex_instr[14:12] == 3'b000 && rf_rs1_data == rf_rs2_data) ||   // BEQ
         (id_ex_instr[14:12] == 3'b001 && rf_rs1_data != rf_rs2_data) ||   // BNE
         (id_ex_instr[14:12] == 3'b100 && $signed(rf_rs1_data) < $signed(rf_rs2_data)) ||  // BLT
         (id_ex_instr[14:12] == 3'b101 && $signed(rf_rs1_data) >= $signed(rf_rs2_data)) || // BGE
         (id_ex_instr[14:12] == 3'b110 && rf_rs1_data < rf_rs2_data) ||    // BLTU
         (id_ex_instr[14:12] == 3'b111 && rf_rs1_data >= rf_rs2_data));    // BGEU

    assign branch_target = id_ex_pc + id_imm;  // PC + B-type immediate

    // Jump target computation
    assign jump_target = (id_ex_instr[6:0] == OPCODE_JALR) ? (rf_rs1_data + id_imm) & ~32'h1 :
                         (id_ex_instr[6:0] == OPCODE_JAL)  ? id_ex_pc + id_imm :
                         32'h0;

    // PC Update Logic
    reg pc_sel_jump;
    always @(*) begin
        pc_sel_jump = 1'b0;
        if (id_ex_valid) begin
            case (id_ex_instr[6:0])
                OPCODE_JAL, OPCODE_JALR: pc_sel_jump = 1'b1;
                OPCODE_BRANCH:          pc_sel_jump = branch_taken;
                default:                pc_sel_jump = 1'b0;
            endcase
        end
    end

    always @(*) begin
        if (pc_sel_jump) begin
            if (id_ex_instr[6:0] == OPCODE_BRANCH)
                next_pc = branch_target;
            else
                next_pc = jump_target;
        end else begin
            next_pc = pc_reg + 4;
        end
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

    // ID/EX Stage - instruction capture and decode (no Xcew registers here)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_ex_instr <= 32'h00000000;
            id_ex_pc <= 32'h00000000;
            id_ex_valid <= 1'b0;

            // Initialize register file
            regfile[1] <= 32'h0;
            regfile[2] <= 32'h0;
            regfile[3] <= 32'h0;
            regfile[4] <= 32'h0;
            regfile[5] <= 32'h0;
            regfile[6] <= 32'h0;
            regfile[7] <= 32'h0;
            regfile[8] <= 32'h0;
            regfile[9] <= 32'h0;
            regfile[10] <= 32'h0;
            regfile[11] <= 32'h0;
            regfile[12] <= 32'h0;
            regfile[13] <= 32'h0;
            regfile[14] <= 32'h0;
            regfile[15] <= 32'h0;
            regfile[16] <= 32'h0;
            regfile[17] <= 32'h0;
            regfile[18] <= 32'h0;
            regfile[19] <= 32'h0;
            regfile[20] <= 32'h0;
            regfile[21] <= 32'h0;
            regfile[22] <= 32'h0;
            regfile[23] <= 32'h0;
            regfile[24] <= 32'h0;
            regfile[25] <= 32'h0;
            regfile[26] <= 32'h0;
            regfile[27] <= 32'h0;
            regfile[28] <= 32'h0;
            regfile[29] <= 32'h0;
            regfile[30] <= 32'h0;
            regfile[31] <= 32'h0;

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

        end else if (id_ex_valid && !stall_id_ex) begin
            id_ex_valid <= 1'b1;
            rf_rs1_addr <= id_ex_instr[19:15];
            rf_rs2_addr <= id_ex_instr[24:20];
        end else begin
            id_ex_valid <= 1'b0;
        end
    end

    // Xcew operation management (single driver for xcew registers)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            xcew_pending <= 1'b0;
            xcew_valid <= 1'b0;
            o_xcew_req <= 32'h00000000;
            xcew_rd_reg <= 5'h0;
            xcew_result <= 32'h0;
        end else begin
            // Detect Xcew instruction in ID/EX stage
            if (id_ex_valid && id_ex_is_xcew && !xcew_pending) begin
                xcew_pending <= 1'b1;
                xcew_rd_reg <= id_ex_instr[11:7];
                o_xcew_req <= id_ex_instr;
            end

            // Handle Xcew completion
            if (i_xcew_done && xcew_pending) begin
                xcew_result <= i_xcew_resp;
                xcew_valid <= 1'b1;
                xcew_pending <= 1'b0;
            end else if (xcew_valid && rf_we) begin
                xcew_valid <= 1'b0;
            end
        end
    end

    // ALU operation setup for non-Xcew instructions
    always @(*) begin
        if (id_ex_valid && !id_ex_is_xcew) begin
            alu_op1 = rf_rs1_data;
            alu_op2 = (id_ex_instr[6:0] == OPCODE_ITYPE || id_ex_instr[6:0] == OPCODE_LTYPE) ? id_imm : rf_rs2_data;

            case (id_ex_instr[6:0])
                OPCODE_RTYPE: begin
                    case (id_ex_instr[14:12])
                        FUNCT3_ADD_SUB: alu_control = (id_ex_instr[31:25] == FUNCT7_SUB) ? ALU_SUB : ALU_ADD;
                        FUNCT3_AND:     alu_control = ALU_AND;
                        FUNCT3_OR:      alu_control = ALU_OR;
                        FUNCT3_XOR:     alu_control = ALU_XOR;
                        FUNCT3_SLT:     alu_control = ALU_SLT;
                        FUNCT3_SLL:     alu_control = ALU_SHL;
                        FUNCT3_SHR:     alu_control = ALU_SHR;
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
                        FUNCT3_SHR:     alu_control = ALU_SHR;
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

    // Determine writeback data (ALU result, Xcew result, PC+4 for jumps, or CSR read)
    wire is_csr_read = id_ex_valid && (id_ex_instr[6:0] == OPCODE_SYSTEM) &&
                       (id_ex_instr[14:12] != 3'b000);  // Any CSR instruction (not ECALL/EBREAK)
    wire [31:0] wb_data;
    assign wb_data = xcew_valid ? xcew_result :
                     is_csr_read ? csr_rd_data :
                     ((id_ex_instr[6:0] == OPCODE_JAL) || (id_ex_instr[6:0] == OPCODE_JALR)) ? id_ex_pc + 32'h4 :
                     (id_ex_instr[6:0] == OPCODE_LUI) ? id_imm :
                     alu_result;

    // Register file writeback
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_we <= 1'b0;
            rf_wdata <= 32'h0;
            rf_rd_addr <= 5'h0;
        end else if (id_ex_valid) begin
            if (!id_ex_is_xcew) begin
                if ((id_ex_instr[6:0] == OPCODE_RTYPE) || (id_ex_instr[6:0] == OPCODE_ITYPE) ||
                    (id_ex_instr[6:0] == OPCODE_LTYPE) || (id_ex_instr[6:0] == OPCODE_LUI) ||
                    (id_ex_instr[6:0] == OPCODE_AUIPC) || (id_ex_instr[6:0] == OPCODE_JAL) ||
                    (id_ex_instr[6:0] == OPCODE_JALR) || (id_ex_instr[6:0] == OPCODE_SYSTEM)) begin

                    if (id_ex_instr[11:7] != 5'h0) begin
                        rf_we <= 1'b1;
                        rf_wdata <= wb_data;
                        rf_rd_addr <= id_ex_instr[11:7];
                        regfile[id_ex_instr[11:7]] <= wb_data;
                    end else begin
                        rf_we <= 1'b0;
                    end
                end else begin
                    rf_we <= 1'b0;
                end
            end else if (xcew_valid && xcew_rd_reg != 5'h0) begin
                rf_we <= 1'b1;
                rf_wdata <= xcew_result;
                rf_rd_addr <= xcew_rd_reg;
                regfile[xcew_rd_reg] <= xcew_result;
            end else begin
                rf_we <= 1'b0;
            end
        end else begin
            rf_we <= 1'b0;
        end
    end

    // Xcew valid output
    assign o_xcew_valid = xcew_pending;

    // Register file read data outputs
    assign o_rs1_data = rf_rs1_data;
    assign o_rs2_data = rf_rs2_data;

    // Stall logic
    assign stall_id_ex = xcew_pending & !i_xcew_done;
    assign stall_if = stall_id_ex;
    assign bubble_if = 1'b0;
    assign bubble_id_ex = stall_id_ex;

    // CSR signals - driven by SYSTEM opcode instructions
    wire is_csr_instr = id_ex_valid && (id_ex_instr[6:0] == OPCODE_SYSTEM) &&
                        (id_ex_instr[14:12] != 3'b000);  // ECALL/EBREAK have funct3=0
    assign csr_addr    = is_csr_instr ? id_ex_instr[31:20] : 12'h0;
    assign csr_wr_en   = is_csr_instr && (id_ex_instr[14:12] == 3'b001);  // CSRRW
    assign csr_wr_data = is_csr_instr ? rf_rs1_data : 32'h0;

    // Memory signals - driven by load/store instructions
    wire is_store = id_ex_valid && (id_ex_instr[6:0] == OPCODE_STYPE);
    wire is_load  = id_ex_valid && (id_ex_instr[6:0] == OPCODE_LTYPE);
    assign mem_addr  = (is_store || is_load) ? alu_result : 32'h0;
    assign mem_wdata = is_store ? rf_rs2_data : 32'h0;
    assign mem_we    = is_store;

    // Byte enable generation based on store funct3 and address[1:0]
    reg [3:0] store_wstrb;
    always @(*) begin
        if (is_store) begin
            case (id_ex_instr[14:12])
                3'b000: begin  // SB - byte
                    case (alu_result[1:0])
                        2'b00: store_wstrb = 4'b0001;
                        2'b01: store_wstrb = 4'b0010;
                        2'b10: store_wstrb = 4'b0100;
                        2'b11: store_wstrb = 4'b1000;
                    endcase
                end
                3'b001: begin  // SH - halfword
                    case (alu_result[1])
                        1'b0: store_wstrb = 4'b0011;
                        1'b1: store_wstrb = 4'b1100;
                    endcase
                end
                3'b010: store_wstrb = 4'b1111;  // SW - word
                default: store_wstrb = 4'b1111;
            endcase
        end else begin
            store_wstrb = 4'h0;
        end
    end
    assign mem_wstrb = store_wstrb;

    // Control outputs
    assign wb_stall = stall_id_ex;
    assign exception = 1'b0;
    assign interrupt = 1'b0;

endmodule
