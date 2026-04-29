// stdp_engine_v1_1.v
// Spike-Timing-Dependent Plasticity learning engine for Xcew Processor v1.1
// Verilog-2001 compliant, synthesizable

module stdp_engine_v1_1 (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  stdp_policy,
    input  wire        stdp_enable,
    input  wire        pre_spike,
    input  wire        post_spike,
    input  wire [31:0] pre_spike_time,
    input  wire [31:0] post_spike_time,
    input  wire [7:0]  current_weight,
    output reg  [7:0]  updated_weight,
    output reg         weight_updated,
    input  wire [31:0] A_plus,
    input  wire [31:0] A_minus,
    input  wire [31:0] tau_plus,
    input  wire [31:0] tau_minus,
    input  wire        learning_enable
);

    // FSM state encoding (binary)
    parameter STATE_IDLE      = 3'b000;
    parameter STATE_WAIT_PAIR = 3'b001;
    parameter STATE_COMPUTE   = 3'b010;
    parameter STATE_SATURATE  = 3'b011;
    parameter STATE_DONE      = 3'b100;

    // Constants
    parameter WEIGHT_MAX = 8'd127;
    parameter WEIGHT_MIN = 8'd129;  // -127 in 8-bit 2's complement (0x81)
    parameter ZERO       = 32'h0;

    // Internal registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [31:0] delta_t;
    reg [31:0] stdp_value;
    reg        ltp_mode;    // 1=LTP (pre before post), 0=LTD (post before pre)
    reg        spike_detected;
    reg [7:0]  weight_delta;
    reg [31:0] last_pre_time;
    reg [31:0] last_post_time;

    // Detect spike pair and compute delta_t
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state    <= STATE_IDLE;
            delta_t          <= ZERO;
            stdp_value       <= ZERO;
            ltp_mode         <= 1'b0;
            spike_detected   <= 1'b0;
            weight_delta     <= 8'h0;
            weight_updated   <= 1'b0;
            updated_weight   <= 8'h0;
            last_pre_time    <= ZERO;
            last_post_time   <= ZERO;
            next_state       <= STATE_IDLE;
        end else begin
            weight_updated   <= 1'b0;
            spike_detected   <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    weight_delta <= 8'h0;
                    if (pre_spike || post_spike) begin
                        spike_detected <= 1'b1;
                        // Determine which spike arrived first
                        if (pre_spike && post_spike) begin
                            // Both arrived simultaneously - use stored times
                            if (pre_spike_time >= last_post_time) begin
                                delta_t <= pre_spike_time - last_post_time;
                                ltp_mode <= 1'b1;
                            end else begin
                                delta_t <= last_post_time - pre_spike_time;
                                ltp_mode <= 1'b0;
                            end
                        end else if (pre_spike) begin
                            // Pre spike arrived - compute LTP if post exists
                            last_pre_time <= pre_spike_time;
                            if (last_post_time > ZERO) begin
                                delta_t <= pre_spike_time - last_post_time;
                                ltp_mode <= 1'b1;
                            end else begin
                                next_state <= STATE_WAIT_PAIR;
                            end
                        end else begin
                            // Post spike arrived - compute LTD if pre exists
                            last_post_time <= post_spike_time;
                            if (last_pre_time > ZERO) begin
                                delta_t <= post_spike_time - last_pre_time;
                                ltp_mode <= 1'b0;
                            end else begin
                                next_state <= STATE_WAIT_PAIR;
                            end
                        end
                        next_state <= STATE_COMPUTE;
                    end
                end

                STATE_WAIT_PAIR: begin
                    if (pre_spike && spike_detected) begin
                        last_pre_time <= pre_spike_time;
                        if (last_post_time > ZERO) begin
                            delta_t <= pre_spike_time - last_post_time;
                            ltp_mode <= 1'b1;
                            next_state <= STATE_COMPUTE;
                        end
                    end else if (post_spike && spike_detected) begin
                        last_post_time <= post_spike_time;
                        if (last_pre_time > ZERO) begin
                            delta_t <= post_spike_time - last_pre_time;
                            ltp_mode <= 1'b0;
                            next_state <= STATE_COMPUTE;
                        end
                    end
                end

                STATE_COMPUTE: begin
                    if (learning_enable && stdp_enable) begin
                        // STDP exponential curve: value = A >> (delta_t / tau)
                        // Approximate: value = A >> (delta_t >> 4) for tau ~ 16
                        if (ltp_mode) begin
                            // LTP: A_plus >> (delta_t / tau_plus)
                            if (tau_plus > ZERO && delta_t > ZERO) begin
                                // Shift amount = delta_t / tau_plus, approximate as delta_t >> 4
                                stdp_value <= A_plus >> (delta_t[7:4]);
                            end else begin
                                stdp_value <= A_plus;
                            end
                        end else begin
                            // LTD: A_minus >> (delta_t / tau_minus)
                            if (tau_minus > ZERO && delta_t > ZERO) begin
                                stdp_value <= A_minus >> (delta_t[7:4]);
                            end else begin
                                stdp_value <= A_minus;
                            end
                        end
                        next_state <= STATE_SATURATE;
                    end else begin
                        next_state <= STATE_IDLE;
                    end
                end

                STATE_SATURATE: begin
                    // Apply STDP policy
                    case (stdp_policy)
                        4'h0: begin
                            // Disabled
                            weight_delta <= 8'h0;
                        end
                        4'h1: begin
                            // Hebbian (LTP: increase weight)
                            if (ltp_mode) begin
                                // Increase: weight_delta = stdp_value[7:0]
                                weight_delta <= stdp_value[7:0];
                            end else begin
                                // Decrease: negative delta
                                weight_delta <= ~stdp_value[7:0] + 8'h1;
                            end
                        end
                        4'h2: begin
                            // Anti-Hebbian (invert LTP/LTD)
                            if (ltp_mode) begin
                                weight_delta <= ~stdp_value[7:0] + 8'h1;
                            end else begin
                                weight_delta <= stdp_value[7:0];
                            end
                        end
                        4'h3: begin
                            // LTP only (ignore LTD, clamp negative to zero)
                            if (ltp_mode) begin
                                weight_delta <= stdp_value[7:0];
                            end else begin
                                weight_delta <= 8'h0;
                            end
                        end
                        4'h4: begin
                            // LTD only (ignore LTP, clamp positive to zero)
                            if (ltp_mode) begin
                                weight_delta <= 8'h0;
                            end else begin
                                weight_delta <= ~stdp_value[7:0] + 8'h1;
                            end
                        end
                        4'h5: begin
                            // Homeostatic (reduce by half)
                            weight_delta <= stdp_value[7:0] >> 1;
                        end
                        default: begin
                            // Default: Hebbian
                            if (ltp_mode) begin
                                weight_delta <= stdp_value[7:0];
                            end else begin
                                weight_delta <= ~stdp_value[7:0] + 8'h1;
                            end
                        end
                    endcase
                    next_state <= STATE_DONE;
                end

                STATE_DONE: begin
                    // Apply delta with saturation
                    if (weight_delta[7]) begin
                        // Negative delta: subtract
                        if (current_weight < (0 - weight_delta)) begin
                            updated_weight <= WEIGHT_MIN;
                        end else begin
                            updated_weight <= current_weight - {1'b0, weight_delta[6:0]};
                        end
                    end else begin
                        // Positive delta: add
                        if ((WEIGHT_MAX - current_weight) < weight_delta) begin
                            updated_weight <= WEIGHT_MAX;
                        end else begin
                            updated_weight <= current_weight + weight_delta;
                        end
                    end
                    weight_updated <= 1'b1;
                    next_state <= STATE_IDLE;
                end

                default: begin
                    next_state <= STATE_IDLE;
                end
            endcase

            current_state <= next_state;
        end
    end

endmodule

// Synapse array wrapper (flat vector interface, 4 synapses)
module stdp_engine_v1_1_array #(
    parameter NUM_SYNAPSES = 256,
    parameter WEIGHT_BITS = 8
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  stdp_policy,
    input  wire        stdp_enable,
    input  wire        pre_spike,
    input  wire        post_spike,
    input  wire [31:0] pre_spike_time,
    input  wire [31:0] post_spike_time,
    input  wire [7:0]  current_weight_0,
    input  wire [7:0]  current_weight_1,
    input  wire [7:0]  current_weight_2,
    input  wire [7:0]  current_weight_3,
    output wire [7:0]  updated_weight_0,
    output wire [7:0]  updated_weight_1,
    output wire [7:0]  updated_weight_2,
    output wire [7:0]  updated_weight_3,
    output wire        weight_updated_0,
    output wire        weight_updated_1,
    output wire        weight_updated_2,
    output wire        weight_updated_3,
    input  wire [31:0] A_plus,
    input  wire [31:0] A_minus,
    input  wire [31:0] tau_plus,
    input  wire [31:0] tau_minus,
    input  wire        learning_enable
);

    wire [7:0]  weight_out [0:3];
    wire        updated_out [0:3];

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : synapse_gen
            stdp_engine_v1_1 engine_inst (
                .clk(clk),
                .rst(rst),
                .stdp_policy(stdp_policy),
                .stdp_enable(stdp_enable),
                .pre_spike(pre_spike),
                .post_spike(post_spike),
                .pre_spike_time(pre_spike_time),
                .post_spike_time(post_spike_time),
                .current_weight(gi === 0 ? current_weight_0 :
                                 gi === 1 ? current_weight_1 :
                                 gi === 2 ? current_weight_2 : current_weight_3),
                .updated_weight(weight_out[gi]),
                .weight_updated(updated_out[gi]),
                .A_plus(A_plus),
                .A_minus(A_minus),
                .tau_plus(tau_plus),
                .tau_minus(tau_minus),
                .learning_enable(learning_enable)
            );
        end
    endgenerate

    assign updated_weight_0 = weight_out[0];
    assign updated_weight_1 = weight_out[1];
    assign updated_weight_2 = weight_out[2];
    assign updated_weight_3 = weight_out[3];
    assign weight_updated_0 = updated_out[0];
    assign weight_updated_1 = updated_out[1];
    assign weight_updated_2 = updated_out[2];
    assign weight_updated_3 = updated_out[3];

endmodule
