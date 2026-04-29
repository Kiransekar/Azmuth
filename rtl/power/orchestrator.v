// rtl/power/orchestrator.v
// Power Orchestration Controller for Xcew Processor
// Implements per-tile sleep/wake FSM with retention registers

`timescale 1ns/1ps

module orchestrator (
    input wire clk,
    input wire rst,

    // Control signals
    input wire [3:0] tile_state_req,    // Requested state for each tile
    input wire [3:0] idle_timeout,     // Configurable timeout value
    input wire wake_irq_mask,          // Mask for wake on IRQ
    input wire [3:0] activity_count,   // Activity counters for each tile

    // Tile control signals
    output reg [3:0] tile_sleep,       // Sleep signal for each tile (EML, SNN, NVM, Core)
    output reg [3:0] tile_iso_en,      // Isolation enable for each tile
    output reg [3:0] tile_ret_en,      // Retention enable for each tile

    // Wake triggers
    input wire [3:0] tile_wake_req,    // Wake request from each tile
    input wire irq_trigger,            // IRQ wake trigger
    input wire axi_activity,           // AXI activity wake trigger

    // CSR interface
    input wire [11:0] csr_addr,
    input wire csr_wr_en,
    input wire [31:0] csr_wr_data,
    output reg [31:0] csr_rd_data
);

    // Tile enumeration
    parameter TILE_CORE = 0;
    parameter TILE_EML = 1;
    parameter TILE_SNN = 2;
    parameter TILE_NVM = 3;

    // Power states
    parameter STATE_RUN = 4'b0001;
    parameter STATE_SLEEP = 4'b0010;
    parameter STATE_RETENTION = 4'b0100;
    parameter STATE_ISO = 4'b1000;

    // Internal signals
    reg [3:0] current_tile_state [0:3];
    reg [31:0] idle_counter [0:3];
    reg [3:0] prev_activity_count;
    reg [31:0] pwr_ctrl_reg;
    reg [31:0] bias_ctrl_reg;

    // Tile FSM
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1) begin
                current_tile_state[i] <= STATE_RUN;
                idle_counter[i] <= 32'h0;
                tile_sleep[i] <= 1'b0;
                tile_iso_en[i] <= 1'b0;
                tile_ret_en[i] <= 1'b0;
            end
            pwr_ctrl_reg <= 32'h0;
            bias_ctrl_reg <= 32'h0;
        end
        else begin
            // Handle CSR writes
            if (csr_wr_en) begin
                case (csr_addr)
                    12'h7C8: pwr_ctrl_reg <= csr_wr_data;
                    12'h7C9: bias_ctrl_reg <= csr_wr_data;
                endcase
            end

            // Update tile states based on FSM logic
            for (i = 0; i < 4; i = i + 1) begin
                case (current_tile_state[i])
                    STATE_RUN: begin
                        // Check for idle condition
                        if (activity_count[i] == 0) begin
                            idle_counter[i] <= idle_counter[i] + 1;

                            // Check if timeout reached for sleep transition
                            if (idle_counter[i] >= {28'd0, pwr_ctrl_reg[7:4]}) begin
                                current_tile_state[i] <= STATE_SLEEP;
                                tile_sleep[i] <= 1'b1;
                                tile_iso_en[i] <= 1'b1;
                                tile_ret_en[i] <= 1'b1;
                            end
                        end
                        else begin
                            idle_counter[i] <= 32'h0;
                        end
                    end

                    STATE_SLEEP: begin
                        // Wake up conditions
                        if (tile_wake_req[i] ||
                            (wake_irq_mask && irq_trigger) ||
                            (i != TILE_CORE && axi_activity && idle_counter[i] < 32'd5)) begin

                            current_tile_state[i] <= STATE_RUN;
                            tile_sleep[i] <= 1'b0;
                            tile_iso_en[i] <= 1'b0;
                            tile_ret_en[i] <= 1'b0;
                            idle_counter[i] <= 32'h0;
                        end
                        else begin
                            // Stay in sleep state
                            idle_counter[i] <= idle_counter[i] + 1;
                        end
                    end

                    default: begin
                        current_tile_state[i] <= STATE_RUN;
                        tile_sleep[i] <= 1'b0;
                        tile_iso_en[i] <= 1'b0;
                        tile_ret_en[i] <= 1'b0;
                    end
                endcase
            end
        end
    end

    // CSR read logic
    always @(*) begin
        case (csr_addr)
            12'h7C8: csr_rd_data = {28'h0, current_tile_state[TILE_NVM], current_tile_state[TILE_SNN],
                                   current_tile_state[TILE_EML], current_tile_state[TILE_CORE],
                                   pwr_ctrl_reg[15:8], pwr_ctrl_reg[7:4], pwr_ctrl_reg[8]};
            12'h7C9: csr_rd_data = bias_ctrl_reg;
            default: csr_rd_data = 32'h0;
        endcase
    end

endmodule

// Retention register wrapper
module retention_reg (
    input wire clk,
    input wire rst,
    input wire ret_en,              // Retention enable
    input wire iso_en,              // Isolation enable
    input wire [31:0] din,
    output wire [31:0] dout,
    input wire scan_mode            // Scan mode for testing
);

    reg [31:0] retained_data;
    reg [31:0] normal_data;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            normal_data <= 32'h0;
            retained_data <= 32'h0;
        end
        else begin
            normal_data <= din;
            if (ret_en) begin
                retained_data <= din;  // Retain value when retention enabled
            end
        end
    end

    reg [31:0] dout_internal;

    // Output selection based on isolation
    assign dout = iso_en ? retained_data : normal_data;

endmodule

// Power state manager
module power_state_manager (
    input wire clk,
    input wire rst,

    // Tile power controls
    input wire [3:0] req_power_state,  // Requested power state for each tile
    output reg [3:0] granted_power_state,  // Granted power state

    // Power switch controls
    output reg [3:0] power_switch_ctrl,  // Control for power switches

    // Status
    output reg [3:0] power_good,         // Power good status for each tile
    output reg [3:0] power_stable         // Power stable status
);

    reg [3:0] pending_request [0:3];
    reg [31:0] power_timer [0:3];

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1) begin
                granted_power_state[i] <= 1'b1;  // Default to ON
                power_switch_ctrl[i] <= 1'b0;    // Default: power ON
                power_good[i] <= 1'b1;          // Default: power good
                power_stable[i] <= 1'b1;        // Default: power stable
                pending_request[i] <= 4'h0;
                power_timer[i] <= 32'h0;
            end
        end
        else begin
            for (i = 0; i < 4; i = i + 1) begin
                if (req_power_state[i] != granted_power_state[i]) begin
                    pending_request[i] <= req_power_state[i];

                    // Handle power state transitions
                    case ({granted_power_state[i], req_power_state[i]})
                        2'b01: begin  // Powering ON
                            power_switch_ctrl[i] <= 1'b1;
                            power_timer[i] <= power_timer[i] + 1;
                            if (power_timer[i] > 32'd100) begin  // Wait for power to stabilize
                                power_good[i] <= 1'b1;
                                power_stable[i] <= 1'b1;
                                granted_power_state[i] <= req_power_state[i];
                                power_timer[i] <= 32'h0;
                            end
                        end

                        2'b10: begin  // Powering OFF
                            power_good[i] <= 1'b0;
                            power_stable[i] <= 1'b0;
                            power_switch_ctrl[i] <= 1'b0;
                            granted_power_state[i] <= req_power_state[i];
                            power_timer[i] <= 32'h0;
                        end

                        default: begin
                            power_timer[i] <= 32'h0;
                        end
                    endcase
                end
            end
        end
    end

endmodule