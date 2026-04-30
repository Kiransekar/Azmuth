// snn_tile_256.v
// 256-neuron Spiking Neural Network classifier for Xcew processor v1.1
// Wraps lif_ttfs_neuron_v1_1_array and implements winner-take-all classification
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module snn_tile_256 #(
    parameter NUM_NEURONS = 256  /* verilator lint_off UNUSEDPARAM */
) ( /* verilator lint_on UNUSEDPARAM */
    input  wire        i_clk_snn,
    input  wire        i_rst,
    input  wire        i_classify_en,
    input  wire        i_ttfs_enable,
    input  wire [2:0]  i_t_window,
    input  wire [2:0]  i_refractory_cycles,
    input  wire [31:0] i_v_threshold,
    input  wire [31:0] i_v_rest,

    // Sequential input loading via 32-bit data bus with neuron index
    input  wire [31:0] i_input_current,
    input  wire [7:0]  i_neuron_idx,      // 0-255 (sw ignores upper bits if NUM_NEURONS < 256)
    input  wire        i_current_valid,

    output reg  [7:0]  o_class,           // Winning neuron
    output reg  [15:0] o_conf,            // Confidence (spike count / timing)
    output reg         o_done,
    output wire        o_ready,

    // Spike outputs for STDP integration
    output wire [NUM_NEURONS-1:0] o_spike_outs,
    output wire [NUM_NEURONS-1:0] o_spike_valids
);

    // -------------------------------------------------------------------------
    // Parameter-derived widths
    // -------------------------------------------------------------------------
    function integer clog2;
        input integer value;
        begin
            clog2 = 0;
            while (value > 1) begin
                clog2 = clog2 + 1;
                value = value >> 1;
            end
        end
    endfunction

    localparam IDX_W = clog2(NUM_NEURONS);

    wire [32*NUM_NEURONS-1:0] input_currents_vec;
    wire [NUM_NEURONS-1:0]    current_valids_vec;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [32*NUM_NEURONS-1:0] membrane_potentials_vec;  // Available for future debug/STDP use
    /* verilator lint_on UNUSEDSIGNAL */
    wire [NUM_NEURONS-1:0]    spike_outs_vec;
    wire [NUM_NEURONS-1:0]    spike_valids_vec;

    // Input current register file (loaded sequentially)
    reg [31:0] input_current_reg [0:NUM_NEURONS-1];
    reg [NUM_NEURONS-1:0] current_valid_reg;

    // Flatten registers to vector for array
    genvar gk;
    generate
        for (gk = 0; gk < NUM_NEURONS; gk = gk + 1) begin : flatten_in
            assign input_currents_vec[gk*32 +: 32] = input_current_reg[gk];
            assign current_valids_vec[gk] = current_valid_reg[gk];
        end
    endgenerate

    // Instantiate 256-neuron array
    lif_ttfs_neuron_v1_1_array #(.NUM_NEURONS(NUM_NEURONS)) neuron_array (
        .clk(i_clk_snn),
        .rst(i_rst),
        .ttfs_enable(i_ttfs_enable),
        .t_window(i_t_window),
        .refractory_cycles(i_refractory_cycles),
        .input_currents(input_currents_vec),
        .current_valids(current_valids_vec),
        .v_threshold(i_v_threshold),
        .v_rest(i_v_rest),
        .membrane_potentials(membrane_potentials_vec),
        .spike_outs(spike_outs_vec),
        .spike_valids(spike_valids_vec)
    );

    // -------------------------------------------------------------------------
    // Classification FSM
    // Scans all NUM_NEURONS neurons and picks winner
    // -------------------------------------------------------------------------
    localparam IDLE       = 3'b000;
    localparam LOAD       = 3'b001;  // Load input currents (sequential)
    localparam INTEGRATE  = 3'b010;  // Wait for spikes
    localparam SCAN       = 3'b011;  // Scan neurons for winner
    localparam DONE_STATE = 3'b100;

    reg [2:0] current_state, next_state;
    reg [IDX_W-1:0] scan_idx;
    reg [IDX_W:0]   scan_counter;     // One extra bit to count up to NUM_NEURONS
    reg [IDX_W:0]   load_counter;     // Count loaded neurons
    reg             load_done;
    reg [15:0]      max_spike_count;
    reg [IDX_W-1:0] winner_neuron;
    reg [15:0] spike_counts [0:NUM_NEURONS-1];
    reg [15:0] cycle_counter;
    reg [15:0] window_cycles;

    // Window cycle mapping (same as lif_ttfs_neuron)
    always @(*) begin
        case (i_t_window)
            3'b000:  window_cycles = 16'd10;
            3'b001:  window_cycles = 16'd20;
            3'b010:  window_cycles = 16'd50;
            3'b011:  window_cycles = 16'd100;
            3'b100:  window_cycles = 16'd200;
            3'b101:  window_cycles = 16'd500;
            3'b110:  window_cycles = 16'd1000;
            3'b111:  window_cycles = 16'd2000;
            default: window_cycles = 16'd100;
        endcase
    end

    assign o_ready = (current_state == IDLE);
    assign o_spike_outs = spike_outs_vec;
    assign o_spike_valids = spike_valids_vec;

    // Sequential state register + input loading + spike counting
    integer si;
    always @(posedge i_clk_snn or posedge i_rst) begin
        if (i_rst) begin
            current_state <= IDLE;
            scan_idx <= {IDX_W{1'b0}};
            scan_counter <= {IDX_W+1{1'b0}};
            load_counter <= {IDX_W+1{1'b0}};
            load_done <= 1'b0;
            max_spike_count <= 16'd0;
            winner_neuron <= {IDX_W{1'b0}};
            cycle_counter <= 16'd0;
            o_class <= 8'd0;
            o_conf <= 16'd0;
            o_done <= 1'b0;
            current_valid_reg <= {NUM_NEURONS{1'b0}};
            for (si = 0; si < NUM_NEURONS; si = si + 1) begin
                input_current_reg[si] <= 32'd0;
                spike_counts[si] <= 16'd0;
            end
        end else begin
            current_state <= next_state;
            o_done <= 1'b0;

            case (current_state)
                IDLE: begin
                    scan_idx <= {IDX_W{1'b0}};
                    scan_counter <= {IDX_W+1{1'b0}};
                    load_counter <= {IDX_W+1{1'b0}};
                    load_done <= 1'b0;  // Reset load_done when entering IDLE
                    max_spike_count <= 16'd0;
                    winner_neuron <= {IDX_W{1'b0}};
                    cycle_counter <= 16'd0;
                    current_valid_reg <= {NUM_NEURONS{1'b0}};
                    for (si = 0; si < NUM_NEURONS; si = si + 1)
                        spike_counts[si] <= 16'd0;

                    if (i_classify_en) begin
                        // Begin loading input currents
                    end
                end

                LOAD: begin
                    if (i_current_valid) begin
                        input_current_reg[i_neuron_idx] <= i_input_current;
                        current_valid_reg[i_neuron_idx] <= 1'b1;
                        load_counter <= load_counter + 1;
                    end
                    // All neurons loaded
                    if (load_counter >= NUM_NEURONS - 1)
                        load_done <= 1'b1;
                end

                INTEGRATE: begin
                    cycle_counter <= cycle_counter + 1;
                    // Count spikes from each neuron
                    for (si = 0; si < NUM_NEURONS; si = si + 1) begin
                        if (spike_valids_vec[si] && spike_outs_vec[si])
                            spike_counts[si] <= spike_counts[si] + 1;
                    end
                end

                SCAN: begin
                    // Find neuron with max spike count
                    if (scan_counter < NUM_NEURONS) begin
                        if (spike_counts[scan_idx] > max_spike_count) begin
                            max_spike_count <= spike_counts[scan_idx];
                            winner_neuron <= scan_idx[IDX_W-1:0];
                        end
                        scan_idx <= scan_idx + 1;
                        scan_counter <= scan_counter + 1;
                    end
                end

                DONE_STATE: begin
                    o_class <= winner_neuron;
                    o_conf <= max_spike_count;
                    o_done <= 1'b1;
                end

                default: ;  // Handled by combinational next-state logic
            endcase
        end
    end

    // Combinational next-state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (i_classify_en)
                    next_state = LOAD;
            end
            LOAD: begin
                // Transition when all neurons loaded
                if (load_done)
                    next_state = INTEGRATE;
            end
            INTEGRATE: begin
                if (cycle_counter >= window_cycles)
                    next_state = SCAN;
            end
            SCAN: begin
                if (scan_counter >= NUM_NEURONS)
                    next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
