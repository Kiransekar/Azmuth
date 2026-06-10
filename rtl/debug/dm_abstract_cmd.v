// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// dm_abstract_cmd.v
// Abstract command engine for Debug Module
// Supports Access Register command
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module dm_abstract_cmd (
    input  wire        clk,
    input  wire        rst_n,
    // DMI interface
    input  wire        dmi_req,
    input  wire        dmi_wr,
    input  wire [6:0]  dmi_addr,
    input  wire [31:0] dmi_wdata,
    output reg  [31:0] dmi_rdata,
    output reg         dmi_ack,
    // Core register access interface
    output reg         core_reg_req,
    output reg         core_reg_wr,
    output reg  [15:0] core_reg_addr,
    output reg  [31:0] core_reg_wdata,
    input  wire [31:0] core_reg_rdata,
    input  wire        core_reg_ack,
    // Program buffer interface
    input  wire [31:0] progbuf0,
    input  wire [31:0] progbuf1,
    // Status
    output reg         cmd_busy,
    output reg  [2:0]  cmd_err
);

    // Abstract CSR addresses
    localparam ABSTRACTCS = 7'h16;
    localparam COMMAND    = 7'h17;
    localparam DATA0      = 7'h04;
    localparam DATA1      = 7'h05;
    localparam DATA2      = 7'h06;
    localparam DATA3      = 7'h07;
    localparam DATA4      = 7'h08;
    localparam DATA5      = 7'h09;
    localparam DATA6      = 7'h0A;
    localparam DATA7      = 7'h0B;
    localparam DATA8      = 7'h0C;
    localparam DATA9      = 7'h0D;
    localparam DATA10     = 7'h0E;
    localparam DATA11     = 7'h0F;

    // Abstract command encoding (per RISC-V Debug Spec 0.13.2)
    localparam CMD_ACC_REG    = 24'h000000; // Access Register
    localparam CMD_ACC_MEM    = 24'h000001; // Access Memory (not implemented)
    localparam CMD_QUICK_ACC  = 24'h000002; // Quick Access (not implemented)

    // Register numbers (GPR: 0x1000-101F, CSR: 0x0000-0FFF)
    localparam GPR_BASE  = 16'h1000;
    localparam CSR_BASE  = 16'h0000;

    reg [31:0] data_regs [0:11];
    reg [31:0] abstractcs;
    reg [23:0] command_reg;
    reg [3:0]  state;
    reg [3:0]  next_state;
    reg [15:0] command_regno;

    localparam S_IDLE       = 4'h0;
    localparam S_DECODE     = 4'h1;
    localparam S_REG_ACCESS = 4'h2;
    localparam S_WAIT_ACK   = 4'h3;
    localparam S_RESPOND    = 4'h4;

    // Abstractcs fields: busy[12], cmderr[10:8], datacount[3:0]=12
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            abstractcs <= 32'h00000C00; // datacount=12, not busy, no error
            command_reg <= 24'h0;
            command_regno <= 16'h0;
            cmd_busy <= 1'b0;
            cmd_err <= 3'b0;
            core_reg_req <= 1'b0;
            core_reg_wr <= 1'b0;
            core_reg_addr <= 16'h0;
            core_reg_wdata <= 32'h0;
            state <= S_IDLE;
            for (integer i = 0; i < 12; i = i + 1) begin
                data_regs[i] <= 32'h0;
            end
        end else begin
            state <= next_state;
            dmi_ack <= dmi_req;

            if (dmi_req && dmi_wr) begin
                case (dmi_addr)
                    COMMAND: begin
                        command_reg <= dmi_wdata[23:0];
                        abstractcs[12] <= 1'b1; // busy
                        cmd_busy <= 1'b1;
                        cmd_err <= 3'b0;
                    end
                    ABSTRACTCS: begin
                        abstractcs <= dmi_wdata;
                        if (dmi_wdata[10:8] == 3'h0) cmd_err <= 3'b0;
                    end
                    DATA0:   data_regs[0]  <= dmi_wdata;
                    DATA1:   data_regs[1]  <= dmi_wdata;
                    DATA2:   data_regs[2]  <= dmi_wdata;
                    DATA3:   data_regs[3]  <= dmi_wdata;
                    DATA4:   data_regs[4]  <= dmi_wdata;
                    DATA5:   data_regs[5]  <= dmi_wdata;
                    DATA6:   data_regs[6]  <= dmi_wdata;
                    DATA7:   data_regs[7]  <= dmi_wdata;
                    DATA8:   data_regs[8]  <= dmi_wdata;
                    DATA9:   data_regs[9]  <= dmi_wdata;
                    DATA10:  data_regs[10] <= dmi_wdata;
                    DATA11:  data_regs[11] <= dmi_wdata;
                    default: ;
                endcase
            end
            
            // DMI reads
            if (dmi_req && !dmi_wr) begin
                case (dmi_addr)
                    ABSTRACTCS: dmi_rdata <= abstractcs;
                    DATA0:      dmi_rdata <= data_regs[0];
                    DATA1:      dmi_rdata <= data_regs[1];
                    DATA2:      dmi_rdata <= data_regs[2];
                    DATA3:      dmi_rdata <= data_regs[3];
                    DATA4:      dmi_rdata <= data_regs[4];
                    DATA5:      dmi_rdata <= data_regs[5];
                    DATA6:      dmi_rdata <= data_regs[6];
                    DATA7:      dmi_rdata <= data_regs[7];
                    DATA8:      dmi_rdata <= data_regs[8];
                    DATA9:      dmi_rdata <= data_regs[9];
                    DATA10:     dmi_rdata <= data_regs[10];
                    DATA11:     dmi_rdata <= data_regs[11];
                    default:    dmi_rdata <= 32'h0;
                endcase
            end

            // Command execution FSM
            // Command execution FSM
            case (state)
                S_IDLE: begin
                    if (dmi_req && dmi_wr && (dmi_addr == COMMAND)) begin
                        next_state <= S_DECODE;
                    end else begin
                        next_state <= S_IDLE;
                    end
                end
                S_DECODE: begin
                    if (command_reg[23:20] == 4'b0000) begin
                        command_regno <= command_reg[15:0];
                        core_reg_req <= 1'b1;
                        core_reg_wr <= command_reg[15];
                        core_reg_addr <= command_reg[15:0];
                        core_reg_wdata <= data_regs[0];
                        next_state <= S_WAIT_ACK;
                    end else begin
                        abstractcs[12] <= 1'b0;
                        abstractcs[10:8] <= 3'b100;
                        cmd_busy <= 1'b0;
                        cmd_err <= 3'b100;
                        next_state <= S_IDLE;
                    end
                end
                S_WAIT_ACK: begin
                    if (core_reg_ack) begin
                        core_reg_req <= 1'b0;
                        if (!command_reg[15]) begin
                            data_regs[0] <= core_reg_rdata;
                        end
                        abstractcs[12] <= 1'b0;
                        cmd_busy <= 1'b0;
                        next_state <= S_IDLE;
                    end else begin
                        next_state <= S_WAIT_ACK;
                    end
                end
                default: next_state <= S_IDLE;
            endcase
        end
    end

endmodule