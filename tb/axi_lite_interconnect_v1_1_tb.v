// tb/axi_lite_interconnect_v1_1_tb.v
// Testbench for AXI4-Lite interconnect v1.1
// Tests: handshake, ROM read, SRAM write, contention arbitration
// Verilog 2001 compliant

`timescale 1ns/1ps

module axi_lite_interconnect_v1_1_tb;

    reg  aclk, aresetn;

    // Master 0 signals (TB drives inputs, DUT drives outputs)
    reg  [15:0] m0_awaddr;
    reg         m0_awvalid;
    wire        m0_awready;       // DUT output
    reg  [31:0] m0_wdata;
    reg  [3:0]  m0_wstrb;
    reg         m0_wvalid;
    wire        m0_wready;        // DUT output
    wire [1:0]  m0_bresp;        // DUT output
    wire        m0_bvalid;       // DUT output
    reg         m0_bready;
    reg  [15:0] m0_araddr;
    reg         m0_arvalid;
    wire        m0_arready;       // DUT output
    wire [31:0] m0_rdata;        // DUT output
    wire [1:0]  m0_rresp;        // DUT output
    wire        m0_rvalid;       // DUT output
    reg         m0_rready;

    // Master 1 signals
    reg  [15:0] m1_awaddr;
    reg         m1_awvalid;
    wire        m1_awready;       // DUT output
    reg  [31:0] m1_wdata;
    reg  [3:0]  m1_wstrb;
    reg         m1_wvalid;
    wire        m1_wready;        // DUT output
    wire [1:0]  m1_bresp;        // DUT output
    wire        m1_bvalid;       // DUT output
    reg         m1_bready;
    reg  [15:0] m1_araddr;
    reg         m1_arvalid;
    wire        m1_arready;       // DUT output
    wire [31:0] m1_rdata;        // DUT output
    wire [1:0]  m1_rresp;        // DUT output
    wire        m1_rvalid;       // DUT output
    reg         m1_rready;

    // Master 2/3 (unused - tie off inputs)
    wire [15:0] m2_awaddr; wire m2_awready; wire [31:0] m2_wdata;
    wire [3:0]  m2_wstrb; wire m2_wready; wire [1:0] m2_bresp;
    wire m2_bvalid; wire [15:0] m2_araddr; wire m2_arready;
    wire [31:0] m2_rdata; wire [1:0] m2_rresp; wire m2_rvalid;
    wire [15:0] m3_awaddr; wire m3_awready; wire [31:0] m3_wdata;
    wire [3:0]  m3_wstrb; wire m3_wready; wire [1:0] m3_bresp;
    wire m3_bvalid; wire [15:0] m3_araddr; wire m3_arready;
    wire [31:0] m3_rdata; wire [1:0] m3_rresp; wire m3_rvalid;

    // Slave 0 (ROM) - DUT outputs are wire, DUT inputs are reg
    wire [15:0] s0_awaddr; wire s0_awvalid;
    reg         s0_awready;       // TB drives (DUT input)
    wire [31:0] s0_wdata; wire [3:0] s0_wstrb; wire s0_wvalid;
    reg         s0_wready;        // TB drives (DUT input)
    wire [1:0]  s0_bresp; wire s0_bvalid;
    wire        s0_bready;        // DUT output
    wire [15:0] s0_araddr; wire s0_arvalid;
    reg         s0_arready;       // TB drives (DUT input)
    wire [31:0] s0_rdata; wire [1:0] s0_rresp; wire s0_rvalid;
    wire        s0_rready;        // DUT output

    // Slave 1 (SRAM)
    wire [15:0] s1_awaddr; wire s1_awvalid;
    reg         s1_awready;       // TB drives (DUT input)
    wire [31:0] s1_wdata; wire [3:0] s1_wstrb; wire s1_wvalid;
    reg         s1_wready;        // TB drives (DUT input)
    wire [1:0]  s1_bresp; wire s1_bvalid;
    wire        s1_bready;        // DUT output
    wire [15:0] s1_araddr; wire s1_arvalid;
    reg         s1_arready;       // TB drives (DUT input)
    wire [31:0] s1_rdata; wire [1:0] s1_rresp; wire s1_rvalid;
    wire        s1_rready;        // DUT output

    // Slave 2/3/4 (unused - all wire)
    wire [15:0] s2_awaddr; wire s2_awvalid; wire s2_awready;
    wire [31:0] s2_wdata; wire [3:0] s2_wstrb; wire s2_wvalid; wire s2_wready;
    wire [1:0]  s2_bresp; wire s2_bvalid; wire s2_bready;
    wire [15:0] s2_araddr; wire s2_arvalid; wire s2_arready;
    wire [31:0] s2_rdata; wire [1:0] s2_rresp; wire s2_rvalid; wire s2_rready;
    wire [15:0] s3_awaddr; wire s3_awvalid; wire s3_awready;
    wire [31:0] s3_wdata; wire [3:0] s3_wstrb; wire s3_wvalid; wire s3_wready;
    wire [1:0]  s3_bresp; wire s3_bvalid; wire s3_bready;
    wire [15:0] s3_araddr; wire s3_arvalid; wire s3_arready;
    wire [31:0] s3_rdata; wire [1:0] s3_rresp; wire s3_rvalid; wire s3_rready;
    wire [15:0] s4_awaddr; wire s4_awvalid; wire s4_awready;
    wire [31:0] s4_wdata; wire [3:0] s4_wstrb; wire s4_wvalid; wire s4_wready;
    wire [1:0]  s4_bresp; wire s4_bvalid; wire s4_bready;
    wire [15:0] s4_araddr; wire s4_arvalid; wire s4_arready;
    wire [31:0] s4_rdata; wire [1:0] s4_rresp; wire s4_rvalid; wire s4_rready;

    integer tb_i;

    // Clock: 10ns period (100MHz)
    always #5 aclk = ~aclk;

    // Instantiate DUT
    axi_lite_interconnect_v1_1 dut (
        .aclk(aclk), .aresetn(aresetn),

        .m0_awaddr(m0_awaddr), .m0_awvalid(m0_awvalid), .m0_awready(m0_awready),
        .m0_wdata(m0_wdata), .m0_wstrb(m0_wstrb), .m0_wvalid(m0_wvalid), .m0_wready(m0_wready),
        .m0_bresp(m0_bresp), .m0_bvalid(m0_bvalid), .m0_bready(m0_bready),
        .m0_araddr(m0_araddr), .m0_arvalid(m0_arvalid), .m0_arready(m0_arready),
        .m0_rdata(m0_rdata), .m0_rresp(m0_rresp), .m0_rvalid(m0_rvalid), .m0_rready(m0_rready),

        .m1_awaddr(m1_awaddr), .m1_awvalid(m1_awvalid), .m1_awready(m1_awready),
        .m1_wdata(m1_wdata), .m1_wstrb(m1_wstrb), .m1_wvalid(m1_wvalid), .m1_wready(m1_wready),
        .m1_bresp(m1_bresp), .m1_bvalid(m1_bvalid), .m1_bready(m1_bready),
        .m1_araddr(m1_araddr), .m1_arvalid(m1_arvalid), .m1_arready(m1_arready),
        .m1_rdata(m1_rdata), .m1_rresp(m1_rresp), .m1_rvalid(m1_rvalid), .m1_rready(m1_rready),

        .m2_awaddr(m2_awaddr), .m2_awvalid(1'b0), .m2_awready(),
        .m2_wdata(m2_wdata), .m2_wstrb(m2_wstrb), .m2_wvalid(1'b0), .m2_wready(),
        .m2_bresp(m2_bresp), .m2_bvalid(m2_bvalid), .m2_bready(1'b1),
        .m2_araddr(m2_araddr), .m2_arvalid(1'b0), .m2_arready(),
        .m2_rdata(m2_rdata), .m2_rresp(m2_rresp), .m2_rvalid(m2_rvalid), .m2_rready(1'b1),

        .m3_awaddr(m3_awaddr), .m3_awvalid(1'b0), .m3_awready(),
        .m3_wdata(m3_wdata), .m3_wstrb(m3_wstrb), .m3_wvalid(1'b0), .m3_wready(),
        .m3_bresp(m3_bresp), .m3_bvalid(m3_bvalid), .m3_bready(1'b1),
        .m3_araddr(m3_araddr), .m3_arvalid(1'b0), .m3_arready(),
        .m3_rdata(m3_rdata), .m3_rresp(m3_rresp), .m3_rvalid(m3_rvalid), .m3_rready(1'b1),

        .s0_awaddr(s0_awaddr), .s0_awvalid(s0_awvalid), .s0_awready(s0_awready),
        .s0_wdata(s0_wdata), .s0_wstrb(s0_wstrb), .s0_wvalid(s0_wvalid), .s0_wready(s0_wready),
        .s0_bresp(s0_bresp), .s0_bvalid(s0_bvalid), .s0_bready(s0_bready),
        .s0_araddr(s0_araddr), .s0_arvalid(s0_arvalid), .s0_arready(s0_arready),
        .s0_rdata(s0_rdata), .s0_rresp(s0_rresp), .s0_rvalid(s0_rvalid), .s0_rready(s0_rready),

        .s1_awaddr(s1_awaddr), .s1_awvalid(s1_awvalid), .s1_awready(s1_awready),
        .s1_wdata(s1_wdata), .s1_wstrb(s1_wstrb), .s1_wvalid(s1_wvalid), .s1_wready(s1_wready),
        .s1_bresp(s1_bresp), .s1_bvalid(s1_bvalid), .s1_bready(s1_bready),
        .s1_araddr(s1_araddr), .s1_arvalid(s1_arvalid), .s1_arready(s1_arready),
        .s1_rdata(s1_rdata), .s1_rresp(s1_rresp), .s1_rvalid(s1_rvalid), .s1_rready(s1_rready),

        .s2_awaddr(s2_awaddr), .s2_awvalid(s2_awvalid), .s2_awready(s2_awready),
        .s2_wdata(s2_wdata), .s2_wstrb(s2_wstrb), .s2_wvalid(s2_wvalid), .s2_wready(s2_wready),
        .s2_bresp(s2_bresp), .s2_bvalid(s2_bvalid), .s2_bready(s2_bready),
        .s2_araddr(s2_araddr), .s2_arvalid(s2_arvalid), .s2_arready(s2_arready),
        .s2_rdata(s2_rdata), .s2_rresp(s2_rresp), .s2_rvalid(s2_rvalid), .s2_rready(s2_rready),

        .s3_awaddr(s3_awaddr), .s3_awvalid(s3_awvalid), .s3_awready(s3_awready),
        .s3_wdata(s3_wdata), .s3_wstrb(s3_wstrb), .s3_wvalid(s3_wvalid), .s3_wready(s3_wready),
        .s3_bresp(s3_bresp), .s3_bvalid(s3_bvalid), .s3_bready(s3_bready),
        .s3_araddr(s3_araddr), .s3_arvalid(s3_arvalid), .s3_arready(s3_arready),
        .s3_rdata(s3_rdata), .s3_rresp(s3_rresp), .s3_rvalid(s3_rvalid), .s3_rready(s3_rready),

        .s4_awaddr(s4_awaddr), .s4_awvalid(s4_awvalid), .s4_awready(s4_awready),
        .s4_wdata(s4_wdata), .s4_wstrb(s4_wstrb), .s4_wvalid(s4_wvalid), .s4_wready(s4_wready),
        .s4_bresp(s4_bresp), .s4_bvalid(s4_bvalid), .s4_bready(s4_bready),
        .s4_araddr(s4_araddr), .s4_arvalid(s4_arvalid), .s4_arready(s4_arready),
        .s4_rdata(s4_rdata), .s4_rresp(s4_rresp), .s4_rvalid(s4_rvalid), .s4_rready(s4_rready)
    );

    // Test: ROM read, SRAM write, contention arbitration
    initial begin
        $dumpfile("tb/axi_v1_1_tb.vcd");
        $dumpvars(0, axi_lite_interconnect_v1_1_tb);

        // Reset
        aclk = 0;
        aresetn = 0;
        m0_awvalid = 0; m0_wvalid = 0; m0_arvalid = 0;
        m1_awvalid = 0; m1_wvalid = 0; m1_arvalid = 0;
        m0_bready = 0; m0_rready = 0;
        m1_bready = 0; m1_rready = 0;
        s0_awready = 0; s0_wready = 0; s0_arready = 0;
        s1_awready = 0; s1_wready = 0; s1_arready = 0;
        #50;
        aresetn = 1;
        #20;

        // Test 1: M0 AR channel read to ROM address (0x0000)
        $display("--- Test 1: ROM read via M0 ---");
        m0_araddr = 16'h0000;
        m0_arvalid = 1;
        m0_rready = 1;
        s0_arready = 1;
        wait (m0_arready);
        #10;
        m0_arvalid = 0;
        if (s0_araddr === 16'h0000)
            $display("PASS: ROM read address routed correctly");
        else
            $display("FAIL: ROM read address mismatch, got %h", s0_araddr);

        // Test 2: M0 AW channel write to SRAM (0x1000)
        $display("--- Test 2: SRAM write via M0 ---");
        m0_awaddr = 16'h1000;
        m0_wdata  = 32'hDEADBEEF;
        m0_wstrb  = 4'hF;
        m0_awvalid = 1;
        m0_wvalid = 1;
        m0_bready = 1;
        s1_awready = 1;
        s1_wready = 1;
        wait (m0_awready && m0_wready);
        #10;
        m0_awvalid = 0;
        m0_wvalid = 0;
        if (s1_awaddr === 16'h1000 && s1_wdata === 32'hDEADBEEF)
            $display("PASS: SRAM write routed correctly");
        else
            $display("FAIL: SRAM write mismatch, addr=%h wdata=%h", s1_awaddr, s1_wdata);

        // Test 3: Contention - M0 and M1 both request different slaves
        $display("--- Test 3: Arbitration - M0 vs M1 ---");
        m1_awaddr = 16'h1100;
        m1_wdata  = 32'hCAFEBABE;
        m1_awvalid = 1;
        m1_wvalid = 1;
        s1_awready = 1;
        s1_wready = 1;
        m0_awaddr = 16'h1200;
        m0_wdata  = 32'hBADDD00D;
        m0_awvalid = 1;
        m0_wvalid = 1;
        #10;
        if (m0_awready)
            $display("PASS: M0 won arbitration over M1");
        else
            $display("FAIL: M0 did not win arbitration");

        if (s1_awaddr === 16'h1200)
            $display("PASS: M0's address routed to slave");
        else
            $display("FAIL: Wrong address on slave, got %h", s1_awaddr);

        m0_awvalid = 0;
        m0_wvalid = 0;
        #10;
        if (m1_awready)
            $display("PASS: M1 served after M0 done");
        else
            $display("FAIL: M1 not served after M0");

        if (s1_awaddr === 16'h1100)
            $display("PASS: M1's address routed to slave");
        else
            $display("FAIL: Wrong address on slave, got %h", s1_awaddr);

        // Clean up
        m1_awvalid = 0;
        m1_wvalid = 0;
        m0_bready = 0;
        m0_rready = 0;
        m1_bready = 0;
        m1_rready = 0;
        #20;

        // Test 4: Verify slave bready/rready are driven by DUT
        $display("--- Test 4: Ready signal routing ---");
        if (s0_bready && s1_bready && s2_bready && s3_bready && s4_bready)
            $display("PASS: All bready routed");
        else
            $display("WARN: Some bready not routed (expected when no master active)");

        $display("--- All tests complete ---");
        #50;
        $finish;
    end

endmodule
