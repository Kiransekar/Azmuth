// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// axi_lite_interconnect_v1_1.v
// AXI4-Lite interconnect for Xcew Processor v1.1
// 4 masters, 5 slaves, fixed-priority arbiter
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module axi_lite_interconnect_v1_1 (
    input  wire        aclk,
    input  wire        aresetn,

    // Master 0 (Core)
    input  wire [15:0] m0_awaddr,  input  wire        m0_awvalid, output reg        m0_awready,
    input  wire [31:0] m0_wdata,   input  wire [3:0]  m0_wstrb,   input  wire        m0_wvalid, output reg        m0_wready,
    output reg  [1:0]  m0_bresp,   output reg         m0_bvalid,  input  wire        m0_bready,
    input  wire [15:0] m0_araddr,  input  wire        m0_arvalid, output reg        m0_arready,
    output reg  [31:0] m0_rdata,   output reg  [1:0]  m0_rresp,   output reg        m0_rvalid, input  wire        m0_rready,

    // Master 1 (EML)
    input  wire [15:0] m1_awaddr,  input  wire        m1_awvalid, output reg        m1_awready,
    input  wire [31:0] m1_wdata,   input  wire [3:0]  m1_wstrb,   input  wire        m1_wvalid, output reg        m1_wready,
    output reg  [1:0]  m1_bresp,   output reg         m1_bvalid,  input  wire        m1_bready,
    input  wire [15:0] m1_araddr,  input  wire        m1_arvalid, output reg        m1_arready,
    output reg  [31:0] m1_rdata,   output reg  [1:0]  m1_rresp,   output reg        m1_rvalid, input  wire        m1_rready,

    // Master 2 (SNN)
    input  wire [15:0] m2_awaddr,  input  wire        m2_awvalid, output reg        m2_awready,
    input  wire [31:0] m2_wdata,   input  wire [3:0]  m2_wstrb,   input  wire        m2_wvalid, output reg        m2_wready,
    output reg  [1:0]  m2_bresp,   output reg         m2_bvalid,  input  wire        m2_bready,
    input  wire [15:0] m2_araddr,  input  wire        m2_arvalid, output reg        m2_arready,
    output reg  [31:0] m2_rdata,   output reg  [1:0]  m2_rresp,   output reg        m2_rvalid, input  wire        m2_rready,

    // Master 3 (NVM)
    input  wire [15:0] m3_awaddr,  input  wire        m3_awvalid, output reg        m3_awready,
    input  wire [31:0] m3_wdata,   input  wire [3:0]  m3_wstrb,   input  wire        m3_wvalid, output reg        m3_wready,
    output reg  [1:0]  m3_bresp,   output reg         m3_bvalid,  input  wire        m3_bready,
    input  wire [15:0] m3_araddr,  input  wire        m3_arvalid, output reg        m3_arready,
    output reg  [31:0] m3_rdata,   output reg  [1:0]  m3_rresp,   output reg        m3_rvalid, input  wire        m3_rready,

    // Master 4 (Debug Module SBA)
    input  wire [15:0] m4_awaddr,  input  wire        m4_awvalid, output reg        m4_awready,
    input  wire [31:0] m4_wdata,   input  wire [3:0]  m4_wstrb,   input  wire        m4_wvalid, output reg        m4_wready,
    output reg  [1:0]  m4_bresp,   output reg         m4_bvalid,  input  wire        m4_bready,
    input  wire [15:0] m4_araddr,  input  wire        m4_arvalid, output reg        m4_arready,
    output reg  [31:0] m4_rdata,   output reg  [1:0]  m4_rresp,   output reg        m4_rvalid, input  wire        m4_rready,

    // Slave 0 (Boot ROM)
    output reg  [15:0] s0_awaddr,  output reg         s0_awvalid, input  wire        s0_awready,
    output reg  [31:0] s0_wdata,   output reg  [3:0]  s0_wstrb,   output reg        s0_wvalid, input  wire        s0_wready,
    input  wire  [1:0] s0_bresp,   input  wire        s0_bvalid,  output reg        s0_bready,
    output reg  [15:0] s0_araddr,  output reg         s0_arvalid, input  wire        s0_arready,
    input  wire  [31:0] s0_rdata,  input  wire  [1:0] s0_rresp,   input  wire        s0_rvalid, output reg        s0_rready,

    // Slave 1 (SRAM)
    output reg  [15:0] s1_awaddr,  output reg         s1_awvalid, input  wire        s1_awready,
    output reg  [31:0] s1_wdata,   output reg  [3:0]  s1_wstrb,   output reg        s1_wvalid, input  wire        s1_wready,
    input  wire  [1:0] s1_bresp,   input  wire        s1_bvalid,  output reg        s1_bready,
    output reg  [15:0] s1_araddr,  output reg         s1_arvalid, input  wire        s1_arready,
    input  wire  [31:0] s1_rdata,  input  wire  [1:0] s1_rresp,   input  wire        s1_rvalid, output reg        s1_rready,

    // Slave 2 (EML CSR)
    output reg  [15:0] s2_awaddr,  output reg         s2_awvalid, input  wire        s2_awready,
    output reg  [31:0] s2_wdata,   output reg  [3:0]  s2_wstrb,   output reg        s2_wvalid, input  wire        s2_wready,
    input  wire  [1:0] s2_bresp,   input  wire        s2_bvalid,  output reg        s2_bready,
    output reg  [15:0] s2_araddr,  output reg         s2_arvalid, input  wire        s2_arready,
    input  wire  [31:0] s2_rdata,  input  wire  [1:0] s2_rresp,   input  wire        s2_rvalid, output reg        s2_rready,

    // Slave 3 (SNN CSR)
    output reg  [15:0] s3_awaddr,  output reg         s3_awvalid, input  wire        s3_awready,
    output reg  [31:0] s3_wdata,   output reg  [3:0]  s3_wstrb,   output reg        s3_wvalid, input  wire        s3_wready,
    input  wire  [1:0] s3_bresp,   input  wire        s3_bvalid,  output reg        s3_bready,
    output reg  [15:0] s3_araddr,  output reg         s3_arvalid, input  wire        s3_arready,
    input  wire  [31:0] s3_rdata,  input  wire  [1:0] s3_rresp,   input  wire        s3_rvalid, output reg        s3_rready,

    // Slave 4 (NVM CSR)
    output reg  [15:0] s4_awaddr,  output reg         s4_awvalid, input  wire        s4_awready,
    output reg  [31:0] s4_wdata,   output reg  [3:0]  s4_wstrb,   output reg        s4_wvalid, input  wire        s4_wready,
    input  wire  [1:0] s4_bresp,   input  wire        s4_bvalid,  output reg        s4_bready,
    output reg  [15:0] s4_araddr,  output reg         s4_arvalid, input  wire        s4_arready,
    input  wire  [31:0] s4_rdata,  input  wire  [1:0] s4_rresp,   input  wire        s4_rvalid, output reg        s4_rready,

    // Slave 5 (Debug Module CSR)
    output reg  [15:0] s5_awaddr,  output reg         s5_awvalid, input  wire        s5_awready,
    output reg  [31:0] s5_wdata,   output reg  [3:0]  s5_wstrb,   output reg        s5_wvalid, input  wire        s5_wready,
    input  wire  [1:0] s5_bresp,   input  wire        s5_bvalid,  output reg        s5_bready,
    output reg  [15:0] s5_araddr,  output reg         s5_arvalid, input  wire        s5_arready,
    input  wire  [31:0] s5_rdata,  input  wire  [1:0] s5_rresp,   input  wire        s5_rvalid, output reg        s5_rready
);

    wire rst = ~aresetn;

    // Address map
    parameter [15:0] ROM_BASE  = 16'h0000, ROM_END  = 16'h0FFF;
    parameter [15:0] SRAM_BASE = 16'h1000, SRAM_END = 16'h1FFF;
    parameter [15:0] EML_BASE  = 16'h2000, EML_END  = 16'h20FF;
    parameter [15:0] SNN_BASE  = 16'h2100, SNN_END  = 16'h21FF;
    parameter [15:0] NVM_BASE  = 16'h2200, NVM_END  = 16'h22FF;
    parameter [15:0] DM_BASE   = 16'h5000, DM_END   = 16'h5FFF;

    // Slave one-hot (6 slaves now with Debug Module)
    parameter [5:0] SLAVE_ROM  = 6'b000001, SLAVE_SRAM = 6'b000010;
    parameter [5:0] SLAVE_EML  = 6'b000100, SLAVE_SNN  = 6'b001000;
    parameter [5:0] SLAVE_NVM  = 6'b010000, SLAVE_DM   = 6'b100000;

    // ==================== Address Decoder ====================
    reg [5:0] m0_aw_slave, m0_ar_slave, m1_aw_slave, m1_ar_slave;
    reg [5:0] m2_aw_slave, m2_ar_slave, m3_aw_slave, m3_ar_slave;
    reg [5:0] m4_aw_slave, m4_ar_slave;

    always @(*) begin
        if      (m0_awaddr <= ROM_END)  m0_aw_slave = SLAVE_ROM;
        else if (m0_awaddr >= SRAM_BASE && m0_awaddr <= SRAM_END) m0_aw_slave = SLAVE_SRAM;
        else if (m0_awaddr >= EML_BASE  && m0_awaddr <= EML_END)  m0_aw_slave = SLAVE_EML;
        else if (m0_awaddr >= SNN_BASE  && m0_awaddr <= SNN_END)  m0_aw_slave = SLAVE_SNN;
        else if (m0_awaddr >= NVM_BASE  && m0_awaddr <= NVM_END)  m0_aw_slave = SLAVE_NVM;
        else                                                       m0_aw_slave = 6'h0;
    end
    always @(*) begin
        if      (m0_araddr <= ROM_END)  m0_ar_slave = SLAVE_ROM;
        else if (m0_araddr >= SRAM_BASE && m0_araddr <= SRAM_END) m0_ar_slave = SLAVE_SRAM;
        else if (m0_araddr >= EML_BASE  && m0_araddr <= EML_END)  m0_ar_slave = SLAVE_EML;
        else if (m0_araddr >= SNN_BASE  && m0_araddr <= SNN_END)  m0_ar_slave = SLAVE_SNN;
        else if (m0_araddr >= NVM_BASE  && m0_araddr <= NVM_END)  m0_ar_slave = SLAVE_NVM;
        else                                                       m0_ar_slave = 6'h0;
    end
    always @(*) begin
        if      (m1_awaddr <= ROM_END)  m1_aw_slave = SLAVE_ROM;
        else if (m1_awaddr >= SRAM_BASE && m1_awaddr <= SRAM_END) m1_aw_slave = SLAVE_SRAM;
        else if (m1_awaddr >= EML_BASE  && m1_awaddr <= EML_END)  m1_aw_slave = SLAVE_EML;
        else if (m1_awaddr >= SNN_BASE  && m1_awaddr <= SNN_END)  m1_aw_slave = SLAVE_SNN;
        else if (m1_awaddr >= NVM_BASE  && m1_awaddr <= NVM_END)  m1_aw_slave = SLAVE_NVM;
        else                                                       m1_aw_slave = 6'h0;
    end
    always @(*) begin
        if      (m1_araddr <= ROM_END)  m1_ar_slave = SLAVE_ROM;
        else if (m1_araddr >= SRAM_BASE && m1_araddr <= SRAM_END) m1_ar_slave = SLAVE_SRAM;
        else if (m1_araddr >= EML_BASE  && m1_araddr <= EML_END)  m1_ar_slave = SLAVE_EML;
        else if (m1_araddr >= SNN_BASE  && m1_araddr <= SNN_END)  m1_ar_slave = SLAVE_SNN;
        else if (m1_araddr >= NVM_BASE  && m1_araddr <= NVM_END)  m1_ar_slave = SLAVE_NVM;
        else                                                       m1_ar_slave = 6'h0;
    end
    always @(*) begin
        if      (m2_awaddr <= ROM_END)  m2_aw_slave = SLAVE_ROM;
        else if (m2_awaddr >= SRAM_BASE && m2_awaddr <= SRAM_END) m2_aw_slave = SLAVE_SRAM;
        else if (m2_awaddr >= EML_BASE  && m2_awaddr <= EML_END)  m2_aw_slave = SLAVE_EML;
        else if (m2_awaddr >= SNN_BASE  && m2_awaddr <= SNN_END)  m2_aw_slave = SLAVE_SNN;
        else if (m2_awaddr >= NVM_BASE  && m2_awaddr <= NVM_END)  m2_aw_slave = SLAVE_NVM;
        else                                                       m2_aw_slave = 6'h0;
    end
    always @(*) begin
        if      (m2_araddr <= ROM_END)  m2_ar_slave = SLAVE_ROM;
        else if (m2_araddr >= SRAM_BASE && m2_araddr <= SRAM_END) m2_ar_slave = SLAVE_SRAM;
        else if (m2_araddr >= EML_BASE  && m2_araddr <= EML_END)  m2_ar_slave = SLAVE_EML;
        else if (m2_araddr >= SNN_BASE  && m2_araddr <= SNN_END)  m2_ar_slave = SLAVE_SNN;
        else if (m2_araddr >= NVM_BASE  && m2_araddr <= NVM_END)  m2_ar_slave = SLAVE_NVM;
        else                                                       m2_ar_slave = 6'h0;
    end
    always @(*) begin
        if      (m3_awaddr <= ROM_END)  m3_aw_slave = SLAVE_ROM;
        else if (m3_awaddr >= SRAM_BASE && m3_awaddr <= SRAM_END) m3_aw_slave = SLAVE_SRAM;
        else if (m3_awaddr >= EML_BASE  && m3_awaddr <= EML_END)  m3_aw_slave = SLAVE_EML;
        else if (m3_awaddr >= SNN_BASE  && m3_awaddr <= SNN_END)  m3_aw_slave = SLAVE_SNN;
        else if (m3_awaddr >= NVM_BASE  && m3_awaddr <= NVM_END)  m3_aw_slave = SLAVE_NVM;
        else if (m3_awaddr >= DM_BASE   && m3_awaddr <= DM_END)   m3_aw_slave = SLAVE_DM;
        else                                                       m3_aw_slave = 6'h0;
    end
    always @(*) begin
        if      (m3_araddr <= ROM_END)  m3_ar_slave = SLAVE_ROM;
        else if (m3_araddr >= SRAM_BASE && m3_araddr <= SRAM_END) m3_ar_slave = SLAVE_SRAM;
        else if (m3_araddr >= EML_BASE  && m3_araddr <= EML_END)  m3_ar_slave = SLAVE_EML;
        else if (m3_araddr >= SNN_BASE  && m3_araddr <= SNN_END)  m3_ar_slave = SLAVE_SNN;
        else if (m3_araddr >= NVM_BASE  && m3_araddr <= NVM_END)  m3_ar_slave = SLAVE_NVM;
        else if (m3_araddr >= DM_BASE   && m3_araddr <= DM_END)   m3_ar_slave = SLAVE_DM;
        else                                                       m3_ar_slave = 6'h0;
    end

    // Master 4 (Debug Module SBA) address decoder
    always @(*) begin
        if      (m4_awaddr <= ROM_END)  m4_aw_slave = SLAVE_ROM;
        else if (m4_awaddr >= SRAM_BASE && m4_awaddr <= SRAM_END) m4_aw_slave = SLAVE_SRAM;
        else if (m4_awaddr >= EML_BASE  && m4_awaddr <= EML_END)  m4_aw_slave = SLAVE_EML;
        else if (m4_awaddr >= SNN_BASE  && m4_awaddr <= SNN_END)  m4_aw_slave = SLAVE_SNN;
        else if (m4_awaddr >= NVM_BASE  && m4_awaddr <= NVM_END)  m4_aw_slave = SLAVE_NVM;
        else if (m4_awaddr >= DM_BASE   && m4_awaddr <= DM_END)   m4_aw_slave = SLAVE_DM;
        else                                                       m4_aw_slave = 6'h0;
    end
    always @(*) begin
        if      (m4_araddr <= ROM_END)  m4_ar_slave = SLAVE_ROM;
        else if (m4_araddr >= SRAM_BASE && m4_araddr <= SRAM_END) m4_ar_slave = SLAVE_SRAM;
        else if (m4_araddr >= EML_BASE  && m4_araddr <= EML_END)  m4_ar_slave = SLAVE_EML;
        else if (m4_araddr >= SNN_BASE  && m4_araddr <= SNN_END)  m4_ar_slave = SLAVE_SNN;
        else if (m4_araddr >= NVM_BASE  && m4_araddr <= NVM_END)  m4_ar_slave = SLAVE_NVM;
        else if (m4_araddr >= DM_BASE   && m4_araddr <= DM_END)   m4_ar_slave = SLAVE_DM;
        else                                                       m4_ar_slave = 6'h0;
    end

    // ==================== Arbiter ====================
    wire [4:0] aw_req = {m4_awvalid, m3_awvalid, m2_awvalid, m1_awvalid, m0_awvalid};
    wire [4:0] ar_req = {m4_arvalid, m3_arvalid, m2_arvalid, m1_arvalid, m0_arvalid};
    // Fixed-priority arbiter (master 0 = highest)
    reg [5:0] aw_select, ar_select;
    wire [2:0] w_select = aw_select[2:0];
    wire [2:0] r_select = ar_select[2:0];

    always @(*) begin
        if (aw_req[0])      aw_select = 6'b000001;
        else if (aw_req[1])  aw_select = 6'b000010;
        else if (aw_req[2])  aw_select = 6'b000100;
        else if (aw_req[3])  aw_select = 6'b001000;
        else if (aw_req[4])  aw_select = 6'b010000;
        else                 aw_select = 5'b00000;
    end
    always @(*) begin
        if (ar_req[0])      ar_select = 6'b000001;
        else if (ar_req[1])  ar_select = 6'b000010;
        else if (ar_req[2])  ar_select = 6'b000100;
        else if (ar_req[3])  ar_select = 6'b001000;
        else if (ar_req[4])  ar_select = 6'b010000;
        else                 ar_select = 5'b00000;
    end

    // ==================== Slave Output Mux ====================
    // One always block per slave: drives AW/W/AR channels
    // All slave outputs are 'output reg', legally driven from always @(*)

    // Slave 0 (ROM)
    always @(*) begin
        if (aw_select == 6'b000001) begin
            s0_awaddr  = m0_awaddr;  s0_awvalid = m0_awvalid;
        end else if (aw_select == 6'b000010) begin
            s0_awaddr  = m1_awaddr;  s0_awvalid = m1_awvalid;
        end else if (aw_select == 6'b000100) begin
            s0_awaddr  = m2_awaddr;  s0_awvalid = m2_awvalid;
        end else if (aw_select == 6'b001000) begin
            s0_awaddr  = m3_awaddr;  s0_awvalid = m3_awvalid;
        end else if (aw_select == 6'b010000) begin
            s0_awaddr  = m4_awaddr;  s0_awvalid = m4_awvalid;
        end else begin
            s0_awaddr  = 16'h0;  s0_awvalid = 1'b0;
        end
        if (w_select == 3'b001) begin
            s0_wdata  = m0_wdata;  s0_wstrb  = m0_wstrb;  s0_wvalid = m0_wvalid;
        end else if (w_select == 3'b010) begin
            s0_wdata  = m1_wdata;  s0_wstrb  = m1_wstrb;  s0_wvalid = m1_wvalid;
        end else if (w_select == 3'b011) begin
            s0_wdata  = m2_wdata;  s0_wstrb  = m2_wstrb;  s0_wvalid = m2_wvalid;
        end else if (w_select == 3'b100) begin
            s0_wdata  = m3_wdata;  s0_wstrb  = m3_wstrb;  s0_wvalid = m3_wvalid;
        end else if (w_select == 3'b101) begin
            s0_wdata  = m4_wdata;  s0_wstrb  = m4_wstrb;  s0_wvalid = m4_wvalid;
        end else begin
            s0_wdata  = 32'h0;  s0_wstrb  = 4'h0;  s0_wvalid = 1'b0;
        end
        if (ar_select == 6'b000001) begin
            s0_araddr  = m0_araddr;  s0_arvalid = m0_arvalid;
        end else if (ar_select == 6'b000010) begin
            s0_araddr  = m1_araddr;  s0_arvalid = m1_arvalid;
        end else if (ar_select == 6'b000100) begin
            s0_araddr  = m2_araddr;  s0_arvalid = m2_arvalid;
        end else if (ar_select == 6'b001000) begin
            s0_araddr  = m3_araddr;  s0_arvalid = m3_arvalid;
        end else if (ar_select == 6'b010000) begin
            s0_araddr  = m4_araddr;  s0_arvalid = m4_arvalid;
        end else begin
            s0_araddr  = 16'h0;  s0_arvalid = 1'b0;
        end
    end

    // Slave 1 (SRAM)
    always @(*) begin
        if (aw_select == 6'b000001 && m0_aw_slave == SLAVE_SRAM) begin
            s1_awaddr  = m0_awaddr;  s1_awvalid = m0_awvalid;
        end else if (aw_select == 6'b000010 && m1_aw_slave == SLAVE_SRAM) begin
            s1_awaddr  = m1_awaddr;  s1_awvalid = m1_awvalid;
        end else if (aw_select == 6'b000100 && m2_aw_slave == SLAVE_SRAM) begin
            s1_awaddr  = m2_awaddr;  s1_awvalid = m2_awvalid;
        end else if (aw_select == 6'b001000 && m3_aw_slave == SLAVE_SRAM) begin
            s1_awaddr  = m3_awaddr;  s1_awvalid = m3_awvalid;
        end else if (aw_select == 6'b010000 && m4_aw_slave == SLAVE_SRAM) begin
            s1_awaddr  = m4_awaddr;  s1_awvalid = m4_awvalid;
        end else begin
            s1_awaddr  = 16'h0;  s1_awvalid = 1'b0;
        end
        if (w_select == 3'b001 && m0_aw_slave == SLAVE_SRAM) begin
            s1_wdata  = m0_wdata;  s1_wstrb  = m0_wstrb;  s1_wvalid = m0_wvalid;
        end else if (w_select == 3'b010 && m1_aw_slave == SLAVE_SRAM) begin
            s1_wdata  = m1_wdata;  s1_wstrb  = m1_wstrb;  s1_wvalid = m1_wvalid;
        end else if (w_select == 3'b011 && m2_aw_slave == SLAVE_SRAM) begin
            s1_wdata  = m2_wdata;  s1_wstrb  = m2_wstrb;  s1_wvalid = m2_wvalid;
        end else if (w_select == 3'b100 && m3_aw_slave == SLAVE_SRAM) begin
            s1_wdata  = m3_wdata;  s1_wstrb  = m3_wstrb;  s1_wvalid = m3_wvalid;
        end else if (w_select == 3'b101 && m4_aw_slave == SLAVE_SRAM) begin
            s1_wdata  = m4_wdata;  s1_wstrb  = m4_wstrb;  s1_wvalid = m4_wvalid;
        end else begin
            s1_wdata  = 32'h0;  s1_wstrb  = 4'h0;  s1_wvalid = 1'b0;
        end
        if (ar_select == 6'b000001 && m0_ar_slave == SLAVE_SRAM) begin
            s1_araddr  = m0_araddr;  s1_arvalid = m0_arvalid;
        end else if (ar_select == 6'b000010 && m1_ar_slave == SLAVE_SRAM) begin
            s1_araddr  = m1_araddr;  s1_arvalid = m1_arvalid;
        end else if (ar_select == 6'b000100 && m2_ar_slave == SLAVE_SRAM) begin
            s1_araddr  = m2_araddr;  s1_arvalid = m2_arvalid;
        end else if (ar_select == 6'b001000 && m3_ar_slave == SLAVE_SRAM) begin
            s1_araddr  = m3_araddr;  s1_arvalid = m3_arvalid;
        end else if (ar_select == 6'b010000 && m4_ar_slave == SLAVE_SRAM) begin
            s1_araddr  = m4_araddr;  s1_arvalid = m4_arvalid;
        end else begin
            s1_araddr  = 16'h0;  s1_arvalid = 1'b0;
        end
    end

    // Slave 2 (EML)
    always @(*) begin
        if (aw_select == 6'b000001 && m0_aw_slave == SLAVE_EML) begin
            s2_awaddr  = m0_awaddr;  s2_awvalid = m0_awvalid;
        end else if (aw_select == 6'b000010 && m1_aw_slave == SLAVE_EML) begin
            s2_awaddr  = m1_awaddr;  s2_awvalid = m1_awvalid;
        end else if (aw_select == 6'b000100 && m2_aw_slave == SLAVE_EML) begin
            s2_awaddr  = m2_awaddr;  s2_awvalid = m2_awvalid;
        end else if (aw_select == 6'b001000 && m3_aw_slave == SLAVE_EML) begin
            s2_awaddr  = m3_awaddr;  s2_awvalid = m3_awvalid;
        end else if (aw_select == 6'b010000 && m4_aw_slave == SLAVE_EML) begin
            s2_awaddr  = m4_awaddr;  s2_awvalid = m4_awvalid;
        end else begin
            s2_awaddr  = 16'h0;  s2_awvalid = 1'b0;
        end
        if (w_select == 3'b001 && m0_aw_slave == SLAVE_EML) begin
            s2_wdata  = m0_wdata;  s2_wstrb  = m0_wstrb;  s2_wvalid = m0_wvalid;
        end else if (w_select == 3'b010 && m1_aw_slave == SLAVE_EML) begin
            s2_wdata  = m1_wdata;  s2_wstrb  = m1_wstrb;  s2_wvalid = m1_wvalid;
        end else if (w_select == 3'b011 && m2_aw_slave == SLAVE_EML) begin
            s2_wdata  = m2_wdata;  s2_wstrb  = m2_wstrb;  s2_wvalid = m2_wvalid;
        end else if (w_select == 3'b100 && m3_aw_slave == SLAVE_EML) begin
            s2_wdata  = m3_wdata;  s2_wstrb  = m3_wstrb;  s2_wvalid = m3_wvalid;
        end else if (w_select == 3'b101 && m4_aw_slave == SLAVE_EML) begin
            s2_wdata  = m4_wdata;  s2_wstrb  = m4_wstrb;  s2_wvalid = m4_wvalid;
        end else begin
            s2_wdata  = 32'h0;  s2_wstrb  = 4'h0;  s2_wvalid = 1'b0;
        end
        if (ar_select == 6'b000001 && m0_ar_slave == SLAVE_EML) begin
            s2_araddr  = m0_araddr;  s2_arvalid = m0_arvalid;
        end else if (ar_select == 6'b000010 && m1_ar_slave == SLAVE_EML) begin
            s2_araddr  = m1_araddr;  s2_arvalid = m1_arvalid;
        end else if (ar_select == 6'b000100 && m2_ar_slave == SLAVE_EML) begin
            s2_araddr  = m2_araddr;  s2_arvalid = m2_arvalid;
        end else if (ar_select == 6'b001000 && m3_ar_slave == SLAVE_EML) begin
            s2_araddr  = m3_araddr;  s2_arvalid = m3_arvalid;
        end else if (ar_select == 6'b010000 && m4_ar_slave == SLAVE_EML) begin
            s2_araddr  = m4_araddr;  s2_arvalid = m4_arvalid;
        end else begin
            s2_araddr  = 16'h0;  s2_arvalid = 1'b0;
        end
    end

    // Slave 3 (SNN)
    always @(*) begin
        if (aw_select == 4'b0001 && m0_aw_slave == SLAVE_SNN) begin
            s3_awaddr  = m0_awaddr;  s3_awvalid = m0_awvalid;
        end else if (aw_select == 4'b0010 && m1_aw_slave == SLAVE_SNN) begin
            s3_awaddr  = m1_awaddr;  s3_awvalid = m1_awvalid;
        end else if (aw_select == 4'b0100 && m2_aw_slave == SLAVE_SNN) begin
            s3_awaddr  = m2_awaddr;  s3_awvalid = m2_awvalid;
        end else if (aw_select == 4'b1000 && m3_aw_slave == SLAVE_SNN) begin
            s3_awaddr  = m3_awaddr;  s3_awvalid = m3_awvalid;
        end else begin
            s3_awaddr  = 16'h0;  s3_awvalid = 1'b0;
        end
        if (w_select == 2'b01 && m0_aw_slave == SLAVE_SNN) begin
            s3_wdata  = m0_wdata;  s3_wstrb  = m0_wstrb;  s3_wvalid = m0_wvalid;
        end else if (w_select == 2'b10 && m1_aw_slave == SLAVE_SNN) begin
            s3_wdata  = m1_wdata;  s3_wstrb  = m1_wstrb;  s3_wvalid = m1_wvalid;
        end else if (m2_aw_slave == SLAVE_SNN) begin
            s3_wdata  = m2_wdata;  s3_wstrb  = m2_wstrb;  s3_wvalid = m2_wvalid;
        end else if (m3_aw_slave == SLAVE_SNN) begin
            s3_wdata  = m3_wdata;  s3_wstrb  = m3_wstrb;  s3_wvalid = m3_wvalid;
        end else begin
            s3_wdata  = 32'h0;  s3_wstrb  = 4'h0;  s3_wvalid = 1'b0;
        end
        if (ar_select == 4'b0001 && m0_ar_slave == SLAVE_SNN) begin
            s3_araddr  = m0_araddr;  s3_arvalid = m0_arvalid;
        end else if (ar_select == 4'b0010 && m1_ar_slave == SLAVE_SNN) begin
            s3_araddr  = m1_araddr;  s3_arvalid = m1_arvalid;
        end else if (ar_select == 4'b0100 && m2_ar_slave == SLAVE_SNN) begin
            s3_araddr  = m2_araddr;  s3_arvalid = m2_arvalid;
        end else if (ar_select == 4'b1000 && m3_ar_slave == SLAVE_SNN) begin
            s3_araddr  = m3_araddr;  s3_arvalid = m3_arvalid;
        end else begin
            s3_araddr  = 16'h0;  s3_arvalid = 1'b0;
        end
    end

    // Slave 4 (NVM)
    always @(*) begin
        if (aw_select == 4'b0001 && m0_aw_slave == SLAVE_NVM) begin
            s4_awaddr  = m0_awaddr;  s4_awvalid = m0_awvalid;
        end else if (aw_select == 4'b0010 && m1_aw_slave == SLAVE_NVM) begin
            s4_awaddr  = m1_awaddr;  s4_awvalid = m1_awvalid;
        end else if (aw_select == 4'b0100 && m2_aw_slave == SLAVE_NVM) begin
            s4_awaddr  = m2_awaddr;  s4_awvalid = m2_awvalid;
        end else if (aw_select == 4'b1000 && m3_aw_slave == SLAVE_NVM) begin
            s4_awaddr  = m3_awaddr;  s4_awvalid = m3_awvalid;
        end else begin
            s4_awaddr  = 16'h0;  s4_awvalid = 1'b0;
        end
        if (w_select == 2'b01 && m0_aw_slave == SLAVE_NVM) begin
            s4_wdata  = m0_wdata;  s4_wstrb  = m0_wstrb;  s4_wvalid = m0_wvalid;
        end else if (w_select == 2'b10 && m1_aw_slave == SLAVE_NVM) begin
            s4_wdata  = m1_wdata;  s4_wstrb  = m1_wstrb;  s4_wvalid = m1_wvalid;
        end else if (m2_aw_slave == SLAVE_NVM) begin
            s4_wdata  = m2_wdata;  s4_wstrb  = m2_wstrb;  s4_wvalid = m2_wvalid;
        end else if (m3_aw_slave == SLAVE_NVM) begin
            s4_wdata  = m3_wdata;  s4_wstrb  = m3_wstrb;  s4_wvalid = m3_wvalid;
        end else begin
            s4_wdata  = 32'h0;  s4_wstrb  = 4'h0;  s4_wvalid = 1'b0;
        end
        if (ar_select == 4'b0001 && m0_ar_slave == SLAVE_NVM) begin
            s4_araddr  = m0_araddr;  s4_arvalid = m0_arvalid;
        end else if (ar_select == 4'b0010 && m1_ar_slave == SLAVE_NVM) begin
            s4_araddr  = m1_araddr;  s4_arvalid = m1_arvalid;
        end else if (ar_select == 4'b0100 && m2_ar_slave == SLAVE_NVM) begin
            s4_araddr  = m2_araddr;  s4_arvalid = m2_arvalid;
        end else if (ar_select == 4'b1000 && m3_ar_slave == SLAVE_NVM) begin
            s4_araddr  = m3_araddr;  s4_arvalid = m3_arvalid;
        end else begin
            s4_araddr  = 16'h0;  s4_arvalid = 1'b0;
        end
    end

    // ==================== Ready Signal Logic ====================
    always @(*) begin
        m0_awready = (s0_awready & (m0_aw_slave == SLAVE_ROM))  |
                      (s1_awready & (m0_aw_slave == SLAVE_SRAM)) |
                      (s2_awready & (m0_aw_slave == SLAVE_EML))  |
                      (s3_awready & (m0_aw_slave == SLAVE_SNN))  |
                      (s4_awready & (m0_aw_slave == SLAVE_NVM));
        m1_awready = (s0_awready & (m1_aw_slave == SLAVE_ROM))  |
                      (s1_awready & (m1_aw_slave == SLAVE_SRAM)) |
                      (s2_awready & (m1_aw_slave == SLAVE_EML))  |
                      (s3_awready & (m1_aw_slave == SLAVE_SNN))  |
                      (s4_awready & (m1_aw_slave == SLAVE_NVM));
        m2_awready = (s0_awready & (m2_aw_slave == SLAVE_ROM))  |
                      (s1_awready & (m2_aw_slave == SLAVE_SRAM)) |
                      (s2_awready & (m2_aw_slave == SLAVE_EML))  |
                      (s3_awready & (m2_aw_slave == SLAVE_SNN))  |
                      (s4_awready & (m2_aw_slave == SLAVE_NVM));
        m3_awready = (s0_awready & (m3_aw_slave == SLAVE_ROM))  |
                      (s1_awready & (m3_aw_slave == SLAVE_SRAM)) |
                      (s2_awready & (m3_aw_slave == SLAVE_EML))  |
                      (s3_awready & (m3_aw_slave == SLAVE_SNN))  |
                      (s4_awready & (m3_aw_slave == SLAVE_NVM));

        m0_wready = (s0_wready & (m0_aw_slave == SLAVE_ROM))  |
                     (s1_wready & (m0_aw_slave == SLAVE_SRAM)) |
                     (s2_wready & (m0_aw_slave == SLAVE_EML))  |
                     (s3_wready & (m0_aw_slave == SLAVE_SNN))  |
                     (s4_wready & (m0_aw_slave == SLAVE_NVM));
        m1_wready = (s0_wready & (m1_aw_slave == SLAVE_ROM))  |
                     (s1_wready & (m1_aw_slave == SLAVE_SRAM)) |
                     (s2_wready & (m1_aw_slave == SLAVE_EML))  |
                     (s3_wready & (m1_aw_slave == SLAVE_SNN))  |
                     (s4_wready & (m1_aw_slave == SLAVE_NVM));
        m2_wready = (s0_wready & (m2_aw_slave == SLAVE_ROM))  |
                     (s1_wready & (m2_aw_slave == SLAVE_SRAM)) |
                     (s2_wready & (m2_aw_slave == SLAVE_EML))  |
                     (s3_wready & (m2_aw_slave == SLAVE_SNN))  |
                     (s4_wready & (m2_aw_slave == SLAVE_NVM));
        m3_wready = (s0_wready & (m3_aw_slave == SLAVE_ROM))  |
                     (s1_wready & (m3_aw_slave == SLAVE_SRAM)) |
                     (s2_wready & (m3_aw_slave == SLAVE_EML))  |
                     (s3_wready & (m3_aw_slave == SLAVE_SNN))  |
                     (s4_wready & (m3_aw_slave == SLAVE_NVM));

        m0_arready = (s0_arready & (m0_ar_slave == SLAVE_ROM))  |
                      (s1_arready & (m0_ar_slave == SLAVE_SRAM)) |
                      (s2_arready & (m0_ar_slave == SLAVE_EML))  |
                      (s3_arready & (m0_ar_slave == SLAVE_SNN))  |
                      (s4_arready & (m0_ar_slave == SLAVE_NVM));
        m1_arready = (s1_arready & (m1_ar_slave == SLAVE_SRAM)) |
                      (s2_arready & (m1_ar_slave == SLAVE_EML))  |
                      (s3_arready & (m1_ar_slave == SLAVE_SNN))  |
                      (s4_arready & (m1_ar_slave == SLAVE_NVM));
        m2_arready = (s1_arready & (m2_ar_slave == SLAVE_SRAM)) |
                      (s2_arready & (m2_ar_slave == SLAVE_EML))  |
                      (s3_arready & (m2_ar_slave == SLAVE_SNN))  |
                      (s4_arready & (m2_ar_slave == SLAVE_NVM));
        m3_arready = (s1_arready & (m3_ar_slave == SLAVE_SRAM)) |
                      (s2_arready & (m3_ar_slave == SLAVE_EML))  |
                      (s3_arready & (m3_ar_slave == SLAVE_SNN))  |
                      (s4_arready & (m3_ar_slave == SLAVE_NVM));

        // Slave bready/rready routing - use single driver per slave
        s0_bready = m0_bready & aw_select[0] | m1_bready & aw_select[1] |
                     m2_bready & aw_select[2] | m3_bready & aw_select[3];
        s0_rready = m0_rready & ar_select[0] | m1_rready & ar_select[1] |
                     m2_rready & ar_select[2] | m3_rready & ar_select[3];
        s1_bready = m0_bready & aw_select[0] | m1_bready & aw_select[1] |
                     m2_bready & aw_select[2] | m3_bready & aw_select[3];
        s1_rready = m0_rready & ar_select[0] | m1_rready & ar_select[1] |
                     m2_rready & ar_select[2] | m3_rready & ar_select[3];
        s2_bready = m0_bready & aw_select[0] | m1_bready & aw_select[1] |
                     m2_bready & aw_select[2] | m3_bready & aw_select[3];
        s2_rready = m0_rready & ar_select[0] | m1_rready & ar_select[1] |
                     m2_rready & ar_select[2] | m3_rready & ar_select[3];
        s3_bready = m0_bready & aw_select[0] | m1_bready & aw_select[1] |
                     m2_bready & aw_select[2] | m3_bready & aw_select[3];
        s3_rready = m0_rready & ar_select[0] | m1_rready & ar_select[1] |
                     m2_rready & ar_select[2] | m3_rready & ar_select[3];
        s4_bready = m0_bready & aw_select[0] | m1_bready & aw_select[1] |
                     m2_bready & aw_select[2] | m3_bready & aw_select[3];
        s4_rready = m0_rready & ar_select[0] | m1_rready & ar_select[1] |
                     m2_rready & ar_select[2] | m3_rready & ar_select[3];
    end

    // ==================== Response Tracking ====================
    reg [3:0] aw_grant_master, ar_grant_master;

    always @(posedge aclk or posedge rst) begin
        if (rst) begin
            aw_grant_master <= 4'h0;
            ar_grant_master <= 4'h0;
        end else begin
            if (m0_awvalid & aw_select[0]) aw_grant_master <= 4'b0001;
            else if (m1_awvalid & aw_select[1]) aw_grant_master <= 4'b0010;
            else if (m2_awvalid & aw_select[2]) aw_grant_master <= 4'b0100;
            else if (m3_awvalid & aw_select[3]) aw_grant_master <= 4'b1000;

            if (m0_arvalid & ar_select[0]) ar_grant_master <= 4'b0001;
            else if (m1_arvalid & ar_select[1]) ar_grant_master <= 4'b0010;
            else if (m2_arvalid & ar_select[2]) ar_grant_master <= 4'b0100;
            else if (m3_arvalid & ar_select[3]) ar_grant_master <= 4'b1000;
        end
    end

    // ==================== Master Response Mux ====================
    always @(*) begin
        // Initialize all masters to default values
        m0_bresp = 2'b00;
        m0_bvalid = 1'b0;
        m1_bresp = 2'b00;
        m1_bvalid = 1'b0;
        m2_bresp = 2'b00;
        m2_bvalid = 1'b0;
        m3_bresp = 2'b00;
        m3_bvalid = 1'b0;

        // Then assign based on grant master for write responses
        case (aw_grant_master)
            4'b0001: begin m0_bresp = s0_bresp;  m0_bvalid = s0_bvalid; end
            4'b0010: begin m1_bresp = s0_bresp;  m1_bvalid = s0_bvalid; end
            4'b0100: begin m2_bresp = s0_bresp;  m2_bvalid = s0_bvalid; end
            4'b1000: begin m3_bresp = s0_bresp;  m3_bvalid = s0_bvalid; end
            default: ; // Already initialized to default values
        endcase
    end

    always @(*) begin
        // Initialize all masters to default values
        m0_rdata = 32'h0;
        m0_rresp = 2'b00;
        m0_rvalid = 1'b0;
        m1_rdata = 32'h0;
        m1_rresp = 2'b00;
        m1_rvalid = 1'b0;
        m2_rdata = 32'h0;
        m2_rresp = 2'b00;
        m2_rvalid = 1'b0;
        m3_rdata = 32'h0;
        m3_rresp = 2'b00;
        m3_rvalid = 1'b0;

        // Then assign based on grant master for read responses
        case (ar_grant_master)
            4'b0001: begin m0_rdata = s0_rdata;  m0_rresp = s0_rresp;  m0_rvalid = s0_rvalid; end
            4'b0010: begin m1_rdata = s1_rdata;  m1_rresp = s1_rresp;  m1_rvalid = s1_rvalid; end
            4'b0100: begin m2_rdata = s2_rdata;  m2_rresp = s2_rresp;  m2_rvalid = s2_rvalid; end
            4'b1000: begin m3_rdata = s3_rdata;  m3_rresp = s3_rresp;  m3_rvalid = s3_rvalid; end
            default: ; // Already initialized to default values
        endcase
    end

endmodule
