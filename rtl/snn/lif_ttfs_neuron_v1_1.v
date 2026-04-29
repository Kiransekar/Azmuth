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

// Neuron array wrapper (flat vector interface)
module lif_ttfs_neuron_v1_1_array #(
    parameter NUM_NEURONS = 256,
    parameter WEIGHT_BITS = 8,
    parameter TIME_WINDOW_BITS = 10
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          ttfs_enable,
    input  wire [2:0]                    t_window,
    input  wire [2:0]                    refractory_cycles,
    input  wire [31:0]                   input_current_0,
    input  wire [31:0]                   input_current_1,
    input  wire [31:0]                   input_current_2,
    input  wire [31:0]                   input_current_3,
    input  wire                          current_valid_0,
    input  wire                          current_valid_1,
    input  wire                          current_valid_2,
    input  wire                          current_valid_3,
    input  wire [31:0]                   v_threshold,
    input  wire [31:0]                   v_rest,
    output wire [31:0]                   membrane_potential_0,
    output wire [31:0]                   membrane_potential_1,
    output wire [31:0]                   membrane_potential_2,
    output wire [31:0]                   membrane_potential_3,
    output wire                          spike_out_0,
    output wire                          spike_out_1,
    output wire                          spike_out_2,
    output wire                          spike_out_3,
    output wire                          spike_valid_0,
    output wire                          spike_valid_1,
    output wire                          spike_valid_2,
    output wire                          spike_valid_3
);

    // Select neuron by ID for input routing
    // For full array, the wrapper would need NUM_NEURONS-wide vectors
    // This 4-neuron example demonstrates the pattern

    wire spike_internal [0:3];
    wire valid_internal [0:3];
    wire [31:0] vmem_internal [0:3];

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : neuron_gen
            lif_ttfs_neuron_v1_1 neuron_inst (
                .clk(clk),
                .rst(rst),
                .ttfs_enable(ttfs_enable),
                .t_window(t_window),
                .refractory_cycles(refractory_cycles),
                .input_current(input_current_0 + (gi === 0 ? 32'h0 :
                                  gi === 1 ? 32'h1 :
                                  gi === 2 ? 32'h2 : 32'h3)),
                .current_valid(current_valid_0 & (gi === 0) |
                              current_valid_1 & (gi === 1) |
                              current_valid_2 & (gi === 2) |
                              current_valid_3 & (gi === 3)),
                .spike_out(spike_internal[gi]),
                .membrane_potential(vmem_internal[gi]),
                .spike_valid(valid_internal[gi]),
                .v_threshold(v_threshold),
                .v_rest(v_rest)
            );
        end
    endgenerate

    // Output assignments
    assign membrane_potential_0 = vmem_internal[0];
    assign membrane_potential_1 = vmem_internal[1];
    assign membrane_potential_2 = vmem_internal[2];
    assign membrane_potential_3 = vmem_internal[3];
    assign spike_out_0 = spike_internal[0];
    assign spike_out_1 = spike_internal[1];
    assign spike_out_2 = spike_internal[2];
    assign spike_out_3 = spike_internal[3];
    assign spike_valid_0 = valid_internal[0];
    assign spike_valid_1 = valid_internal[1];
    assign spike_valid_2 = valid_internal[2];
    assign spike_valid_3 = valid_internal[3];

endmodule
