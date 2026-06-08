// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// power_fv.sv — formal property wrapper for orchestrator (tapeout audit §1.3c).
// Immediate-assertion style; temporal properties use $past. SVA lives HERE,
// not in the Verilog-2001 RTL; not in rtl/rtl_list.f.
//
// All properties use observable output ports only: current_tile_state and
// idle_counter are reg ARRAYS (memories) whose hierarchical access is unreliable
// in open-source Yosys, and the sleep/iso/ret/wake behaviour is fully observable
// at the tile control outputs. Checked for tile 0 (Core); the FSM is identical
// per tile (shared loop body).
//   P1  a sleeping tile also has isolation AND retention asserted.
//   P2  isolation is asserted only while the tile sleeps.
//   P3  retention is asserted only while the tile sleeps.
//   P4  a wake request to a sleeping tile clears sleep the next cycle.
//   P5  a running tile with activity stays awake (no spurious sleep).
module power_fv (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  tile_state_req,
    input  wire [3:0]  idle_timeout,
    input  wire        wake_irq_mask,
    input  wire [3:0]  activity_count,
    input  wire [3:0]  tile_wake_req,
    input  wire        irq_trigger,
    input  wire        axi_activity,
    input  wire [11:0] csr_addr,
    input  wire        csr_wr_en,
    input  wire [31:0] csr_wr_data
);
    wire [3:0]  tile_sleep;
    wire [3:0]  tile_iso_en;
    wire [3:0]  tile_ret_en;
    wire [31:0] csr_rd_data;

    orchestrator dut (
        .clk(clk), .rst(rst),
        .tile_state_req(tile_state_req), .idle_timeout(idle_timeout),
        .wake_irq_mask(wake_irq_mask), .activity_count(activity_count),
        .tile_sleep(tile_sleep), .tile_iso_en(tile_iso_en), .tile_ret_en(tile_ret_en),
        .tile_wake_req(tile_wake_req), .irq_trigger(irq_trigger),
        .axi_activity(axi_activity),
        .csr_addr(csr_addr), .csr_wr_en(csr_wr_en), .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data)
    );

    initial assume (rst);

    always @(posedge clk) begin
        if (!rst) begin
            p_sleep_implies_iso_ret: assert (!tile_sleep[0] ||
                (tile_iso_en[0] && tile_ret_en[0]));
            p_iso_implies_sleep: assert (!tile_iso_en[0] || tile_sleep[0]);
            p_ret_implies_sleep: assert (!tile_ret_en[0] || tile_sleep[0]);
            if (!$past(rst)) begin
                p_wake_exits_sleep: assert (
                    !($past(tile_wake_req[0]) && $past(tile_sleep[0])) || !tile_sleep[0]);
                p_activity_keeps_awake: assert (
                    !(!$past(tile_sleep[0]) && ($past(activity_count[0]) != 1'b0)) ||
                    !tile_sleep[0]);
            end
        end
    end
endmodule
