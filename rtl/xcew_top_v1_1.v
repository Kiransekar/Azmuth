// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// xcew_top_v1_1.v
// Top-level module for Xcew Processor v1.1
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module xcew_top_v1_1 (
    input  wire         i_clk_core,
    input  wire         i_clk_snn,
    input  wire         i_rst,
    input  wire         v1_1_mode,
    output wire         o_irq_eml,
    output wire         o_irq_snn,
    output wire         o_irq_nvm,
    output wire         o_irq_fault,
    output wire [7:0]   o_debug_uart,
    output wire [31:0]  o_debug_status
);

    // =========================================================================
    // Clock/reset tree with power-gating sync
    // =========================================================================
    wire clk_core       = i_clk_core;
    wire clk_snn        = i_clk_snn;
    wire rst            = i_rst;
    wire rst_n          = ~i_rst;

    // Per-tile clock gating
    wire tile_sleep_core, tile_sleep_eml, tile_sleep_snn, tile_sleep_nvm;
    wire clk_core_gated  = clk_core & ~tile_sleep_core;
    wire clk_eml_gated   = clk_core & ~tile_sleep_eml;
    wire clk_snn_gated   = clk_snn  & ~tile_sleep_snn;
    wire clk_nvm_gated   = clk_core & ~tile_sleep_nvm;

    // =========================================================================
    // v1.1 feature enable
    // =========================================================================
    reg  v1_1_en;
    always @(posedge clk_core or posedge rst) begin
        if (rst) v1_1_en <= 1'b1;
        else     v1_1_en <= v1_1_mode;
    end

    // =========================================================================
    // CSR storage (internal registers)
    // =========================================================================
    reg [31:0] csr_xcew_cfg;
    reg [31:0] csr_xcew_status;
    reg [31:0] csr_snn_ctrl_ext;
    reg [31:0] csr_eml_dag_ctl;
    reg [31:0] csr_pwr_ctrl_reg;
    reg [31:0] csr_bias_ctrl_reg;
    reg [31:0] csr_sec_ctrl;
    reg [31:0] csr_pol_sec;
    reg [31:0] csr_fault_status_reg;

    // Sub-module CSR interface wires (driven by sub-modules on CSR access)
    wire [31:0] pwr_csr_rd_if;
    wire [31:0] bias_csr_rd_if;
    wire [31:0] fault_csr_rd_if;

    // Use sub-module CSR read-back during CSR operations, else internal reg
    wire [31:0] csr_pwr_ctrl = (core_csr_addr == 12'h7C8) ? pwr_csr_rd_if : csr_pwr_ctrl_reg;
    wire [31:0] csr_bias_ctrl = (core_csr_addr == 12'h7C9) ? bias_csr_rd_if : csr_bias_ctrl_reg;
    wire [31:0] csr_fault_status = (core_csr_addr == 12'h7CC) ? fault_csr_rd_if : csr_fault_status_reg;

    // CSR access from core
    wire [11:0] core_csr_addr;
    wire        core_csr_wr_en;
    wire [31:0] core_csr_wr_data;
    wire [31:0] core_csr_rd_data;

    // =========================================================================
    // Core interface signals
    // =========================================================================
    wire [31:0] core_pc;
    wire [31:0] core_instr;
    wire [31:0] core_mem_addr;
    wire [31:0] core_mem_wdata;
    wire        core_mem_we;
    wire [3:0]  core_mem_wstrb;
    wire [31:0] core_mem_rdata;
    wire [31:0] core_xcew_req;
    wire        core_xcew_valid;
    wire        core_xcew_ready;
    wire [31:0] core_xcew_resp;
    wire        core_xcew_done;
    wire [31:0] core_rs1_data;
    wire [31:0] core_rs2_data;
    wire        core_wb_stall;
    wire        core_exception;
    wire        core_interrupt;
    wire [15:0] core_mem_addr_16 = core_mem_addr[15:0];
    wire        core_addr_fault  = |core_mem_addr[31:16];

    // =========================================================================
    // AXI interconnect - master signals (core is M0)
    // =========================================================================
    wire [15:0] m0_awaddr = core_mem_addr_16;
    wire        m0_awvalid = core_mem_we;
    wire        m0_awready;
    wire [31:0] m0_wdata = core_mem_wdata;
    wire [3:0]  m0_wstrb = core_mem_wstrb;
    wire        m0_wvalid = core_mem_we;
    wire        m0_wready;
    wire [1:0]  m0_bresp;
    wire        m0_bvalid;
    wire        m0_bready = 1'b1;
    wire [15:0] m0_araddr = core_mem_addr_16;
    wire        m0_arvalid = ~core_mem_we;
    wire        m0_arready;
    wire [31:0] m0_rdata;
    wire [1:0]  m0_rresp;
    wire        m0_rvalid;
    wire        m0_rready = 1'b1;

    // Masters 1-3 unused (tied to 0)
    wire [15:0] dummy_awaddr = 16'h0;
    wire        dummy_awvalid = 1'b0;
    wire        dummy_awready;
    wire [31:0] dummy_wdata = 32'h0;
    wire [3:0]  dummy_wstrb = 4'h0;
    wire        dummy_wvalid = 1'b0;
    wire        dummy_wready;
    wire        dummy_bready = 1'b1;
    wire [15:0] dummy_araddr = 16'h0;
    wire        dummy_arvalid = 1'b0;
    wire        dummy_arready;
    wire [1:0]  dummy_bresp;
    wire        dummy_bvalid;
    wire [31:0] dummy_rdata;
    wire [1:0]  dummy_rresp;
    wire        dummy_rvalid;
    wire        dummy_rready = 1'b1;

    // =========================================================================
    // AXI interconnect - slave signals
    // =========================================================================
    wire [15:0] s0_awaddr, s1_awaddr, s2_awaddr, s3_awaddr, s4_awaddr;
    wire        s0_awvalid, s1_awvalid, s2_awvalid, s3_awvalid, s4_awvalid;
    wire        s0_awready, s1_awready, s2_awready, s3_awready, s4_awready;
    wire [31:0] s0_wdata, s1_wdata, s2_wdata, s3_wdata, s4_wdata;
    wire [3:0]  s0_wstrb, s1_wstrb, s2_wstrb, s3_wstrb, s4_wstrb;
    wire        s0_wvalid, s1_wvalid, s2_wvalid, s3_wvalid, s4_wvalid;
    wire        s0_wready, s1_wready, s2_wready, s3_wready, s4_wready;
    wire [1:0]  s0_bresp, s1_bresp, s2_bresp, s3_bresp, s4_bresp;
    wire        s0_bvalid, s1_bvalid, s2_bvalid, s3_bvalid, s4_bvalid;
    wire        s0_bready, s1_bready, s2_bready, s3_bready, s4_bready;
    wire [15:0] s0_araddr, s1_araddr, s2_araddr, s3_araddr, s4_araddr;
    wire        s0_arvalid, s1_arvalid, s2_arvalid, s3_arvalid, s4_arvalid;
    wire        s0_arready, s1_arready, s2_arready, s3_arready, s4_arready;
    wire [31:0] s0_rdata, s1_rdata, s2_rdata, s3_rdata, s4_rdata;
    wire [1:0]  s0_rresp, s1_rresp, s2_rresp, s3_rresp, s4_rresp;
    wire        s0_rvalid, s1_rvalid, s2_rvalid, s3_rvalid, s4_rvalid;
    wire        s0_rready, s1_rready, s2_rready, s3_rready, s4_rready;

    // =========================================================================
    // Instruction ROM & SRAM
    // =========================================================================
    reg [31:0] instr_rom [0:1023];
    reg [31:0] sram_memory [0:4095];

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            instr_rom[i] = 32'h00000013;
        instr_rom[0] = 32'h00000093;
        instr_rom[1] = 32'h00A00093;
        instr_rom[2] = 32'h00B000B3;
    end

    // =========================================================================
    // Power orchestration signals
    // =========================================================================
    wire [3:0] tile_sleep_int;
    wire [3:0] tile_iso_en_int;
    wire [3:0] tile_ret_en_int;
    wire [3:0] tile_wake_req_int;
    wire       wake_irq_trigger;
    wire       axi_activity;
    wire [3:0] tile_activity_count;

    assign tile_sleep_core = tile_sleep_int[0];
    assign tile_sleep_eml  = tile_sleep_int[1];
    assign tile_sleep_snn  = tile_sleep_int[2];
    assign tile_sleep_nvm  = tile_sleep_int[3];
    assign wake_irq_trigger = o_irq_eml | o_irq_snn | o_irq_nvm;
    assign axi_activity = core_mem_we | core_csr_wr_en;

    // =========================================================================
    // Body bias control signals
    // =========================================================================
    wire [7:0]  bias_code_int;
    wire        cal_en_int;
    wire        leakage_ready_int;
    wire [7:0]  pb_bias_out_int;
    wire [7:0]  nb_bias_out_int;

    // =========================================================================
    // Fault monitor signals
    // =========================================================================
    wire        fault_irq_int;
    wire        pipeline_halt_int;
    wire [3:0]  error_code_int;
    wire [3:0]  soft_error_int;
    wire [3:0]  hard_error_int;
    wire        ecc_error_int;
    wire        watchdog_trip_int;
    wire        fault_detected_int;
    wire        fault_clr_int;
    wire        irq_enable_int;

    // =========================================================================
    // EML unit signals
    // =========================================================================
    wire [31:0] eml_rs1, eml_rs2, eml_cfg_int;
    wire        eml_valid_int;
    wire [31:0] eml_rd_raw;
    wire [31:0] eml_ct_rd;
    wire        eml_valid_out_int;
    wire        eml_ready_int;
    wire        eml_exc_int;

    // EML DAG cache
    wire [31:0] eml_expr_hash_in, eml_expr_result_in;
    wire        eml_expr_valid_in, eml_expr_compute_done;
    wire [31:0] eml_cached_result;
    wire        eml_cache_hit, eml_cache_miss;
    wire [31:0] eml_alloc_addr;
    wire [31:0] eml_subexpr_hash;
    wire        eml_subexpr_valid, eml_subexpr_cached;
    wire [31:0] eml_subexpr_result;

    // EML constant-time
    wire        const_time_en_int;
    wire        timing_var_en_int;
    wire        eml_ct_ready_out, eml_ct_valid_out, eml_ct_ready_in;
    wire        eml_ct_exc, eml_stall_pipeline;

    // EML policy determinism
    wire        policy_exec_start_int;
    wire [31:0] policy_data_int;
    wire        policy_valid_int;
    wire        policy_done_int;
    wire [31:0] policy_result_int;
    wire        det_en_int;
    wire [4:1]  max_cycles_int;
    wire        timeout_irq_int;

    // =========================================================================
    // SNN unit signals
    // =========================================================================
    wire        snn_classify_en_int;
    wire [7:0]  snn_class_int;
    wire [15:0] snn_conf_int;
    wire        snn_done_int;
    wire        snn_ready_int;

    // SNN TTFS config
    wire        snn_ttfs_enable_int;
    wire [2:0]  snn_t_window_int;
    wire [2:0]  snn_refractory_cycles_int;

    // SNN 256-neuron input loading
    wire [31:0] snn_input_current_int;
    wire [7:0]  snn_neuron_idx_int;
    wire        snn_current_valid_int;

    // SNN spike outputs (from tile_256 for STDP)
    wire [255:0] snn_spike_outs_vec;
    wire [255:0] snn_spike_valids_vec;

    // SNN STDP
    wire [3:0]  snn_stdp_policy_int;
    wire        snn_stdp_enable_int;
    wire        snn_learning_enable_int;
    wire        snn_pre_spike_int;
    wire        snn_post_spike_int;
    wire [31:0] snn_pre_spike_time_int;
    wire [31:0] snn_post_spike_time_int;
    wire [7:0]  snn_updated_weight_int;
    wire        snn_weight_updated_int;

    // =========================================================================
    // NVM signals
    // =========================================================================
    wire [15:0] nvm_addr_int;
    wire        nvm_wr_en_int;
    wire [31:0] nvm_wr_data_int;
    wire        nvm_rd_en_int;
    wire [31:0] nvm_rd_data_int;
    wire        nvm_busy_int;
    wire        nvm_ecc_err_int;

    // =========================================================================
    // CSR address decode (named wires for clarity)
    // =========================================================================
    wire csr_is_xcew_cfg   = (core_csr_addr == 12'h7C0);
    wire csr_is_xcew_status = (core_csr_addr == 12'h7C1);
    wire csr_is_snn_ctrl   = (core_csr_addr == 12'h7C5);
    wire csr_is_eml_dag    = (core_csr_addr == 12'h7C6);
    wire csr_is_pwr_ctrl   = (core_csr_addr == 12'h7C8);
    wire csr_is_bias_ctrl  = (core_csr_addr == 12'h7C9);
    wire csr_is_sec_ctrl   = (core_csr_addr == 12'h7CA);
    wire csr_is_pol_sec    = (core_csr_addr == 12'h7CB);
    wire csr_is_fault_sts  = (core_csr_addr == 12'h7CC);

    // =========================================================================
    // CSR read multiplexer
    // =========================================================================
    assign core_csr_rd_data =
        csr_is_xcew_cfg    ? csr_xcew_cfg     :
        csr_is_xcew_status ? csr_xcew_status  :
        csr_is_snn_ctrl    ? csr_snn_ctrl_ext :
        csr_is_eml_dag     ? csr_eml_dag_ctl  :
        csr_is_pwr_ctrl    ? csr_pwr_ctrl     :
        csr_is_bias_ctrl   ? csr_bias_ctrl    :
        csr_is_sec_ctrl    ? csr_sec_ctrl     :
        csr_is_pol_sec     ? csr_pol_sec      :
        csr_is_fault_sts   ? csr_fault_status :
        32'h0;

    // =========================================================================
    // CSR write logic (v1.1 features gated by v1_1_en)
    // =========================================================================
    always @(posedge clk_core or posedge rst) begin
        if (rst) begin
            csr_xcew_cfg      <= 32'h0;
            csr_xcew_status   <= 32'h0;
            csr_snn_ctrl_ext  <= 32'h0;
            csr_eml_dag_ctl   <= 32'h0;
            csr_pwr_ctrl_reg  <= 32'h0;
            csr_bias_ctrl_reg <= 32'h0;
            csr_sec_ctrl      <= 32'h0;
            csr_pol_sec       <= 32'h0;
            csr_fault_status_reg <= 32'h0;
        end else begin
            if (core_csr_wr_en) begin
                case (core_csr_addr)
                    12'h7C0: csr_xcew_cfg <= {16'h0, core_csr_wr_data[15],
                                              core_csr_wr_data[14:12],
                                              core_csr_wr_data[11:8],
                                              core_csr_wr_data[7], 7'h0};
                    12'h7C1: ;
                    12'h7C5: if (v1_1_en) csr_snn_ctrl_ext <= core_csr_wr_data;
                    12'h7C6: if (v1_1_en) csr_eml_dag_ctl <= core_csr_wr_data;
                    12'h7C8: if (v1_1_en) csr_pwr_ctrl_reg <= core_csr_wr_data;
                    12'h7C9: if (v1_1_en) csr_bias_ctrl_reg <= core_csr_wr_data;
                    12'h7CA: if (v1_1_en) csr_sec_ctrl <= core_csr_wr_data;
                    12'h7CB: if (v1_1_en) csr_pol_sec <= core_csr_wr_data;
                    12'h7CC: if (v1_1_en) csr_fault_status_reg <= csr_fault_status_reg & ~core_csr_wr_data;
                    default: ;
                endcase
            end
        end
    end

    // =========================================================================
    // RISC-V Core
    // =========================================================================
    riscv_core core_inst (
        .clk(clk_core_gated),
        .rst(rst),
        .pc(core_pc),
        .instr(core_instr),
        .mem_addr(core_mem_addr),
        .mem_wdata(core_mem_wdata),
        .mem_we(core_mem_we),
        .mem_wstrb(core_mem_wstrb),
        .mem_rdata(core_mem_rdata),
        .csr_addr(core_csr_addr),
        .csr_wr_en(core_csr_wr_en),
        .csr_wr_data(core_csr_wr_data),
        .csr_rd_data(core_csr_rd_data),
        // Machine interrupts: external = aggregate of live IRQ sources
        .i_meip(o_irq_fault | timeout_irq_int),
        .i_mtip(1'b0),
        .i_msip(1'b0),
        .o_xcew_req(core_xcew_req),
        .o_xcew_valid(core_xcew_valid),
        .i_xcew_ready(core_xcew_ready),
        .i_xcew_resp(core_xcew_resp),
        .i_xcew_done(core_xcew_done),
        .o_rs1_data(core_rs1_data),
        .o_rs2_data(core_rs2_data),
        .wb_stall(core_wb_stall),
        .exception(core_exception),
        .interrupt(core_interrupt)
    );

    assign core_instr = (core_pc[12:2] < 11'd1024) ? instr_rom[core_pc[11:2]] : 32'h00000013;

    // =========================================================================
    // AXI4-Lite Interconnect (v1.1)
    // =========================================================================
    axi_lite_interconnect_v1_1 interconnect_inst (
        .aclk(clk_core_gated),
        .aresetn(rst_n),

        // Master 0: Core
        .m0_awaddr(m0_awaddr),  .m0_awvalid(m0_awvalid), .m0_awready(m0_awready),
        .m0_wdata(m0_wdata),    .m0_wstrb(m0_wstrb),    .m0_wvalid(m0_wvalid),
        .m0_wready(m0_wready),  .m0_bresp(m0_bresp),    .m0_bvalid(m0_bvalid),
        .m0_bready(m0_bready),  .m0_araddr(m0_araddr),  .m0_arvalid(m0_arvalid),
        .m0_arready(m0_arready),.m0_rdata(m0_rdata),    .m0_rresp(m0_rresp),
        .m0_rvalid(m0_rvalid),  .m0_rready(m0_rready),

        // Master 1: EML (reserved)
        .m1_awaddr(dummy_awaddr), .m1_awvalid(dummy_awvalid), .m1_awready(dummy_awready),
        .m1_wdata(dummy_wdata),   .m1_wstrb(dummy_wstrb),    .m1_wvalid(dummy_wvalid), .m1_wready(dummy_wready),
        .m1_bresp(dummy_bresp),   .m1_bvalid(dummy_bvalid),  .m1_bready(dummy_bready),
        .m1_araddr(dummy_araddr), .m1_arvalid(dummy_arvalid), .m1_arready(dummy_arready),
        .m1_rdata(dummy_rdata),   .m1_rresp(dummy_rresp),    .m1_rvalid(dummy_rvalid), .m1_rready(dummy_rready),

        // Master 2: SNN (reserved)
        .m2_awaddr(dummy_awaddr), .m2_awvalid(dummy_awvalid), .m2_awready(dummy_awready),
        .m2_wdata(dummy_wdata),   .m2_wstrb(dummy_wstrb),    .m2_wvalid(dummy_wvalid), .m2_wready(dummy_wready),
        .m2_bresp(dummy_bresp),   .m2_bvalid(dummy_bvalid),  .m2_bready(dummy_bready),
        .m2_araddr(dummy_araddr), .m2_arvalid(dummy_arvalid), .m2_arready(dummy_arready),
        .m2_rdata(dummy_rdata),   .m2_rresp(dummy_rresp),    .m2_rvalid(dummy_rvalid), .m2_rready(dummy_rready),

        // Master 3: NVM (reserved)
        .m3_awaddr(dummy_awaddr), .m3_awvalid(dummy_awvalid), .m3_awready(dummy_awready),
        .m3_wdata(dummy_wdata),   .m3_wstrb(dummy_wstrb),    .m3_wvalid(dummy_wvalid), .m3_wready(dummy_wready),
        .m3_bresp(dummy_bresp),   .m3_bvalid(dummy_bvalid),  .m3_bready(dummy_bready),
        .m3_araddr(dummy_araddr), .m3_arvalid(dummy_arvalid), .m3_arready(dummy_arready),
        .m3_rdata(dummy_rdata),   .m3_rresp(dummy_rresp),    .m3_rvalid(dummy_rvalid), .m3_rready(dummy_rready),

        // Slave 0: Boot ROM
        .s0_awaddr(s0_awaddr), .s0_awvalid(s0_awvalid), .s0_awready(s0_awready),
        .s0_wdata(s0_wdata),   .s0_wstrb(s0_wstrb),   .s0_wvalid(s0_wvalid),
        .s0_wready(s0_wready), .s0_bresp(s0_bresp),   .s0_bvalid(s0_bvalid),
        .s0_bready(s0_bready), .s0_araddr(s0_araddr), .s0_arvalid(s0_arvalid),
        .s0_arready(s0_arready), .s0_rdata(s0_rdata), .s0_rresp(s0_rresp),
        .s0_rvalid(s0_rvalid), .s0_rready(s0_rready),

        // Slave 1: SRAM
        .s1_awaddr(s1_awaddr), .s1_awvalid(s1_awvalid), .s1_awready(s1_awready),
        .s1_wdata(s1_wdata),   .s1_wstrb(s1_wstrb),   .s1_wvalid(s1_wvalid),
        .s1_wready(s1_wready), .s1_bresp(s1_bresp),   .s1_bvalid(s1_bvalid),
        .s1_bready(s1_bready), .s1_araddr(s1_araddr), .s1_arvalid(s1_arvalid),
        .s1_arready(s1_arready), .s1_rdata(s1_rdata), .s1_rresp(s1_rresp),
        .s1_rvalid(s1_rvalid), .s1_rready(s1_rready),

        // Slave 2: EML CSR
        .s2_awaddr(s2_awaddr), .s2_awvalid(s2_awvalid), .s2_awready(s2_awready),
        .s2_wdata(s2_wdata),   .s2_wstrb(s2_wstrb),   .s2_wvalid(s2_wvalid),
        .s2_wready(s2_wready), .s2_bresp(s2_bresp),   .s2_bvalid(s2_bvalid),
        .s2_bready(s2_bready), .s2_araddr(s2_araddr), .s2_arvalid(s2_arvalid),
        .s2_arready(s2_arready), .s2_rdata(s2_rdata), .s2_rresp(s2_rresp),
        .s2_rvalid(s2_rvalid), .s2_rready(s2_rready),

        // Slave 3: SNN CSR
        .s3_awaddr(s3_awaddr), .s3_awvalid(s3_awvalid), .s3_awready(s3_awready),
        .s3_wdata(s3_wdata),   .s3_wstrb(s3_wstrb),   .s3_wvalid(s3_wvalid),
        .s3_wready(s3_wready), .s3_bresp(s3_bresp),   .s3_bvalid(s3_bvalid),
        .s3_bready(s3_bready), .s3_araddr(s3_araddr), .s3_arvalid(s3_arvalid),
        .s3_arready(s3_arready), .s3_rdata(s3_rdata), .s3_rresp(s3_rresp),
        .s3_rvalid(s3_rvalid), .s3_rready(s3_rready),

        // Slave 4: NVM CSR
        .s4_awaddr(s4_awaddr), .s4_awvalid(s4_awvalid), .s4_awready(s4_awready),
        .s4_wdata(s4_wdata),   .s4_wstrb(s4_wstrb),   .s4_wvalid(s4_wvalid),
        .s4_wready(s4_wready), .s4_bresp(s4_bresp),   .s4_bvalid(s4_bvalid),
        .s4_bready(s4_bready), .s4_araddr(s4_araddr), .s4_arvalid(s4_arvalid),
        .s4_arready(s4_arready), .s4_rdata(s4_rdata), .s4_rresp(s4_rresp),
        .s4_rvalid(s4_rvalid), .s4_rready(s4_rready)
    );

    // =========================================================================
    // Boot ROM slave
    // =========================================================================
    assign s0_rdata  = (s0_araddr[12:2] < 11'd1024) ? instr_rom[s0_araddr[11:2]] : 32'h0;
    assign s0_rvalid = s0_arvalid;
    assign s0_rresp  = 2'b00;
    assign s0_bvalid = 1'b0;
    assign s0_bresp  = 2'b00;
    assign s0_awready = 1'b0;
    assign s0_wready  = 1'b0;
    assign s0_arready = s0_arvalid;

    // =========================================================================
    // SRAM slave
    // =========================================================================
    always @(posedge clk_core_gated) begin
        if (s1_awvalid && s1_wvalid && s1_awready && s1_wready) begin
            if (s1_wstrb[0]) sram_memory[s1_awaddr[13:2]][7:0]   <= s1_wdata[7:0];
            if (s1_wstrb[1]) sram_memory[s1_awaddr[13:2]][15:8]  <= s1_wdata[15:8];
            if (s1_wstrb[2]) sram_memory[s1_awaddr[13:2]][23:16] <= s1_wdata[23:16];
            if (s1_wstrb[3]) sram_memory[s1_awaddr[13:2]][31:24] <= s1_wdata[31:24];
        end
    end
    assign s1_rdata  = sram_memory[s1_araddr[13:2]];
    assign s1_rvalid = s1_arvalid;
    assign s1_rresp  = 2'b00;
    assign s1_bvalid = (s1_awvalid && s1_wvalid) ? 1'b1 : 1'b0;
    assign s1_bresp  = 2'b00;
    assign s1_awready = 1'b1;
    assign s1_wready  = 1'b1;
    assign s1_arready = 1'b1;

    // =========================================================================
    // EML Unit
    // =========================================================================
    assign eml_cfg_int = csr_xcew_cfg;
    assign eml_rs1 = (core_xcew_req != 32'h0) ? core_rs1_data : 32'h0;
    assign eml_rs2 = (core_xcew_req != 32'h0) ? core_rs2_data : 32'h0;
    assign eml_valid_int = core_xcew_valid;

    eml_unit eml_inst (
        .i_clk(clk_eml_gated),
        .i_rst(rst),
        .i_rs1(eml_rs1),
        .i_rs2(eml_rs2),
        .i_cfg(eml_cfg_int),
        .i_valid(eml_valid_int),
        .o_rd(eml_rd_raw),
        .o_valid(eml_valid_out_int),
        .o_ready(eml_ready_int),
        .o_exc(eml_exc_int)
    );

    // EML DAG Cache
    wire [7:0]  dag_cache_tag_wr, dag_cache_data_wr, dag_cache_lru_wr;
    wire [7:0]  dag_cache_tag_rd, dag_cache_data_rd, dag_cache_lru_rd;
    wire [31:0] dag_cache_data_out;
    wire [7:0]  dag_cache_lru_out;
    assign dag_cache_data_out = 32'h0;
    assign dag_cache_lru_out = 8'h0;
    eml_dag_cache eml_dag_cache_inst (
        .clk(clk_eml_gated),
        .rst(rst),
        .enable(v1_1_en),
        .dag_mode(csr_eml_dag_ctl[0]),
        .expr_hash_in(eml_expr_hash_in),
        .expr_result_in(eml_expr_result_in),
        .expr_valid_in(eml_expr_valid_in),
        .expr_compute_done(eml_expr_compute_done),
        .cached_result(eml_cached_result),
        .cache_hit(eml_cache_hit),
        .cache_miss(eml_cache_miss),
        .alloc_addr(eml_alloc_addr),
        .subexpr_hash(eml_subexpr_hash),
        .subexpr_valid(eml_subexpr_valid),
        .subexpr_cached(eml_subexpr_cached),
        .subexpr_result(eml_subexpr_result),
        .cache_tag_wr(dag_cache_tag_wr),
        .cache_data_wr(dag_cache_data_wr),
        .cache_lru_wr(dag_cache_lru_wr),
        .cache_tag_rd(dag_cache_tag_rd),
        .cache_data_rd(dag_cache_data_rd),
        .cache_lru_rd(dag_cache_lru_rd),
        .cache_data_out(dag_cache_data_out),
        .cache_lru_out(dag_cache_lru_out)
    );

    // EML Constant-Time
    assign const_time_en_int = v1_1_en & csr_sec_ctrl[0];
    assign timing_var_en_int = v1_1_en & csr_sec_ctrl[1];

    eml_constant_time eml_ct_inst (
        .clk(clk_eml_gated),
        .rst(rst),
        .rs1(eml_rs1),
        .rs2(eml_rs2),
        .cfg(eml_cfg_int),
        .valid_in(eml_valid_int),
        .ready_out(eml_ct_ready_out),
        .rd(eml_ct_rd),
        .valid_out(eml_ct_valid_out),
        .ready_in(eml_ct_ready_in),
        .exc(eml_ct_exc),
        .csr_addr(core_csr_addr),
        .csr_wr_en(core_csr_wr_en),
        .csr_wr_data(core_csr_wr_data),
        .csr_rd_data(),
        .const_time_en(const_time_en_int),
        .timing_var_en(timing_var_en_int),
        .stall_pipeline(eml_stall_pipeline)
    );

    // EML Policy Determinism
    assign det_en_int = v1_1_en & csr_pol_sec[0];
    assign max_cycles_int = csr_pol_sec[4:1];

    policy_determinism policy_inst (
        .clk(clk_core_gated),
        .rst(rst),
        .policy_exec_start(policy_exec_start_int),
        .policy_data(policy_data_int),
        .policy_valid(policy_valid_int),
        .policy_done(policy_done_int),
        .policy_result(policy_result_int),
        .det_en(det_en_int),
        .max_cycles(max_cycles_int),
        .timeout_irq(timeout_irq_int),
        .csr_addr(core_csr_addr),
        .csr_wr_en(core_csr_wr_en),
        .csr_wr_data(core_csr_wr_data),
        .csr_rd_data()
    );

    // EML CSR slave
    assign s2_rdata  = 32'h0;
    assign s2_rvalid = s2_arvalid;
    assign s2_rresp  = 2'b00;
    assign s2_bvalid = (s2_awvalid && s2_wvalid) ? 1'b1 : 1'b0;
    assign s2_bresp  = 2'b00;
    assign s2_awready = 1'b1;
    assign s2_wready  = 1'b1;
    assign s2_arready = 1'b1;

    // =========================================================================
    // SNN Tile (256 neurons)
    // =========================================================================
    assign snn_classify_en_int = core_xcew_valid && (core_xcew_req[6:0] == 7'b1011011);
    assign snn_ttfs_enable_int = v1_1_en & csr_snn_ctrl_ext[7];
    assign snn_t_window_int = csr_snn_ctrl_ext[10:8];
    assign snn_refractory_cycles_int = csr_snn_ctrl_ext[14:12];

    // Sequential input loading: rs1=data, rs2[7:0]=neuron index
    // current_valid is driven by core's xcew_valid when SNN opcode is active
    assign snn_input_current_int = core_rs1_data;
    assign snn_neuron_idx_int    = core_rs2_data[7:0];
    assign snn_current_valid_int = core_xcew_valid && (core_xcew_req[6:0] == 7'b1111011);

    snn_tile_256 #(.NUM_NEURONS(256)) snn_inst (
        .i_clk_snn(clk_snn_gated),
        .i_rst(rst),
        .i_classify_en(snn_classify_en_int),
        .i_ttfs_enable(snn_ttfs_enable_int),
        .i_t_window(snn_t_window_int),
        .i_refractory_cycles(snn_refractory_cycles_int),
        .i_v_threshold(32'h40000000),
        .i_v_rest(32'h0),
        .i_input_current(snn_input_current_int),
        .i_neuron_idx(snn_neuron_idx_int),
        .i_current_valid(snn_current_valid_int),
        .o_class(snn_class_int),
        .o_conf(snn_conf_int),
        .o_done(snn_done_int),
        .o_ready(snn_ready_int),
        .o_spike_outs(snn_spike_outs_vec),
        .o_spike_valids(snn_spike_valids_vec)
    );

    // SNN STDP Engine (v1.1)
    // Wire spike outputs: neuron 0 as pre-synaptic, neuron 1 as post-synaptic
    assign snn_pre_spike_int  = snn_spike_outs_vec[0];
    assign snn_post_spike_int = snn_spike_outs_vec[1];
    assign snn_pre_spike_time_int  = 32'd0;  // Placeholder: TTFS timing not yet wired
    assign snn_post_spike_time_int = 32'd0;
    assign snn_stdp_policy_int = csr_snn_ctrl_ext[19:16];
    assign snn_stdp_enable_int = v1_1_en & csr_snn_ctrl_ext[20];
    assign snn_learning_enable_int = v1_1_en & csr_snn_ctrl_ext[21];

    stdp_engine_v1_1 snn_stdp_inst (
        .clk(clk_snn_gated),
        .rst(rst),
        .stdp_policy(snn_stdp_policy_int),
        .stdp_enable(snn_stdp_enable_int),
        .pre_spike(snn_pre_spike_int),
        .post_spike(snn_post_spike_int),
        .pre_spike_time(snn_pre_spike_time_int),
        .post_spike_time(snn_post_spike_time_int),
        .current_weight(8'h40),
        .updated_weight(snn_updated_weight_int),
        .weight_updated(snn_weight_updated_int),
        .A_plus(32'h02000000),
        .A_minus(32'h02000000),
        .tau_plus(32'd20),
        .tau_minus(32'd20),
        .learning_enable(snn_learning_enable_int)
    );

    // SNN CSR slave
    assign s3_rdata  = 32'h0;
    assign s3_rvalid = s3_arvalid;
    assign s3_rresp  = 2'b00;
    assign s3_bvalid = (s3_awvalid && s3_wvalid) ? 1'b1 : 1'b0;
    assign s3_bresp  = 2'b00;
    assign s3_awready = 1'b1;
    assign s3_wready  = 1'b1;
    assign s3_arready = 1'b1;

    // =========================================================================
    // NVM Controller
    // =========================================================================
    nvm_ctrl nvm_inst (
        .i_clk_nvm(clk_nvm_gated),
        .i_rst(rst),
        .i_addr(nvm_addr_int),
        .i_wr_en(nvm_wr_en_int),
        .i_wr_data(nvm_wr_data_int),
        .i_rd_en(nvm_rd_en_int),
        .o_rd_data(nvm_rd_data_int),
        .o_busy(nvm_busy_int),
        .o_ecc_err(nvm_ecc_err_int)
    );

    // NVM CSR slave
    assign s4_rdata  = 32'h0;
    assign s4_rvalid = s4_arvalid;
    assign s4_rresp  = 2'b00;
    assign s4_bvalid = (s4_awvalid && s4_wvalid) ? 1'b1 : 1'b0;
    assign s4_bresp  = 2'b00;
    assign s4_awready = 1'b1;
    assign s4_wready  = 1'b1;
    assign s4_arready = 1'b1;

    // =========================================================================
    // Power Orchestrator
    // =========================================================================
    orchestrator orchestrator_inst (
        .clk(clk_core_gated),
        .rst(rst),
        .tile_state_req(csr_pwr_ctrl[3:0]),
        .idle_timeout(csr_pwr_ctrl[7:4]),
        .wake_irq_mask(csr_pwr_ctrl[8]),
        .activity_count(tile_activity_count),
        .tile_sleep(tile_sleep_int),
        .tile_iso_en(tile_iso_en_int),
        .tile_ret_en(tile_ret_en_int),
        .tile_wake_req(tile_wake_req_int),
        .irq_trigger(wake_irq_trigger),
        .axi_activity(axi_activity),
        .csr_addr(core_csr_addr),
        .csr_wr_en(core_csr_wr_en),
        .csr_wr_data(core_csr_wr_data),
        .csr_rd_data(pwr_csr_rd_if)
    );

    // =========================================================================
    // Body Bias Controller
    // =========================================================================
    assign bias_code_int = v1_1_en ? csr_bias_ctrl[7:0] : 8'h80;
    assign cal_en_int = v1_1_en ? csr_bias_ctrl[8] : 1'b0;

    body_bias_ctrl bias_ctrl_inst (
        .clk(clk_core_gated),
        .rst(rst),
        .bias_code(bias_code_int),
        .cal_en(cal_en_int),
        .leakage_ready(leakage_ready_int),
        .pb_bias_out(pb_bias_out_int),
        .nb_bias_out(nb_bias_out_int),
        .leakage_counter(1'b0),
        .measure_en(1'b0),
        .csr_addr(core_csr_addr),
        .csr_wr_en(core_csr_wr_en),
        .csr_wr_data(core_csr_wr_data),
        .csr_rd_data(bias_csr_rd_if)
    );

    // =========================================================================
    // Fault Monitor
    // =========================================================================
    assign soft_error_int = 4'h0;
    assign hard_error_int = 4'h0;
    assign ecc_error_int  = nvm_ecc_err_int;
    assign fault_clr_int  = 1'b0;
    assign irq_enable_int = 1'b1;

    fault_monitor fault_mon_inst (
        .clk(clk_core_gated),
        .rst(rst),
        .eml_pipe_active(eml_valid_int),
        .snn_pipe_active(snn_classify_en_int),
        .nvm_pipe_active(nvm_wr_en_int | nvm_rd_en_int),
        .csr_access_active(core_csr_wr_en),
        .instr_fetch_active(1'b1),
        .soft_error(soft_error_int),
        .hard_error(hard_error_int),
        .ecc_error(ecc_error_int),
        .watchdog_trip(watchdog_trip_int),
        .fault_detected(fault_detected_int),
        .fault_clr(fault_clr_int),
        .irq_enable(irq_enable_int),
        .irq_fault(fault_irq_int),
        .pipeline_halt(pipeline_halt_int),
        .error_code(error_code_int),
        .csr_addr(core_csr_addr),
        .csr_wr_en(core_csr_wr_en),
        .csr_wr_data(core_csr_wr_data),
        .csr_rd_data(fault_csr_rd_if)
    );

    // =========================================================================
    // Status register & interrupt outputs
    // =========================================================================
    always @(posedge clk_core or posedge rst) begin
        if (rst) begin
            csr_xcew_status <= 32'h0;
        end else begin
            csr_xcew_status[31:4] <= 28'h0;
            csr_xcew_status[3]    <= o_irq_eml | o_irq_snn | o_irq_fault;
            csr_xcew_status[2]    <= nvm_busy_int;
            csr_xcew_status[1]    <= eml_exc_int;
            csr_xcew_status[0]    <= 1'b0;
        end
    end

    assign o_irq_eml   = 1'b0;
    assign o_irq_snn   = 1'b0;
    assign o_irq_nvm   = 1'b0;
    assign o_irq_fault = fault_irq_int;

    // =========================================================================
    // Core memory read data routing
    // =========================================================================
    assign core_mem_rdata =
        (core_mem_addr[31:28] == 4'h0) ? m0_rdata :
        (core_mem_addr[31:28] == 4'h1) ? m0_rdata :
        (core_mem_addr[31:20] == 12'h200) ? m0_rdata :
        (core_mem_addr[31:20] == 12'h210) ? m0_rdata :
        (core_mem_addr[31:20] == 12'h220) ? m0_rdata :
        32'h0;

    // =========================================================================
    // Debug outputs
    // =========================================================================
    assign o_debug_uart = 8'h00;
    assign o_debug_status = {
        12'h0,
        pipeline_halt_int,
        watchdog_trip_int,
        ecc_error_int,
        error_code_int,
        tile_sleep_int,
        leakage_ready_int,
        snn_done_int,
        nvm_busy_int,
        eml_valid_out_int,
        eml_cache_hit,
        eml_ct_valid_out,
        policy_done_int,
        core_interrupt,
        core_exception | core_addr_fault
    };

endmodule
