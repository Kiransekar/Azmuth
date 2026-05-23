// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// xcew_top.v
// Top-level module for Xcew Processor
// Implements the interface as specified in the architecture document
// Updated to include AXI4-Lite interconnect and SOC components
// Integrated EML DAG compression (v1.1) and SNN temporal coding (v1.1)

module xcew_top (
    // Clock and Reset
    input  wire         i_clk,
    input  wire         i_rst,

    // Interrupts
    output wire [3:0]   o_irq,

    // Debug
    output wire [7:0]   o_debug_uart
);

    // Internal clock and reset
    wire clk_250mhz = i_clk;
    wire rst_n = ~i_rst;  // Active-low reset for AXI

    // Core signals
    wire [31:0] core_pc;
    wire [31:0] core_instr;
    wire [31:0] core_mem_addr;
    wire [31:0] core_mem_wdata;
    wire core_mem_we;
    wire [3:0] core_mem_wstrb;
    wire [31:0] core_mem_rdata;
    wire [11:0] core_csr_addr;
    wire core_csr_wr_en;
    wire [31:0] core_csr_wr_data;
    reg [31:0] core_csr_rd_data;
    wire [31:0] core_xcew_req;
    wire core_xcew_ready;
    wire [31:0] core_xcew_resp;
    wire core_xcew_done;
    wire core_wb_stall;
    wire core_exception;
    wire core_interrupt;

    // AXI4-Lite interconnect signals
    // Master connections (Core, EML, SNN, NVM)
    wire [15:0] core_awaddr, eml_awaddr, snn_awaddr, nvm_awaddr;
    wire core_awvalid, eml_awvalid, snn_awvalid, nvm_awvalid;
    wire core_awready, eml_awready, snn_awready, nvm_awready;
    wire [31:0] core_wdata, eml_wdata, snn_wdata, nvm_wdata;
    wire [3:0] core_wstrb, eml_wstrb, snn_wstrb, nvm_wstrb;
    wire core_wvalid, eml_wvalid, snn_wvalid, nvm_wvalid;
    wire core_wready, eml_wready, snn_wready, nvm_wready;
    wire [1:0] core_bresp, eml_bresp, snn_bresp, nvm_bresp;
    wire core_bvalid, eml_bvalid, snn_bvalid, nvm_bvalid;
    wire core_bready, eml_bready, snn_bready, nvm_bready;

    wire [15:0] core_araddr, eml_araddr, snn_araddr, nvm_araddr;
    wire core_arvalid, eml_arvalid, snn_arvalid, nvm_arvalid;
    wire core_arready, eml_arready, snn_arready, nvm_arready;
    wire [31:0] core_rdata, eml_rdata, snn_rdata, nvm_rdata;
    wire [1:0] core_rresp, eml_rresp, snn_rresp, nvm_rresp;
    wire core_rvalid, eml_rvalid, snn_rvalid, nvm_rvalid;
    wire core_rready, eml_rready, snn_rready, nvm_rready;

    // Slave connections (Boot ROM, SRAM, EML, SNN, NVM)
    wire [15:0] rom_awaddr, sram_awaddr, eml_csr_awaddr, snn_ctrl_awaddr, nvm_ctrl_awaddr;
    wire rom_awvalid, sram_awvalid, eml_csr_awvalid, snn_ctrl_awvalid, nvm_ctrl_awvalid;
    wire rom_awready, sram_awready, eml_csr_awready, snn_ctrl_awready, nvm_ctrl_awready;
    wire [31:0] rom_wdata, sram_wdata, eml_csr_wdata, snn_ctrl_wdata, nvm_ctrl_wdata;
    wire [3:0] rom_wstrb, sram_wstrb, eml_csr_wstrb, snn_ctrl_wstrb, nvm_ctrl_wstrb;
    wire rom_wvalid, sram_wvalid, eml_csr_wvalid, snn_ctrl_wvalid, nvm_ctrl_wvalid;
    wire rom_wready, sram_wready, eml_csr_wready, snn_ctrl_wready, nvm_ctrl_wready;
    wire [1:0] rom_bresp, sram_bresp, eml_csr_bresp, snn_ctrl_bresp, nvm_ctrl_bresp;
    wire rom_bvalid, sram_bvalid, eml_csr_bvalid, snn_ctrl_bvalid, nvm_ctrl_bvalid;
    wire rom_bready, sram_bready, eml_csr_bready, snn_ctrl_bready, nvm_ctrl_bready;

    wire [15:0] rom_araddr, sram_araddr, eml_csr_araddr, snn_ctrl_araddr, nvm_ctrl_araddr;
    wire rom_arvalid, sram_arvalid, eml_csr_arvalid, snn_ctrl_arvalid, nvm_ctrl_arvalid;
    wire rom_arready, sram_arready, eml_csr_arready, snn_ctrl_arready, nvm_ctrl_arready;
    wire [31:0] rom_rdata, sram_rdata, eml_csr_rdata, snn_ctrl_rdata, nvm_ctrl_rdata;
    wire [1:0] rom_rresp, sram_rresp, eml_csr_rresp, snn_ctrl_rresp, nvm_ctrl_rresp;
    wire rom_rvalid, sram_rvalid, eml_csr_rvalid, snn_ctrl_rvalid, nvm_ctrl_rvalid;
    wire rom_rready, sram_rready, eml_csr_rready, snn_ctrl_rready, nvm_ctrl_rready;

    // Peripheral connections
    wire [31:0] boot_rom_rdata;
    wire [31:0] eml_csr_rdata_int, eml_csr_wdata_int;
    wire eml_csr_we_int;
    wire [31:0] snn_ctrl_rdata_int, snn_ctrl_wdata_int;
    wire snn_ctrl_we_int;
    wire [31:0] nvm_ctrl_rdata_int, nvm_ctrl_wdata_int;
    wire nvm_ctrl_we_int;

    // Xcew-specific connections
    wire [31:0] eml_xcew_req, snn_xcew_req, nvm_xcew_req;
    wire eml_xcew_ready, snn_xcew_ready, nvm_xcew_ready;
    wire [31:0] eml_xcew_resp, snn_xcew_resp, nvm_xcew_resp;
    wire eml_xcew_done, snn_xcew_done, nvm_xcew_done;

    // EML DAG cache signals (v1.1)
    wire [31:0] eml_expr_hash_in;
    wire [31:0] eml_expr_result_in;
    wire eml_expr_valid_in;
    wire eml_expr_compute_done;
    wire [31:0] eml_cached_result;
    wire eml_cache_hit;
    wire eml_cache_miss;
    wire [31:0] eml_alloc_addr;
    wire [31:0] eml_subexpr_hash;
    wire eml_subexpr_valid;
    wire eml_subexpr_cached;
    wire [31:0] eml_subexpr_result;

    // SNN TTFS and STDP signals (v1.1)
    reg snn_ttfs_enable;
    reg [2:0] snn_t_window;
    reg [2:0] snn_refractory_cycles;
    reg [3:0] snn_stdp_policy;
    reg snn_stdp_enable;
    reg snn_learning_enable;
    wire [31:0] snn_input_current;
    wire snn_current_valid;
    wire snn_spike_out;
    wire snn_spike_valid;
    wire [31:0] snn_membrane_potential;
    wire [7:0] snn_updated_weight;
    wire snn_weight_updated;

    // Address truncation for AXI compatibility (convert 32-bit to 16-bit)
    wire [15:0] core_mem_addr_16 = core_mem_addr[15:0];
    wire core_addr_fault = |core_mem_addr[31:16];  // Fault if upper bits non-zero

    // Instruction ROM (simplified for this example)
    reg [31:0] instr_rom [0:1023];  // Boot ROM content

    // Initialize ROM
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            instr_rom[i] = 32'h00000013; // NOP instruction
        end
        // Initialize first few instructions for testing
        instr_rom[0] = 32'h00000093; // ADDI x1, x0, 0
        instr_rom[1] = 32'h00A00093; // ADDI x1, x0, 10 (x1 = 10)
        instr_rom[2] = 32'h00B000B3; // ADD x1, x1, x0 (x1 = x1 + 0)
    end

    // Instantiate RISC-V core
    wire [31:0] core_rs1_data;
    wire [31:0] core_rs2_data;
    wire        core_xcew_valid;
    riscv_core core_inst (
        .clk(clk_250mhz),
        .rst(i_rst),
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
        .i_meip(1'b0),
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

    // Fetch from Boot ROM via AXI interconnect
    assign core_instr = (core_pc[12:2] < 11'd1024) ? instr_rom[core_pc[11:2]] : 32'h00000013; // Default NOP

    // AXI4-Lite interconnect
    axi_lite_interconnect_v1_1 interconnect_inst (
        .aclk(clk_250mhz),
        .aresetn(rst_n),

        // Master 0: Core (highest priority)
        .m0_awaddr(core_mem_addr_16),  // Use truncated address
        .m0_awvalid(core_mem_we),      // Write valid when WE is asserted
        .m0_awready(core_awready),
        .m0_wdata(core_mem_wdata),
        .m0_wstrb(core_mem_wstrb),
        .m0_wvalid(core_mem_we),       // Write valid when WE is asserted
        .m0_wready(core_wready),
        .m0_bresp(core_bresp),
        .m0_bvalid(core_bvalid),
        .m0_bready(core_bready),
        .m0_araddr(core_mem_addr_16),  // Use truncated address
        .m0_arvalid(~core_mem_we),     // Read valid when WE is not asserted
        .m0_arready(core_arready),
        .m0_rdata(core_rdata),
        .m0_rresp(core_rresp),
        .m0_rvalid(core_rvalid),
        .m0_rready(core_rready),

        // Master 1: EML (as master) - not connected yet
        .m1_awaddr(16'h0000),
        .m1_awvalid(1'b0),
        .m1_awready(),
        .m1_wdata(32'h00000000),
        .m1_wstrb(4'h0),
        .m1_wvalid(1'b0),
        .m1_wready(),
        .m1_bresp(),
        .m1_bvalid(),
        .m1_bready(1'b1),
        .m1_araddr(16'h0000),
        .m1_arvalid(1'b0),
        .m1_arready(),
        .m1_rdata(),
        .m1_rresp(),
        .m1_rvalid(),
        .m1_rready(1'b1),

        // Master 2: SNN (as master) - not connected yet
        .m2_awaddr(16'h0000),
        .m2_awvalid(1'b0),
        .m2_awready(),
        .m2_wdata(32'h00000000),
        .m2_wstrb(4'h0),
        .m2_wvalid(1'b0),
        .m2_wready(),
        .m2_bresp(),
        .m2_bvalid(),
        .m2_bready(1'b1),
        .m2_araddr(16'h0000),
        .m2_arvalid(1'b0),
        .m2_arready(),
        .m2_rdata(),
        .m2_rresp(),
        .m2_rvalid(),
        .m2_rready(1'b1),

        // Master 3: NVM (as master) - not connected yet
        .m3_awaddr(16'h0000),
        .m3_awvalid(1'b0),
        .m3_awready(),
        .m3_wdata(32'h00000000),
        .m3_wstrb(4'h0),
        .m3_wvalid(1'b0),
        .m3_wready(),
        .m3_bresp(),
        .m3_bvalid(),
        .m3_bready(1'b1),
        .m3_araddr(16'h0000),
        .m3_arvalid(1'b0),
        .m3_arready(),
        .m3_rdata(),
        .m3_rresp(),
        .m3_rvalid(),
        .m3_rready(1'b1),

        // Slave 0: Boot ROM (0x0000_0000–0x0000_FFFF)
        .s0_awaddr(rom_awaddr),
        .s0_awvalid(rom_awvalid),
        .s0_awready(rom_awready),
        .s0_wdata(rom_wdata),
        .s0_wstrb(rom_wstrb),
        .s0_wvalid(rom_wvalid),
        .s0_wready(rom_wready),
        .s0_bresp(rom_bresp),
        .s0_bvalid(rom_bvalid),
        .s0_bready(rom_bready),
        .s0_araddr(rom_araddr),
        .s0_arvalid(rom_arvalid),
        .s0_arready(rom_arready),
        .s0_rdata(rom_rdata),
        .s0_rresp(rom_rresp),
        .s0_rvalid(rom_rvalid),
        .s0_rready(rom_rready),

        // Slave 1: SRAM (0x0001_0000–0x0001_FFFF)
        .s1_awaddr(sram_awaddr),
        .s1_awvalid(sram_awvalid),
        .s1_awready(sram_awready),
        .s1_wdata(sram_wdata),
        .s1_wstrb(sram_wstrb),
        .s1_wvalid(sram_wvalid),
        .s1_wready(sram_wready),
        .s1_bresp(sram_bresp),
        .s1_bvalid(sram_bvalid),
        .s1_bready(sram_bready),
        .s1_araddr(sram_araddr),
        .s1_arvalid(sram_arvalid),
        .s1_arready(sram_arready),
        .s1_rdata(sram_rdata),
        .s1_rresp(sram_rresp),
        .s1_rvalid(sram_rvalid),
        .s1_rready(sram_rready),

        // Slave 2: EML_CSR + Memo Cache (0x0002_0000–0x0002_0FFF)
        .s2_awaddr(eml_csr_awaddr),
        .s2_awvalid(eml_csr_awvalid),
        .s2_awready(eml_csr_awready),
        .s2_wdata(eml_csr_wdata),
        .s2_wstrb(eml_csr_wstrb),
        .s2_wvalid(eml_csr_wvalid),
        .s2_wready(eml_csr_wready),
        .s2_bresp(eml_csr_bresp),
        .s2_bvalid(eml_csr_bvalid),
        .s2_bready(eml_csr_bready),
        .s2_araddr(eml_csr_araddr),
        .s2_arvalid(eml_csr_arvalid),
        .s2_arready(eml_csr_arready),
        .s2_rdata(eml_csr_rdata),
        .s2_rresp(eml_csr_rresp),
        .s2_rvalid(eml_csr_rvalid),
        .s2_rready(eml_csr_rready),

        // Slave 3: SNN_CTRL + Weight RAM (0x0002_1000–0x0002_1FFF)
        .s3_awaddr(snn_ctrl_awaddr),
        .s3_awvalid(snn_ctrl_awvalid),
        .s3_awready(snn_ctrl_awready),
        .s3_wdata(snn_ctrl_wdata),
        .s3_wstrb(snn_ctrl_wstrb),
        .s3_wvalid(snn_ctrl_wvalid),
        .s3_wready(snn_ctrl_wready),
        .s3_bresp(snn_ctrl_bresp),
        .s3_bvalid(snn_ctrl_bvalid),
        .s3_bready(snn_ctrl_bready),
        .s3_araddr(snn_ctrl_araddr),
        .s3_arvalid(snn_ctrl_arvalid),
        .s3_arready(snn_ctrl_arready),
        .s3_rdata(snn_ctrl_rdata),
        .s3_rresp(snn_ctrl_rresp),
        .s3_rvalid(snn_ctrl_rvalid),
        .s3_rready(snn_ctrl_rready),

        // Slave 4: NVM_CTRL + KB window (0x0002_2000–0x0002_2FFF)
        .s4_awaddr(nvm_ctrl_awaddr),
        .s4_awvalid(nvm_ctrl_awvalid),
        .s4_awready(nvm_ctrl_awready),
        .s4_wdata(nvm_ctrl_wdata),
        .s4_wstrb(nvm_ctrl_wstrb),
        .s4_wvalid(nvm_ctrl_wvalid),
        .s4_wready(nvm_ctrl_wready),
        .s4_bresp(nvm_ctrl_bresp),
        .s4_bvalid(nvm_ctrl_bvalid),
        .s4_bready(nvm_ctrl_bready),
        .s4_araddr(nvm_ctrl_araddr),
        .s4_arvalid(nvm_ctrl_arvalid),
        .s4_arready(nvm_ctrl_arready),
        .s4_rdata(nvm_ctrl_rdata),
        .s4_rresp(nvm_ctrl_rresp),
        .s4_rvalid(nvm_ctrl_rvalid),
        .s4_rready(nvm_ctrl_rready)
    );

    // Boot ROM (simplified)
    assign rom_rdata = (rom_araddr[12:2] < 11'd1024) ? instr_rom[rom_araddr[11:2]] : 32'h00000000;
    assign rom_rvalid = rom_arvalid;  // Always ready to respond (ROM)
    assign rom_rresp = 2'b00;  // OKAY response
    assign rom_bvalid = 1'b0;  // Boot ROM is read-only
    assign rom_bresp = 2'b00;  // OKAY response (won't occur)
    assign rom_awready = 1'b0; // Boot ROM is read-only
    assign rom_wready = 1'b0;  // Boot ROM is read-only
    assign rom_arready = rom_arvalid;  // Accept read requests immediately

    // SRAM
    reg [31:0] sram_memory [0:4095];  // 16KB SRAM (4K words * 32 bits)

    always @(posedge clk_250mhz) begin
        if (sram_awvalid && sram_wvalid && sram_awready && sram_wready) begin
            if (sram_wstrb[0]) sram_memory[sram_awaddr[13:2]][7:0]   <= sram_wdata[7:0];
            if (sram_wstrb[1]) sram_memory[sram_awaddr[13:2]][15:8]  <= sram_wdata[15:8];
            if (sram_wstrb[2]) sram_memory[sram_awaddr[13:2]][23:16] <= sram_wdata[23:16];
            if (sram_wstrb[3]) sram_memory[sram_awaddr[13:2]][31:24] <= sram_wdata[31:24];
        end
    end

    assign sram_rdata = sram_memory[sram_araddr[13:2]];
    assign sram_rvalid = sram_arvalid;  // Respond immediately
    assign sram_rresp = 2'b00;  // OKAY
    assign sram_bvalid = (sram_awvalid && sram_wvalid) ? 1'b1 : 1'b0;  // Write response
    assign sram_bresp = 2'b00;  // OKAY
    assign sram_awready = 1'b1;  // Always ready for write address
    assign sram_wready = 1'b1;   // Always ready for write data
    assign sram_arready = 1'b1;  // Always ready for read address

    // EML Unit with DAG Cache integration (v1.1)
    eml_unit eml_inst (
        .i_clk(clk_250mhz),
        .i_rst(i_rst),
        .i_rs1(32'h0),
        .i_rs2(32'h0),
        .i_cfg(32'h0),
        .i_valid(1'b0),  // Controlled by Xcew operations
        .o_rd(),
        .o_valid(),
        .o_ready(),
        .o_exc()
    );

    // EML DAG Cache (v1.1) - Integrated with CSR control
    wire [7:0]  dag_cache_tag_wr, dag_cache_data_wr, dag_cache_lru_wr;
    wire [7:0]  dag_cache_tag_rd, dag_cache_data_rd, dag_cache_lru_rd;
    wire [31:0] dag_cache_data_out;
    wire [7:0]  dag_cache_lru_out;
    assign dag_cache_data_out = 32'h0;
    assign dag_cache_lru_out = 8'h0;
    eml_dag_cache eml_dag_cache_inst (
        .clk(clk_250mhz),
        .rst(i_rst),
        .enable(1'b1),
        .dag_mode(1'b1),
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

    // EML CSR and Memo Cache with DAG extensions
    assign eml_csr_rdata = 32'h0;  // Simplified - in real implementation would connect to actual registers
    assign eml_csr_rvalid = eml_csr_arvalid;
    assign eml_csr_rresp = 2'b00;  // OKAY
    assign eml_csr_bvalid = (eml_csr_awvalid && eml_csr_wvalid) ? 1'b1 : 1'b0;
    assign eml_csr_bresp = 2'b00;  // OKAY
    assign eml_csr_awready = 1'b1;
    assign eml_csr_wready = 1'b1;
    assign eml_csr_arready = 1'b1;

    // SNN Tile (256 neurons)
    snn_tile_256 #(.NUM_NEURONS(256)) snn_inst (
        .i_clk_snn(clk_250mhz),
        .i_rst(i_rst),
        .i_classify_en(1'b0),
        .i_ttfs_enable(1'b0),
        .i_t_window(3'b011),
        .i_refractory_cycles(3'b001),
        .i_v_threshold(32'h40000000),
        .i_v_rest(32'h0),
        .i_input_current(32'h0),
        .i_neuron_idx(8'h0),
        .i_current_valid(1'b0),
        .o_class(),
        .o_conf(),
        .o_done(),
        .o_ready(),
        .o_spike_outs(),
        .o_spike_valids()
    );

    // SNN TTFS Neuron (v1.1)
    lif_ttfs_neuron_v1_1 snn_ttfs_inst (
        .clk(clk_250mhz),
        .rst(i_rst),
        .ttfs_enable(snn_ttfs_enable),
        .t_window(snn_t_window),
        .refractory_cycles(snn_refractory_cycles),
        .input_current(snn_input_current),
        .current_valid(snn_current_valid),
        .spike_out(snn_spike_out),
        .spike_valid(snn_spike_valid),
        .membrane_potential(snn_membrane_potential),
        .v_threshold(32'h40000000),  // Default threshold
        .v_rest(32'h00000000)       // Resting potential
    );

    // SNN STDP Engine (v1.1)
    stdp_engine_v1_1 snn_stdp_inst (
        .clk(clk_250mhz),
        .rst(i_rst),
        .stdp_policy(snn_stdp_policy),
        .stdp_enable(snn_stdp_enable),
        .pre_spike(1'b0),  // Simplified for integration
        .post_spike(1'b0), // Simplified for integration
        .pre_spike_time(32'h0),
        .post_spike_time(32'h0),
        .current_weight(8'h40),  // Default weight
        .updated_weight(snn_updated_weight),
        .weight_updated(snn_weight_updated),
        .A_plus(32'h02000000),
        .A_minus(32'h02000000),
        .tau_plus(32'd20),
        .tau_minus(32'd20),
        .learning_enable(snn_learning_enable)
    );

    // SNN Control and Weight RAM
    assign snn_ctrl_rdata = 32'h0;  // Simplified
    assign snn_ctrl_rvalid = snn_ctrl_arvalid;
    assign snn_ctrl_rresp = 2'b00;  // OKAY
    assign snn_ctrl_bvalid = (snn_ctrl_awvalid && snn_ctrl_wvalid) ? 1'b1 : 1'b0;
    assign snn_ctrl_bresp = 2'b00;  // OKAY
    assign snn_ctrl_awready = 1'b1;
    assign snn_ctrl_wready = 1'b1;
    assign snn_ctrl_arready = 1'b1;

    // NVM Controller
    nvm_ctrl nvm_inst (
        .i_clk_nvm(clk_250mhz),
        .i_rst(i_rst),
        .i_addr(16'h0),
        .i_wr_en(1'b0),
        .i_wr_data(32'h0),
        .i_rd_en(1'b0),
        .o_rd_data(),
        .o_busy(),
        .o_ecc_err()
    );

    // NVM Control and Knowledge Base
    assign nvm_ctrl_rdata = 32'h0;  // Simplified
    assign nvm_ctrl_rvalid = nvm_ctrl_arvalid;
    assign nvm_ctrl_rresp = 2'b00;  // OKAY
    assign nvm_ctrl_bvalid = (nvm_ctrl_awvalid && nvm_ctrl_wvalid) ? 1'b1 : 1'b0;
    assign nvm_ctrl_bresp = 2'b00;  // OKAY
    assign nvm_ctrl_awready = 1'b1;
    assign nvm_ctrl_wready = 1'b1;
    assign nvm_ctrl_arready = 1'b1;

    // CSR Address Map for v1.1 Extensions:
    // 0x7C0-0x7C4: Original v1.0 Xcew CSRs
    // 0x7C5: SNN Control (extended for TTFS and STDP controls)
    // 0x7C6: EML DAG Control (new for v1.1)
    // 0x7C7: Reserved for future extensions

    // CSR Read Logic
    wire [11:0] csr_addr = core_csr_addr;
    wire csr_wr_en = core_csr_wr_en;
    wire [31:0] csr_wr_data = core_csr_wr_data;

    // Internal CSR storage for extended functions
    reg [31:0] csr_xcew_cfg_extended = 32'h0;      // 0x7C5 - Extended SNN control
    reg [31:0] csr_eml_dag_ctl = 32'h0;            // 0x7C6 - EML DAG control

    // CSR read multiplexer
    always @(*) begin
        case (csr_addr)
            12'h7C0: core_csr_rd_data = 32'h0;  // Original Xcew config
            12'h7C1: core_csr_rd_data = 32'h0;  // Original Xcew status
            12'h7C2: core_csr_rd_data = 32'h0;  // Original EML config
            12'h7C3: core_csr_rd_data = 32'h0;  // Original SNN config
            12'h7C4: core_csr_rd_data = 32'h0;  // Original NVM config
            12'h7C5: core_csr_rd_data = csr_xcew_cfg_extended;  // Extended SNN control
            12'h7C6: core_csr_rd_data = csr_eml_dag_ctl;         // EML DAG control
            default: core_csr_rd_data = 32'h0;
        endcase
    end

    // CSR write logic
    always @(posedge clk_250mhz or posedge i_rst) begin
        if (i_rst) begin
            csr_xcew_cfg_extended <= 32'h0;
            csr_eml_dag_ctl <= 32'h0;
            snn_ttfs_enable <= 1'b0;
            snn_t_window <= 3'b000;
            snn_refractory_cycles <= 3'b000;
            snn_stdp_policy <= 4'h0;
            snn_stdp_enable <= 1'b0;
            snn_learning_enable <= 1'b0;
        end
        else if (csr_wr_en) begin
            case (csr_addr)
                12'h7C5: begin
                    csr_xcew_cfg_extended <= csr_wr_data;
                    // Extract SNN control bits
                    snn_ttfs_enable <= csr_wr_data[7];      // TTFS enable
                    snn_t_window <= csr_wr_data[10:8];      // Temporal window
                    snn_refractory_cycles <= csr_wr_data[14:12]; // Refractory cycles
                    snn_stdp_policy <= csr_wr_data[19:16];  // STDP policy
                    snn_stdp_enable <= csr_wr_data[20];     // STDP enable
                    snn_learning_enable <= csr_wr_data[21]; // Learning enable
                end
                12'h7C6: begin
                    csr_eml_dag_ctl <= csr_wr_data;
                    // Extract EML DAG control bits
                    // Bit 0: DAG mode enable
                    // Bits 1-7: Cache policy
                    // Bits 8-15: Compression algorithm
                end
                default: begin
                    // Handle other CSRs as needed
                end
            endcase
        end
    end

    // Connect interconnect output to core
    assign core_mem_rdata = (core_mem_addr[31:28] == 4'h0) ? core_rdata :  // ROM
                           (core_mem_addr[31:28] == 4'h1) ? core_rdata :  // SRAM
                           (core_mem_addr[31:20] == 12'h200) ? core_rdata :  // EML CSR
                           (core_mem_addr[31:20] == 12'h210) ? core_rdata : // SNN Ctrl
                           (core_mem_addr[31:20] == 12'h220) ? core_rdata : // NVM Ctrl
                           32'h0;  // Default

    // Update exception with address fault
    wire combined_exception = core_exception | core_addr_fault;

    // Assign outputs
    assign o_irq = {core_interrupt, 3'b000};  // Simplified - only core interrupt for now
    assign o_debug_uart = 8'h00;  // Default to 0, would connect to debug module in full implementation

endmodule