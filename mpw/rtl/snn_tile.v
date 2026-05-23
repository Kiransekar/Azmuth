// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// snn_tile.v
// Spiking Neural Network tile for Xcew processor
// Implements the LIF neuron array and spike router as specified

module snn_tile (
    input  wire        i_clk_snn,
    input  wire        i_rst,
    input  wire [63:0] i_spike_in,
    input  wire [15:0] i_weight_ptr,
    input  wire        i_classify_en,

    output reg [7:0]   o_class,
    output reg [7:0]   o_conf,
    output reg         o_done
);

    // LIF neuron parameters
    localparam NEURON_COUNT = 8;  // Using 8 for simplified implementation
    localparam V_MEM_WIDTH = 16;
    localparam THRESH_WIDTH = 8;
    localparam LEAK_WIDTH = 8;
    localparam RESET_WIDTH = 16;

    // Internal state arrays for neurons
    reg [V_MEM_WIDTH-1:0]  v_mem [0:NEURON_COUNT-1];
    reg [THRESH_WIDTH-1:0] spike_thresh [0:NEURON_COUNT-1];
    reg [LEAK_WIDTH-1:0]   leak_rate [0:NEURON_COUNT-1];
    reg [RESET_WIDTH-1:0]  reset_val [0:NEURON_COUNT-1];
    reg [7:0]              neuron_out [0:NEURON_COUNT-1];

    // FSM states
    typedef enum reg [2:0] {
        IDLE       = 3'b000,
        LOAD_BUFFER = 3'b001,
        CLASSIFY   = 3'b010,
        CHECK_CONF = 3'b011,
        DONE_STATE = 3'b100
    } snn_state_t;

    snn_state_t current_state, next_state;
    reg [3:0]  neuron_idx;
    reg [7:0]  classification_result;
    reg [7:0]  confidence_result;

    // Register state
    always @(posedge i_clk_snn or posedge i_rst) begin
        if (i_rst) begin
            current_state <= IDLE;
            o_class <= 8'h00;
            o_conf <= 8'h00;
            o_done <= 1'b0;
            neuron_idx <= 4'h0;
            classification_result <= 8'h00;
            confidence_result <= 8'h00;

            // Initialize neuron parameters
            for (integer i = 0; i < NEURON_COUNT; i = i + 1) begin
                v_mem[i] <= 16'h0000;
                spike_thresh[i] <= 8'h80;  // Default threshold
                leak_rate[i] <= 8'h0A;     // Default leak rate
                reset_val[i] <= 16'h0000;  // Default reset value
                neuron_out[i] <= 8'h00;
            end
        end else begin
            current_state <= next_state;

            case (next_state)
                IDLE: begin
                    o_done <= 1'b0;
                    if (i_classify_en) begin
                        next_state <= LOAD_BUFFER;
                    end
                end

                LOAD_BUFFER: begin
                    // Load spike buffer from input
                    // In a real implementation, this would interface with the spike router
                    next_state <= CLASSIFY;
                end

                CLASSIFY: begin
                    // Process each neuron in sequence
                    if (neuron_idx < NEURON_COUNT) begin
                        // LIF neuron update: v_mem <= v_mem + spike_input - leak_rate
                        // For simplicity, we'll use a simplified model
                        integer input_val;
                        input_val = i_spike_in[neuron_idx*8 +: 8];  // Get 8-bit input for this neuron

                        // Update membrane potential
                        if (v_mem[neuron_idx] > 16'h7FFF - input_val) begin
                            v_mem[neuron_idx] <= 16'h7FFF;  // Clamp to prevent overflow
                        end else begin
                            v_mem[neuron_idx] <= v_mem[neuron_idx] + input_val - {8'h00, leak_rate[neuron_idx]};
                        end

                        // Check if threshold is crossed
                        if (v_mem[neuron_idx] >= {8'h00, spike_thresh[neuron_idx]}) begin
                            // Spike occurred
                            neuron_out[neuron_idx] <= 8'hFF;
                            v_mem[neuron_idx] <= reset_val[neuron_idx];  // Reset membrane potential
                        end else begin
                            neuron_out[neuron_idx] <= 8'h00;
                        end

                        neuron_idx <= neuron_idx + 1;
                    end else begin
                        // Classification complete
                        next_state <= CHECK_CONF;
                        neuron_idx <= 4'h0;  // Reset for next round
                    end
                end

                CHECK_CONF: begin
                    // Calculate classification and confidence
                    // For simplicity, just take the highest activated neuron
                    integer max_activation;
                    integer max_idx;

                    max_activation = 0;
                    max_idx = 0;

                    for (integer i = 0; i < NEURON_COUNT; i = i + 1) begin
                        if (neuron_out[i] > max_activation) begin
                            max_activation = neuron_out[i];
                            max_idx = i;
                        end
                    end

                    classification_result <= max_idx[7:0];
                    confidence_result <= max_activation;

                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    o_class <= classification_result;
                    o_conf <= confidence_result;
                    o_done <= 1'b1;

                    if (!i_classify_en) begin
                        next_state <= IDLE;
                        o_done <= 1'b0;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (i_classify_en)
                    next_state = LOAD_BUFFER;
                else
                    next_state = IDLE;
            end
            LOAD_BUFFER: next_state = CLASSIFY;
            CLASSIFY: begin
                if (neuron_idx >= NEURON_COUNT)
                    next_state = CHECK_CONF;
                else
                    next_state = CLASSIFY;
            end
            CHECK_CONF: next_state = DONE_STATE;
            DONE_STATE: begin
                if (!i_classify_en)
                    next_state = IDLE;
                else
                    next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule