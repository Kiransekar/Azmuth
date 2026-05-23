// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// lif_ttfs_neuron_v1_1.v
// LIF Neuron with Time-to-First-Spike encoding for Xcew Processor v1.1
// Verilog-2001 compliant, synthesizable

module lif_ttfs_neuron_v1_1 (
    input  wire        clk,
    input  wire        rst,
    input  wire        ttfs_enable,
    input  wire [2:0]  t_window,
    input  wire [2:0]  refractory_cycles,
    input  wire [31:0] input_current,
    input  wire        current_valid,
    output reg         spike_out,
    output reg  [31:0] membrane_potential,
    output reg         spike_valid,
    input  wire [31:0] v_threshold,
    input  wire [31:0] v_rest
);

    // FSM state encoding (binary)
    parameter STATE_IDLE       = 2'b00;
    parameter STATE_INTEGRATE  = 2'b01;
    parameter STATE_SPIKE      = 2'b10;
    parameter STATE_REFRACTORY = 2'b11;

    // Internal registers
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [31:0] v_mem;
    reg [31:0] cycle_count;
    reg [31:0] window_cycles;
    reg [31:0] refractory_count;
    reg        threshold_crossed;

    // Combinational: map t_window to cycle count
    always @(*) begin
        case (t_window)
            3'b000: window_cycles = 32'd10;
            3'b001: window_cycles = 32'd20;
            3'b010: window_cycles = 32'd50;
            3'b011: window_cycles = 32'd100;
            3'b100: window_cycles = 32'd200;
            3'b101: window_cycles = 32'd500;
            3'b110: window_cycles = 32'd1000;
            3'b111: window_cycles = 32'd2000;
            default: window_cycles = 32'd100;
        endcase
    end

    // Sequential: state register and core logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state      <= STATE_IDLE;
            v_mem              <= 32'h0;
            cycle_count        <= 32'h0;
            refractory_count   <= 32'h0;
            spike_out          <= 1'b0;
            spike_valid        <= 1'b0;
            membrane_potential <= 32'h0;
            threshold_crossed  <= 1'b0;
        end else begin
            current_state <= next_state;
            membrane_potential <= v_mem;
            spike_valid <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    spike_out <= 1'b0;
                    cycle_count <= 32'h0;
                    v_mem <= v_rest;
                    threshold_crossed <= 1'b0;
                    if (current_valid && ttfs_enable) begin
                        next_state <= STATE_INTEGRATE;
                        v_mem <= v_mem + input_current;
                    end else if (current_valid && !ttfs_enable) begin
                        // Non-TTFS mode: simple integrate-and-fire
                        next_state <= STATE_INTEGRATE;
                        v_mem <= v_mem + input_current;
                    end
                end

                STATE_INTEGRATE: begin
                    spike_out <= 1'b0;
                    cycle_count <= cycle_count + 1'b1;

                    // Integrate input
                    if (current_valid) begin
                        v_mem <= v_mem + input_current;
                    end

                    // Check threshold
                    if (v_mem >= v_threshold && !threshold_crossed) begin
                        threshold_crossed <= 1'b1;
                        spike_out <= 1'b1;
                        spike_valid <= 1'b1;
                        next_state <= STATE_SPIKE;
                    end

                    // Window expired without spike (TTFS mode only)
                    if (ttfs_enable && cycle_count >= window_cycles && !threshold_crossed) begin
                        v_mem <= v_rest;
                        cycle_count <= 32'h0;
                        next_state <= STATE_IDLE;
                    end
                end

                STATE_SPIKE: begin
                    spike_out <= 1'b1;
                    spike_valid <= 1'b0;
                    threshold_crossed <= 1'b0;
                    // Initialize refractory counter
                    refractory_count <= {29'h0, refractory_cycles};
                    next_state <= STATE_REFRACTORY;
                end

                STATE_REFRACTORY: begin
                    spike_out <= 1'b0;
                    if (refractory_count > 0) begin
                        refractory_count <= refractory_count - 1'b1;
                        v_mem <= v_rest;
                    end else begin
                        v_mem <= v_rest;
                        cycle_count <= 32'h0;
                        next_state <= STATE_IDLE;
                    end
                end

                default: begin
                    next_state <= STATE_IDLE;
                    v_mem <= v_rest;
                end
            endcase
        end
    end

endmodule

// Neuron array wrapper — scalable flat-vector interface
// Supports NUM_NEURONS instances of lif_ttfs_neuron_v1_1
/* verilator lint_off DECLFILENAME */
module lif_ttfs_neuron_v1_1_array #(
    parameter NUM_NEURONS = 256
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          ttfs_enable,
    input  wire [2:0]                    t_window,
    input  wire [2:0]                    refractory_cycles,
    input  wire [32*NUM_NEURONS-1:0]     input_currents,   // 32 bits per neuron
    input  wire [NUM_NEURONS-1:0]        current_valids,   // 1 bit per neuron
    input  wire [31:0]                   v_threshold,
    input  wire [31:0]                   v_rest,
    output wire [32*NUM_NEURONS-1:0]     membrane_potentials,
    output wire [NUM_NEURONS-1:0]        spike_outs,
    output wire [NUM_NEURONS-1:0]        spike_valids
);

    // Internal arrays (unpacked — valid in Verilog-2001 for internal use)
    wire spike_internal [0:NUM_NEURONS-1];
    wire valid_internal [0:NUM_NEURONS-1];
    wire [31:0] vmem_internal [0:NUM_NEURONS-1];

    genvar gi;
    generate
        for (gi = 0; gi < NUM_NEURONS; gi = gi + 1) begin : neuron_gen
            lif_ttfs_neuron_v1_1 neuron_inst (
                .clk(clk),
                .rst(rst),
                .ttfs_enable(ttfs_enable),
                .t_window(t_window),
                .refractory_cycles(refractory_cycles),
                .input_current(input_currents[gi*32 +: 32]),
                .current_valid(current_valids[gi]),
                .spike_out(spike_internal[gi]),
                .membrane_potential(vmem_internal[gi]),
                .spike_valid(valid_internal[gi]),
                .v_threshold(v_threshold),
                .v_rest(v_rest)
            );
        end
    endgenerate

    // Flatten internal unpacked arrays back to output vectors
    // Verilog-2001: generate loop for continuous assignments
    genvar gj;
    generate
        for (gj = 0; gj < NUM_NEURONS; gj = gj + 1) begin : output_assign
            assign membrane_potentials[gj*32 +: 32] = vmem_internal[gj];
            assign spike_outs[gj] = spike_internal[gj];
            assign spike_valids[gj] = valid_internal[gj];
        end
    endgenerate

endmodule
