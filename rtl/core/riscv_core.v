// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
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

    // CSR interface (external CSRs, e.g. Xcew 0x7Cx)
    output wire [11:0] csr_addr,
    output wire        csr_wr_en,
    output wire [31:0] csr_wr_data,
    input  wire [31:0] csr_rd_data,

    // Machine interrupt inputs (M-mode): external / timer / software pending
    input  wire        i_meip,
    input  wire        i_mtip,
    input  wire        i_msip,

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
    integer rf_init_idx;  // For register file initialization loop

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
    localparam ALU_SLTU = 4'b1000;   // unsigned set-less-than (BUG-031)
    localparam ALU_SRA  = 4'b1001;   // arithmetic shift right (BUG-032)
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
                ALU_SLTU: alu_compute = (op1 < op2) ? 32'h1 : 32'h0;
                ALU_SHL:  alu_compute = op1 << op2[4:0];
                ALU_SHR:  alu_compute = op1 >> op2[4:0];
                ALU_SRA:  alu_compute = $signed(op1) >>> op2[4:0];
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
                OPCODE_ITYPE, OPCODE_LTYPE:  // I-type immediate (ALU-imm and loads)
                    // BUG-029: OPCODE_LTYPE was missing, so load offsets were
                    // always 0 (fell through to default).
                    generate_imm = { {20{instr[31]}}, instr[31:20] };
                OPCODE_STYPE:  // S-type immediate
                    generate_imm = { {20{instr[31]}}, instr[31:25], instr[11:7] };
                OPCODE_BRANCH: // B-type immediate
                    generate_imm = { {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 };
                OPCODE_JAL:    // J-type immediate
                    generate_imm = { {11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 };
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
        if (trap_taken)
            next_pc = csr_mtvec;          // direct-mode trap vector
        else if (mret_taken)
            next_pc = csr_mepc;           // return from trap
        else if (pc_sel_jump) begin
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
            if_pc <= pc_reg;   // PC of the instruction just fetched (was next_pc:
                               // an off-by-4 bug affecting branch/jump targets & mepc)
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

            // Initialize register file (x0–x31)
            for (rf_init_idx = 0; rf_init_idx < REG_COUNT; rf_init_idx = rf_init_idx + 1) begin
                regfile[rf_init_idx] <= 32'h0;
            end

        end else if (!stall_id_ex && !bubble_id_ex) begin
            // Capture instruction from IF stage (squash the two wrong-path
            // instructions following a taken control transfer).
            id_ex_instr <= if_instr;
            id_ex_pc <= if_pc;
            id_ex_valid <= !flush;

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
            // Address/operand: loads, I-type, AND stores use the immediate
            // (store address = rs1 + S-imm; the store DATA comes from rs2 via
            // mem_wdata, not the ALU). BUG-028: stores previously used rs2 here,
            // computing rs1+rs2 as the address.
            alu_op2 = (id_ex_instr[6:0] == OPCODE_ITYPE ||
                       id_ex_instr[6:0] == OPCODE_LTYPE ||
                       id_ex_instr[6:0] == OPCODE_STYPE) ? id_imm : rf_rs2_data;

            case (id_ex_instr[6:0])
                OPCODE_RTYPE: begin
                    case (id_ex_instr[14:12])
                        FUNCT3_ADD_SUB: alu_control = (id_ex_instr[31:25] == FUNCT7_SUB) ? ALU_SUB : ALU_ADD;
                        FUNCT3_AND:     alu_control = ALU_AND;
                        FUNCT3_OR:      alu_control = ALU_OR;
                        FUNCT3_XOR:     alu_control = ALU_XOR;
                        FUNCT3_SLT:     alu_control = ALU_SLT;
                        FUNCT3_SLTU:    alu_control = ALU_SLTU;   // BUG-031
                        FUNCT3_SLL:     alu_control = ALU_SHL;
                        FUNCT3_SHR:     alu_control = id_ex_instr[30] ? ALU_SRA : ALU_SHR; // BUG-032: SRA vs SRL
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
                        FUNCT3_SLTU:    alu_control = ALU_SLTU;   // SLTIU (BUG-031)
                        FUNCT3_SLL:     alu_control = ALU_SHL;
                        FUNCT3_SHR:     alu_control = id_ex_instr[30] ? ALU_SRA : ALU_SHR; // SRAI vs SRLI (BUG-032)
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

    // Determine writeback data (ALU result, Xcew result, PC+4 for jumps, CSR read, or load data)
    wire is_csr_read = id_ex_valid && (id_ex_instr[6:0] == OPCODE_SYSTEM) &&
                       (id_ex_instr[14:12] != 3'b000);  // Any CSR instruction (not ECALL/EBREAK)
    wire is_load = id_ex_valid && (id_ex_instr[6:0] == OPCODE_LTYPE);
    wire [31:0] wb_data;
    assign wb_data = xcew_valid ? xcew_result :
                     is_csr_read ? csr_read_value :
                     is_load ? mem_rdata :
                     ((id_ex_instr[6:0] == OPCODE_JAL) || (id_ex_instr[6:0] == OPCODE_JALR)) ? id_ex_pc + 32'h4 :
                     (id_ex_instr[6:0] == OPCODE_LUI) ? id_imm :
                     alu_result;

    // Register file writeback
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_we <= 1'b0;
            rf_wdata <= 32'h0;
            rf_rd_addr <= 5'h0;
        end else if (id_ex_valid && !trap_taken) begin
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

    // ================= Machine-mode trap / CSR (Zicsr, M-mode) =================
    localparam CSR_MSTATUS = 12'h300, CSR_MISA  = 12'h301, CSR_MIE  = 12'h304,
               CSR_MTVEC   = 12'h305, CSR_MSCRATCH = 12'h340, CSR_MEPC = 12'h341,
               CSR_MCAUSE  = 12'h342, CSR_MTVAL = 12'h343, CSR_MIP  = 12'h344,
               CSR_MHARTID = 12'hF14;

    reg [31:0] csr_mstatus, csr_mie, csr_mtvec, csr_mscratch, csr_mepc, csr_mcause, csr_mtval;
    wire mstatus_mie = csr_mstatus[3];
    // mip is read-only here, reflecting the interrupt inputs (MEIP=11,MTIP=7,MSIP=3)
    wire [31:0] csr_mip = (i_meip ? 32'h00000800 : 32'h0)
                        | (i_mtip ? 32'h00000080 : 32'h0)
                        | (i_msip ? 32'h00000008 : 32'h0);

    wire [11:0] csr_a = id_ex_instr[31:20];
    wire csr_is_machine =
        (csr_a==CSR_MSTATUS)||(csr_a==CSR_MISA)||(csr_a==CSR_MIE)||(csr_a==CSR_MTVEC)||
        (csr_a==CSR_MSCRATCH)||(csr_a==CSR_MEPC)||(csr_a==CSR_MCAUSE)||(csr_a==CSR_MTVAL)||
        (csr_a==CSR_MIP)||(csr_a==CSR_MHARTID);

    reg [31:0] csr_int_rdata;
    always @(*) begin
        case (csr_a)
            CSR_MSTATUS:  csr_int_rdata = csr_mstatus;
            CSR_MISA:     csr_int_rdata = 32'h40001100; // MXL=32, ext I+M
            CSR_MIE:      csr_int_rdata = csr_mie;
            CSR_MTVEC:    csr_int_rdata = csr_mtvec;
            CSR_MSCRATCH: csr_int_rdata = csr_mscratch;
            CSR_MEPC:     csr_int_rdata = csr_mepc;
            CSR_MCAUSE:   csr_int_rdata = csr_mcause;
            CSR_MTVAL:    csr_int_rdata = csr_mtval;
            CSR_MIP:      csr_int_rdata = csr_mip;
            default:      csr_int_rdata = 32'h0; // MHARTID and others read 0
        endcase
    end

    // Zicsr operation (CSRRW/S/C and immediate variants)
    wire is_system    = id_ex_valid && (id_ex_instr[6:0] == OPCODE_SYSTEM);
    wire [2:0] sys_f3 = id_ex_instr[14:12];
    wire is_csr_op    = is_system && (sys_f3 != 3'b000);
    wire csr_use_imm  = sys_f3[2];
    wire [31:0] csr_src = csr_use_imm ? {27'h0, id_ex_instr[19:15]} : rf_rs1_data;
    wire [31:0] csr_old = csr_is_machine ? csr_int_rdata : csr_rd_data;
    reg  [31:0] csr_new;
    always @(*) begin
        case (sys_f3[1:0])
            2'b01:   csr_new = csr_src;            // CSRRW / CSRRWI
            2'b10:   csr_new = csr_old | csr_src;  // CSRRS / CSRRSI
            2'b11:   csr_new = csr_old & ~csr_src; // CSRRC / CSRRCI
            default: csr_new = csr_old;
        endcase
    end
    // RW always writes; RS/RC write only if the source field (rs1/uimm) != 0
    wire csr_wr_happens = is_csr_op &&
        ((sys_f3[1:0]==2'b01) || (id_ex_instr[19:15]!=5'h0));

    // System / trap instruction decode
    wire is_ecall  = is_system && (sys_f3==3'b000) && (csr_a==12'h000);
    wire is_ebreak = is_system && (sys_f3==3'b000) && (csr_a==12'h001);
    wire is_mret   = is_system && (sys_f3==3'b000) && (csr_a==12'h302);

    wire [6:0] op7 = id_ex_instr[6:0];
    wire legal_opcode =
        (op7==OPCODE_RTYPE)||(op7==OPCODE_ITYPE)||(op7==OPCODE_LTYPE)||(op7==OPCODE_STYPE)||
        (op7==OPCODE_BRANCH)||(op7==OPCODE_JAL)||(op7==OPCODE_JALR)||(op7==OPCODE_AUIPC)||
        (op7==OPCODE_LUI)||(op7==OPCODE_SYSTEM)||(op7==7'b0001111)|| // FENCE
        id_ex_is_xcew;

    // Exception conditions
    wire exc_illegal  = id_ex_valid && !legal_opcode;
    wire exc_load_ma  = is_load &&
        (((id_ex_instr[14:12]==3'b001)&&alu_result[0]) ||                 // LH
         ((id_ex_instr[14:12]==3'b101)&&alu_result[0]) ||                 // LHU
         ((id_ex_instr[14:12]==3'b010)&&(alu_result[1:0]!=2'b00)));        // LW
    wire exc_store_ma = is_store &&
        (((id_ex_instr[14:12]==3'b001)&&alu_result[0]) ||                 // SH
         ((id_ex_instr[14:12]==3'b010)&&(alu_result[1:0]!=2'b00)));        // SW
    wire any_exception = exc_illegal | is_ecall | is_ebreak | exc_load_ma | exc_store_ma;

    // Interrupt pending (globally + individually enabled)
    wire irq_pending = mstatus_mie &&
        ((csr_mie[11]&i_meip) | (csr_mie[7]&i_mtip) | (csr_mie[3]&i_msip));

    // A trap is taken only when a handler is installed (mtvec != 0). This keeps
    // pre-handler bring-up behavior intact (existing tests never set mtvec) while
    // giving full M-mode trap behavior once firmware programs mtvec. (DECISION-009)
    wire trap_taken = id_ex_valid && (csr_mtvec != 32'h0) && !xcew_pending &&
                      (any_exception | irq_pending);
    wire mret_taken = is_mret && id_ex_valid && !trap_taken;

    // A taken control transfer (branch/jump/trap/mret) redirects the PC. With
    // IF and ID/EX register stages, the TWO sequentially-fetched instructions
    // behind it (PC+4 and PC+8) are wrong-path and must both be squashed, so the
    // flush spans two capture cycles (redirect this cycle + redirect last cycle).
    wire redirect = pc_sel_jump | trap_taken | mret_taken;
    reg  redirect_r;
    always @(posedge clk or posedge rst) begin
        if (rst) redirect_r <= 1'b0;
        else if (!stall_id_ex) redirect_r <= redirect;
    end
    wire flush = redirect | redirect_r;

    // Trap cause / mtval (synchronous exceptions take priority over interrupts)
    reg [31:0] trap_cause, trap_tval;
    always @(*) begin
        if (exc_illegal)             begin trap_cause=32'd2;        trap_tval=id_ex_instr; end
        else if (is_ecall)           begin trap_cause=32'd11;       trap_tval=32'h0;       end
        else if (is_ebreak)          begin trap_cause=32'd3;        trap_tval=id_ex_pc;    end
        else if (exc_load_ma)        begin trap_cause=32'd4;        trap_tval=alu_result;  end
        else if (exc_store_ma)       begin trap_cause=32'd6;        trap_tval=alu_result;  end
        else if (csr_mie[11]&i_meip) begin trap_cause=32'h8000000B; trap_tval=32'h0;       end
        else if (csr_mie[7]&i_mtip)  begin trap_cause=32'h80000007; trap_tval=32'h0;       end
        else                         begin trap_cause=32'h80000003; trap_tval=32'h0;       end
    end

    // Machine CSR state update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            csr_mstatus  <= 32'h0;  csr_mie    <= 32'h0;  csr_mtvec <= 32'h0;
            csr_mscratch <= 32'h0;  csr_mepc   <= 32'h0;  csr_mcause<= 32'h0;
            csr_mtval    <= 32'h0;
        end else if (trap_taken) begin
            csr_mepc           <= id_ex_pc;
            csr_mcause         <= trap_cause;
            csr_mtval          <= trap_tval;
            csr_mstatus[7]     <= csr_mstatus[3]; // MPIE <= MIE
            csr_mstatus[3]     <= 1'b0;           // MIE  <= 0
            csr_mstatus[12:11] <= 2'b11;          // MPP  <= M
        end else if (mret_taken) begin
            csr_mstatus[3]     <= csr_mstatus[7]; // MIE  <= MPIE
            csr_mstatus[7]     <= 1'b1;           // MPIE <= 1
            csr_mstatus[12:11] <= 2'b11;
        end else if (is_csr_op && csr_is_machine && csr_wr_happens) begin
            case (csr_a)
                CSR_MSTATUS:  csr_mstatus  <= csr_new;
                CSR_MIE:      csr_mie      <= csr_new;
                CSR_MTVEC:    csr_mtvec    <= csr_new;
                CSR_MSCRATCH: csr_mscratch <= csr_new;
                CSR_MEPC:     csr_mepc     <= csr_new;
                CSR_MCAUSE:   csr_mcause   <= csr_new;
                CSR_MTVAL:    csr_mtval    <= csr_new;
                default: ; // MISA/MIP/MHARTID read-only
            endcase
        end
    end

    // External CSR bus (non-machine addresses, e.g. Xcew 0x7Cx)
    assign csr_addr    = is_csr_op ? csr_a : 12'h0;
    assign csr_wr_en   = csr_wr_happens && !csr_is_machine && !trap_taken;
    assign csr_wr_data = csr_new;

    // CSR read value for writeback: internal machine CSR or external bus
    wire [31:0] csr_read_value = csr_is_machine ? csr_int_rdata : csr_rd_data;

    // Memory signals - driven by load/store instructions
    wire is_store = id_ex_valid && (id_ex_instr[6:0] == OPCODE_STYPE);
    assign mem_addr  = (is_store || is_load) ? alu_result : 32'h0;
    assign mem_wdata = is_store ? rf_rs2_data : 32'h0;
    assign mem_we    = is_store && !trap_taken;  // suppress store on a taken trap

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

    // Control outputs. exception/interrupt reflect a *taken* trap (handler
    // installed), so they stay 0 before mtvec is programmed (no regression on
    // pre-handler bring-up streams).
    assign wb_stall = stall_id_ex;
    assign exception = trap_taken && any_exception;
    assign interrupt = trap_taken && !any_exception;

endmodule
