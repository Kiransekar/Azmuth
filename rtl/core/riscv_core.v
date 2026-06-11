// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// riscv_core.v
// In-order 3-stage RISC-V core with Xcew extension
// IF -> ID/EX -> WB pipeline
// Verilog-2001 compliant, no SV features

`timescale 1ns/1ps

module riscv_core #(
    parameter [31:0] RESET_PC = 32'h00000000   // reset vector (0 default; 0x80000000 for RISCOF)
) (
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

    // Debug interface
    input  wire        i_dm_halt_req,
    input  wire        i_dm_resume_req,
    input  wire        i_dm_reset_req,
    output wire        o_dm_halted,
    output wire        o_dm_running,
    output wire        o_dm_has_reset,
    output wire [31:0] o_dm_pc,
    input  wire        i_debug_trigger_hit,
    // Debug CSRs (per RISC-V Debug Spec 0.13.2)
    output wire [31:0] o_csr_dcsr,
    output wire [31:0] o_csr_dpc,
    output wire [31:0] o_csr_dscratch0,
    output wire [31:0] o_csr_dscratch1,
    // Debug register access interface (from debug module abstract command)
    input  wire        i_dbg_reg_req,
    input  wire        i_dbg_reg_wr,
    input  wire [11:0] i_dbg_reg_addr,
    input  wire [31:0] i_dbg_reg_wdata,
    output reg  [31:0] o_dbg_reg_rdata,
    output reg         o_dbg_reg_ack,

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
`ifdef SUPPORT_C
    reg        if_is_compressed;
`endif

    // ID/EX stage signals
    reg [31:0] id_ex_instr;
    reg [31:0] id_ex_pc;
    reg        id_ex_valid;
`ifdef SUPPORT_C
    reg        id_ex_is_compressed;
`endif

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
    reg [4:0]  alu_control;
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
    localparam ALU_ADD    = 5'b00000;
    localparam ALU_SUB    = 5'b00001;
    localparam ALU_AND    = 5'b00010;
    localparam ALU_OR     = 5'b00011;
    localparam ALU_XOR    = 5'b00100;
    localparam ALU_SLT    = 5'b00101;
    localparam ALU_SHL    = 5'b00110;
    localparam ALU_SHR    = 5'b00111;
    localparam ALU_SLTU   = 5'b01000;
    localparam ALU_SRA    = 5'b01001;
    localparam ALU_MUL    = 5'b01010;
    localparam ALU_MULH   = 5'b01011;
    localparam ALU_MULHSU = 5'b01100;
    localparam ALU_MULHU  = 5'b01101;
    localparam ALU_DIV    = 5'b01110;
    localparam ALU_DIVU   = 5'b01111;
    localparam ALU_REM    = 5'b10000;
    localparam ALU_REMU   = 5'b10001;
    localparam ALU_PASS   = 5'b11111;

    // M-extension helper calculations
    wire signed [31:0] alu_op1_signed = $signed(alu_op1);
    wire signed [31:0] alu_op2_signed = $signed(alu_op2);
    wire signed [31:0] div_signed_result = alu_op1_signed / alu_op2_signed;
    wire signed [31:0] rem_signed_result = alu_op1_signed % alu_op2_signed;

    wire signed [63:0] mul_signed   = alu_op1_signed * alu_op2_signed;
    wire signed [63:0] mul_signedsp = alu_op1_signed * $signed({1'b0, alu_op2});
    wire [63:0]        mul_unsigned = {32'h0, alu_op1} * {32'h0, alu_op2};

    wire div_op2_is_zero = (alu_op2 == 32'h0);
    wire div_op1_is_min  = (alu_op1 == 32'h80000000);
    wire div_op2_is_neg1 = (alu_op2 == 32'hFFFFFFFF);

    wire [31:0] div_signed   = div_op2_is_zero ? 32'hFFFFFFFF :
                               (div_op1_is_min && div_op2_is_neg1) ? 32'h80000000 :
                               div_signed_result;

    wire [31:0] div_unsigned = div_op2_is_zero ? 32'hFFFFFFFF :
                               alu_op1 / alu_op2;

    wire [31:0] rem_signed   = div_op2_is_zero ? alu_op1 :
                               (div_op1_is_min && div_op2_is_neg1) ? 32'h0 :
                               rem_signed_result;

    wire [31:0] rem_unsigned = div_op2_is_zero ? alu_op1 :
                               alu_op1 % alu_op2;

    reg [31:0] alu_result_reg;
    always @(*) begin
        case (alu_control)
            ALU_ADD:    alu_result_reg = alu_op1 + alu_op2;
            ALU_SUB:    alu_result_reg = alu_op1 - alu_op2;
            ALU_AND:    alu_result_reg = alu_op1 & alu_op2;
            ALU_OR:     alu_result_reg = alu_op1 | alu_op2;
            ALU_XOR:    alu_result_reg = alu_op1 ^ alu_op2;
            ALU_SLT:    alu_result_reg = ($signed(alu_op1) < $signed(alu_op2)) ? 32'h1 : 32'h0;
            ALU_SLTU:   alu_result_reg = (alu_op1 < alu_op2) ? 32'h1 : 32'h0;
            ALU_SHL:    alu_result_reg = alu_op1 << alu_op2[4:0];
            ALU_SHR:    alu_result_reg = alu_op1 >> alu_op2[4:0];
            ALU_SRA:    alu_result_reg = $signed(alu_op1) >>> alu_op2[4:0];
            ALU_MUL:    alu_result_reg = mul_signed[31:0];
            ALU_MULH:   alu_result_reg = mul_signed[63:32];
            ALU_MULHSU: alu_result_reg = mul_signedsp[63:32];
            ALU_MULHU:  alu_result_reg = mul_unsigned[63:32];
            ALU_DIV:    alu_result_reg = div_signed;
            ALU_DIVU:   alu_result_reg = div_unsigned;
            ALU_REM:    alu_result_reg = rem_signed;
            ALU_REMU:   alu_result_reg = rem_unsigned;
            default:    alu_result_reg = alu_op1;
        endcase
    end

    // Immediate generation
    function [31:0] generate_imm;
        input [31:0] instr;
        input [6:0]  opcode;
        begin
            case (opcode)
                OPCODE_ITYPE, OPCODE_LTYPE, OPCODE_JALR:  // I-type immediate (ALU-imm, loads, JALR)
                    // BUG-029: LTYPE was missing (load offsets always 0).
                    // BUG-034: JALR was missing (JALR offset always 0).
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

`ifdef SUPPORT_C
    function [31:0] decompress;
        input [15:0] c;
        begin
            decompress = 32'h00000000; // default to illegal instruction
            case (c[1:0])
                2'b00: begin
                    case (c[15:13])
                        3'b000: begin // c.addi4spn -> addi rd', sp, imm
                            if (c[12:5] != 8'h0) begin
                                decompress = {2'b00, c[10:7], c[12:11], c[5], c[6], 2'b00, 5'd2, 3'b000, 2'b01, c[4:2], 7'h13};
                            end
                        end
                        3'b010: begin // c.lw -> lw rd', offset(rs1')
                            decompress = {5'b00000, c[5], c[12:10], c[6], 2'b00, 2'b01, c[9:7], 3'b010, 2'b01, c[4:2], 7'h03};
                        end
                        3'b110: begin // c.sw -> sw rs2', offset(rs1')
                            decompress = {5'b00000, c[5], c[12], 2'b01, c[4:2], 2'b01, c[9:7], 3'b010, c[11:10], c[6], 2'b00, 7'h23};
                        end
                        default: ;
                    endcase
                end
                2'b01: begin
                    case (c[15:13])
                        3'b000: begin // c.nop / c.addi -> addi rd, rd, imm
                            decompress = { {6{c[12]}}, c[12], c[6:2], c[11:7], 3'b000, c[11:7], 7'h13};
                        end
                        3'b001: begin // c.jal -> jal x1, imm
                            decompress = {c[12], c[8], c[10:9], c[6], c[7], c[2], c[11], c[5:3], c[12], {8{c[12]}}, 5'd1, 7'h6f};
                        end
                        3'b010: begin // c.li -> addi rd, x0, imm
                            decompress = { {6{c[12]}}, c[12], c[6:2], 5'd0, 3'b000, c[11:7], 7'h13};
                        end
                        3'b011: begin
                            if (c[11:7] == 5'd2) begin // c.addi16sp -> addi sp, sp, imm
                                decompress = { {2{c[12]}}, c[12], c[4:3], c[5], c[2], c[6], 4'b00, 5'd2, 3'b000, 5'd2, 7'h13};
                            end else begin // c.lui -> lui rd, imm
                                decompress = { {14{c[12]}}, c[12], c[6:2], c[11:7], 7'h37};
                            end
                        end
                        3'b100: begin
                            case (c[11:10])
                                2'b00: begin // c.srli
                                    decompress = {7'h00, c[6:2], 2'b01, c[9:7], 3'b101, 2'b01, c[9:7], 7'h13};
                                end
                                2'b01: begin // c.srai
                                    decompress = {7'h20, c[6:2], 2'b01, c[9:7], 3'b101, 2'b01, c[9:7], 7'h13};
                                end
                                2'b10: begin // c.andi
                                    decompress = { {6{c[12]}}, c[12], c[6:2], 2'b01, c[9:7], 3'b111, 2'b01, c[9:7], 7'h13};
                                end
                                2'b11: begin
                                    case ( {c[12], c[6:5]} )
                                        3'b000: decompress = {7'h20, 2'b01, c[4:2], 2'b01, c[9:7], 3'b000, 2'b01, c[9:7], 7'h33}; // c.sub
                                        3'b001: decompress = {7'h00, 2'b01, c[4:2], 2'b01, c[9:7], 3'b100, 2'b01, c[9:7], 7'h33}; // c.xor
                                        3'b010: decompress = {7'h00, 2'b01, c[4:2], 2'b01, c[9:7], 3'b110, 2'b01, c[9:7], 7'h33}; // c.or
                                        3'b011: decompress = {7'h00, 2'b01, c[4:2], 2'b01, c[9:7], 3'b111, 2'b01, c[9:7], 7'h33}; // c.and
                                        default: ;
                                    endcase
                                end
                            endcase
                        end
                        3'b101: begin // c.j
                            decompress = {c[12], c[8], c[10:9], c[6], c[7], c[2], c[11], c[5:3], c[12], {8{c[12]}}, 5'd0, 7'h6f};
                        end
                        3'b110: begin // c.beqz
                            decompress = {c[12], c[12], c[12], c[12], c[6], c[5], c[2], 5'd0, 2'b01, c[9:7], 3'b000, c[11], c[10], c[4], c[3], c[12], 7'h63};
                        end
                        3'b111: begin // c.bnez
                            decompress = {c[12], c[12], c[12], c[12], c[6], c[5], c[2], 5'd0, 2'b01, c[9:7], 3'b001, c[11], c[10], c[4], c[3], c[12], 7'h63};
                        end
                    endcase
                end
                2'b10: begin
                    case (c[15:13])
                        3'b000: begin // c.slli
                            decompress = {7'h00, c[6:2], c[11:7], 3'b001, c[11:7], 7'h13};
                        end
                        3'b010: begin // c.lwsp
                            decompress = {4'b0000, c[3:2], c[12], c[6:4], 2'b00, 5'd2, 3'b010, c[11:7], 7'h03};
                        end
                        3'b100: begin
                            if (c[12] == 1'b0 && c[6:2] == 5'b0) begin // c.jr
                                decompress = {12'h000, c[11:7], 3'b000, 5'd0, 7'h67};
                            end else if (c[12] == 1'b0 && c[6:2] != 5'b0) begin // c.mv
                                decompress = {7'h00, c[6:2], 5'd0, 3'b000, c[11:7], 7'h33};
                            end else if (c[12] == 1'b1 && c[6:2] == 5'b0) begin
                                if (c[11:7] == 5'b0) begin // c.ebreak
                                    decompress = 32'h00100073;
                                end else begin // c.jalr
                                    decompress = {12'h000, c[11:7], 3'b000, 5'd1, 7'h67};
                                end
                            end else if (c[12] == 1'b1 && c[6:2] != 5'b0) begin // c.add
                                decompress = {7'h00, c[6:2], c[11:7], 3'b000, c[11:7], 7'h33};
                            end
                        end
                        3'b110: begin // c.swsp
                            decompress = {4'b0000, c[8:7], c[12], c[6:2], 5'd2, 3'b010, c[11:9], 2'b00, 7'h23};
                        end
                        default: ;
                    endcase
                end
                default: ;
            endcase
        end
    endfunction
`endif

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
        if (debug_enter)
            next_pc = 32'h00000800;       // Debug ROM base address
        else if (debug_exit)
            next_pc = csr_dpc;            // Resume from debug PC
        else if (trap_taken)
            next_pc = (csr_mtvec[1:0] == 2'b01 && trap_cause[31]) ?
                      ((csr_mtvec & 32'hFFFFFFFC) + (trap_cause[30:0] << 2)) :
                      (csr_mtvec & 32'hFFFFFFFC);
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

`ifdef SUPPORT_C
    reg [15:0] fetch_buf;
    reg        fetch_buf_valid;
`endif

    // IF Stage
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_reg <= RESET_PC;
            if_instr <= 32'h00000000;
            if_pc <= RESET_PC;
`ifdef SUPPORT_C
            fetch_buf_valid <= 1'b0;
            fetch_buf <= 16'h0;
            if_is_compressed <= 1'b0;
`endif
        end else if (debug_enter || debug_exit || trap_taken || mret_taken) begin
            // Force PC redirect on debug/trap events (override stall)
            pc_reg <= next_pc;
            if_instr <= 32'h00000013;  // Insert NOP bubble during redirect
            if_pc <= next_pc;
`ifdef SUPPORT_C
            fetch_buf_valid <= 1'b0;
            if_is_compressed <= 1'b0;
`endif
        end else if (!stall_if && !bubble_if) begin
`ifdef SUPPORT_C
            if (pc_sel_jump) begin
                pc_reg <= next_pc;
                if_instr <= 32'h00000013;
                if_pc <= next_pc;
                fetch_buf_valid <= 1'b0;
                if_is_compressed <= 1'b0;
            end else if (fetch_buf_valid) begin
                pc_reg <= pc_reg + 2;
                if_instr <= {instr[15:0], fetch_buf};
                if_pc <= pc_reg - 2;
                fetch_buf_valid <= 1'b0;
                if_is_compressed <= 1'b0;
            end else if (pc_reg[1]) begin
                if (instr[17:16] == 2'b11) begin
                    // 32-bit cross-word instruction: stall and buffer first half
                    fetch_buf <= instr[31:16];
                    fetch_buf_valid <= 1'b1;
                    pc_reg <= pc_reg + 2;
                    if_instr <= 32'h00000013; // insert bubble
                    if_pc <= pc_reg;
                    if_is_compressed <= 1'b0;
                end else begin
                    // 16-bit compressed instruction starting at 2-byte boundary
                    pc_reg <= pc_reg + 2;
                    if_instr <= decompress(instr[31:16]);
                    if_pc <= pc_reg;
                    if_is_compressed <= 1'b1;
                end
            end else begin
                if (instr[1:0] == 2'b11) begin
                    // 32-bit aligned instruction
                    pc_reg <= pc_reg + 4;
                    if_instr <= instr;
                    if_pc <= pc_reg;
                    if_is_compressed <= 1'b0;
                end else begin
                    // 16-bit compressed instruction starting at 4-byte boundary
                    pc_reg <= pc_reg + 2;
                    if_instr <= decompress(instr[15:0]);
                    if_pc <= pc_reg;
                    if_is_compressed <= 1'b1;
                end
            end
`else
            pc_reg <= next_pc;
            if_instr <= instr;
            if_pc <= pc_reg;   // PC of the instruction just fetched (was next_pc:
                               // an off-by-4 bug affecting branch/jump targets & mepc)
`endif
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
`ifdef SUPPORT_C
            id_ex_is_compressed <= 1'b0;
`endif

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
`ifdef SUPPORT_C
            id_ex_is_compressed <= !flush && if_is_compressed;
`endif

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
`ifdef SUPPORT_C
            id_ex_is_compressed <= id_ex_is_compressed;
`endif
        end else begin
            id_ex_valid <= 1'b0;
`ifdef SUPPORT_C
            id_ex_is_compressed <= 1'b0;
`endif
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
                    if (id_ex_instr[31:25] == 7'b0000001) begin
                        case (id_ex_instr[14:12])
                            3'b000: alu_control = ALU_MUL;
                            3'b001: alu_control = ALU_MULH;
                            3'b010: alu_control = ALU_MULHSU;
                            3'b011: alu_control = ALU_MULHU;
                            3'b100: alu_control = ALU_DIV;
                            3'b101: alu_control = ALU_DIVU;
                            3'b110: alu_control = ALU_REM;
                            3'b111: alu_control = ALU_REMU;
                            default: alu_control = ALU_ADD;
                        endcase
                    end else begin
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
    assign alu_result = alu_result_reg;

    // Determine writeback data (ALU result, Xcew result, PC+4 for jumps, CSR read, or load data)
    wire is_csr_read = id_ex_valid && (id_ex_instr[6:0] == OPCODE_SYSTEM) &&
                       (id_ex_instr[14:12] != 3'b000);  // Any CSR instruction (not ECALL/EBREAK)
    wire is_load = id_ex_valid && (id_ex_instr[6:0] == OPCODE_LTYPE);
    // Sub-word load extraction + sign/zero-extension (BUG-036: loads wrote the
    // whole fetched word, so LB/LBU/LH/LHU and any non-zero byte offset were
    // wrong). Select the addressed byte/half from mem_rdata via alu_result[1:0].
    wire [7:0]  load_byte = mem_rdata >> {alu_result[1:0], 3'b000};
    wire [15:0] load_half = mem_rdata >> {alu_result[1],   4'b0000};
    reg  [31:0] load_data;
    always @(*) begin
        case (id_ex_instr[14:12])
            3'b000:  load_data = {{24{load_byte[7]}},  load_byte};  // LB
            3'b100:  load_data = {24'h0,               load_byte};  // LBU
            3'b001:  load_data = {{16{load_half[15]}}, load_half};  // LH
            3'b101:  load_data = {16'h0,               load_half};  // LHU
            default: load_data = mem_rdata;                         // LW
        endcase
    end
    wire [31:0] wb_data;
    assign wb_data = xcew_valid ? xcew_result :
                     is_csr_read ? csr_read_value :
                     is_load ? load_data :
                      ((id_ex_instr[6:0] == OPCODE_JAL) || (id_ex_instr[6:0] == OPCODE_JALR)) ?
`ifdef SUPPORT_C
                      (id_ex_is_compressed ? id_ex_pc + 32'h2 : id_ex_pc + 32'h4) :
`else
                      id_ex_pc + 32'h4 :
`endif
                     (id_ex_instr[6:0] == OPCODE_LUI) ? id_imm :
                     (id_ex_instr[6:0] == OPCODE_AUIPC) ? (id_ex_pc + id_imm) : // BUG-033: was ALU garbage
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
    wire csr_is_debug =
        (csr_a==CSR_DCSR)||(csr_a==CSR_DPC)||(csr_a==CSR_DSCRATCH0)||(csr_a==CSR_DSCRATCH1);

    reg [31:0] csr_int_rdata;
    always @(*) begin
        case (csr_a)
            CSR_MSTATUS:  csr_int_rdata = csr_mstatus;
`ifdef SUPPORT_C
            CSR_MISA:     csr_int_rdata = 32'h40001104; // MXL=32, extensions I, M, C enabled
`else
            CSR_MISA:     csr_int_rdata = 32'h40001100; // MXL=32, extensions I, M enabled
`endif
            CSR_MIE:      csr_int_rdata = csr_mie;
            CSR_MTVEC:    csr_int_rdata = csr_mtvec;
            CSR_MSCRATCH: csr_int_rdata = csr_mscratch;
            CSR_MEPC:     csr_int_rdata = csr_mepc;
            CSR_MCAUSE:   csr_int_rdata = csr_mcause;
            CSR_MTVAL:    csr_int_rdata = csr_mtval;
            CSR_MIP:      csr_int_rdata = csr_mip;
            CSR_DCSR:     csr_int_rdata = csr_dcsr;
            CSR_DPC:      csr_int_rdata = csr_dpc;
            CSR_DSCRATCH0: csr_int_rdata = csr_dscratch0;
            CSR_DSCRATCH1: csr_int_rdata = csr_dscratch1;
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
    wire [31:0] target_pc = (id_ex_instr[6:0] == OPCODE_BRANCH) ? branch_target : jump_target;
`ifdef SUPPORT_C
    wire exc_instr_ma = id_ex_valid && pc_sel_jump && target_pc[0];
`else
    wire exc_instr_ma = id_ex_valid && pc_sel_jump && (target_pc[1:0] != 2'b00);
`endif

    wire exc_illegal  = id_ex_valid && !legal_opcode;
    wire exc_load_ma  = is_load &&
        (((id_ex_instr[14:12]==3'b001)&&alu_result[0]) ||                 // LH
         ((id_ex_instr[14:12]==3'b101)&&alu_result[0]) ||                 // LHU
         ((id_ex_instr[14:12]==3'b010)&&(alu_result[1:0]!=2'b00)));        // LW
    wire exc_store_ma = is_store &&
        (((id_ex_instr[14:12]==3'b001)&&alu_result[0]) ||                 // SH
         ((id_ex_instr[14:12]==3'b010)&&(alu_result[1:0]!=2'b00)));        // SW
    wire any_exception = exc_illegal | is_ecall | is_ebreak | exc_load_ma | exc_store_ma | exc_instr_ma;

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
    wire flush = redirect | redirect_r | debug_exit | debug_enter;

    // Trap cause / mtval (synchronous exceptions take priority over interrupts)
    reg [31:0] trap_cause, trap_tval;
    always @(*) begin
        if (exc_instr_ma)            begin trap_cause=32'd0;        trap_tval=target_pc;   end
        else if (exc_illegal)        begin trap_cause=32'd2;        trap_tval=id_ex_instr; end
        else if (is_ecall)           begin trap_cause=32'd11;       trap_tval=32'h0;       end
        else if (is_ebreak)          begin trap_cause=32'd3;        trap_tval=id_ex_pc;    end
        else if (exc_load_ma)        begin trap_cause=32'd4;        trap_tval=alu_result;  end
        else if (exc_store_ma)       begin trap_cause=32'd6;        trap_tval=alu_result;  end
        else if (csr_mie[11]&i_meip) begin trap_cause=32'h8000000B; trap_tval=32'h0;       end
        else if (csr_mie[7]&i_mtip)  begin trap_cause=32'h80000007; trap_tval=32'h0;       end
        else                         begin trap_cause=32'h80000003; trap_tval=32'h0;       end
    end

    // Debug CSR addresses
    localparam CSR_DCSR       = 12'h7B0;
    localparam CSR_DPC        = 12'h7B1;
    localparam CSR_DSCRATCH0  = 12'h7B2;
    localparam CSR_DSCRATCH1  = 12'h7B3;

    // Debug mode state
    reg        debug_mode;
    reg        debug_halted;
    reg        debug_single_step;
    reg [1:0]  debug_prv;
    reg [31:0] csr_dcsr;
    reg [31:0] csr_dpc;
    reg [31:0] csr_dscratch0;
    reg [31:0] csr_dscratch1;

    // DCSR fields
    wire dcsr_prv    = csr_dcsr[31:30];
    wire dcsr_step   = csr_dcsr[2];
    wire dcsr_nmip   = csr_dcsr[1];
    wire dcsr_stopcount = csr_dcsr[0];
    wire dcsr_cause  = csr_dcsr[8:6]; // halt cause

    // Halt request from DM
    wire dm_halt_req_sync = i_dm_halt_req;

    // Debug mode entry conditions
    wire debug_halt_request = dm_halt_req_sync && !debug_mode;
    wire debug_ebreak       = is_ebreak && !debug_mode && csr_dcsr[15];
    wire debug_trigger_hit  = i_debug_trigger_hit && !debug_mode;
    // Single-step: after resume with dcsr.step=1, re-enter debug after one instruction completes
    // step_armed prevents re-entry on the same cycle as resume
    wire debug_step_reenter = debug_single_step && !debug_mode && !debug_halted && 
                               step_armed && id_ex_valid && !stall_id_ex;

    wire debug_enter = debug_halt_request | debug_ebreak | debug_trigger_hit | debug_step_reenter;

    // step_armed: set after resume with single-step, delayed by one instruction execution
    // Only arm after the redirect to dpc has completed (redirect_r = 0)
    reg step_armed;
    always @(posedge clk or posedge rst) begin
        if (rst)
            step_armed <= 1'b0;
        else if (debug_step_reenter)
            step_armed <= 1'b0;  // Clear after re-entering debug mode
        else if (!debug_single_step)
            step_armed <= 1'b0;  // Clear if single-step mode disabled
        else if (debug_exit)
            step_armed <= 1'b1;  // Arm when resuming with single-step
    end

    // Debug mode exit
    wire debug_exit = i_dm_resume_req && debug_mode;

    // Machine CSR state update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            csr_mstatus  <= 32'h0;  csr_mie    <= 32'h0;  csr_mtvec <= 32'h0;
            csr_mscratch <= 32'h0;  csr_mepc   <= 32'h0;  csr_mcause<= 32'h0;
            csr_mtval    <= 32'h0;
            debug_mode   <= 1'b0;
            debug_halted <= 1'b0;
            debug_single_step <= 1'b0;
            debug_prv    <= 2'b11; // M-mode
            csr_dcsr     <= 32'h40000000; // xdebugver=4 (0.13.2), ebreakm=1
            csr_dpc      <= 32'h0;
            csr_dscratch0 <= 32'h0;
            csr_dscratch1 <= 32'h0;
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

    // Debug mode state machine and CSR updates
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            debug_mode   <= 1'b0;
            debug_halted <= 1'b0;
            debug_single_step <= 1'b0;
            debug_prv    <= 2'b11;
            csr_dcsr     <= 32'h40000000;
            csr_dpc      <= 32'h0;
            csr_dscratch0 <= 32'h0;
            csr_dscratch1 <= 32'h0;
        end else begin
            // Debug mode entry
            if (debug_enter) begin
                debug_mode   <= 1'b1;
                debug_halted <= 1'b1;
                debug_prv    <= csr_mstatus[12:11]; // Save MPP
                // For single-step: dpc = next instruction (after the one just executed)
                // For halt/ebreak/trigger: dpc = current instruction (not yet completed)
                csr_dpc      <= debug_step_reenter ?
`ifdef SUPPORT_C
                                (id_ex_is_compressed ? id_ex_pc + 2 : id_ex_pc + 4) :
`else
                                (id_ex_pc + 4) :
`endif
                                id_ex_pc;
                csr_dcsr[8:6] <= debug_step_reenter ? 3'b100 :  // single step
                                  debug_ebreak ? 3'b001 :  // ebreak
                                  debug_halt_request ? 3'b011 : // halt req
                                  3'b100; // trigger
                csr_dcsr[1:0] <= debug_prv;  // Save privilege mode to prv field
            end

            // Debug mode exit (resume)
            if (debug_exit) begin
                debug_mode   <= 1'b0;
                debug_halted <= 1'b0;
                debug_single_step <= 1'b0;
            end

            // Single step handling
            if (debug_mode && !debug_halted) begin
                if (debug_single_step) begin
                    debug_halted <= 1'b1;
                    csr_dpc <= pc_reg;
                    csr_dcsr[8:6] <= 3'b100; // single step
                end
            end

            // DM requests single step
            if (i_dm_resume_req && debug_mode && csr_dcsr[2]) begin
                debug_single_step <= 1'b1;
            end

            // Debug CSR writes (from abstract command)
            if (is_csr_op && (csr_a == CSR_DCSR) && csr_wr_happens) begin
                csr_dcsr <= csr_new;
            end
            if (is_csr_op && (csr_a == CSR_DPC) && csr_wr_happens) begin
                csr_dpc <= csr_new;
            end
            if (is_csr_op && (csr_a == CSR_DSCRATCH0) && csr_wr_happens) begin
                csr_dscratch0 <= csr_new;
            end
            if (is_csr_op && (csr_a == CSR_DSCRATCH1) && csr_wr_happens) begin
                csr_dscratch1 <= csr_new;
            end

            // Halt on reset
            if (i_dm_reset_req) begin
                debug_mode   <= 1'b1;
                debug_halted <= 1'b1;
                debug_prv    <= 2'b11;
                csr_dpc      <= RESET_PC;
                csr_dcsr[8:6] <= 3'b110; // halt on reset
            end
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
    // SB/SH place the source byte/half in the addressed lane: shift rs2 left by
    // 8*byte-offset so it aligns with the byte-enables below. (BUG-035: store
    // data was unshifted, so SB/SH to offsets 1-3 wrote rs2[7:0] to lane 0.)
    wire [4:0] store_shamt = {alu_result[1:0], 3'b000};
    assign mem_wdata = is_store ? (rf_rs2_data << store_shamt) : 32'h0;
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

    // Debug outputs
    assign o_dm_halted    = debug_halted;
    assign o_dm_running   = debug_mode && !debug_halted;
    assign o_dm_has_reset = 1'b0; // No reset in debug mode currently
    assign o_dm_pc        = debug_mode ? csr_dpc : pc_reg;
    assign o_csr_dcsr     = csr_dcsr;
    assign o_csr_dpc      = csr_dpc;
    assign o_csr_dscratch0 = csr_dscratch0;
    assign o_csr_dscratch1 = csr_dscratch1;

    // Debug register access (GPR and CSR read/write from debug module)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_dbg_reg_rdata <= 32'h0;
            o_dbg_reg_ack   <= 1'b0;
        end else begin
            o_dbg_reg_ack <= 1'b0; // default: pulse on completion
            if (i_dbg_reg_req && !o_dbg_reg_ack) begin
                if (i_dbg_reg_wr) begin
                    // Write operation
                    if (i_dbg_reg_addr[11:5] == 7'h00) begin
                        // GPR write (0x000-0x01F)
                        if (i_dbg_reg_addr[4:0] != 5'h0) begin
                            regfile[i_dbg_reg_addr[4:0]] <= i_dbg_reg_wdata;
                        end
                    end else begin
                        // CSR write
                        case (i_dbg_reg_addr)
                            CSR_DCSR:       csr_dcsr <= i_dbg_reg_wdata;
                            CSR_DPC:        csr_dpc <= i_dbg_reg_wdata;
                            CSR_DSCRATCH0:  csr_dscratch0 <= i_dbg_reg_wdata;
                            CSR_DSCRATCH1:  csr_dscratch1 <= i_dbg_reg_wdata;
                            CSR_MSTATUS:    csr_mstatus <= i_dbg_reg_wdata;
                            CSR_MIE:        csr_mie <= i_dbg_reg_wdata;
                            CSR_MTVEC:      csr_mtvec <= i_dbg_reg_wdata;
                            CSR_MSCRATCH:   csr_mscratch <= i_dbg_reg_wdata;
                            CSR_MEPC:       csr_mepc <= i_dbg_reg_wdata;
                            CSR_MCAUSE:     csr_mcause <= i_dbg_reg_wdata;
                            CSR_MTVAL:      csr_mtval <= i_dbg_reg_wdata;
                            default: ; // Read-only CSRs ignored
                        endcase
                    end
                    o_dbg_reg_ack <= 1'b1;
                end else begin
                    // Read operation
                    if (i_dbg_reg_addr[11:5] == 7'h00) begin
                        // GPR read (0x000-0x01F)
                        if (i_dbg_reg_addr[4:0] == 5'h0)
                            o_dbg_reg_rdata <= 32'h0;
                        else
                            o_dbg_reg_rdata <= regfile[i_dbg_reg_addr[4:0]];
                    end else begin
                        // CSR read
                        case (i_dbg_reg_addr)
                            CSR_DCSR:       o_dbg_reg_rdata <= csr_dcsr;
                            CSR_DPC:        o_dbg_reg_rdata <= csr_dpc;
                            CSR_DSCRATCH0:  o_dbg_reg_rdata <= csr_dscratch0;
                            CSR_DSCRATCH1:  o_dbg_reg_rdata <= csr_dscratch1;
                            CSR_MSTATUS:    o_dbg_reg_rdata <= csr_mstatus;
`ifdef SUPPORT_C
                            CSR_MISA:       o_dbg_reg_rdata <= 32'h40001104;
`else
                            CSR_MISA:       o_dbg_reg_rdata <= 32'h40001100;
`endif
                            CSR_MIE:        o_dbg_reg_rdata <= csr_mie;
                            CSR_MTVEC:      o_dbg_reg_rdata <= csr_mtvec;
                            CSR_MSCRATCH:   o_dbg_reg_rdata <= csr_mscratch;
                            CSR_MEPC:       o_dbg_reg_rdata <= csr_mepc;
                            CSR_MCAUSE:     o_dbg_reg_rdata <= csr_mcause;
                            CSR_MTVAL:      o_dbg_reg_rdata <= csr_mtval;
                            CSR_MIP:        o_dbg_reg_rdata <= csr_mip;
                            CSR_MHARTID:    o_dbg_reg_rdata <= 32'h0;
                            default:        o_dbg_reg_rdata <= 32'h0;
                        endcase
                    end
                    o_dbg_reg_ack <= 1'b1;
                end
            end
        end
    end

endmodule
