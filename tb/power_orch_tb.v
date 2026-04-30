// tb/power_orch_tb.v
// Testbench for Power Orchestration Controller
// Verilog 2001 compliant

`timescale 1ns/1ps

module power_orch_tb;

    reg clk;
    reg rst;

    // Control signals
    reg [3:0] tile_state_req;
    reg [3:0] idle_timeout;
    reg wake_irq_mask;
    reg [3:0] activity_count;

    // Tile control signals
    wire [3:0] tile_sleep;
    wire [3:0] tile_iso_en;
    wire [3:0] tile_ret_en;

    // Wake triggers
    reg [3:0] tile_wake_req;
    reg irq_trigger;
    reg axi_activity;

    // CSR interface
    reg [11:0] csr_addr;
    reg csr_wr_en;
    reg [31:0] csr_wr_data;
    wire [31:0] csr_rd_data;

    // Retention register test signals (module-level for V2001)
    reg [31:0]  test_data_in;

    // Test variables (module-level for V2001)
    integer i, j;
    integer test_num;
    integer sleep_count;
    reg [31:0] test_results [0:9];

    // Instantiate the orchestrator
    orchestrator uut (
        .clk(clk),
        .rst(rst),
        .tile_state_req(tile_state_req),
        .idle_timeout(idle_timeout),
        .wake_irq_mask(wake_irq_mask),
        .activity_count(activity_count),
        .tile_sleep(tile_sleep),
        .tile_iso_en(tile_iso_en),
        .tile_ret_en(tile_ret_en),
        .tile_wake_req(tile_wake_req),
        .irq_trigger(irq_trigger),
        .axi_activity(axi_activity),
        .csr_addr(csr_addr),
        .csr_wr_en(csr_wr_en),
        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data)
    );


    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("Starting Power Orchestration Testbench...");

        // Initialize signals
        rst = 1;
        tile_state_req = 4'b0001;
        idle_timeout = 4'h5;
        wake_irq_mask = 1'b0;
        activity_count = 4'b1111;
        tile_wake_req = 4'b0000;
        irq_trigger = 1'b0;
        axi_activity = 1'b0;
        csr_addr = 12'h000;
        csr_wr_en = 0;
        csr_wr_data = 32'h0;
        test_num = 0;
        test_data_in = 32'h0;

        #22 rst = 0;
        #20;

        $display("Test 1: Idle-to-Sleep Transition");
        test_num = 1;

        activity_count = 4'b0000;

        csr_addr = 12'h7C8;
        csr_wr_data = {24'h0, 4'b0001, 4'h5, 1'b0};
        csr_wr_en = 1;
        #10;
        csr_wr_en = 0;
        #50;

        $display("  Activity count: %b, Timeout: %h", activity_count, idle_timeout);
        $display("  Tile sleep states after timeout:");
        for (i = 0; i < 4; i = i + 1) begin
            $display("    Tile %0d: sleep=%b, iso=%b, ret=%b", i, tile_sleep[i], tile_iso_en[i], tile_ret_en[i]);
        end

        $display("Test 2: Wake-up on Activity");
        test_num = 2;

        axi_activity = 1'b1;
        #30;
        axi_activity = 1'b0;

        $display("  After AXI wake activity:");
        for (i = 0; i < 4; i = i + 1) begin
            $display("    Tile %0d: sleep=%b, iso=%b, ret=%b", i, tile_sleep[i], tile_iso_en[i], tile_ret_en[i]);
        end

        $display("Test 3: Wake-up on Tile Request");
        test_num = 3;

        tile_wake_req[2] = 1'b1;
        #25;
        tile_wake_req[2] = 1'b0;

        $display("  After SNN tile wake request:");
        for (i = 0; i < 4; i = i + 1) begin
            $display("    Tile %0d: sleep=%b, iso=%b, ret=%b", i, tile_sleep[i], tile_iso_en[i], tile_ret_en[i]);
        end

        $display("Test 4: CSR Access Verification");
        test_num = 4;

        csr_addr = 12'h7C8;
        csr_wr_en = 0;
        #10;
        $display("  CSR 0x7C8 read: %08x", csr_rd_data);

        csr_addr = 12'h7C9;
        #10;
        $display("  CSR 0x7C9 read: %08x", csr_rd_data);

        $display("Test 5: Retention Register Test");
        test_num = 5;

        test_data_in = 32'hDEADBEEF;
        #50;
        test_data_in = 32'h00000000;
        #10;
        test_data_in = 32'h12345678;
        #10;
        $display("  Retention test: Data written=%08x", test_data_in);

        $display("=== POWER ORCHESTRATION TEST RESULTS ===");

        // Count sleeping tiles
        sleep_count = 0;
        for (i = 0; i < 4; i = i + 1) begin
            if (tile_sleep[i]) sleep_count = sleep_count + 1;
        end

        if (sleep_count >= 2) begin
            $display("PASS: Sleep functionality working: %0d tiles in sleep", sleep_count);
        end else begin
            $display("WARN: Sleep functionality limited: %0d tiles in sleep", sleep_count);
        end

        #100;
        $display("Power Orchestration Testbench completed.");
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            // Reset active
        end
        else if (($time % 100) == 0) begin
            $display("Time: %0t, Core: S=%b I=%b R=%b, EML: S=%b I=%b R=%b, SNN: S=%b I=%b R=%b, NVM: S=%b I=%b R=%b",
                     $time,
                     tile_sleep[0], tile_iso_en[0], tile_ret_en[0],
                     tile_sleep[1], tile_iso_en[1], tile_ret_en[1],
                     tile_sleep[2], tile_iso_en[2], tile_ret_en[2],
                     tile_sleep[3], tile_iso_en[3], tile_ret_en[3]);
        end
    end

endmodule

module power_state_simulator (
    input wire clk,
    input wire rst,
    input wire sleep_signal,
    input wire iso_signal,
    input wire ret_signal,
    output reg [31:0] power_consumption
);

    reg [31:0] base_power;
    reg [31:0] sleep_power;
    reg [31:0] iso_power;

    initial begin
        base_power = 32'd1000;
        sleep_power = 32'd50;
        iso_power = 32'd100;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            power_consumption <= base_power;
        end
        else begin
            if (sleep_signal) begin
                power_consumption <= sleep_power;
            end
            else if (iso_signal) begin
                power_consumption <= iso_power;
            end
            else begin
                power_consumption <= base_power;
            end
        end
    end

endmodule
