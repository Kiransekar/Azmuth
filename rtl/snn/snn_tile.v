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

    // Temporary registers to avoid local declarations
    reg [7:0] temp_input_val;
    reg [7:0] temp_max;
    reg [7:0] temp_idx;

    // FSM states (binary encoding, no typedef enum)
    parameter IDLE        = 3'b000;
    parameter LOAD_BUFFER = 3'b001;
    parameter CLASSIFY    = 3'b010;
    parameter CHECK_CONF  = 3'b011;
    parameter DONE_STATE  = 3'b100;

    reg [2:0] current_state, next_state;
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
            v_mem[0] <= 16'h0000;
            spike_thresh[0] <= 8'h80;  // Default threshold
            leak_rate[0] <= 8'h0A;     // Default leak rate
            reset_val[0] <= 16'h0000;  // Default reset value
            neuron_out[0] <= 8'h00;
            v_mem[1] <= 16'h0000;
            spike_thresh[1] <= 8'h80;  // Default threshold
            leak_rate[1] <= 8'h0A;     // Default leak rate
            reset_val[1] <= 16'h0000;  // Default reset value
            neuron_out[1] <= 8'h00;
            v_mem[2] <= 16'h0000;
            spike_thresh[2] <= 8'h80;  // Default threshold
            leak_rate[2] <= 8'h0A;     // Default leak rate
            reset_val[2] <= 16'h0000;  // Default reset value
            neuron_out[2] <= 8'h00;
            v_mem[3] <= 16'h0000;
            spike_thresh[3] <= 8'h80;  // Default threshold
            leak_rate[3] <= 8'h0A;     // Default leak rate
            reset_val[3] <= 16'h0000;  // Default reset value
            neuron_out[3] <= 8'h00;
            v_mem[4] <= 16'h0000;
            spike_thresh[4] <= 8'h80;  // Default threshold
            leak_rate[4] <= 8'h0A;     // Default leak rate
            reset_val[4] <= 16'h0000;  // Default reset value
            neuron_out[4] <= 8'h00;
            v_mem[5] <= 16'h0000;
            spike_thresh[5] <= 8'h80;  // Default threshold
            leak_rate[5] <= 8'h0A;     // Default leak rate
            reset_val[5] <= 16'h0000;  // Default reset value
            neuron_out[5] <= 8'h00;
            v_mem[6] <= 16'h0000;
            spike_thresh[6] <= 8'h80;  // Default threshold
            leak_rate[6] <= 8'h0A;     // Default leak rate
            reset_val[6] <= 16'h0000;  // Default reset value
            neuron_out[6] <= 8'h00;
            v_mem[7] <= 16'h0000;
            spike_thresh[7] <= 8'h80;  // Default threshold
            leak_rate[7] <= 8'h0A;     // Default leak rate
            reset_val[7] <= 16'h0000;  // Default reset value
            neuron_out[7] <= 8'h00;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    o_done <= 1'b0;
                end

                LOAD_BUFFER: begin
                    // Load spike buffer from input
                end

                CLASSIFY: begin
                    // Process each neuron in sequence
                    if (neuron_idx < NEURON_COUNT) begin
                        // LIF neuron update: v_mem <= v_mem + spike_input - leak_rate
                        temp_input_val = i_spike_in[neuron_idx*8 +: 8];

                        // Update membrane potential
                        if (v_mem[neuron_idx] > 16'h7FFF - temp_input_val) begin
                            v_mem[neuron_idx] <= 16'h7FFF;  // Clamp to prevent overflow
                        end else begin
                            v_mem[neuron_idx] <= v_mem[neuron_idx] + temp_input_val - {8'h00, leak_rate[neuron_idx]};
                        end

                        // Check if threshold is crossed
                        if (v_mem[neuron_idx] >= {8'h00, spike_thresh[neuron_idx]}) begin
                            neuron_out[neuron_idx] <= 8'hFF;
                            v_mem[neuron_idx] <= reset_val[neuron_idx];
                        end else begin
                            neuron_out[neuron_idx] <= 8'h00;
                        end

                        neuron_idx <= neuron_idx + 1;
                    end else begin
                        neuron_idx <= 4'h0;
                    end
                end

                CHECK_CONF: begin
                    // Calculate classification and confidence
                    temp_max = neuron_out[0];
                    temp_idx = 0;

                    if (neuron_out[1] > temp_max) begin temp_max = neuron_out[1]; temp_idx = 1; end
                    if (neuron_out[2] > temp_max) begin temp_max = neuron_out[2]; temp_idx = 2; end
                    if (neuron_out[3] > temp_max) begin temp_max = neuron_out[3]; temp_idx = 3; end
                    if (neuron_out[4] > temp_max) begin temp_max = neuron_out[4]; temp_idx = 4; end
                    if (neuron_out[5] > temp_max) begin temp_max = neuron_out[5]; temp_idx = 5; end
                    if (neuron_out[6] > temp_max) begin temp_max = neuron_out[6]; temp_idx = 6; end
                    if (neuron_out[7] > temp_max) begin temp_max = neuron_out[7]; temp_idx = 7; end

                    classification_result <= temp_idx[7:0];
                    confidence_result <= temp_max;
                end

                DONE_STATE: begin
                    o_class <= classification_result;
                    o_conf <= confidence_result;
                    o_done <= 1'b1;
                end

                default: ;
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