// rtl/snn/lif_ttfs_neuron.v
// Leaky Integrate-and-Fire Temporal Coding Neuron with Time-to-First-Spike (TTFS)
// Replaces rate-based encoding with temporal window comparator

`timescale 1ns/1ps

module lif_ttfs_neuron (
    input wire clk,
    input wire rst,

    // Control signals
    input wire ttfs_enable,           // CSR snn_ctrl[7]: TTFS mode enable
    input wire [2:0] t_window,        // CSR snn_ctrl[10:8]: Temporal window setting
    input wire [2:0] refractory_cycles, // Refractory period setting

    // Input signals
    input wire [31:0] input_current,   // Input current (includes synaptic inputs)
    input wire current_valid,          // Input current is valid

    // Output signals
    output reg spike_out,              // Spike output (on first threshold crossing)
    output reg [31:0] membrane_potential, // Membrane potential output
    output reg spike_valid,            // Spike output is valid

    // Configuration
    input wire [31:0] v_threshold,     // Threshold voltage
    input wire [31:0] v_rest,          // Resting potential
    input wire [31:0] leak_factor      // Leak factor for membrane decay
);

    // Internal parameters
    parameter WINDOW_CYCLES = 32'd100; // Default temporal window
    parameter DT = 32'd1;              // Time step

    // Internal signals
    reg [31:0] v_mem;                  // Membrane potential
    reg [31:0] spike_timestamp;        // Time of first spike
    reg [31:0] window_counter;         // Counter for temporal window
    reg [31:0] refractory_counter;     // Refractory period counter
    reg in_refractory;                 // Neuron in refractory period
    reg threshold_crossed;             // Indicates threshold was crossed in window
    reg [2:0] window_setting;          // Internal window setting

    // TTFS-specific signals
    reg [31:0] temporal_window_start;  // Start time of temporal window
    reg [31:0] time_since_start;       // Time elapsed since window start

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            v_mem <= v_rest;
            spike_out <= 1'b0;
            membrane_potential <= 32'h0;
            spike_valid <= 1'b0;
            window_counter <= 32'h0;
            refractory_counter <= 32'h0;
            in_refractory <= 1'b0;
            threshold_crossed <= 1'b0;
            spike_timestamp <= 32'h0;
            window_setting <= 3'b000;
            temporal_window_start <= 32'h0;
            time_since_start <= 32'h0;
        end
        else begin
            // Update window setting if changed
            if (t_window != window_setting) begin
                window_setting <= t_window;
            end

            // Calculate actual window length based on setting
            reg [31:0] effective_window;
            case (window_setting)
                3'b000: effective_window = 32'd10;    // 10 cycles
                3'b001: effective_window = 32'd25;    // 25 cycles
                3'b010: effective_window = 32'd50;    // 50 cycles
                3'b011: effective_window = 32'd100;   // 100 cycles
                3'b100: effective_window = 32'd200;   // 200 cycles
                3'b101: effective_window = 32'd500;   // 500 cycles
                3'b110: effective_window = 32'd1000;  // 1000 cycles
                3'b111: effective_window = 32'd2000;  // 2000 cycles
            endcase

            // Update time since window start
            if (current_valid && !in_refractory && ttfs_enable) begin
                if (window_counter == 0) begin
                    temporal_window_start <= $time;
                    time_since_start <= 32'h0;
                    threshold_crossed <= 1'b0;
                    window_counter <= effective_window;
                end else begin
                    time_since_start <= time_since_start + DT;
                end
            end

            // Update refractory counter
            if (in_refractory) begin
                if (refractory_counter > 0) begin
                    refractory_counter <= refractory_counter - 1;
                end else begin
                    in_refractory <= 1'b0;
                end
            end

            // Neuron dynamics
            if (in_refractory) begin
                // Hold at resting potential during refractory period
                v_mem <= v_rest;
            end
            else if (ttfs_enable && current_valid) begin
                // TTFS mode - temporal coding
                if (window_counter > 0) begin
                    // Update membrane potential with leak
                    v_mem <= v_mem + input_current - (leak_factor * v_mem) / 32'd1000;

                    // Check for threshold crossing in TTFS mode
                    if (v_mem >= v_threshold && !threshold_crossed) begin
                        // Spike on first threshold crossing within window
                        spike_out <= 1'b1;
                        spike_valid <= 1'b1;
                        threshold_crossed <= 1'b1;
                        spike_timestamp <= time_since_start; // Timestamp of spike

                        // Enter refractory period
                        in_refractory <= 1'b1;
                        refractory_counter <= {refractory_cycles, 29'd0}; // Scale to proper range

                        // Reset membrane potential
                        v_mem <= v_rest;
                    end
                    else begin
                        spike_out <= 1'b0;
                        spike_valid <= 1'b0;
                    end

                    // Decrement window counter
                    window_counter <= window_counter - 1;
                end
                else begin
                    // Window expired, reset for next temporal event
                    v_mem <= v_rest;
                    spike_out <= 1'b0;
                    spike_valid <= 1'b0;
                    threshold_crossed <= 1'b0;
                end
            end
            else if (!ttfs_enable && current_valid) begin
                // Traditional LIF mode (disabled when TTFS is enabled)
                // Update membrane potential with leak
                v_mem <= v_mem + input_current - (leak_factor * v_mem) / 32'd1000;

                if (v_mem >= v_threshold) begin
                    // Generate spike and reset membrane potential
                    spike_out <= 1'b1;
                    spike_valid <= 1'b1;
                    v_mem <= v_rest;

                    // Enter refractory period
                    in_refractory <= 1'b1;
                    refractory_counter <= {refractory_cycles, 29'd0};
                end
                else begin
                    spike_out <= 1'b0;
                    spike_valid <= 1'b0;
                end
            end
            else begin
                // No input current, just leak
                v_mem <= v_mem - (leak_factor * v_mem) / 32'd1000;
                if (v_mem < v_rest) v_mem <= v_rest; // Don't go below resting potential

                spike_out <= 1'b0;
                spike_valid <= 1'b0;
            end

            // Update membrane potential output
            membrane_potential <= v_mem;
        end
    end

    // Additional control for window and refractory period
    function [31:0] get_window_duration;
        input [2:0] setting;
        begin
            case (setting)
                3'b000: get_window_duration = 32'd10;
                3'b001: get_window_duration = 32'd25;
                3'b010: get_window_duration = 32'd50;
                3'b011: get_window_duration = 32'd100;
                3'b100: get_window_duration = 32'd200;
                3'b101: get_window_duration = 32'd500;
                3'b110: get_window_duration = 32'd1000;
                3'b111: get_window_duration = 32'd2000;
                default: get_window_duration = 32'd100;
            endcase
        end
    endfunction

endmodule

// TTFS neuron array wrapper
module lif_ttfs_neuron_array #(
    parameter NUM_NEURONS = 64
)(
    input wire clk,
    input wire rst,
    input wire ttfs_enable,
    input wire [2:0] t_window,
    input wire [2:0] refractory_cycles,

    input wire [NUM_NEURONS-1:0] input_valid,
    input wire [31:0] input_current [0:NUM_NEURONS-1],

    output wire [NUM_NEURONS-1:0] spike_out,
    output wire [NUM_NEURONS-1:0] spike_valid,
    output wire [31:0] membrane_potential [0:NUM_NEURONS-1],

    input wire [31:0] v_threshold,
    input wire [31:0] v_rest,
    input wire [31:0] leak_factor
);

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : neuron_gen
            lif_ttfs_neuron neuron_inst (
                .clk(clk),
                .rst(rst),
                .ttfs_enable(ttfs_enable),
                .t_window(t_window),
                .refractory_cycles(refractory_cycles),
                .input_current(input_current[i]),
                .current_valid(input_valid[i]),
                .spike_out(spike_out[i]),
                .spike_valid(spike_valid[i]),
                .membrane_potential(membrane_potential[i]),
                .v_threshold(v_threshold),
                .v_rest(v_rest),
                .leak_factor(leak_factor)
            );
        end
    endgenerate

endmodule