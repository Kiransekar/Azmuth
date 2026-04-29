// rtl/snn/stdp_engine.v
// Spike-Timing Dependent Plasticity Engine
// Implements biological learning rule for synaptic weight updates

`timescale 1ns/1ps

module stdp_engine (
    input wire clk,
    input wire rst,

    // Control signals
    input wire [3:0] stdp_policy,      // CSR snn_ctrl[15:12]: STDP policy
    input wire stdp_enable,            // Enable STDP learning

    // Spike timing information
    input wire pre_spike,              // Presynaptic spike
    input wire post_spike,             // Postsynaptic spike
    input wire [31:0] pre_spike_time,  // Presynaptic spike timestamp
    input wire [31:0] post_spike_time, // Postsynaptic spike timestamp

    // Weight interface
    input wire [7:0] current_weight,   // Current synaptic weight (8-bit signed)
    output reg [7:0] updated_weight,   // Updated synaptic weight
    output reg weight_updated,         // Weight was updated

    // STDP parameters
    input wire [31:0] A_plus,          // STDP amplitude for LTP (pre→post)
    input wire [31:0] A_minus,         // STDP amplitude for LTD (post→pre)
    input wire [31:0] tau_plus,        // STDP time constant for LTP
    input wire [31:0] tau_minus,       // STDP time constant for LTD

    // Learning control
    input wire learning_enable         // Global learning enable
);

    // Internal parameters
    parameter WEIGHT_WIDTH = 8;
    parameter SIGNED_WEIGHT_MIN = -127;
    parameter SIGNED_WEIGHT_MAX = 127;

    // STDP timing difference
    reg [31:0] delta_t;                // Time difference between spikes
    reg spike_event_pending;           // Indicates spike event to process
    reg [31:0] pending_pre_time;       // Pending presynaptic time
    reg [31:0] pending_post_time;      // Pending postsynaptic time
    reg pending_direction;             // Direction: 0=post-pre, 1=pre-post

    // STDP curve evaluation
    reg [31:0] stdp_value;             // Calculated STDP value
    reg [7:0] weight_change;           // Weight change amount
    reg [7:0] signed_current_weight;   // Signed version of current weight

    // Internal state
    reg [31:0] last_pre_spike_time;    // Last presynaptic spike time
    reg [31:0] last_post_spike_time;   // Last postsynaptic spike time

    // STDP calculation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            updated_weight <= 8'sd0;
            weight_updated <= 1'b0;
            last_pre_spike_time <= 32'h0;
            last_post_spike_time <= 32'h0;
            delta_t <= 32'h0;
            stdp_value <= 32'h0;
            weight_change <= 8'h0;
            spike_event_pending <= 1'b0;
            pending_pre_time <= 32'h0;
            pending_post_time <= 32'h0;
            pending_direction <= 1'b0;
            signed_current_weight <= 8'sd0;
        end
        else begin
            weight_updated <= 1'b0;

            // Track spike times
            if (pre_spike) begin
                last_pre_spike_time <= pre_spike_time;
            end

            if (post_spike) begin
                last_post_spike_time <= post_spike_time;
            end

            // Detect spike pair events and calculate timing
            if (pre_spike && post_spike) begin
                // Both spikes occurred simultaneously, handle as pre→post
                if (pre_spike_time < post_spike_time) begin
                    // Pre-spike before post-spike: LTP
                    delta_t <= post_spike_time - pre_spike_time;
                    pending_direction <= 1'b1; // pre→post
                end
                else begin
                    // Post-spike before pre-spike: LTD
                    delta_t <= pre_spike_time - post_spike_time;
                    pending_direction <= 1'b0; // post→pre
                end

                pending_pre_time <= pre_spike_time;
                pending_post_time <= post_spike_time;
                spike_event_pending <= 1'b1;
            end
            else if (pre_spike && (last_post_spike_time > 0)) begin
                // Pre-spike after previous post-spike: LTP
                delta_t <= pre_spike_time - last_post_spike_time;
                pending_direction <= 1'b1; // pre→post
                pending_pre_time <= pre_spike_time;
                pending_post_time <= last_post_spike_time;
                spike_event_pending <= 1'b1;
            end
            else if (post_spike && (last_pre_spike_time > 0)) begin
                // Post-spike after previous pre-spike: LTD
                delta_t <= post_spike_time - last_pre_spike_time;
                pending_direction <= 1'b0; // post→pre
                pending_pre_time <= last_pre_spike_time;
                pending_post_time <= post_spike_time;
                spike_event_pending <= 1'b1;
            end

            // Process pending STDP event if learning is enabled
            if (spike_event_pending && learning_enable && stdp_enable) begin
                if (pending_direction) begin
                    // Pre→post (LTP): Long-term potentiation
                    // Δw = A+ * exp(-Δt/τ+)
                    if (tau_plus > 0) begin
                        // Simplified exponential approximation
                        stdp_value <= A_plus >> (delta_t / tau_plus);  // Right shift approximates division and exp
                    end
                    else begin
                        stdp_value <= A_plus;
                    end
                end
                else begin
                    // Post→pre (LTD): Long-term depression
                    // Δw = A- * exp(-Δt/τ-)
                    if (tau_minus > 0) begin
                        stdp_value <= A_minus >> (delta_t / tau_minus);  // Right shift approximates division and exp
                    end
                    else begin
                        stdp_value <= A_minus;
                    end

                    // Make LTD negative
                    stdp_value <= ~stdp_value + 1;  // Two's complement
                end

                // Convert STDP value to weight change (scale appropriately)
                weight_change <= stdp_value[7:0];  // Take lower 8 bits

                // Apply STDP policy constraints
                case (stdp_policy)
                    4'h0: begin // Disabled
                        weight_change <= 8'h0;
                    end
                    4'h1: begin // Hebbian: LTP and LTD allowed
                        // Use calculated weight_change
                    end
                    4'h2: begin // Anti-Hebbian: inverse of Hebbian
                        weight_change <= ~weight_change + 1;  // Invert
                    end
                    4'h3: begin // LTP only: depress only positive changes
                        if (weight_change[7]) begin  // If negative
                            weight_change <= 8'h0;  // Clamp to zero
                        end
                    end
                    4'h4: begin // LTD only: depress only negative changes
                        if (!weight_change[7]) begin  // If positive
                            weight_change <= 8'h0;  // Clamp to zero
                        end
                    end
                    4'h5: begin // Homeostatic: maintain average activity
                        // Would require additional activity tracking
                        // For now, apply normal STDP but with reduced magnitude
                        weight_change <= weight_change >>> 1;  // Divide by 2
                    end
                    default: begin // Default: Hebbian
                        // Use calculated weight_change
                    end
                end

                // Apply weight change to current weight
                signed_current_weight <= $signed({current_weight[7], current_weight});

                // Calculate new weight with saturation arithmetic
                if (pending_direction) begin
                    // LTP: Add positive change
                    if ($signed(signed_current_weight) > SIGNED_WEIGHT_MAX - $signed(weight_change)) begin
                        updated_weight <= SIGNED_WEIGHT_MAX;
                    end
                    else if ($signed(signed_current_weight) < SIGNED_WEIGHT_MIN + $signed(weight_change)) begin
                        updated_weight <= SIGNED_WEIGHT_MIN;
                    end
                    else begin
                        updated_weight <= signed_current_weight + weight_change;
                    end
                end
                else begin
                    // LTD: Add negative change (subtract positive)
                    if ($signed(signed_current_weight) > SIGNED_WEIGHT_MAX + $signed(weight_change)) begin
                        updated_weight <= SIGNED_WEIGHT_MAX;
                    end
                    else if ($signed(signed_current_weight) < SIGNED_WEIGHT_MIN + $signed(weight_change)) begin
                        updated_weight <= SIGNED_WEIGHT_MIN;
                    end
                    else begin
                        updated_weight <= signed_current_weight - weight_change;
                    end
                end

                weight_updated <= 1'b1;
                spike_event_pending <= 1'b0;
            end
            else if (!learning_enable || !stdp_enable) begin
                // No learning, keep current weight
                updated_weight <= current_weight;
                spike_event_pending <= 1'b0;
            end
        end
    end

    // Weight array management for multiple synapses
    function [7:0] apply_stdp_to_weight;
        input [7:0] current_w;
        input [31:0] pre_time;
        input [31:0] post_time;
        input is_pre_post;
        begin
            // Helper function to apply STDP to a single weight
            // Implementation would be similar to the logic above
            apply_stdp_to_weight = current_w;  // Placeholder
        end
    endfunction

endmodule

// STDP weight array module
module stdp_weight_array #(
    parameter NUM_SYNAPSES = 256
)(
    input wire clk,
    input wire rst,
    input wire [3:0] stdp_policy,
    input wire stdp_enable,
    input wire learning_enable,

    // Spike inputs for multiple synapses
    input wire [NUM_SYNAPSES-1:0] pre_spike,
    input wire [NUM_SYNAPSES-1:0] post_spike,
    input wire [31:0] pre_spike_time [0:NUM_SYNAPSES-1],
    input wire [31:0] post_spike_time [0:NUM_SYNAPSES-1],

    // Weight arrays
    input wire [7:0] current_weights [0:NUM_SYNAPSES-1],
    output reg [7:0] updated_weights [0:NUM_SYNAPSES-1],
    output reg [NUM_SYNAPSES-1:0] weight_updated
);

    integer i;

    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < NUM_SYNAPSES; i = i + 1) begin
                updated_weights[i] <= current_weights[i];
                weight_updated[i] <= 1'b0;
            end
        end
        else begin
            for (i = 0; i < NUM_SYNAPSES; i = i + 1) begin
                stdp_engine engine_inst (
                    .clk(clk),
                    .rst(rst),
                    .stdp_policy(stdp_policy),
                    .stdp_enable(stdp_enable),
                    .pre_spike(pre_spike[i]),
                    .post_spike(post_spike[i]),
                    .pre_spike_time(pre_spike_time[i]),
                    .post_spike_time(post_spike_time[i]),
                    .current_weight(current_weights[i]),
                    .updated_weight(updated_weights[i]),
                    .weight_updated(weight_updated[i]),
                    .A_plus(32'h10000000),  // Default STDP parameters
                    .A_minus(32'h10000000),
                    .tau_plus(32'd10),
                    .tau_minus(32'd10),
                    .learning_enable(learning_enable)
                );
            end
        end
    end

endmodule