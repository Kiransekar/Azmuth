// axi_lite_interconnect.v
// AXI4-Lite Crossbar Interconnect for Xcew SOC
// 4 Masters, 5 Slaves with fixed priority arbitration

module axi_lite_interconnect (
    input  wire        aclk,
    input  wire        aresetn,

    // Master 0: Core (highest priority)
    input  wire [15:0] m0_awaddr,
    input  wire        m0_awvalid,
    output wire        m0_awready,
    input  wire [31:0] m0_wdata,
    input  wire [3:0]  m0_wstrb,
    input  wire        m0_wvalid,
    output wire        m0_wready,
    output wire [1:0]  m0_bresp,
    output wire        m0_bvalid,
    input  wire        m0_bready,

    input  wire [15:0] m0_araddr,
    input  wire        m0_arvalid,
    output wire        m0_arready,
    output wire [31:0] m0_rdata,
    output wire [1:0]  m0_rresp,
    output wire        m0_rvalid,
    input  wire        m0_rready,

    // Master 1: EML
    input  wire [15:0] m1_awaddr,
    input  wire        m1_awvalid,
    output wire        m1_awready,
    input  wire [31:0] m1_wdata,
    input  wire [3:0]  m1_wstrb,
    input  wire        m1_wvalid,
    output wire        m1_wready,
    output wire [1:0]  m1_bresp,
    output wire        m1_bvalid,
    input  wire        m1_bready,

    input  wire [15:0] m1_araddr,
    input  wire        m1_arvalid,
    output wire        m1_arready,
    output wire [31:0] m1_rdata,
    output wire [1:0]  m1_rresp,
    output wire        m1_rvalid,
    input  wire        m1_rready,

    // Master 2: SNN
    input  wire [15:0] m2_awaddr,
    input  wire        m2_awvalid,
    output wire        m2_awready,
    input  wire [31:0] m2_wdata,
    input  wire [3:0]  m2_wstrb,
    input  wire        m2_wvalid,
    output wire        m2_wready,
    output wire [1:0]  m2_bresp,
    output wire        m2_bvalid,
    input  wire        m2_bready,

    input  wire [15:0] m2_araddr,
    input  wire        m2_arvalid,
    output wire        m2_arready,
    output wire [31:0] m2_rdata,
    output wire [1:0]  m2_rresp,
    output wire        m2_rvalid,
    input  wire        m2_rready,

    // Master 3: NVM
    input  wire [15:0] m3_awaddr,
    input  wire        m3_awvalid,
    output wire        m3_awready,
    input  wire [31:0] m3_wdata,
    input  wire [3:0]  m3_wstrb,
    input  wire        m3_wvalid,
    output wire        m3_wready,
    output wire [1:0]  m3_bresp,
    output wire        m3_bvalid,
    input  wire        m3_bready,

    input  wire [15:0] m3_araddr,
    input  wire        m3_arvalid,
    output wire        m3_arready,
    output wire [31:0] m3_rdata,
    output wire [1:0]  m3_rresp,
    output wire        m3_rvalid,
    input  wire        m3_rready,

    // Slave 0: Boot ROM (0x0000_0000-0x0000_FFFF)
    output wire [15:0] s0_awaddr,
    output wire        s0_awvalid,
    input  wire        s0_awready,
    output wire [31:0] s0_wdata,
    output wire [3:0]  s0_wstrb,
    output wire        s0_wvalid,
    input  wire        s0_wready,
    input  wire [1:0]  s0_bresp,
    input  wire        s0_bvalid,
    output wire        s0_bready,

    output wire [15:0] s0_araddr,
    output wire        s0_arvalid,
    input  wire        s0_arready,
    input  wire [31:0] s0_rdata,
    input  wire [1:0]  s0_rresp,
    input  wire        s0_rvalid,
    output wire        s0_rready,

    // Slave 1: SRAM (0x0001_0000-0x0001_FFFF)
    output wire [15:0] s1_awaddr,
    output wire        s1_awvalid,
    input  wire        s1_awready,
    output wire [31:0] s1_wdata,
    output wire [3:0]  s1_wstrb,
    output wire        s1_wvalid,
    input  wire        s1_wready,
    input  wire [1:0]  s1_bresp,
    input  wire        s1_bvalid,
    output wire        s1_bready,

    output wire [15:0] s1_araddr,
    output wire        s1_arvalid,
    input  wire        s1_arready,
    input  wire [31:0] s1_rdata,
    input  wire [1:0]  s1_rresp,
    input  wire        s1_rvalid,
    output wire        s1_rready,

    // Slave 2: EML_CSR + Memo Cache (0x0002_0000-0x0002_0FFF)
    output wire [15:0] s2_awaddr,
    output wire        s2_awvalid,
    input  wire        s2_awready,
    output wire [31:0] s2_wdata,
    output wire [3:0]  s2_wstrb,
    output wire        s2_wvalid,
    input  wire        s2_wready,
    input  wire [1:0]  s2_bresp,
    input  wire        s2_bvalid,
    output wire        s2_bready,

    output wire [15:0] s2_araddr,
    output wire        s2_arvalid,
    input  wire        s2_arready,
    input  wire [31:0] s2_rdata,
    input  wire [1:0]  s2_rresp,
    input  wire        s2_rvalid,
    output wire        s2_rready,

    // Slave 3: SNN_CTRL + Weight RAM (0x0002_1000-0x0002_1FFF)
    output wire [15:0] s3_awaddr,
    output wire        s3_awvalid,
    input  wire        s3_awready,
    output wire [31:0] s3_wdata,
    output wire [3:0]  s3_wstrb,
    output wire        s3_wvalid,
    input  wire        s3_wready,
    input  wire [1:0]  s3_bresp,
    input  wire        s3_bvalid,
    output wire        s3_bready,

    output wire [15:0] s3_araddr,
    output wire        s3_arvalid,
    input  wire        s3_arready,
    input  wire [31:0] s3_rdata,
    input  wire [1:0]  s3_rresp,
    input  wire        s3_rvalid,
    output wire        s3_rready,

    // Slave 4: NVM_CTRL + KB (0x0002_2000-0x0002_2FFF)
    output wire [15:0] s4_awaddr,
    output wire        s4_awvalid,
    input  wire        s4_awready,
    output wire [31:0] s4_wdata,
    output wire [3:0]  s4_wstrb,
    output wire        s4_wvalid,
    input  wire        s4_wready,
    input  wire [1:0]  s4_bresp,
    input  wire        s4_bvalid,
    output wire        s4_bready,

    output wire [15:0] s4_araddr,
    output wire        s4_arvalid,
    input  wire        s4_arready,
    input  wire [31:0] s4_rdata,
    input  wire [1:0]  s4_rresp,
    input  wire        s4_rvalid,
    output wire        s4_rready
);

    localparam NUM_MASTERS = 4;
    localparam NUM_SLAVES = 5;
    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 32;
    localparam STRB_WIDTH = 4;

    // Address constants
    localparam [15:0] ROM_BASE = 16'h0000;
    localparam [15:0] ROM_END  = 16'h0FFF;
    localparam [15:0] SRAM_BASE = 16'h1000;
    localparam [15:0] SRAM_END  = 16'h1FFF;
    localparam [15:0] EML_BASE = 16'h2000;
    localparam [15:0] EML_END  = 16'h20FF;
    localparam [15:0] SNN_BASE = 16'h2100;
    localparam [15:0] SNN_END  = 16'h21FF;
    localparam [15:0] NVM_BASE = 16'h2200;
    localparam [15:0] NVM_END  = 16'h22FF;

    // Address decoder: combinational, one-hot slave select per master
    wire [4:0] m0_aw_slave_sel;
    wire [4:0] m1_aw_slave_sel;
    wire [4:0] m2_aw_slave_sel;
    wire [4:0] m3_aw_slave_sel;
    wire [4:0] m0_ar_slave_sel;
    wire [4:0] m1_ar_slave_sel;
    wire [4:0] m2_ar_slave_sel;
    wire [4:0] m3_ar_slave_sel;

    assign m0_aw_slave_sel = (m0_awaddr >= ROM_BASE && m0_awaddr <= ROM_END) ? 5'b00001 :
                            (m0_awaddr >= SRAM_BASE && m0_awaddr <= SRAM_END) ? 5'b00010 :
                            (m0_awaddr >= EML_BASE && m0_awaddr <= EML_END) ? 5'b00100 :
                            (m0_awaddr >= SNN_BASE && m0_awaddr <= SNN_END) ? 5'b01000 :
                            (m0_awaddr >= NVM_BASE && m0_awaddr <= NVM_END) ? 5'b10000 : 5'b00000;

    assign m1_aw_slave_sel = (m1_awaddr >= ROM_BASE && m1_awaddr <= ROM_END) ? 5'b00001 :
                            (m1_awaddr >= SRAM_BASE && m1_awaddr <= SRAM_END) ? 5'b00010 :
                            (m1_awaddr >= EML_BASE && m1_awaddr <= EML_END) ? 5'b00100 :
                            (m1_awaddr >= SNN_BASE && m1_awaddr <= SNN_END) ? 5'b01000 :
                            (m1_awaddr >= NVM_BASE && m1_awaddr <= NVM_END) ? 5'b10000 : 5'b00000;

    assign m2_aw_slave_sel = (m2_awaddr >= ROM_BASE && m2_awaddr <= ROM_END) ? 5'b00001 :
                            (m2_awaddr >= SRAM_BASE && m2_awaddr <= SRAM_END) ? 5'b00010 :
                            (m2_awaddr >= EML_BASE && m2_awaddr <= EML_END) ? 5'b00100 :
                            (m2_awaddr >= SNN_BASE && m2_awaddr <= SNN_END) ? 5'b01000 :
                            (m2_awaddr >= NVM_BASE && m2_awaddr <= NVM_END) ? 5'b10000 : 5'b00000;

    assign m3_aw_slave_sel = (m3_awaddr >= ROM_BASE && m3_awaddr <= ROM_END) ? 5'b00001 :
                            (m3_awaddr >= SRAM_BASE && m3_awaddr <= SRAM_END) ? 5'b00010 :
                            (m3_awaddr >= EML_BASE && m3_awaddr <= EML_END) ? 5'b00100 :
                            (m3_awaddr >= SNN_BASE && m3_awaddr <= SNN_END) ? 5'b01000 :
                            (m3_awaddr >= NVM_BASE && m3_awaddr <= NVM_END) ? 5'b10000 : 5'b00000;

    assign m0_ar_slave_sel = (m0_araddr >= ROM_BASE && m0_araddr <= ROM_END) ? 5'b00001 :
                            (m0_araddr >= SRAM_BASE && m0_araddr <= SRAM_END) ? 5'b00010 :
                            (m0_araddr >= EML_BASE && m0_araddr <= EML_END) ? 5'b00100 :
                            (m0_araddr >= SNN_BASE && m0_araddr <= SNN_END) ? 5'b01000 :
                            (m0_araddr >= NVM_BASE && m0_araddr <= NVM_END) ? 5'b10000 : 5'b00000;

    assign m1_ar_slave_sel = (m1_araddr >= ROM_BASE && m1_araddr <= ROM_END) ? 5'b00001 :
                            (m1_araddr >= SRAM_BASE && m1_araddr <= SRAM_END) ? 5'b00010 :
                            (m1_araddr >= EML_BASE && m1_araddr <= EML_END) ? 5'b00100 :
                            (m1_araddr >= SNN_BASE && m1_araddr <= SNN_END) ? 5'b01000 :
                            (m1_araddr >= NVM_BASE && m1_araddr <= NVM_END) ? 5'b10000 : 5'b00000;

    assign m2_ar_slave_sel = (m2_araddr >= ROM_BASE && m2_araddr <= ROM_END) ? 5'b00001 :
                            (m2_araddr >= SRAM_BASE && m2_araddr <= SRAM_END) ? 5'b00010 :
                            (m2_araddr >= EML_BASE && m2_araddr <= EML_END) ? 5'b00100 :
                            (m2_araddr >= SNN_BASE && m2_araddr <= SNN_END) ? 5'b01000 :
                            (m2_araddr >= NVM_BASE && m2_araddr <= NVM_END) ? 5'b10000 : 5'b00000;

    assign m3_ar_slave_sel = (m3_araddr >= ROM_BASE && m3_araddr <= ROM_END) ? 5'b00001 :
                            (m3_araddr >= SRAM_BASE && m3_araddr <= SRAM_END) ? 5'b00010 :
                            (m3_araddr >= EML_BASE && m3_araddr <= EML_END) ? 5'b00100 :
                            (m3_araddr >= SNN_BASE && m3_araddr <= SNN_END) ? 5'b01000 :
                            (m3_araddr >= NVM_BASE && m3_araddr <= NVM_END) ? 5'b10000 : 5'b00000;

    // Arbitration: Core > EML > SNN > NVM
    wire [NUM_MASTERS-1:0] aw_req = {m3_awvalid, m2_awvalid, m1_awvalid, m0_awvalid};
    wire [NUM_MASTERS-1:0] ar_req = {m3_arvalid, m2_arvalid, m1_arvalid, m0_arvalid};

    // Fixed priority arbiter for write address channel
    wire [NUM_MASTERS-1:0] aw_select;
    wire [NUM_MASTERS-1:0] w_select;
    wire [NUM_MASTERS-1:0] ar_select;
    wire [NUM_MASTERS-1:0] r_select;

    assign aw_select = aw_req[0] ? 4'b0001 :  // Core has highest priority
                      aw_req[1] ? 4'b0010 :  // EML
                      aw_req[2] ? 4'b0100 :  // SNN
                      aw_req[3] ? 4'b1000 :  // NVM
                      4'b0000;

    // Fixed priority arbiter for read address channel
    assign ar_select = ar_req[0] ? 4'b0001 :  // Core has highest priority
                      ar_req[1] ? 4'b0010 :  // EML
                      ar_req[2] ? 4'b0100 :  // SNN
                      ar_req[3] ? 4'b1000 :  // NVM
                      4'b0000;

    // W and B channels follow AW grant
    assign w_select = aw_select;
    assign r_select = ar_select;

    // Ready signals (single driver for each master)
    // AWREADY logic
    reg m0_awready_int, m1_awready_int, m2_awready_int, m3_awready_int;
    reg m0_wready_int, m1_wready_int, m2_wready_int, m3_wready_int;
    reg m0_arready_int, m1_arready_int, m2_arready_int, m3_arready_int;
    reg m0_rready_int, m1_rready_int, m2_rready_int, m3_rready_int;

    always @(*) begin
        m0_awready_int = 1'b0;
        if (aw_select[0]) begin  // Core granted
            case (1'b1)
                m0_aw_slave_sel[0]: m0_awready_int = s0_awready;  // ROM
                m0_aw_slave_sel[1]: m0_awready_int = s1_awready;  // SRAM
                m0_aw_slave_sel[2]: m0_awready_int = s2_awready;  // EML
                m0_aw_slave_sel[3]: m0_awready_int = s3_awready;  // SNN
                m0_aw_slave_sel[4]: m0_awready_int = s4_awready;  // NVM
                default: m0_awready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m1_awready_int = 1'b0;
        if (aw_select[1]) begin  // EML granted
            case (1'b1)
                m1_aw_slave_sel[0]: m1_awready_int = s0_awready;  // ROM
                m1_aw_slave_sel[1]: m1_awready_int = s1_awready;  // SRAM
                m1_aw_slave_sel[2]: m1_awready_int = s2_awready;  // EML
                m1_aw_slave_sel[3]: m1_awready_int = s3_awready;  // SNN
                m1_aw_slave_sel[4]: m1_awready_int = s4_awready;  // NVM
                default: m1_awready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m2_awready_int = 1'b0;
        if (aw_select[2]) begin  // SNN granted
            case (1'b1)
                m2_aw_slave_sel[0]: m2_awready_int = s0_awready;  // ROM
                m2_aw_slave_sel[1]: m2_awready_int = s1_awready;  // SRAM
                m2_aw_slave_sel[2]: m2_awready_int = s2_awready;  // EML
                m2_aw_slave_sel[3]: m2_awready_int = s3_awready;  // SNN
                m2_aw_slave_sel[4]: m2_awready_int = s4_awready;  // NVM
                default: m2_awready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m3_awready_int = 1'b0;
        if (aw_select[3]) begin  // NVM granted
            case (1'b1)
                m3_aw_slave_sel[0]: m3_awready_int = s0_awready;  // ROM
                m3_aw_slave_sel[1]: m3_awready_int = s1_awready;  // SRAM
                m3_aw_slave_sel[2]: m3_awready_int = s2_awready;  // EML
                m3_aw_slave_sel[3]: m3_awready_int = s3_awready;  // SNN
                m3_aw_slave_sel[4]: m3_awready_int = s4_awready;  // NVM
                default: m3_awready_int = 1'b0;
            endcase
        end
    end

    assign m0_awready = m0_awready_int;
    assign m1_awready = m1_awready_int;
    assign m2_awready = m2_awready_int;
    assign m3_awready = m3_awready_int;

    // WREADY logic
    always @(*) begin
        m0_wready_int = 1'b0;
        if (w_select[0]) begin  // Core granted
            case (1'b1)
                m0_aw_slave_sel[0]: m0_wready_int = s0_wready;  // ROM
                m0_aw_slave_sel[1]: m0_wready_int = s1_wready;  // SRAM
                m0_aw_slave_sel[2]: m0_wready_int = s2_wready;  // EML
                m0_aw_slave_sel[3]: m0_wready_int = s3_wready;  // SNN
                m0_aw_slave_sel[4]: m0_wready_int = s4_wready;  // NVM
                default: m0_wready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m1_wready_int = 1'b0;
        if (w_select[1]) begin  // EML granted
            case (1'b1)
                m1_aw_slave_sel[0]: m1_wready_int = s0_wready;  // ROM
                m1_aw_slave_sel[1]: m1_wready_int = s1_wready;  // SRAM
                m1_aw_slave_sel[2]: m1_wready_int = s2_wready;  // EML
                m1_aw_slave_sel[3]: m1_wready_int = s3_wready;  // SNN
                m1_aw_slave_sel[4]: m1_wready_int = s4_wready;  // NVM
                default: m1_wready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m2_wready_int = 1'b0;
        if (w_select[2]) begin  // SNN granted
            case (1'b1)
                m2_aw_slave_sel[0]: m2_wready_int = s0_wready;  // ROM
                m2_aw_slave_sel[1]: m2_wready_int = s1_wready;  // SRAM
                m2_aw_slave_sel[2]: m2_wready_int = s2_wready;  // EML
                m2_aw_slave_sel[3]: m2_wready_int = s3_wready;  // SNN
                m2_aw_slave_sel[4]: m2_wready_int = s4_wready;  // NVM
                default: m2_wready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m3_wready_int = 1'b0;
        if (w_select[3]) begin  // NVM granted
            case (1'b1)
                m3_aw_slave_sel[0]: m3_wready_int = s0_wready;  // ROM
                m3_aw_slave_sel[1]: m3_wready_int = s1_wready;  // SRAM
                m3_aw_slave_sel[2]: m3_wready_int = s2_wready;  // EML
                m3_aw_slave_sel[3]: m3_wready_int = s3_wready;  // SNN
                m3_aw_slave_sel[4]: m3_wready_int = s4_wready;  // NVM
                default: m3_wready_int = 1'b0;
            endcase
        end
    end

    assign m0_wready = m0_wready_int;
    assign m1_wready = m1_wready_int;
    assign m2_wready = m2_wready_int;
    assign m3_wready = m3_wready_int;

    // ARREADY logic
    always @(*) begin
        m0_arready_int = 1'b0;
        if (ar_select[0]) begin  // Core granted
            case (1'b1)
                m0_ar_slave_sel[0]: m0_arready_int = s0_arready;  // ROM
                m0_ar_slave_sel[1]: m0_arready_int = s1_arready;  // SRAM
                m0_ar_slave_sel[2]: m0_arready_int = s2_arready;  // EML
                m0_ar_slave_sel[3]: m0_arready_int = s3_arready;  // SNN
                m0_ar_slave_sel[4]: m0_arready_int = s4_arready;  // NVM
                default: m0_arready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m1_arready_int = 1'b0;
        if (ar_select[1]) begin  // EML granted
            case (1'b1)
                m1_ar_slave_sel[0]: m1_arready_int = s0_arready;  // ROM
                m1_ar_slave_sel[1]: m1_arready_int = s1_arready;  // SRAM
                m1_ar_slave_sel[2]: m1_arready_int = s2_arready;  // EML
                m1_ar_slave_sel[3]: m1_arready_int = s3_arready;  // SNN
                m1_ar_slave_sel[4]: m1_arready_int = s4_arready;  // NVM
                default: m1_arready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m2_arready_int = 1'b0;
        if (ar_select[2]) begin  // SNN granted
            case (1'b1)
                m2_ar_slave_sel[0]: m2_arready_int = s0_arready;  // ROM
                m2_ar_slave_sel[1]: m2_arready_int = s1_arready;  // SRAM
                m2_ar_slave_sel[2]: m2_arready_int = s2_arready;  // EML
                m2_ar_slave_sel[3]: m2_arready_int = s3_arready;  // SNN
                m2_ar_slave_sel[4]: m2_arready_int = s4_arready;  // NVM
                default: m2_arready_int = 1'b0;
            endcase
        end
    end

    always @(*) begin
        m3_arready_int = 1'b0;
        if (ar_select[3]) begin  // NVM granted
            case (1'b1)
                m3_ar_slave_sel[0]: m3_arready_int = s0_arready;  // ROM
                m3_ar_slave_sel[1]: m3_arready_int = s1_arready;  // SRAM
                m3_ar_slave_sel[2]: m3_arready_int = s2_arready;  // EML
                m3_ar_slave_sel[3]: m3_arready_int = s3_arready;  // SNN
                m3_ar_slave_sel[4]: m3_arready_int = s4_arready;  // NVM
                default: m3_arready_int = 1'b0;
            endcase
        end
    end

    assign m0_arready = m0_arready_int;
    assign m1_arready = m1_arready_int;
    assign m2_arready = m2_arready_int;
    assign m3_arready = m3_arready_int;

    // Channel connection logic
    // Write address channel
    assign s0_awaddr = aw_select[0] && m0_aw_slave_sel[0] ? m0_awaddr :
                      aw_select[1] && m1_aw_slave_sel[0] ? m1_awaddr :
                      aw_select[2] && m2_aw_slave_sel[0] ? m2_awaddr :
                      aw_select[3] && m3_aw_slave_sel[0] ? m3_awaddr : 16'h0000;
    assign s0_awvalid = (aw_select[0] && m0_aw_slave_sel[0] && m0_awvalid) ||
                       (aw_select[1] && m1_aw_slave_sel[0] && m1_awvalid) ||
                       (aw_select[2] && m2_aw_slave_sel[0] && m2_awvalid) ||
                       (aw_select[3] && m3_aw_slave_sel[0] && m3_awvalid);
    assign s1_awaddr = aw_select[0] && m0_aw_slave_sel[1] ? m0_awaddr :
                      aw_select[1] && m1_aw_slave_sel[1] ? m1_awaddr :
                      aw_select[2] && m2_aw_slave_sel[1] ? m2_awaddr :
                      aw_select[3] && m3_aw_slave_sel[1] ? m3_awaddr : 16'h0000;
    assign s1_awvalid = (aw_select[0] && m0_aw_slave_sel[1] && m0_awvalid) ||
                       (aw_select[1] && m1_aw_slave_sel[1] && m1_awvalid) ||
                       (aw_select[2] && m2_aw_slave_sel[1] && m2_awvalid) ||
                       (aw_select[3] && m3_aw_slave_sel[1] && m3_awvalid);
    assign s2_awaddr = aw_select[0] && m0_aw_slave_sel[2] ? m0_awaddr :
                      aw_select[1] && m1_aw_slave_sel[2] ? m1_awaddr :
                      aw_select[2] && m2_aw_slave_sel[2] ? m2_awaddr :
                      aw_select[3] && m3_aw_slave_sel[2] ? m3_awaddr : 16'h0000;
    assign s2_awvalid = (aw_select[0] && m0_aw_slave_sel[2] && m0_awvalid) ||
                       (aw_select[1] && m1_aw_slave_sel[2] && m1_awvalid) ||
                       (aw_select[2] && m2_aw_slave_sel[2] && m2_awvalid) ||
                       (aw_select[3] && m3_aw_slave_sel[2] && m3_awvalid);
    assign s3_awaddr = aw_select[0] && m0_aw_slave_sel[3] ? m0_awaddr :
                      aw_select[1] && m1_aw_slave_sel[3] ? m1_awaddr :
                      aw_select[2] && m2_aw_slave_sel[3] ? m2_awaddr :
                      aw_select[3] && m3_aw_slave_sel[3] ? m3_awaddr : 16'h0000;
    assign s3_awvalid = (aw_select[0] && m0_aw_slave_sel[3] && m0_awvalid) ||
                       (aw_select[1] && m1_aw_slave_sel[3] && m1_awvalid) ||
                       (aw_select[2] && m2_aw_slave_sel[3] && m2_awvalid) ||
                       (aw_select[3] && m3_aw_slave_sel[3] && m3_awvalid);
    assign s4_awaddr = aw_select[0] && m0_aw_slave_sel[4] ? m0_awaddr :
                      aw_select[1] && m1_aw_slave_sel[4] ? m1_awaddr :
                      aw_select[2] && m2_aw_slave_sel[4] ? m2_awaddr :
                      aw_select[3] && m3_aw_slave_sel[4] ? m3_awaddr : 16'h0000;
    assign s4_awvalid = (aw_select[0] && m0_aw_slave_sel[4] && m0_awvalid) ||
                       (aw_select[1] && m1_aw_slave_sel[4] && m1_awvalid) ||
                       (aw_select[2] && m2_aw_slave_sel[4] && m2_awvalid) ||
                       (aw_select[3] && m3_aw_slave_sel[4] && m3_awvalid);

    // Write data channel
    assign s0_wdata = w_select[0] && m0_aw_slave_sel[0] ? m0_wdata :
                     w_select[1] && m1_aw_slave_sel[0] ? m1_wdata :
                     w_select[2] && m2_aw_slave_sel[0] ? m2_wdata :
                     w_select[3] && m3_aw_slave_sel[0] ? m3_wdata : 32'h00000000;
    assign s0_wstrb = w_select[0] && m0_aw_slave_sel[0] ? m0_wstrb :
                     w_select[1] && m1_aw_slave_sel[0] ? m1_wstrb :
                     w_select[2] && m2_aw_slave_sel[0] ? m2_wstrb :
                     w_select[3] && m3_aw_slave_sel[0] ? m3_wstrb : 4'h0;
    assign s0_wvalid = (w_select[0] && m0_aw_slave_sel[0] && m0_wvalid) ||
                      (w_select[1] && m1_aw_slave_sel[0] && m1_wvalid) ||
                      (w_select[2] && m2_aw_slave_sel[0] && m2_wvalid) ||
                      (w_select[3] && m3_aw_slave_sel[0] && m3_wvalid);
    assign s1_wdata = w_select[0] && m0_aw_slave_sel[1] ? m0_wdata :
                     w_select[1] && m1_aw_slave_sel[1] ? m1_wdata :
                     w_select[2] && m2_aw_slave_sel[1] ? m2_wdata :
                     w_select[3] && m3_aw_slave_sel[1] ? m3_wdata : 32'h00000000;
    assign s1_wstrb = w_select[0] && m0_aw_slave_sel[1] ? m0_wstrb :
                     w_select[1] && m1_aw_slave_sel[1] ? m1_wstrb :
                     w_select[2] && m2_aw_slave_sel[1] ? m2_wstrb :
                     w_select[3] && m3_aw_slave_sel[1] ? m3_wstrb : 4'h0;
    assign s1_wvalid = (w_select[0] && m0_aw_slave_sel[1] && m0_wvalid) ||
                      (w_select[1] && m1_aw_slave_sel[1] && m1_wvalid) ||
                      (w_select[2] && m2_aw_slave_sel[1] && m2_wvalid) ||
                      (w_select[3] && m3_aw_slave_sel[1] && m3_wvalid);
    assign s2_wdata = w_select[0] && m0_aw_slave_sel[2] ? m0_wdata :
                     w_select[1] && m1_aw_slave_sel[2] ? m1_wdata :
                     w_select[2] && m2_aw_slave_sel[2] ? m2_wdata :
                     w_select[3] && m3_aw_slave_sel[2] ? m3_wdata : 32'h00000000;
    assign s2_wstrb = w_select[0] && m0_aw_slave_sel[2] ? m0_wstrb :
                     w_select[1] && m1_aw_slave_sel[2] ? m1_wstrb :
                     w_select[2] && m2_aw_slave_sel[2] ? m2_wstrb :
                     w_select[3] && m3_aw_slave_sel[2] ? m3_wstrb : 4'h0;
    assign s2_wvalid = (w_select[0] && m0_aw_slave_sel[2] && m0_wvalid) ||
                      (w_select[1] && m1_aw_slave_sel[2] && m1_wvalid) ||
                      (w_select[2] && m2_aw_slave_sel[2] && m2_wvalid) ||
                      (w_select[3] && m3_aw_slave_sel[2] && m3_wvalid);
    assign s3_wdata = w_select[0] && m0_aw_slave_sel[3] ? m0_wdata :
                     w_select[1] && m1_aw_slave_sel[3] ? m1_wdata :
                     w_select[2] && m2_aw_slave_sel[3] ? m2_wdata :
                     w_select[3] && m3_aw_slave_sel[3] ? m3_wdata : 32'h00000000;
    assign s3_wstrb = w_select[0] && m0_aw_slave_sel[3] ? m0_wstrb :
                     w_select[1] && m1_aw_slave_sel[3] ? m1_wstrb :
                     w_select[2] && m2_aw_slave_sel[3] ? m2_wstrb :
                     w_select[3] && m3_aw_slave_sel[3] ? m3_wstrb : 4'h0;
    assign s3_wvalid = (w_select[0] && m0_aw_slave_sel[3] && m0_wvalid) ||
                      (w_select[1] && m1_aw_slave_sel[3] && m1_wvalid) ||
                      (w_select[2] && m2_aw_slave_sel[3] && m2_wvalid) ||
                      (w_select[3] && m3_aw_slave_sel[3] && m3_wvalid);
    assign s4_wdata = w_select[0] && m0_aw_slave_sel[4] ? m0_wdata :
                     w_select[1] && m1_aw_slave_sel[4] ? m1_wdata :
                     w_select[2] && m2_aw_slave_sel[4] ? m2_wdata :
                     w_select[3] && m3_aw_slave_sel[4] ? m3_wdata : 32'h00000000;
    assign s4_wstrb = w_select[0] && m0_aw_slave_sel[4] ? m0_wstrb :
                     w_select[1] && m1_aw_slave_sel[4] ? m1_wstrb :
                     w_select[2] && m2_aw_slave_sel[4] ? m2_wstrb :
                     w_select[3] && m3_aw_slave_sel[4] ? m3_wstrb : 4'h0;
    assign s4_wvalid = (w_select[0] && m0_aw_slave_sel[4] && m0_wvalid) ||
                      (w_select[1] && m1_aw_slave_sel[4] && m1_wvalid) ||
                      (w_select[2] && m2_aw_slave_sel[4] && m2_wvalid) ||
                      (w_select[3] && m3_aw_slave_sel[4] && m3_wvalid);

    // Read address channel
    assign s0_araddr = ar_select[0] && m0_ar_slave_sel[0] ? m0_araddr :
                      ar_select[1] && m1_ar_slave_sel[0] ? m1_araddr :
                      ar_select[2] && m2_ar_slave_sel[0] ? m2_araddr :
                      ar_select[3] && m3_ar_slave_sel[0] ? m3_araddr : 16'h0000;
    assign s0_arvalid = (ar_select[0] && m0_ar_slave_sel[0] && m0_arvalid) ||
                       (ar_select[1] && m1_ar_slave_sel[0] && m1_arvalid) ||
                       (ar_select[2] && m2_ar_slave_sel[0] && m2_arvalid) ||
                       (ar_select[3] && m3_ar_slave_sel[0] && m3_arvalid);
    assign s1_araddr = ar_select[0] && m0_ar_slave_sel[1] ? m0_araddr :
                      ar_select[1] && m1_ar_slave_sel[1] ? m1_araddr :
                      ar_select[2] && m2_ar_slave_sel[1] ? m2_araddr :
                      ar_select[3] && m3_ar_slave_sel[1] ? m3_araddr : 16'h0000;
    assign s1_arvalid = (ar_select[0] && m0_ar_slave_sel[1] && m0_arvalid) ||
                       (ar_select[1] && m1_ar_slave_sel[1] && m1_arvalid) ||
                       (ar_select[2] && m2_ar_slave_sel[1] && m2_arvalid) ||
                       (ar_select[3] && m3_ar_slave_sel[1] && m3_arvalid);
    assign s2_araddr = ar_select[0] && m0_ar_slave_sel[2] ? m0_araddr :
                      ar_select[1] && m1_ar_slave_sel[2] ? m1_araddr :
                      ar_select[2] && m2_ar_slave_sel[2] ? m2_araddr :
                      ar_select[3] && m3_ar_slave_sel[2] ? m3_araddr : 16'h0000;
    assign s2_arvalid = (ar_select[0] && m0_ar_slave_sel[2] && m0_arvalid) ||
                       (ar_select[1] && m1_ar_slave_sel[2] && m1_arvalid) ||
                       (ar_select[2] && m2_ar_slave_sel[2] && m2_arvalid) ||
                       (ar_select[3] && m3_ar_slave_sel[2] && m3_arvalid);
    assign s3_araddr = ar_select[0] && m0_ar_slave_sel[3] ? m0_araddr :
                      ar_select[1] && m1_ar_slave_sel[3] ? m1_araddr :
                      ar_select[2] && m2_ar_slave_sel[3] ? m2_araddr :
                      ar_select[3] && m3_ar_slave_sel[3] ? m3_araddr : 16'h0000;
    assign s3_arvalid = (ar_select[0] && m0_ar_slave_sel[3] && m0_arvalid) ||
                       (ar_select[1] && m1_ar_slave_sel[3] && m1_arvalid) ||
                       (ar_select[2] && m2_ar_slave_sel[3] && m2_arvalid) ||
                       (ar_select[3] && m3_ar_slave_sel[3] && m3_arvalid);
    assign s4_araddr = ar_select[0] && m0_ar_slave_sel[4] ? m0_araddr :
                      ar_select[1] && m1_ar_slave_sel[4] ? m1_araddr :
                      ar_select[2] && m2_ar_slave_sel[4] ? m2_araddr :
                      ar_select[3] && m3_ar_slave_sel[4] ? m3_araddr : 16'h0000;
    assign s4_arvalid = (ar_select[0] && m0_ar_slave_sel[4] && m0_arvalid) ||
                       (ar_select[1] && m1_ar_slave_sel[4] && m1_arvalid) ||
                       (ar_select[2] && m2_ar_slave_sel[4] && m2_arvalid) ||
                       (ar_select[3] && m3_ar_slave_sel[4] && m3_arvalid);

    // Write response channel routing - use transaction tracking to route back to requesting master
    // Simplified implementation using basic response routing logic
    reg [1:0] current_b_master;  // Track which master gets current response
    reg b_response_valid;

    // Response routing based on slave ownership
    wire s0_b_resp_valid = s0_bvalid;
    wire s1_b_resp_valid = s1_bvalid;
    wire s2_b_resp_valid = s2_bvalid;
    wire s3_b_resp_valid = s3_bvalid;
    wire s4_b_resp_valid = s4_bvalid;

    always @(*) begin
        // Route B responses based on which slave is responding
        m0_bresp = (current_b_master == 2'd0 && b_response_valid) ? s0_bresp : 2'b00;
        m0_bvalid = (current_b_master == 2'd0 && b_response_valid);

        m1_bresp = (current_b_master == 2'd1 && b_response_valid) ? s0_bresp : 2'b00;
        m1_bvalid = (current_b_master == 2'd1 && b_response_valid);

        m2_bresp = (current_b_master == 2'd2 && b_response_valid) ? s0_bresp : 2'b00;
        m2_bvalid = (current_b_master == 2'd2 && b_response_valid);

        m3_bresp = (current_b_master == 2'd3 && b_response_valid) ? s0_bresp : 2'b00;
        m3_bvalid = (current_b_master == 2'd3 && b_response_valid);
    end

    // Assign BREADY to currently selected slave
    assign s0_bready = (current_b_master == 2'd0) ? m0_bready :
                      (current_b_master == 2'd1) ? m1_bready :
                      (current_b_master == 2'd2) ? m2_bready :
                      (current_b_master == 2'd3) ? m3_bready : 1'b0;

    assign s1_bready = (current_b_master == 2'd0) ? m0_bready :
                      (current_b_master == 2'd1) ? m1_bready :
                      (current_b_master == 2'd2) ? m2_bready :
                      (current_b_master == 2'd3) ? m3_bready : 1'b0;

    assign s2_bready = (current_b_master == 2'd0) ? m0_bready :
                      (current_b_master == 2'd1) ? m1_bready :
                      (current_b_master == 2'd2) ? m2_bready :
                      (current_b_master == 2'd3) ? m3_bready : 1'b0;

    assign s3_bready = (current_b_master == 2'd0) ? m0_bready :
                      (current_b_master == 2'd1) ? m1_bready :
                      (current_b_master == 2'd2) ? m2_bready :
                      (current_b_master == 2'd3) ? m3_bready : 1'b0;

    assign s4_bready = (current_b_master == 2'd0) ? m0_bready :
                      (current_b_master == 2'd1) ? m1_bready :
                      (current_b_master == 2'd2) ? m2_bready :
                      (current_b_master == 2'd3) ? m3_bready : 1'b0;

    // Read data channel (simplified - actual implementation needs proper response routing)
    wire [31:0] rdata_mux [0:4];  // Data from each slave
    wire [1:0] rresp_mux [0:4];   // Response from each slave
    wire rvalid_mux [0:4];        // Valid from each slave

    assign rdata_mux[0] = s0_rdata;
    assign rdata_mux[1] = s1_rdata;
    assign rdata_mux[2] = s2_rdata;
    assign rdata_mux[3] = s3_rdata;
    assign rdata_mux[4] = s4_rdata;

    assign rresp_mux[0] = s0_rresp;
    assign rresp_mux[1] = s1_rresp;
    assign rresp_mux[2] = s2_rresp;
    assign rresp_mux[3] = s3_rresp;
    assign rresp_mux[4] = s4_rresp;

    assign rvalid_mux[0] = s0_rvalid;
    assign rvalid_mux[1] = s1_rvalid;
    assign rvalid_mux[2] = s2_rvalid;
    assign rvalid_mux[3] = s3_rvalid;
    assign rvalid_mux[4] = s4_rvalid;

    reg [2:0] current_r_master;  // Track which master gets current read response

    always @(*) begin
        case (current_r_master)
            3'd0: begin
                m0_rdata = rdata_mux[current_r_master];
                m0_rresp = rresp_mux[current_r_master];
                m0_rvalid = rvalid_mux[current_r_master];
                m1_rdata = 32'h00000000;
                m1_rresp = 2'b00;
                m1_rvalid = 1'b0;
                m2_rdata = 32'h00000000;
                m2_rresp = 2'b00;
                m2_rvalid = 1'b0;
                m3_rdata = 32'h00000000;
                m3_rresp = 2'b00;
                m3_rvalid = 1'b0;
            end
            3'd1: begin
                m1_rdata = rdata_mux[current_r_master];
                m1_rresp = rresp_mux[current_r_master];
                m1_rvalid = rvalid_mux[current_r_master];
                m0_rdata = 32'h00000000;
                m0_rresp = 2'b00;
                m0_rvalid = 1'b0;
                m2_rdata = 32'h00000000;
                m2_rresp = 2'b00;
                m2_rvalid = 1'b0;
                m3_rdata = 32'h00000000;
                m3_rresp = 2'b00;
                m3_rvalid = 1'b0;
            end
            3'd2: begin
                m2_rdata = rdata_mux[current_r_master];
                m2_rresp = rresp_mux[current_r_master];
                m2_rvalid = rvalid_mux[current_r_master];
                m0_rdata = 32'h00000000;
                m0_rresp = 2'b00;
                m0_rvalid = 1'b0;
                m1_rdata = 32'h00000000;
                m1_rresp = 2'b00;
                m1_rvalid = 1'b0;
                m3_rdata = 32'h00000000;
                m3_rresp = 2'b00;
                m3_rvalid = 1'b0;
            end
            3'd3: begin
                m3_rdata = rdata_mux[current_r_master];
                m3_rresp = rresp_mux[current_r_master];
                m3_rvalid = rvalid_mux[current_r_master];
                m0_rdata = 32'h00000000;
                m0_rresp = 2'b00;
                m0_rvalid = 1'b0;
                m1_rdata = 32'h00000000;
                m1_rresp = 2'b00;
                m1_rvalid = 1'b0;
                m2_rdata = 32'h00000000;
                m2_rresp = 2'b00;
                m2_rvalid = 1'b0;
            end
            default: begin
                m0_rdata = 32'h00000000;
                m0_rresp = 2'b00;
                m0_rvalid = 1'b0;
                m1_rdata = 32'h00000000;
                m1_rresp = 2'b00;
                m1_rvalid = 1'b0;
                m2_rdata = 32'h00000000;
                m2_rresp = 2'b00;
                m2_rvalid = 1'b0;
                m3_rdata = 32'h00000000;
                m3_rresp = 2'b00;
                m3_rvalid = 1'b0;
            end
        endcase
    end

    // RREADY routing
    assign s0_rready = (current_r_master == 3'd0) ? m0_rready :
                      (current_r_master == 3'd1) ? m1_rready :
                      (current_r_master == 3'd2) ? m2_rready :
                      (current_r_master == 3'd3) ? m3_rready : 1'b0;
    assign s1_rready = (current_r_master == 3'd0) ? m0_rready :
                      (current_r_master == 3'd1) ? m1_rready :
                      (current_r_master == 3'd2) ? m2_rready :
                      (current_r_master == 3'd3) ? m3_rready : 1'b0;
    assign s2_rready = (current_r_master == 3'd0) ? m0_rready :
                      (current_r_master == 3'd1) ? m1_rready :
                      (current_r_master == 3'd2) ? m2_rready :
                      (current_r_master == 3'd3) ? m3_rready : 1'b0;
    assign s3_rready = (current_r_master == 3'd0) ? m0_rready :
                      (current_r_master == 3'd1) ? m1_rready :
                      (current_r_master == 3'd2) ? m2_rready :
                      (current_r_master == 3'd3) ? m3_rready : 1'b0;
    assign s4_rready = (current_r_master == 3'd0) ? m0_rready :
                      (current_r_master == 3'd1) ? m1_rready :
                      (current_r_master == 3'd2) ? m2_rready :
                      (current_r_master == 3'd3) ? m3_rready : 1'b0;

    // Track response masters based on original requests
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            current_b_master <= 2'd0;
            b_response_valid <= 1'b0;
            current_r_master <= 3'd0;
        end else begin
            // Update when a slave transaction completes
            if (s0_bvalid) current_b_master <= aw_select;  // Simplified: associate with AW requester
            if (s1_bvalid) current_b_master <= aw_select;
            if (s2_bvalid) current_b_master <= aw_select;
            if (s3_bvalid) current_b_master <= aw_select;
            if (s4_bvalid) current_b_master <= aw_select;

            // For read responses
            if (s0_rvalid) current_r_master <= ar_select;  // Associate with AR requester
            if (s1_rvalid) current_r_master <= ar_select;
            if (s2_rvalid) current_r_master <= ar_select;
            if (s3_rvalid) current_r_master <= ar_select;
            if (s4_rvalid) current_r_master <= ar_select;

            // Track when response is valid for routing
            b_response_valid <= s0_bvalid | s1_bvalid | s2_bvalid | s3_bvalid | s4_bvalid;
        end
    end

endmodule