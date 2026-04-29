// rtl/power/body_bias_ctrl.v
// Digital Body Bias Controller for Xcew Processor
// Controls P/N-well bias to minimize leakage

`timescale 1ns/1ps

module body_bias_ctrl (
    input wire clk,
    input wire rst,

    // Digital bias control
    input wire [7:0] bias_code,       // 8-bit bias code input
    input wire cal_en,               // Calibration enable
    output wire leakage_ready,       // Leakage measurement ready

    // Physical interface (would connect to padframe)
    output reg [7:0] pb_bias_out,    // P-well bias control
    output reg [7:0] nb_bias_out,    // N-well bias control

    // Measurement interface
    input wire leakage_counter,      // Leakage measurement input
    input wire measure_en,           // Enable leakage measurement

    // CSR interface
    input wire [11:0] csr_addr,
    input wire csr_wr_en,
    input wire [31:0] csr_wr_data,
    output reg [31:0] csr_rd_data
);

    // Internal registers
    reg [7:0] bias_code_reg;
    reg [7:0] dac_output;
    reg [31:0] leakage_count_reg;
    reg cal_en_reg;
    reg cal_active;
    reg [7:0] target_bias_code;
    reg leakage_ready_reg;
    reg [7:0] min_leakage_code;
    reg [31:0] min_leakage_value;
    reg [31:0] current_leakage;
    reg [31:0] measurement_timer;

    // Calibration state machine (binary encoding, no typedef enum)
    parameter CAL_IDLE                = 3'b000;
    parameter CAL_MEASURE             = 3'b001;
    parameter CAL_ADJUST              = 3'b010;
    parameter CAL_VERIFY              = 3'b011;
    parameter CAL_CALIBRATE_COMPLETE  = 3'b100;

    reg [2:0] cal_state, next_cal_state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bias_code_reg <= 8'h80;  // Mid-scale default
            dac_output <= 8'h80;
            leakage_count_reg <= 32'h0;
            cal_en_reg <= 1'b0;
            cal_active <= 1'b0;
            target_bias_code <= 8'h80;
            leakage_ready_reg <= 1'b0;
            min_leakage_code <= 8'h80;
            min_leakage_value <= 32'hFFFF_FFFF;
            current_leakage <= 32'h0;
            measurement_timer <= 32'h0;
            pb_bias_out <= 8'h80;
            nb_bias_out <= 8'h80;
        end
        else begin
            // CSR write handling
            if (csr_wr_en) begin
                case (csr_addr)
                    12'h7C9: begin
                        bias_code_reg <= csr_wr_data[7:0];
                        cal_en_reg <= csr_wr_data[8];
                    end
                endcase
            end

            // Apply bias code to physical outputs
            dac_output <= bias_code_reg;
            pb_bias_out <= dac_output;  // P-well bias
            nb_bias_out <= ~dac_output; // N-well bias (complementary)

            // Calibration state machine
            cal_state <= next_cal_state;

            case (cal_state)
                CAL_IDLE: begin
                    leakage_ready_reg <= 1'b0;
                    measurement_timer <= 32'h0;

                    if (cal_en_reg) begin
                        next_cal_state <= CAL_MEASURE;
                        min_leakage_value <= 32'hFFFF_FFFF;
                        min_leakage_code <= bias_code_reg;
                    end
                    else begin
                        next_cal_state <= CAL_IDLE;
                    end
                end

                CAL_MEASURE: begin
                    if (measure_en) begin
                        current_leakage <= leakage_counter;
                        measurement_timer <= measurement_timer + 1;

                        // Update minimum if we found a better bias point
                        if (current_leakage < min_leakage_value) begin
                            min_leakage_value <= current_leakage;
                            min_leakage_code <= bias_code_reg;
                        end

                        // Sweep through bias codes during calibration
                        if (measurement_timer > 32'd1000) begin
                            measurement_timer <= 32'h0;

                            // Increment bias code for sweep
                            if (bias_code_reg < 8'hFF) begin
                                bias_code_reg <= bias_code_reg + 1;
                            end
                            else begin
                                // Calibration sweep complete
                                target_bias_code <= min_leakage_code;
                                next_cal_state <= CAL_CALIBRATE_COMPLETE;
                            end
                        end
                        else begin
                            next_cal_state <= CAL_MEASURE;
                        end
                    end
                    else begin
                        next_cal_state <= CAL_MEASURE;  // Wait for measurement to be enabled
                    end
                end

                CAL_ADJUST: begin
                    // Adjust bias code toward optimal value
                    if (bias_code_reg != target_bias_code) begin
                        if (bias_code_reg < target_bias_code) begin
                            bias_code_reg <= bias_code_reg + 1;
                        end
                        else begin
                            bias_code_reg <= bias_code_reg - 1;
                        end
                    end
                    else begin
                        next_cal_state <= CAL_VERIFY;
                    end
                    next_cal_state <= CAL_VERIFY;  // Move to verification
                end

                CAL_VERIFY: begin
                    // Verify that the calibrated bias achieves target leakage
                    if (current_leakage < 32'd1000) begin  // Assuming scaled measurement
                        leakage_ready_reg <= 1'b1;
                        next_cal_state <= CAL_CALIBRATE_COMPLETE;
                    end
                    else begin
                        // If leakage still too high, continue adjusting
                        next_cal_state <= CAL_ADJUST;
                    end
                end

                CAL_CALIBRATE_COMPLETE: begin
                    // Calibration finished, keep optimal bias
                    if (!cal_en_reg) begin
                        next_cal_state <= CAL_IDLE;
                    end
                    else begin
                        next_cal_state <= CAL_CALIBRATE_COMPLETE;
                    end
                end

                default: next_cal_state <= CAL_IDLE;
            endcase
        end
    end

    // CSR read logic
    always @(*) begin
        case (csr_addr)
            12'h7C9: csr_rd_data = {23'h0, leakage_ready_reg, cal_en_reg, bias_code_reg};
            default: csr_rd_data = 32'h0;
        endcase
    end

    assign leakage_ready = leakage_ready_reg;

endmodule

// Bias DAC module (simulated)
module bias_dac (
    input wire [7:0] digital_code,
    output wire analog_bias
);

    // This would be an actual DAC in hardware
    // For simulation, just assign the digital code
    assign analog_bias = &digital_code;  // Dummy assignment

endmodule

// Leakage sensor interface
module leakage_sensor (
    input wire clk,
    input wire rst,
    input wire sensor_en,
    output reg [31:0] leakage_count
);

    // Simulated leakage counter
    reg [31:0] temp_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            leakage_count <= 32'h0;
            temp_count <= 32'h0;
        end
        else begin
            if (sensor_en) begin
                temp_count <= temp_count + 1;
                // Simulate leakage based on process/voltage/temperature
                leakage_count <= temp_count + 32'h100;  // Base leakage
            end
            else begin
                temp_count <= 32'h0;
                leakage_count <= 32'h0;
            end
        end
    end

endmodule