// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// dm_top.v
// Debug Module top-level integrating all debug submodules
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module dm_top (
    input  wire        clk,
    input  wire        rst_n,
    // DMI interface from DTM
    input  wire        dmi_req,
    input  wire        dmi_wr,
    input  wire [6:0]  dmi_addr,
    input  wire [31:0] dmi_wdata,
    output wire [31:0] dmi_rdata,
    output wire        dmi_ack,
    // Core interface
    input  wire [31:0] core_pc,
    input  wire        core_halted,
    input  wire        core_running,
    input  wire        core_has_reset,
    output wire        dm_halt_req,
    output wire        dm_resume_req,
    output wire        dm_reset_req,
    output wire        dm_ndmreset,
    output wire [15:0] dm_hartsel,
    // Abstract command core register access
    output wire        core_reg_req,
    output wire        core_reg_wr,
    output wire [15:0] core_reg_addr,
    output wire [31:0] core_reg_wdata,
    input  wire [31:0] core_reg_rdata,
    input  wire        core_reg_ack,
    // Program buffer
    output wire [31:0] progbuf0,
    output wire [31:0] progbuf1,
    // Trigger
    output wire        trigger_hit,
    // Debug ROM interface
    output wire [11:0] debug_rom_addr,
    output wire [31:0] debug_rom_instr
);

    // DM register addresses (per RISC-V Debug Spec 0.13.2)
    localparam DMSTATUS     = 7'h04;
    localparam DMCONTROL    = 7'h10;
    localparam HARTINFO     = 7'h11;
    localparam HALTSUM0     = 7'h12;
    localparam ABSTRACTCS   = 7'h16;
    localparam COMMAND      = 7'h17;
    localparam PROGBUF0     = 7'h20;
    localparam PROGBUF1     = 7'h21;
    localparam DATA0        = 7'h04;
    localparam DATA1        = 7'h05;
    localparam DATA2        = 7'h06;
    localparam DATA3        = 7'h07;
    localparam DATA4        = 7'h08;
    localparam DATA5        = 7'h09;
    localparam DATA6        = 7'h0A;
    localparam DATA7        = 7'h0B;
    localparam DATA8        = 7'h0C;
    localparam DATA9        = 7'h0D;
    localparam DATA10       = 7'h0E;
    localparam DATA11       = 7'h0F;
    localparam SBCS         = 7'h38;
    localparam TSELECT      = 7'h00;
    localparam TDATA1_0     = 7'h01;
    localparam TDATA2_0     = 7'h02;
    localparam TDATA1_1     = 7'h03;
    localparam TDATA2_1     = 7'h04;
    localparam TINFO        = 7'h0F;

    // Internal wires from submodules
    wire [31:0] regfile_dmi_rdata;
    wire        regfile_dmi_ack;
    wire [31:0] abstract_dmi_rdata;
    wire        abstract_dmi_ack;
    
    wire [31:0] internal_progbuf0;
    wire [31:0] internal_progbuf1;
    
    // Trigger interface signals
    wire        trigger_treg_wr;
    wire        trigger_treg_rd;
    wire [11:0] trigger_treg_addr;
    wire [31:0] trigger_treg_wdata;
    wire [31:0] trigger_treg_rdata;

    // DMI address decoding for routing
    // NOTE: DMSTATUS (0x04) and DATA0 (0x04) share the same DMI address.
    // Reads to 0x04 always go to regfile (DMSTATUS).
    // Writes to 0x04 go to abstract_cmd (DATA0 for abstract command data).
    // This works because DMSTATUS is read-only and DATA0 is only written during
    // abstract command flows.
    
    wire data0_is_write = (dmi_addr == 7'h04) && dmi_wr;
    
    wire addr_is_regfile = !data0_is_write && (
                           (dmi_addr == DMSTATUS) || 
                           (dmi_addr == DMCONTROL) ||
                           (dmi_addr == HARTINFO) ||
                           (dmi_addr == HALTSUM0) ||
                           (dmi_addr == SBCS) ||
                           (dmi_addr == PROGBUF0) ||
                           (dmi_addr == PROGBUF1));
    
    wire addr_is_abstract = (dmi_addr == ABSTRACTCS) ||
                            (dmi_addr == COMMAND) ||
                            ((dmi_addr >= 7'h04) && (dmi_addr <= 7'h0F));
    
    wire addr_is_trigger = (dmi_addr == TSELECT) ||
                           (dmi_addr == TDATA1_0) ||
                           (dmi_addr == TDATA2_0) ||
                           (dmi_addr == TDATA1_1) ||
                           (dmi_addr == TDATA2_1) ||
                           (dmi_addr == TINFO);

    // DMI response mux
    // Reads: regfile handles DMSTATUS (0x04), abstract handles DATA1-DATA11 (0x05-0x0F)
    wire [31:0] trigger_dmi_rdata;
    assign trigger_dmi_rdata = (dmi_addr == TSELECT) ? trigger_treg_rdata :
                               (dmi_addr == TDATA1_0) ? trigger_treg_rdata :
                               (dmi_addr == TDATA2_0) ? trigger_treg_rdata :
                               (dmi_addr == TDATA1_1) ? trigger_treg_rdata :
                               (dmi_addr == TDATA2_1) ? trigger_treg_rdata :
                               32'h0;
    
    assign dmi_rdata = addr_is_regfile ? regfile_dmi_rdata :
                       addr_is_abstract ? abstract_dmi_rdata :
                       addr_is_trigger ? trigger_dmi_rdata :
                       32'h0;
    
    assign dmi_ack = (addr_is_regfile && regfile_dmi_ack) ||
                     (addr_is_abstract && abstract_dmi_ack) ||
                     (addr_is_trigger && dmi_req);

    // Trigger register write enable
    // Map DM trigger addresses to trigger CSR addresses
    // Both TDATA1_0 and TDATA1_1 map to CSR_TDATA1 (0x7A1) - tselect determines which slot
    wire [11:0] trigger_csr_addr;
    assign trigger_csr_addr = (dmi_addr == TSELECT) ? 12'h7A0 :
                              (dmi_addr == TDATA1_0) ? 12'h7A1 :
                              (dmi_addr == TDATA1_1) ? 12'h7A1 :
                              (dmi_addr == TDATA2_0) ? 12'h7A2 :
                              (dmi_addr == TDATA2_1) ? 12'h7A2 :
                              12'h0;

    assign trigger_treg_wr = dmi_req && dmi_wr && addr_is_trigger;
    assign trigger_treg_rd = dmi_req && !dmi_wr && addr_is_trigger;
    assign trigger_treg_addr = trigger_csr_addr;
    assign trigger_treg_wdata = dmi_wdata;

    // DM Regfile instance - handles DMSTATUS, DMCONTROL, HARTINFO, HALTSUM0, SBCS, PROGBUF*
    dm_regfile u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .dmi_req(dmi_req && addr_is_regfile),
        .dmi_wr(dmi_wr),
        .dmi_addr(dmi_addr),
        .dmi_wdata(dmi_wdata),
        .dmi_rdata(regfile_dmi_rdata),
        .dmi_ack(regfile_dmi_ack),
        .hart_halted(core_halted),
        .hart_running(core_running),
        .hart_has_reset(core_has_reset),
        .dm_halt_req(dm_halt_req),
        .dm_resume_req(dm_resume_req),
        .dm_reset_req(dm_reset_req),
        .dm_ndmreset(dm_ndmreset),
        .dm_hartsel(dm_hartsel),
        .sba_enable()
    );

    // Abstract command instance - handles ABSTRACTCS, COMMAND, DATA0 (write), DATA1-DATA11
    dm_abstract_cmd u_abstract_cmd (
        .clk(clk),
        .rst_n(rst_n),
        .dmi_req(dmi_req && addr_is_abstract),
        .dmi_wr(dmi_wr),
        .dmi_addr(dmi_addr),
        .dmi_wdata(dmi_wdata),
        .dmi_rdata(abstract_dmi_rdata),
        .dmi_ack(abstract_dmi_ack),
        .core_reg_req(core_reg_req),
        .core_reg_wr(core_reg_wr),
        .core_reg_addr(core_reg_addr),
        .core_reg_wdata(core_reg_wdata),
        .core_reg_rdata(core_reg_rdata),
        .core_reg_ack(core_reg_ack),
        .progbuf0(internal_progbuf0),
        .progbuf1(internal_progbuf1),
        .cmd_busy(),
        .cmd_err()
    );

    // Program buffer instance
    dm_progbuf u_progbuf (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(dmi_req && dmi_wr && ((dmi_addr == PROGBUF0) || (dmi_addr == PROGBUF1))),
        .index(dmi_addr[1:0]),
        .wr_data(dmi_wdata),
        .progbuf0(internal_progbuf0),
        .progbuf1(internal_progbuf1)
    );

    assign progbuf0 = internal_progbuf0;
    assign progbuf1 = internal_progbuf1;

    // Trigger module instance
    dm_trigger u_trigger (
        .clk(clk),
        .rst(~rst_n),  // Active-high reset
        .treg_wr(trigger_treg_wr),
        .treg_rd(trigger_treg_rd),
        .treg_addr(trigger_csr_addr),
        .treg_wdata(trigger_treg_wdata),
        .treg_rdata(trigger_treg_rdata),
        .trigger_hit(trigger_hit),
        .if_pc(core_pc),
        .if_valid(core_running)
    );

    // Debug ROM instance
    debug_rom u_debug_rom (
        .clk(clk),
        .addr(debug_rom_addr),
        .instr(debug_rom_instr)
    );

    // Debug ROM address comes from core PC when in debug mode
    assign debug_rom_addr = core_pc[11:0];

endmodule
