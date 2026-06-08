// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// security_fv.sv — formal property wrapper for fault_monitor (tapeout audit §1.3c).
// Immediate-assertion style; temporal properties use $past. SVA lives HERE,
// not in the Verilog-2001 RTL; not in rtl/rtl_list.f.
//
// Properties (5). The two guards (fault_clr/csr_clear, any_fault) reflect real
// RTL behaviour, not weakening: the fault-detect block runs LATER in the same
// always block than the CSR clear, so a fault coincident with a clear re-sets
// fault_latch. The guards exclude exactly that coincident-fault case.
//   P1  once latched, fault_latch holds while neither clear path is active.
//   P2  pipeline_halt is only ever asserted while a fault is latched.
//   P3  irq_fault is only ever asserted while a fault is latched.
//   P4  one cycle after reset the error_code output is zero.
//   P5  a CSR write of 0x7CC[31] clears fault_latch (absent a coincident fault).
module security_fv (
    input  wire        clk,
    input  wire        rst,
    input  wire        eml_pipe_active,
    input  wire        snn_pipe_active,
    input  wire        nvm_pipe_active,
    input  wire        csr_access_active,
    input  wire        instr_fetch_active,
    input  wire [3:0]  soft_error,
    input  wire [3:0]  hard_error,
    input  wire        ecc_error,
    input  wire        watchdog_trip,
    input  wire        fault_detected,
    input  wire        fault_clr,
    input  wire        irq_enable,
    input  wire [11:0] csr_addr,
    input  wire        csr_wr_en,
    input  wire [31:0] csr_wr_data
);
    wire        irq_fault;
    wire        pipeline_halt;
    wire [3:0]  error_code;
    wire [31:0] csr_rd_data;
    wire        o_dbg_fault_latch;
    wire [2:0]  o_dbg_state;
    wire [3:0]  o_dbg_latched_error_code;

    fault_monitor dut (
        .clk(clk), .rst(rst),
        .eml_pipe_active(eml_pipe_active), .snn_pipe_active(snn_pipe_active),
        .nvm_pipe_active(nvm_pipe_active), .csr_access_active(csr_access_active),
        .instr_fetch_active(instr_fetch_active),
        .soft_error(soft_error), .hard_error(hard_error), .ecc_error(ecc_error),
        .watchdog_trip(watchdog_trip), .fault_detected(fault_detected),
        .fault_clr(fault_clr), .irq_enable(irq_enable),
        .irq_fault(irq_fault), .pipeline_halt(pipeline_halt), .error_code(error_code),
        .csr_addr(csr_addr), .csr_wr_en(csr_wr_en), .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),
        .o_dbg_fault_latch(o_dbg_fault_latch),
        .o_dbg_state(o_dbg_state),
        .o_dbg_latched_error_code(o_dbg_latched_error_code)
    );

    // Power-on reset: pin the initial state to fault_monitor's documented reset
    // state. smtbmc leaves async-reset FF init values free, so asserting rst at
    // t=0 is not by itself enough to start BMC from the real reset state.
    initial begin
        assume (rst);
        assume (!o_dbg_fault_latch);
        assume (o_dbg_state == 3'b000);
        assume (o_dbg_latched_error_code == 4'h0);
        assume (!irq_fault);
        assume (!pipeline_halt);
    end

    wire any_fault = (|soft_error) || (|hard_error) || ecc_error ||
                     watchdog_trip || fault_detected;
    wire csr_clear = csr_wr_en && (csr_addr == 12'h7CC) && csr_wr_data[31];

    always @(posedge clk) begin
        if (!rst) begin
            p_halt_implies_latch: assert (!pipeline_halt || o_dbg_fault_latch);
            p_irq_implies_latch:  assert (!irq_fault     || o_dbg_fault_latch);
            if (!$past(rst)) begin
                p_latch_persists: assert (
                    !($past(o_dbg_fault_latch) && !$past(fault_clr) && !$past(csr_clear)) ||
                    o_dbg_fault_latch);
                p_csr_clears_latch: assert (
                    !($past(csr_clear) && !$past(any_fault)) || !o_dbg_fault_latch);
            end
        end
        // Holds across the reset boundary; $past is 0 at t=0 so this is vacuous there.
        p_reset_clears_errcode: assert (!$past(rst) || (error_code == 4'h0));
    end
endmodule
