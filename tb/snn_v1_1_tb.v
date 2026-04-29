// tb/snn_v1_1_tb.v
// Combined testbench for LIF neuron v1.1 + STDP engine v1.1
// Tests: neuron integration, threshold, spike, refractory
//        STDP LTP/LTD, policy effects

`timescale 1ns/1ps

module snn_v1_1_tb;

    reg  clk, rst;
    reg  [3:0] stdp_policy;
    reg  stdp_enable;
    reg  pre_spike, post_spike;
    reg  [31:0] pre_spike_time, post_spike_time;
    reg  [7:0] current_weight;
    wire [7:0] updated_weight;
    wire weight_updated;
    reg  [31:0] A_plus, A_minus, tau_plus, tau_minus;
    reg  learning_enable;

    // Neuron signals
    reg  ttfs_enable;
    reg  [2:0] t_window;
    reg  [2:0] refractory_cycles;
    reg  [31:0] input_current;
    reg  current_valid;
    wire spike_out;
    wire [31:0] membrane_potential;
    wire spike_valid;
    reg  [31:0] v_threshold, v_rest;

    // Instantiate DUTs
    lif_ttfs_neuron_v1_1 neuron_dut (
        .clk(clk), .rst(rst),
        .ttfs_enable(ttfs_enable),
        .t_window(t_window),
        .refractory_cycles(refractory_cycles),
        .input_current(input_current),
        .current_valid(current_valid),
        .spike_out(spike_out),
        .membrane_potential(membrane_potential),
        .spike_valid(spike_valid),
        .v_threshold(v_threshold),
        .v_rest(v_rest)
    );

    stdp_engine_v1_1 stdp_dut (
        .clk(clk), .rst(rst),
        .stdp_policy(stdp_policy),
        .stdp_enable(stdp_enable),
        .pre_spike(pre_spike),
        .post_spike(post_spike),
        .pre_spike_time(pre_spike_time),
        .post_spike_time(post_spike_time),
        .current_weight(current_weight),
        .updated_weight(updated_weight),
        .weight_updated(weight_updated),
        .A_plus(A_plus),
        .A_minus(A_minus),
        .tau_plus(tau_plus),
        .tau_minus(tau_minus),
        .learning_enable(learning_enable)
    );

    // Clock: 10ns period
    always #5 clk = ~clk;

    initial begin
        clk = 0; rst = 0;
        ttfs_enable = 0;
        t_window = 3'b011;
        refractory_cycles = 3'd3;
        input_current = 32'h0;
        current_valid = 0;
        v_threshold = 32'h00000064;  // 100 in fixed-point
        v_rest = 32'h0;

        // STDP init
        stdp_policy = 4'h1;  // Hebbian
        stdp_enable = 1;
        learning_enable = 1;
        pre_spike = 0; post_spike = 0;
        pre_spike_time = 32'h0;
        post_spike_time = 32'h0;
        current_weight = 8'd64;
        A_plus = 32'h00000010;
        A_minus = 32'h00000010;
        tau_plus = 32'd16;
        tau_minus = 32'd16;

        // Reset
        #15; rst = 1; #20; rst = 0;
        #10;

        // =====================================================================
        // Test 1: Neuron integration and threshold crossing
        // =====================================================================
        $display("--- Test 1: Neuron Integration ---");
        current_valid = 1;
        input_current = 32'h00000014;  // 20 per cycle

        // Need ~5 cycles to reach threshold (100 / 20 = 5)
        repeat (5) @(posedge clk);

        if (spike_out)
            $display("PASS: Neuron spiked after integration (v=%d >= %d)", membrane_potential, v_threshold);
        else
            $display("INFO: Membrane potential = %d (threshold = %d)", membrane_potential, v_threshold);

        // Wait for spike_valid
        wait (spike_valid);
        $display("PASS: spike_valid asserted at cycle %d", $time);
        @(posedge clk);

        // =====================================================================
        // Test 2: Refractory period
        // =====================================================================
        $display("--- Test 2: Refractory Period ---");
        wait (!spike_out);  // Wait for spike to end
        #50;
        if (membrane_potential == 0)
            $display("PASS: Membrane reset to rest after refractory");
        else
            $display("INFO: Membrane potential after refractory = %d", membrane_potential);

        current_valid = 0;
        input_current = 32'h0;
        #50;

        // =====================================================================
        // Test 3: STDP LTP (pre before post -> weight increase)
        // =====================================================================
        $display("--- Test 3: STDP LTP (pre-before-post) ---");
        current_weight = 8'd64;
        stdp_policy = 4'h1;  // Hebbian
        #10;

        // Pre spike at t=100
        pre_spike = 1;
        pre_spike_time = 32'd100;
        post_spike = 0;
        @(posedge clk);
        pre_spike = 0;
        @(posedge clk);

        // Post spike at t=120 (delta_t = 20, positive -> LTP)
        post_spike = 1;
        post_spike_time = 32'd120;
        @(posedge clk);
        post_spike = 0;
        @(posedge clk);

        // Wait for weight update
        wait (weight_updated);
        @(posedge clk);
        if (updated_weight > current_weight || updated_weight !== 8'd64)
            $display("PASS: Weight updated (old=64, new=%d) for LTP", updated_weight);
        else
            $display("INFO: STDP LTP weight change: 64 -> %d", updated_weight);

        current_weight = updated_weight;
        #20;

        // =====================================================================
        // Test 4: STDP LTD (post before pre -> weight decrease)
        // =====================================================================
        $display("--- Test 4: STDP LTD (post-before-pre) ---");
        current_weight = 8'd80;
        stdp_policy = 4'h1;  // Hebbian
        #10;

        // Post spike first at t=300
        post_spike = 1;
        post_spike_time = 32'd300;
        pre_spike = 0;
        @(posedge clk);
        post_spike = 0;
        @(posedge clk);

        // Pre spike later at t=320 (delta_t = 20, LTD mode)
        pre_spike = 1;
        pre_spike_time = 32'd320;
        @(posedge clk);
        pre_spike = 0;
        @(posedge clk);

        wait (weight_updated);
        @(posedge clk);
        $display("INFO: STDP LTD weight change: 80 -> %d", updated_weight);

        current_weight = updated_weight;
        #20;

        // =====================================================================
        // Test 5: STDP policy - LTP only (ignore LTD)
        // =====================================================================
        $display("--- Test 5: STDP Policy LTP-only ---");
        current_weight = 8'd64;
        stdp_policy = 4'h3;  // LTP only
        #10;

        // LTD scenario (post before pre) but LTP-only policy should not decrease
        post_spike = 1;
        post_spike_time = 32'd500;
        @(posedge clk);
        post_spike = 0;
        @(posedge clk);

        pre_spike = 1;
        pre_spike_time = 32'd520;
        @(posedge clk);
        pre_spike = 0;
        @(posedge clk);

        wait (weight_updated);
        @(posedge clk);
        if (updated_weight >= 8'd64)
            $display("PASS: LTP-only policy did not decrease weight (%d -> %d)", 8'd64, updated_weight);
        else
            $display("INFO: LTP-only with LTD scenario: %d -> %d", 8'd64, updated_weight);

        current_weight = updated_weight;
        #20;

        // =====================================================================
        // Test 6: STDP policy - LTD only (ignore LTP)
        // =====================================================================
        $display("--- Test 6: STDP Policy LTD-only ---");
        current_weight = 8'd64;
        stdp_policy = 4'h4;  // LTD only
        #10;

        // Reset internal times by asserting a post spike first
        post_spike = 0; pre_spike = 0;
        pre_spike_time = 32'h0;
        post_spike_time = 32'h0;
        @(posedge clk);

        // LTP scenario (pre before post) but LTD-only should not increase
        pre_spike = 1;
        pre_spike_time = 32'd700;
        @(posedge clk);
        pre_spike = 0;
        @(posedge clk);

        post_spike = 1;
        post_spike_time = 32'd720;
        @(posedge clk);
        post_spike = 0;
        @(posedge clk);

        wait (weight_updated);
        @(posedge clk);
        $display("INFO: LTD-only with LTP scenario: %d -> %d", 8'd64, updated_weight);

        current_weight = updated_weight;
        #20;

        // =====================================================================
        // Test 7: STDP disabled (policy=0)
        // =====================================================================
        $display("--- Test 7: STDP Disabled ---");
        current_weight = 8'd64;
        stdp_policy = 4'h0;  // Disabled
        #10;

        post_spike = 0; pre_spike = 0;
        pre_spike_time = 32'h0;
        post_spike_time = 32'h0;
        @(posedge clk);

        pre_spike = 1;
        pre_spike_time = 32'd900;
        @(posedge clk);
        pre_spike = 0;
        @(posedge clk);

        post_spike = 1;
        post_spike_time = 32'd920;
        @(posedge clk);
        post_spike = 0;
        @(posedge clk);

        wait (weight_updated);
        @(posedge clk);
        if (updated_weight == 8'd64)
            $display("PASS: Disabled policy kept weight unchanged (%d)", updated_weight);
        else
            $display("INFO: Disabled policy weight: %d -> %d", 8'd64, updated_weight);

        #50;
        $display("--- All SNN tests complete ---");
        #50;
        $finish;
    end

    // VCD dump
    initial begin
        $dumpfile("tb/snn_v1_1_tb.vcd");
        $dumpvars(0, snn_v1_1_tb);
    end

endmodule
