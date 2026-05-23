// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// tb/fault_monitor_stub.v
// Stub for fault_monitor (has ecc function call issues with iverilog)

module fault_monitor (
    input wire clk,
    input wire rst,
    input wire eml_pipe_active,
    input wire snn_pipe_active,
    input wire nvm_pipe_active,
    input wire csr_access_active,
    input wire instr_fetch_active,
    input wire [3:0] soft_error,
    input wire [3:0] hard_error,
    input wire ecc_error,
    output wire watchdog_trip,
    output wire fault_detected,
    input wire fault_clr,
    input wire irq_enable,
    output wire irq_fault,
    output wire pipeline_halt,
    output wire [3:0] error_code,
    input wire [11:0] csr_addr,
    input wire csr_wr_en,
    input wire [31:0] csr_wr_data,
    output wire [31:0] csr_rd_data
);

    assign watchdog_trip = 1'b0;
    assign fault_detected = 1'b0;
    assign irq_fault = 1'b0;
    assign pipeline_halt = 1'b0;
    assign error_code = 4'h0;
    assign csr_rd_data = 32'h0;

endmodule
