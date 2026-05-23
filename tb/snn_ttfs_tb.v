// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/snn_ttfs_tb.v
// Testbench for SNN TTFS (Time-to-First-Spike) temporal coding and STDP
// Verilog 2001 compliant

`timescale 1ns/1ps

module snn_ttfs_tb;

    reg clk;
    reg rst;

    // Control signals
    reg ttfs_enable;
    reg [2:0] t_window;
    reg [2:0] refractory_cycles;
    reg [3:0] stdp_policy;
    reg stdp_enable;
    reg learning_enable;

    // Neuron input signals
    reg [31:0] input_current;
    reg current_valid;

    // Spike inputs for STDP
    reg pre_spike;
    reg post_spike;
    reg [31:0] pre_spike_time;
    reg [31:0] post_spike_time;

    // Configuration
    reg [31:0] v_threshold;
    reg [31:0] v_rest;
    reg [31:0] leak_factor;

    // STDP parameters
    reg [31:0] A_plus;
    reg [31:0] A_minus;
    reg [31:0] tau_plus;
    reg [31:0] tau_minus;

    // Outputs
    wire spike_out;
    wire spike_valid;
    wire [31:0] membrane_potential;
    wire [7:0] updated_weight;
    wire weight_updated;

    // Test variables (module-level for Verilog 2001)
    integer i, j;
    integer test_num;
    reg [31:0] spike_times [0:99];
    reg [7:0] weights_before [0:9];
    reg [7:0] weights_after [0:9];
    integer stdp_updates;
    integer window_len;
    integer ttfs_spikes;
    integer rate_spikes;
    integer valid_weights;
    integer energy_pct;
    reg spike_found;

    // Instantiate LIF TTFS neuron
    lif_ttfs_neuron_v1_1 neuron_uut (
        .clk(clk),
        .rst(rst),
        .ttfs_enable(ttfs_enable),
        .t_window(t_window),
        .refractory_cycles(refractory_cycles),
        .input_current(input_current),
        .current_valid(current_valid),
        .spike_out(spike_out),
        .spike_valid(spike_valid),
        .membrane_potential(membrane_potential),
        .v_threshold(v_threshold),
        .v_rest(v_rest)
    );

    // Instantiate STDP engine
    stdp_engine_v1_1 stdp_uut (
        .clk(clk),
        .rst(rst),
        .stdp_policy(stdp_policy),
        .stdp_enable(stdp_enable),
        .pre_spike(pre_spike),
        .post_spike(post_spike),
        .pre_spike_time(pre_spike_time),
        .post_spike_time(post_spike_time),
        .current_weight(8'h40),
        .updated_weight(updated_weight),
        .weight_updated(weight_updated),
        .A_plus(A_plus),
        .A_minus(A_minus),
        .tau_plus(tau_plus),
        .tau_minus(tau_minus),
        .learning_enable(learning_enable)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("Starting SNN TTFS and STDP Testbench...");

        // Initialize signals
        rst = 1;
        ttfs_enable = 0;
        stdp_enable = 0;
        learning_enable = 0;
        t_window = 3'b011;
        refractory_cycles = 3'b010;
        stdp_policy = 4'h1;
        v_threshold = 32'h40000000;
        v_rest = 32'h00000000;
        leak_factor = 32'd100;
        A_plus = 32'h02000000;
        A_minus = 32'h02000000;
        tau_plus = 32'd20;
        tau_minus = 32'd20;

        input_current = 32'h0;
        current_valid = 0;
        pre_spike = 0;
        post_spike = 0;
        pre_spike_time = 32'h0;
        post_spike_time = 32'h0;
        test_num = 0;
        stdp_updates = 0;
        ttfs_spikes = 0;
        rate_spikes = 0;

        #22 rst = 0;
        #20;

        $display("Test 1: TTFS Temporal Coding Verification");
        test_num = 1;

        ttfs_enable = 1;
        current_valid = 1;

        for (i = 0; i < 10; i = i + 1) begin
            input_current = 32'h20000000 + (i * 32'h08000000);

            if (i == 0) begin
                current_valid = 0;
                #50;
                current_valid = 1;
            end

            window_len = 100;
            spike_found = 0;
            for (j = 0; j < window_len && !spike_found; j = j + 1) begin
                #10;
                if (spike_out && spike_valid) begin
                    spike_times[test_num * 10 + i] = j;
                    $display("  TTFS Spike %0d: Time=%0d, Input=%08x", i, j, input_current);
                    spike_found = 1;
                end
            end

            #50;
        end

        $display("Test 2: STDP Learning Rule Verification");
        test_num = 2;

        stdp_enable = 1;
        learning_enable = 1;
        stdp_updates = 0;

        for (i = 0; i < 10; i = i + 1) begin
            weights_before[i] = 8'h40 + (i * 8'h05);
            pre_spike_time = i * 32'd10;
            post_spike_time = pre_spike_time + (i * 2);

            #5 pre_spike = 1; post_spike = 1;
            #5 pre_spike = 0; post_spike = 0;

            #20;

            if (weight_updated) begin
                weights_after[i] = updated_weight;
                stdp_updates = stdp_updates + 1;
                $display("  STDP Update %0d: Pre@%0d, Post@%0d, Old=%02x, New=%02x",
                         i, pre_spike_time, post_spike_time, weights_before[i], updated_weight);
            end

            #50;
        end

        $display("Test 3: TTFS vs Rate Coding Comparison");
        test_num = 3;

        ttfs_spikes = 0;
        rate_spikes = 0;

        ttfs_enable = 1;
        input_current = 32'h60000000;

        for (i = 0; i < 200; i = i + 1) begin
            current_valid = 1;
            #10;

            if (spike_out && spike_valid) begin
                ttfs_spikes = ttfs_spikes + 1;
                $display("  TTFS Mode - Spike at cycle %0d", i);
            end

            if (i > 150) begin
                ttfs_enable = 0;
            end
        end

        #50;
        rst = 1;
        #10;
        rst = 0;
        current_valid = 1;
        input_current = 32'h60000000;
        ttfs_enable = 0;

        for (i = 0; i < 200; i = i + 1) begin
            #10;

            if (spike_out && spike_valid) begin
                rate_spikes = rate_spikes + 1;
                $display("  Rate Mode - Spike at cycle %0d", i);
            end
        end

        $display("=== TTFS vs Rate Coding Results ===");
        $display("TTFS Mode Spikes: %0d", ttfs_spikes);
        $display("Rate Mode Spikes: %0d", rate_spikes);

        if (rate_spikes > 0) begin
            energy_pct = ((rate_spikes - ttfs_spikes) * 10000) / rate_spikes;
            $display("Energy Reduction: %0d.%02d%%", energy_pct / 100, energy_pct % 100);

            if (energy_pct >= 4000) begin
                $display("PASS: Energy reduction (>=40%%) MET: %0d.%02d%%", energy_pct / 100, energy_pct % 100);
            end else begin
                $display("WARN: Energy reduction (>=40%%) NOT MET: %0d.%02d%%", energy_pct / 100, energy_pct % 100);
            end
        end else begin
            $display("WARN: No rate spikes, cannot compute energy reduction");
        end

        $display("=== STDP Learning Results ===");
        $display("STDP Updates Completed: %0d", stdp_updates);

        valid_weights = 0;
        for (i = 0; i < 10 && i < stdp_updates; i = i + 1) begin
            if (weights_after[i] >= 8'h01 && weights_after[i] <= 8'hFE) begin
                valid_weights = valid_weights + 1;
            end
        end

        $display("Weight Update Validity: %0d/%0d valid",
                 valid_weights, stdp_updates > 0 ? stdp_updates : 1);

        #100;
        $display("SNN TTFS and STDP Testbench completed.");
        $finish;
    end

    always @(posedge clk) begin
        if (!rst && spike_valid && spike_out) begin
            $display("Time: %0t, Spike fired, Membrane: %08x", $time, membrane_potential);
        end
        else if (!rst && weight_updated) begin
            $display("Time: %0t, STDP weight updated to: %02x", $time, updated_weight);
        end
    end

endmodule
