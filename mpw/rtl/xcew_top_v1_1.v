// xcew_top_v1.1.v
// Unified Top-Level Module for Xcew Processor v1.1
// Merges v1.0 SOC + 6A(DAG Cache) + 6B(TTFS/STDP) + 6C(Power/Body Bias) + 6D(Security)
// Backward compatible: set v1.1_mode=0 for v1.0 behavior
// Target: TSMC 130nm CMOS | 250MHz Core/EML, 125MHz SNN | <18mm2, <2W peak

`timescale 1ns/1ps

module xcew_top_v1_1 (
    // Global Clock and Reset
    input  wire         i_clk_core,        // 250MHz core clock
    input  wire         i_clk_snn,         // 125MHz SNN domain clock
    input  wire         i_rst,

    // v1.1 mode pin: 1=enable all v1.1 features, 0=v1.0 backward compatible
    input  wire         v1_1_mode,

    // Interrupts (unified)
    output wire         o_irq_eml,
    output wire         o_irq_snn,
    output wire         o_irq_nvm,
    output wire         o_irq_fault,

    // Debug
    output wire [7:0]   o_debug_uart,
    output wire [31:0]  o_debug_status
);

    // =========================================================================
    // Clock/reset tree with power-gating sync
    // =========================================================================
    wire clk_core       = i_clk_core;
    wire clk_snn        = i_clk_snn;
    wire rst_n          = ~i_rst;           // Active-low reset for AXI
    wire rst            = i_rst;            // Active-high reset (internal)

    // Power-gating sync flops: gate clocks when tile is asleep
    wire clk_core_gated, clk_eml_gated, clk_snn_gated, clk_nvm_gated;

    // Core/axi clock tree
    assign clk_core_gated = clk_core;       // Core always on

    // Per-tile clock gating (power orchestration driven)
    assign clk_eml_gated  = clk_core & ~tile_sleep_int[1];  // EML tile
    assign clk_snn_gated  = clk_snn  & ~tile_sleep_int[2];  // SNN tile
    assign clk_nvm_gated  = clk_core & ~tile_sleep_int[3];  // NVM tile

    // =========================================================================
    // v1.1 feature enables (driven by v1_1_mode pin and CSR override)
    // =========================================================================
    reg  v1_1_en;
    always @(posedge clk_core or posedge rst) begin
        if (rst) v1_1_en <= 1'b1;
        else     v1_1_en <= v1_1_mode;     // Pin controls feature set
    end

    // =========================================================================
    // CSR address map (unified 0x7C0-0x7CC, backward compatible)
    // =========================================================================
    // 0x7C0: xcew_cfg      - v1.0: COMPLEX_MODE, MAX_DEPTH, PRECISION, BRANCH_CUT
    // 0x7C1: xcew_status   - v1.0: PIPELINE_STAGE, IRQ_PENDING, NVM_BUSY, OVERFLOW, NaN
    // 0x7C5: snn_ctrl_ext  - v1.1: TTFS_EN, T_WINDOW, STDP_POLICY, LEARNING_EN
    // 0x7C6: eml_dag_ctl   - v1.1: DAG_MODE, CACHE_POLICY, COMPRESSION_ALG
    // 0x7C8: pwr_ctrl      - v1.1: TILE_STATE, IDLE_TIMEOUT, WAKE_IRQ_MASK
    // 0x7C9: bias_ctrl     - v1.1: BIAS_CODE, CAL_EN, LEAKAGE_RDY
    // 0x7CA: sec_ctrl      - v1.1: CONST_TIME_EN, TIMING_VAR_EN
    // 0x7CB: pol_sec       - v1.1: DETERM_EN, MAX_CYCLES
    // 0x7CC: fault_status  - v1.1: ERROR_CODE, WATCHDOG_TRIP, ECC_ERR

    // =========================================================================
    // Internal CSR storage (v1.1 extended register file)
    // =========================================================================
    reg [31:0] csr_xcew_cfg;          // 0x7C0
    reg [31:0] csr_xcew_status;       // 0x7C1 - read-only, updated by units
    reg [31:0] csr_snn_ctrl_ext;      // 0x7C5
    reg [31:0] csr_eml_dag_ctl;       // 0x7C6
    reg [31:0] csr_pwr_ctrl;          // 0x7C8
    reg [31:0] csr_bias_ctrl;         // 0x7C9
    reg [31:0] csr_sec_ctrl;          // 0x7CA
    reg [31:0] csr_pol_sec;           // 0x7CB
    reg [31:0] csr_fault_status;      // 0x7CC

    // CSR access signals from core
    wire [11:0] core_csr_addr;
    wire        core_csr_wr_en;
    wire [31:0] core_csr_wr_data;
    wire [31:0] core_csr_rd_data;

    // =========================================================================
    // AXI4-Lite interconnect signals
    // =========================================================================
    // Master connections (Core as sole AXI master in v1.0, EML/SNN/NVM as masters in v1.1)
    wire [15:0] core_awaddr;
    wire        core_awvalid;
    wire        core_awready;
    wire [31:0] core_wdata;
    wire [3:0]  core_wstrb;
    wire        core_wvalid;
    wire        core_wready;
    wire [1:0]  core_bresp;
    wire        core_bvalid;
    wire        core_bready;
    wire [15:0] core_araddr;
    wire        core_arvalid;
    wire        core_arready;
    wire [31:0] core_rdata;
    wire [1:0]  core_rresp;
    wire        core_rvalid;
    wire        core_rready;

    // Slave connections
    wire [15:0] rom_awaddr, sram_awaddr, eml_csr_awaddr, snn_ctrl_awaddr, nvm_ctrl_awaddr;
    wire        rom_awvalid, sram_awvalid, eml_csr_awvalid, snn_ctrl_awvalid, nvm_ctrl_awvalid;
    wire        rom_awready, sram_awready, eml_csr_awready, snn_ctrl_awready, nvm_ctrl_awready;
    wire [31:0] rom_wdata, sram_wdata, eml_csr_wdata, snn_ctrl_wdata, nvm_ctrl_wdata;
    wire [3:0]  rom_wstrb, sram_wstrb, eml_csr_wstrb, snn_ctrl_wstrb, nvm_ctrl_wstrb;
    wire        rom_wvalid, sram_wvalid, eml_csr_wvalid, snn_ctrl_wvalid, nvm_ctrl_wvalid;
    wire        rom_wready, sram_wready, eml_csr_wready, snn_ctrl_wready, nvm_ctrl_wready;
    wire [1:0]  rom_bresp, sram_bresp, eml_csr_bresp, snn_ctrl_bresp, nvm_ctrl_bresp;
    wire        rom_bvalid, sram_bvalid, eml_csr_bvalid, snn_ctrl_bvalid, nvm_ctrl_bvalid;
    wire        rom_bready, sram_bready, eml_csr_bready, snn_ctrl_bready, nvm_ctrl_bready;

    wire [15:0] rom_araddr, sram_araddr, eml_csr_araddr, snn_ctrl_araddr, nvm_ctrl_araddr;
    wire        rom_arvalid, sram_arvalid, eml_csr_arvalid, snn_ctrl_arvalid, nvm_ctrl_arvalid;
    wire        rom_arready, sram_arready, eml_csr_arready, snn_ctrl_arready, nvm_ctrl_arready;
    wire [31:0] rom_rdata, sram_rdata, eml_csr_rdata, snn_ctrl_rdata, nvm_ctrl_rdata;
    wire [1:0]  rom_rresp, sram_rresp, eml_csr_rresp, snn_ctrl_rresp, nvm_ctrl_rresp;
    wire        rom_rvalid, sram_rvalid, eml_csr_rvalid, snn_ctrl_rvalid, nvm_ctrl_rvalid;
    wire        rom_rready, sram_rready, eml_csr_rready, snn_ctrl_rready, nvm_ctrl_rready;

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
    wire        core_xcew_ready;
    wire [31:0] core_xcew_resp;
    wire        core_xcew_done;
    wire        core_wb_stall;
    wire        core_exception;
    wire        core_interrupt;

    // Address truncation for AXI compatibility
    wire [15:0] core_mem_addr_16 = core_mem_addr[15:0];
    wire        core_addr_fault  = |core_mem_addr[31:16];

    // =========================================================================
    // Instruction ROM
    // =========================================================================
    reg [31:0] instr_rom [0:1023];

    integer init_i;
    initial begin
        for (init_i = 0; init_i < 1024; init_i = init_i + 1) begin
            instr_rom[init_i] = 32'h00000013; // NOP
        end
        instr_rom[0] = 32'h00000093;  // ADDI x1, x0, 0
        instr_rom[1] = 32'h00A00093;  // ADDI x1, x0, 10
        instr_rom[2] = 32'h00B000B3;  // ADD  x1, x1, x0
    end

    // =========================================================================
    // SRAM (16KB)
    // =========================================================================
    reg [31:0] sram_memory [0:4095];

    // =========================================================================
    // Power orchestration internal signals
    // =========================================================================
    wire [3:0] tile_sleep_int;    // [0]=Core, [1]=EML, [2]=SNN, [3]=NVM
    wire [3:0] tile_iso_en_int;
    wire [3:0] tile_ret_en_int;
    wire [3:0] tile_wake_req_int;
    wire       wake_irq_trigger_int;
    wire       axi_activity_int;
    wire [3:0] tile_activity_count;

    // =========================================================================
    // Body bias control signals
    // =========================================================================
    wire [7:0]  bias_code_int;
    wire        cal_en_int;
    wire        leakage_ready_int;
    wire [7:0]  pb_bias_out_int;
    wire [7:0]  nb_bias_out_int;

    // =========================================================================
    // Security / fault monitor signals
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
    // EML unit interface signals
    // =========================================================================
    wire [31:0] eml_rs1, eml_rs2;
    wire [31:0] eml_cfg_int;
    wire        eml_valid_int;
    wire [31:0] eml_rd_int;
    wire        eml_valid_out_int;
    wire        eml_ready_int;
    wire        eml_exc_int;

    // EML DAG cache signals
    wire [31:0] eml_expr_hash_in;
    wire [31:0] eml_expr_result_in;
    wire        eml_expr_valid_in;
    wire        eml_expr_compute_done;
    wire [31:0] eml_cached_result;
    wire        eml_cache_hit;
    wire        eml_cache_miss;
    wire [31:0] eml_alloc_addr;
    wire [31:0] eml_subexpr_hash;
    wire        eml_subexpr_valid;
    wire        eml_subexpr_cached;
    wire [31:0] eml_subexpr_result;

    // EML constant-time signals
    wire        const_time_en_int;
    wire        timing_var_en_int;
    wire        eml_ct_ready_out;
    wire        eml_ct_valid_out;
    wire        eml_ct_ready_in;
    wire        eml_ct_exc;
    wire        eml_stall_pipeline;

    // EML policy determinism signals
    wire        policy_exec_start_int;
    wire [31:0] policy_data_int;
    wire        policy_valid_int;
    wire        policy_done_int;
    wire [31:0] policy_result_int;
    wire        det_en_int;
    wire [4:1]  max_cycles_int;
    wire        timeout_irq_int;

    // =========================================================================
    // SNN unit interface signals
    // =========================================================================
    wire [63:0] snn_spike_in_int;
    wire [15:0] snn_weight_ptr_int;
    wire        snn_classify_en_int;
    wire [7:0]  snn_class_int;
    wire [7:0]  snn_conf_int;
    wire        snn_done_int;

    // SNN TTFS signals
    wire        snn_ttfs_enable_int;
    wire [2:0]  snn_t_window_int;
    wire [2:0]  snn_refractory_cycles_int;
    wire [31:0] snn_input_current_int;
    wire        snn_current_valid_int;
    wire        snn_spike_out_int;
    wire        snn_spike_valid_int;
    wire [31:0] snn_membrane_potential_int;

    // SNN STDP signals
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
    // NVM unit interface signals
    // =========================================================================
    wire [15:0] nvm_addr_int;
    wire        nvm_wr_en_int;
    wire [31:0] nvm_wr_data_int;
    wire        nvm_rd_en_int;
    wire [31:0] nvm_rd_data_int;
    wire        nvm_busy_int;
    wire        nvm_ecc_err_int;

    // =========================================================================
    // Unified decoder: v1.1_mode selects extended or basic CSR routing
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
    // CSR read multiplexer (collision-free by address)
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
    // CSR write logic (only writable registers accept writes)
    // =========================================================================
    always @(posedge clk_core or posedge rst) begin
        if (rst) begin
            csr_xcew_cfg      <= 32'h0;
            csr_xcew_status   <= 32'h0;
            csr_snn_ctrl_ext  <= 32'h0;
            csr_eml_dag_ctl   <= 32'h0;
            csr_pwr_ctrl      <= 32'h0;
            csr_bias_ctrl     <= 32'h0;
            csr_sec_ctrl      <= 32'h0;
            csr_pol_sec       <= 32'h0;
            csr_fault_status  <= 32'h0;
        end else begin
            if (core_csr_wr_en) begin
                case (core_csr_addr)
                    12'h7C0: // xcew_cfg
                        csr_xcew_cfg <= {16'h0, core_csr_wr_data[15],
                                         core_csr_wr_data[14:12],
                                         core_csr_wr_data[11:8],
                                         core_csr_wr_data[7],
                                         7'h0};
                    12'h7C1: ; // xcew_status - read-only
                    12'h7C5: // snn_ctrl_ext - v1.1
                        if (v1_1_en) csr_snn_ctrl_ext <= core_csr_wr_data;
                    12'h7C6: // eml_dag_ctl - v1.1
                        if (v1_1_en) csr_eml_dag_ctl <= core_csr_wr_data;
                    12'h7C8: // pwr_ctrl - v1.1
                        if (v1_1_en) csr_pwr_ctrl <= core_csr_wr_data;
                    12'h7C9: // bias_ctrl - v1.1
                        if (v1_1_en) csr_bias_ctrl <= core_csr_wr_data;
                    12'h7CA: // sec_ctrl - v1.1
                        if (v1_1_en) csr_sec_ctrl <= core_csr_wr_data;
                    12'h7CB: // pol_sec - v1.1
                        if (v1_1_en) csr_pol_sec <= core_csr_wr_data;
                    12'h7CC: // fault_status - WC1 (write-1-clear)
                        if (v1_1_en) csr_fault_status <= csr_fault_status & ~core_csr_wr_data;
                    default: ;
                endcase
            end
        end
    end

    // =========================================================================
    // Instantiate RISC-V Core (v1.0 baseline)
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
        .o_xcew_req(core_xcew_req),
        .i_xcew_ready(core_xcew_ready),
        .i_xcew_resp(core_xcew_resp),
        .i_xcew_done(core_xcew_done),
        .wb_stall(core_wb_stall),
        .exception(core_exception),
        .interrupt(core_interrupt)
    );

    // Fetch from Boot ROM
    assign core_instr = (core_pc[11:2] < 1024) ? instr_rom[core_pc[11:2]] : 32'h00000013;

    // =========================================================================
    // AXI4-Lite Interconnect
    // =========================================================================
    axi_lite_interconnect interconnect_inst (
        .aclk(clk_core_gated),
        .aresetn(rst_n),

        // Master 0: Core
        .m0_awaddr(core_mem_addr_16),
        .m0_awvalid(core_mem_we),
        .m0_awready(core_awready),
        .m0_wdata(core_mem_wdata),
        .m0_wstrb(core_mem_wstrb),
        .m0_wvalid(core_mem_we),
        .m0_wready(core_wready),
        .m0_bresp(core_bresp),
        .m0_bvalid(core_bvalid),
        .m0_bready(core_bready),
        .m0_araddr(core_mem_addr_16),
        .m0_arvalid(~core_mem_we),
        .m0_arready(core_arready),
        .m0_rdata(core_rdata),
        .m0_rresp(core_rresp),
        .m0_rvalid(core_rvalid),
        .m0_rready(core_rready),

        // Masters 1-3: EML/SNN/NVM (not used in v1.0, reserved for future)
        .m1_awaddr(16'h0000), .m1_awvalid(1'b0), .m1_wdata(32'h0),
        .m1_wstrb(4'h0), .m1_wvalid(1'b0), .m1_bready(1'b1),
        .m1_araddr(16'h0000), .m1_arvalid(1'b0), .m1_rready(1'b1),
        .m2_awaddr(16'h0000), .m2_awvalid(1'b0), .m2_wdata(32'h0),
        .m2_wstrb(4'h0), .m2_wvalid(1'b0), .m2_bready(1'b1),
        .m2_araddr(16'h0000), .m2_arvalid(1'b0), .m2_rready(1'b1),
        .m3_awaddr(16'h0000), .m3_awvalid(1'b0), .m3_wdata(32'h0),
        .m3_wstrb(4'h0), .m3_wvalid(1'b0), .m3_bready(1'b1),
        .m3_araddr(16'h0000), .m3_arvalid(1'b0), .m3_rready(1'b1),

        // Slave 0: Boot ROM (0x0000_0000 - 0x0000_FFFF)
        .s0_awaddr(rom_awaddr), .s0_awvalid(rom_awvalid),
        .s0_awready(rom_awready), .s0_wdata(rom_wdata),
        .s0_wstrb(rom_wstrb), .s0_wvalid(rom_wvalid),
        .s0_wready(rom_wready), .s0_bresp(rom_bresp),
        .s0_bvalid(rom_bvalid), .s0_bready(rom_bready),
        .s0_araddr(rom_araddr), .s0_arvalid(rom_arvalid),
        .s0_arready(rom_arready), .s0_rdata(rom_rdata),
        .s0_rresp(rom_rresp), .s0_rvalid(rom_rvalid),
        .s0_rready(rom_rready),

        // Slave 1: SRAM (0x0001_0000 - 0x0001_FFFF)
        .s1_awaddr(sram_awaddr), .s1_awvalid(sram_awvalid),
        .s1_awready(sram_awready), .s1_wdata(sram_wdata),
        .s1_wstrb(sram_wstrb), .s1_wvalid(sram_wvalid),
        .s1_wready(sram_wready), .s1_bresp(sram_bresp),
        .s1_bvalid(sram_bvalid), .s1_bready(sram_bready),
        .s1_araddr(sram_araddr), .s1_arvalid(sram_arvalid),
        .s1_arready(sram_arready), .s1_rdata(sram_rdata),
        .s1_rresp(sram_rresp), .s1_rvalid(sram_rvalid),
        .s1_rready(sram_rready),

        // Slave 2: EML_CSR (0x0002_0000 - 0x0002_0FFF)
        .s2_awaddr(eml_csr_awaddr), .s2_awvalid(eml_csr_awvalid),
        .s2_awready(eml_csr_awready), .s2_wdata(eml_csr_wdata),
        .s2_wstrb(eml_csr_wstrb), .s2_wvalid(eml_csr_wvalid),
        .s2_wready(eml_csr_wready), .s2_bresp(eml_csr_bresp),
        .s2_bvalid(eml_csr_bvalid), .s2_bready(eml_csr_bready),
        .s2_araddr(eml_csr_araddr), .s2_arvalid(eml_csr_arvalid),
        .s2_arready(eml_csr_arready), .s2_rdata(eml_csr_rdata),
        .s2_rresp(eml_csr_rresp), .s2_rvalid(eml_csr_rvalid),
        .s2_rready(eml_csr_rready),

        // Slave 3: SNN_CTRL (0x0002_1000 - 0x0002_1FFF)
        .s3_awaddr(snn_ctrl_awaddr), .s3_awvalid(snn_ctrl_awvalid),
        .s3_awready(snn_ctrl_awready), .s3_wdata(snn_ctrl_wdata),
        .s3_wstrb(snn_ctrl_wstrb), .s3_wvalid(snn_ctrl_wvalid),
        .s3_wready(snn_ctrl_wready), .s3_bresp(snn_ctrl_bresp),
        .s3_bvalid(snn_ctrl_bvalid), .s3_bready(snn_ctrl_bready),
        .s3_araddr(snn_ctrl_araddr), .s3_arvalid(snn_ctrl_arvalid),
        .s3_arready(snn_ctrl_arready), .s3_rdata(snn_ctrl_rdata),
        .s3_rresp(snn_ctrl_rresp), .s3_rvalid(snn_ctrl_rvalid),
        .s3_rready(snn_ctrl_rready),

        // Slave 4: NVM_CTRL (0x0002_2000 - 0x0002_2FFF)
        .s4_awaddr(nvm_ctrl_awaddr), .s4_awvalid(nvm_ctrl_awvalid),
        .s4_awready(nvm_ctrl_awready), .s4_wdata(nvm_ctrl_wdata),
        .s4_wstrb(nvm_ctrl_wstrb), .s4_wvalid(nvm_ctrl_wvalid),
        .s4_wready(nvm_ctrl_wready), .s4_bresp(nvm_ctrl_bresp),
        .s4_bvalid(nvm_ctrl_bvalid), .s4_bready(nvm_ctrl_bready),
        .s4_araddr(nvm_ctrl_araddr), .s4_arvalid(nvm_ctrl_arvalid),
        .s4_arready(nvm_ctrl_arready), .s4_rdata(nvm_ctrl_rdata),
        .s4_rresp(nvm_ctrl_rresp), .s4_rvalid(nvm_ctrl_rvalid),
        .s4_rready(nvm_ctrl_rready)
    );

    // Peripheral slaves (inline models)
    // Boot ROM
    assign rom_rdata     = (rom_araddr[11:2] < 1024) ? instr_rom[rom_araddr[11:2]] : 32'h0;
    assign rom_rvalid    = rom_arvalid;
    assign rom_rresp     = 2'b00;
    assign rom_bvalid    = 1'b0;
    assign rom_bresp     = 2'b00;
    assign rom_awready   = 1'b0;
    assign rom_wready    = 1'b0;
    assign rom_arready   = rom_arvalid;

    // SRAM
    always @(posedge clk_core_gated) begin
        if (sram_awvalid && sram_wvalid && sram_awready && sram_wready) begin
            if (sram_wstrb[0]) sram_memory[sram_awaddr[13:2]][7:0]   <= sram_wdata[7:0];
            if (sram_wstrb[1]) sram_memory[sram_awaddr[13:2]][15:8]  <= sram_wdata[15:8];
            if (sram_wstrb[2]) sram_memory[sram_awaddr[13:2]][23:16] <= sram_wdata[23:16];
            if (sram_wstrb[3]) sram_memory[sram_awaddr[13:2]][31:24] <= sram_wdata[31:24];
        end
    end
    assign sram_rdata    = sram_memory[sram_araddr[13:2]];
    assign sram_rvalid   = sram_arvalid;
    assign sram_rresp    = 2'b00;
    assign sram_bvalid   = (sram_awvalid && sram_wvalid) ? 1'b1 : 1'b0;
    assign sram_bresp    = 2'b00;
    assign sram_awready  = 1'b1;
    assign sram_wready   = 1'b1;
    assign sram_arready  = 1'b1;

    // =========================================================================
    // EML Unit (v1.0 base + v1.1 DAG cache + v1.1 constant-time)
    // =========================================================================
    assign eml_cfg_int   = csr_xcew_cfg;
    assign eml_rs1       = 32'h0;  // Driven by Xcew instruction decode
    assign eml_rs2       = 32'h0;
    assign eml_valid_int = 1'b0;   // Driven by Xcew operation

    eml_unit eml_inst (
        .i_clk(clk_eml_gated),
        .i_rst(rst),
        .i_rs1(eml_rs1),
        .i_rs2(eml_rs2),
        .i_cfg(eml_cfg_int),
        .i_valid(eml_valid_int),
        .o_rd(eml_rd_int),
        .o_valid(eml_valid_out_int),
        .o_ready(eml_ready_int),
        .o_exc(eml_exc_int)
    );

    // EML DAG Cache (v1.1 Phase 6A)
    generate
        if (1) begin : dag_cache_blk
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
                .cache_tag_wr(), .cache_data_wr(), .cache_lru_wr(),
                .cache_tag_rd(), .cache_data_rd(), .cache_lru_rd(),
                .cache_data_out(32'h0), .cache_lru_out(8'h0)
            );
        end
    endgenerate

    // EML Constant-Time Execution (v1.1 Phase 6D)
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
        .rd(eml_rd_int),
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

    // EML Policy Determinism (v1.1 Phase 6D)
    assign det_en_int      = v1_1_en & csr_pol_sec[0];
    assign max_cycles_int  = csr_pol_sec[4:1];

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

    // EML CSR slave responses
    assign eml_csr_rdata  = 32'h0;
    assign eml_csr_rvalid = eml_csr_arvalid;
    assign eml_csr_rresp  = 2'b00;
    assign eml_csr_bvalid = (eml_csr_awvalid && eml_csr_wvalid) ? 1'b1 : 1'b0;
    assign eml_csr_bresp  = 2'b00;
    assign eml_csr_awready = 1'b1;
    assign eml_csr_wready  = 1'b1;
    assign eml_csr_arready  = 1'b1;

    // =========================================================================
    // SNN Tile (v1.0 base + v1.1 TTFS + v1.1 STDP)
    // =========================================================================
    assign snn_classify_en_int = 1'b0;  // Driven by Xcew instruction
    assign snn_spike_in_int    = 64'h0;
    assign snn_weight_ptr_int  = 16'h0;

    snn_tile snn_inst (
        .i_clk_snn(clk_snn_gated),
        .i_rst(rst),
        .i_spike_in(snn_spike_in_int),
        .i_weight_ptr(snn_weight_ptr_int),
        .i_classify_en(snn_classify_en_int),
        .o_class(snn_class_int),
        .o_conf(snn_conf_int),
        .o_done(snn_done_int)
    );

    // SNN TTFS Neuron (v1.1 Phase 6B)
    assign snn_ttfs_enable_int    = v1_1_en & csr_snn_ctrl_ext[7];
    assign snn_t_window_int       = csr_snn_ctrl_ext[10:8];
    assign snn_refractory_cycles_int = csr_snn_ctrl_ext[14:12];

    lif_ttfs_neuron snn_ttfs_inst (
        .clk(clk_snn_gated),
        .rst(rst),
        .ttfs_enable(snn_ttfs_enable_int),
        .t_window(snn_t_window_int),
        .refractory_cycles(snn_refractory_cycles_int),
        .input_current(snn_input_current_int),
        .current_valid(snn_current_valid_int),
        .spike_out(snn_spike_out_int),
        .spike_valid(snn_spike_valid_int),
        .membrane_potential(snn_membrane_potential_int),
        .v_threshold(32'h40000000),
        .v_rest(32'h0),
        .leak_factor(32'd100)
    );

    // SNN STDP Engine (v1.1 Phase 6B)
    assign snn_stdp_policy_int     = csr_snn_ctrl_ext[19:16];
    assign snn_stdp_enable_int     = v1_1_en & csr_snn_ctrl_ext[20];
    assign snn_learning_enable_int = v1_1_en & csr_snn_ctrl_ext[21];

    stdp_engine snn_stdp_inst (
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

    // SNN CSR slave responses
    assign snn_ctrl_rdata   = 32'h0;
    assign snn_ctrl_rvalid  = snn_ctrl_arvalid;
    assign snn_ctrl_rresp   = 2'b00;
    assign snn_ctrl_bvalid  = (snn_ctrl_awvalid && snn_ctrl_wvalid) ? 1'b1 : 1'b0;
    assign snn_ctrl_bresp   = 2'b00;
    assign snn_ctrl_awready = 1'b1;
    assign snn_ctrl_wready  = 1'b1;
    assign snn_ctrl_arready = 1'b1;

    // =========================================================================
    // NVM Controller (v1.0 base)
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

    // NVM CSR slave responses
    assign nvm_ctrl_rdata   = 32'h0;
    assign nvm_ctrl_rvalid  = nvm_ctrl_arvalid;
    assign nvm_ctrl_rresp   = 2'b00;
    assign nvm_ctrl_bvalid  = (nvm_ctrl_awvalid && nvm_ctrl_wvalid) ? 1'b1 : 1'b0;
    assign nvm_ctrl_bresp   = 2'b00;
    assign nvm_ctrl_awready = 1'b1;
    assign nvm_ctrl_wready  = 1'b1;
    assign nvm_ctrl_arready = 1'b1;

    // =========================================================================
    // Power Orchestrator (v1.1 Phase 6C)
    // =========================================================================
    assign wake_irq_trigger_int = o_irq_eml | o_irq_snn | o_irq_nvm;
    assign axi_activity_int     = core_mem_we | (~core_mem_we);

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
        .irq_trigger(wake_irq_trigger_int),
        .axi_activity(axi_activity_int),
        .csr_addr(core_csr_addr),
        .csr_wr_en(core_csr_wr_en),
        .csr_wr_data(core_csr_wr_data),
        .csr_rd_data(csr_pwr_ctrl)
    );

    // Retention registers for each tile
    retention_reg ret_eml (.clk(clk_core_gated), .rst(rst),
        .ret_en(tile_ret_en_int[1]), .iso_en(tile_iso_en_int[1]),
        .din(eml_rd_int), .dout(), .scan_mode(1'b0));
    retention_reg ret_snn (.clk(clk_core_gated), .rst(rst),
        .ret_en(tile_ret_en_int[2]), .iso_en(tile_iso_en_int[2]),
        .din({snn_class_int, snn_conf_int}), .dout(), .scan_mode(1'b0));
    retention_reg ret_nvm (.clk(clk_core_gated), .rst(rst),
        .ret_en(tile_ret_en_int[3]), .iso_en(tile_iso_en_int[3]),
        .din(nvm_rd_data_int), .dout(), .scan_mode(1'b0));

    // =========================================================================
    // Body Bias Controller (v1.1 Phase 6C)
    // =========================================================================
    assign bias_code_int = v1_1_en ? csr_bias_ctrl[7:0] : 8'h80;
    assign cal_en_int    = v1_1_en ? csr_bias_ctrl[8]   : 1'b0;

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
        .csr_rd_data(csr_bias_ctrl)
    );

    // =========================================================================
    // Fault Monitor (v1.1 Phase 6D)
    // =========================================================================
    assign fault_irq_int      = 1'b0;       // Driven by fault_monitor
    assign pipeline_halt_int  = 1'b0;       // Driven by fault_monitor
    assign soft_error_int     = 4'h0;
    assign hard_error_int     = 4'h0;
    assign ecc_error_int      = nvm_ecc_err_int;
    assign watchdog_trip_int  = 1'b0;
    assign fault_detected_int = 1'b0;
    assign fault_clr_int      = 1'b0;
    assign irq_enable_int     = 1'b1;

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
        .csr_rd_data(csr_fault_status)
    );

    // =========================================================================
    // Status register update (combines signals from all units)
    // =========================================================================
    always @(posedge clk_core or posedge rst) begin
        if (rst) begin
            csr_xcew_status <= 32'h0;
        end else begin
            csr_xcew_status[31:4]  <= 28'h0;  // PIPELINE_STAGE (wired to EML)
            csr_xcew_status[3]     <= o_irq_eml | o_irq_snn | o_irq_fault;
            csr_xcew_status[2]     <= nvm_busy_int;
            csr_xcew_status[1]     <= eml_exc_int;
            csr_xcew_status[0]     <= 1'b0;
        end
    end

    // =========================================================================
    // Interrupt and memory routing
    // =========================================================================
    assign o_irq_eml   = 1'b0;  // Driven by EML unit
    assign o_irq_snn   = 1'b0;  // Driven by SNN unit
    assign o_irq_nvm   = 1'b0;  // Driven by NVM unit
    assign o_irq_fault = fault_irq_int;

    // Memory read data routing
    assign core_mem_rdata =
        (core_mem_addr[31:28] == 4'h0) ? core_rdata :
        (core_mem_addr[31:28] == 4'h1) ? core_rdata :
        (core_mem_addr[31:20] == 12'h200) ? core_rdata :
        (core_mem_addr[31:20] == 12'h210) ? core_rdata :
        (core_mem_addr[31:20] == 12'h220) ? core_rdata :
        32'h0;

    wire combined_exception = core_exception | core_addr_fault;

    // =========================================================================
    // Debug outputs
    // =========================================================================
    assign o_debug_uart   = 8'h00;
    assign o_debug_status = {
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
        combined_exception
    };

endmodule
