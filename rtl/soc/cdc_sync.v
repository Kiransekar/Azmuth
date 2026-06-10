// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// cdc_sync.v
// Clock Domain Crossing synchronizers for core ↔ SNN domain
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

// 2-FF synchronizer for single-bit signals (control/status)
module cdc_sync_2ff #(
    parameter RESET_VAL = 1'b0
) (
    input  wire clk_dst,
    input  wire rst_dst,
    input  wire sig_src,
    output wire sig_dst
);
    reg sync_ff1, sync_ff2;

    always @(posedge clk_dst or posedge rst_dst) begin
        if (rst_dst) begin
            sync_ff1 <= RESET_VAL;
            sync_ff2 <= RESET_VAL;
        end else begin
            sync_ff1 <= sig_src;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sig_dst = sync_ff2;
endmodule


// Pulse synchronizer: converts a pulse in source domain to a level in destination domain
// then back to a pulse (handshake-based)
module cdc_pulse_sync #(
    parameter RESET_VAL = 1'b0
) (
    input  wire clk_src,
    input  wire rst_src,
    input  wire clk_dst,
    input  wire rst_dst,
    input  wire pulse_src,
    output wire pulse_dst
);
    // Source domain: generate request level
    reg req_level_src;
    always @(posedge clk_src or posedge rst_src) begin
        if (rst_src)
            req_level_src <= RESET_VAL;
        else if (pulse_src)
            req_level_src <= 1'b1;
        else if (ack_dst_sync)
            req_level_src <= 1'b0;
    end

    // Synchronize req_level to destination domain (2-FF)
    wire req_level_dst;
    cdc_sync_2ff #(.RESET_VAL(RESET_VAL)) u_req_sync (
        .clk_dst(clk_dst),
        .rst_dst(rst_dst),
        .sig_src(req_level_src),
        .sig_dst(req_level_dst)
    );

    // Destination domain: detect rising edge of req_level -> pulse_dst
    reg req_level_dst_d;
    reg pulse_dst_reg;
    always @(posedge clk_dst or posedge rst_dst) begin
        if (rst_dst) begin
            req_level_dst_d <= RESET_VAL;
            pulse_dst_reg <= RESET_VAL;
        end else begin
            req_level_dst_d <= req_level_dst;
            pulse_dst_reg <= req_level_dst & ~req_level_dst_d;
        end
    end

    assign pulse_dst = pulse_dst_reg;

    // Synchronize ack back to source domain
    wire ack_dst_sync;
    cdc_sync_2ff #(.RESET_VAL(RESET_VAL)) u_ack_sync (
        .clk_dst(clk_src),
        .rst_dst(rst_src),
        .sig_src(pulse_dst_reg),
        .sig_dst(ack_dst_sync)
    );
endmodule


// Async-assert, sync-deassert reset synchronizer
module cdc_reset_sync (
    input  wire clk_dst,
    input  wire rst_src,
    output wire rst_dst
);
    reg [1:0] sync_ff;

    always @(posedge clk_dst or posedge rst_src) begin
        if (rst_src)
            sync_ff <= 2'b11;
        else
            sync_ff <= {sync_ff[0], 1'b0};
    end

    assign rst_dst = sync_ff[1];
endmodule


// Handshake-based multi-bit data transfer (req/ack)
// Source holds data stable, asserts req; destination latches on req, asserts ack
module cdc_data_sync #(
    parameter WIDTH = 32
) (
    input  wire              clk_src,
    input  wire              rst_src,
    input  wire              clk_dst,
    input  wire              rst_dst,
    input  wire [WIDTH-1:0]  data_src,
    input  wire              req_src,
    output wire              ack_src,
    output wire [WIDTH-1:0]  data_dst,
    output wire              valid_dst,
    input  wire              ready_dst
);
    // Source domain
    reg [WIDTH-1:0] data_reg_src;
    reg             req_reg_src;

    always @(posedge clk_src or posedge rst_src) begin
        if (rst_src) begin
            data_reg_src <= {WIDTH{1'b0}};
            req_reg_src  <= 1'b0;
        end else begin
            if (req_src) begin
                data_reg_src <= data_src;
                req_reg_src  <= 1'b1;
            end else if (ack_src) begin
                req_reg_src <= 1'b0;
            end
        end
    end

    // Synchronize req to destination domain
    wire req_dst;
    cdc_sync_2ff u_req_sync (
        .clk_dst(clk_dst),
        .rst_dst(rst_dst),
        .sig_src(req_reg_src),
        .sig_dst(req_dst)
    );

    // Destination domain
    reg [WIDTH-1:0] data_reg_dst;
    reg             valid_reg_dst;
    reg             req_dst_d;

    always @(posedge clk_dst or posedge rst_dst) begin
        if (rst_dst) begin
            data_reg_dst  <= {WIDTH{1'b0}};
            valid_reg_dst <= 1'b0;
            req_dst_d     <= 1'b0;
        end else begin
            req_dst_d <= req_dst;
            if (req_dst & ~req_dst_d) begin
                // Rising edge of req -> latch data
                data_reg_dst  <= data_reg_src;
                valid_reg_dst <= 1'b1;
            end else if (valid_reg_dst & ready_dst) begin
                valid_reg_dst <= 1'b0;
            end
        end
    end

    // Synchronize valid back as ack to source domain
    wire ack_dst;
    cdc_sync_2ff u_ack_sync (
        .clk_dst(clk_src),
        .rst_dst(rst_src),
        .sig_src(valid_reg_dst),
        .sig_dst(ack_dst)
    );

    reg ack_dst_d;
    always @(posedge clk_src or posedge rst_src) begin
        if (rst_src)
            ack_dst_d <= 1'b0;
        else
            ack_dst_d <= ack_dst;
    end

    assign ack_src = ack_dst & ~ack_dst_d;
    assign data_dst = data_reg_dst;
    assign valid_dst = valid_reg_dst;
endmodule
