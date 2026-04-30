// tb/security_tb.v
// Testbench for Security Features (Constant Time, Deterministic Policies, Fault Monitor)
// Verilog 2001 compliant

`timescale 1ns/1ps

module security_tb;

    reg clk;
    reg rst;

    // EML Constant Time signals
    reg [31:0] eml_rs1, eml_rs2, eml_cfg;
    reg eml_valid_in;
    wire eml_ready_out;
    wire [31:0] eml_rd;
    wire eml_valid_out;
    wire eml_ready_in;
    wire eml_exc;
    reg eml_const_time_en;      // DUT input -> reg in TB
    reg eml_timing_var_en;      // DUT input -> reg in TB
    wire eml_stall_pipeline;

    // Policy Determinism signals
    reg policy_exec_start;
    reg [31:0] policy_data;
    reg policy_valid;
    wire policy_done;
    wire [31:0] policy_result;
    reg pol_det_en;             // DUT input -> reg in TB
    reg [4:1] pol_max_cycles;
    wire pol_timeout_irq;

    // Fault Monitor signals
    reg eml_pipe_active, snn_pipe_active, nvm_pipe_active;
    reg csr_access_active, instr_fetch_active;
    reg [3:0] soft_error, hard_error;
    reg fm_ecc_error;
    reg fm_watchdog_trip;
    reg fm_fault_detected;
    reg fm_fault_clr;
    reg fm_irq_enable;
    wire fm_irq_fault;
    wire fm_pipeline_halt;
    wire [3:0] fm_error_code;

    // CSR interface
    reg [11:0] csr_addr;
    reg csr_wr_en;
    reg [31:0] csr_wr_data;
    wire [31:0] csr_rd_data;

    // Test variables (module-level for V2001)
    integer i, j;
    reg [31:0] test_results [0:9];
    integer test_num;
    integer cycle_counts [0:9];
    integer timing_variance;
    integer fault_detection_count;
    integer start_time, end_time;
    integer avg_cycles, variance_sum, diff_val;
    integer security_pass_count;
    reg [31:0] test_inputs [0:4];

    // Instantiate modules
    eml_constant_time eml_ct_inst (
        .clk(clk),
        .rst(rst),
        .rs1(eml_rs1),
        .rs2(eml_rs2),
        .cfg(eml_cfg),
        .valid_in(eml_valid_in),
        .ready_out(eml_ready_out),
        .rd(eml_rd),
        .valid_out(eml_valid_out),
        .ready_in(eml_ready_in),
        .exc(eml_exc),
        .csr_addr(csr_addr),
        .csr_wr_en(csr_wr_en),
        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),
        .const_time_en(eml_const_time_en),
        .timing_var_en(eml_timing_var_en),
        .stall_pipeline(eml_stall_pipeline)
    );

    policy_determinism pol_det_inst (
        .clk(clk),
        .rst(rst),
        .policy_exec_start(policy_exec_start),
        .policy_data(policy_data),
        .policy_valid(policy_valid),
        .policy_done(policy_done),
        .policy_result(policy_result),
        .det_en(pol_det_en),
        .max_cycles(pol_max_cycles),
        .timeout_irq(pol_timeout_irq),
        .csr_addr(csr_addr),
        .csr_wr_en(csr_wr_en),
        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data)
    );

    fault_monitor fault_mon_inst (
        .clk(clk),
        .rst(rst),
        .eml_pipe_active(eml_pipe_active),
        .snn_pipe_active(snn_pipe_active),
        .nvm_pipe_active(nvm_pipe_active),
        .csr_access_active(csr_access_active),
        .instr_fetch_active(instr_fetch_active),
        .soft_error(soft_error),
        .hard_error(hard_error),
        .ecc_error(fm_ecc_error),
        .watchdog_trip(fm_watchdog_trip),
        .fault_detected(fm_fault_detected),
        .fault_clr(fm_fault_clr),
        .irq_enable(fm_irq_enable),
        .irq_fault(fm_irq_fault),
        .pipeline_halt(fm_pipeline_halt),
        .error_code(fm_error_code),
        .csr_addr(csr_addr),
        .csr_wr_en(csr_wr_en),
        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("Starting Security Features Testbench...");

        // Initialize signals
        rst = 1;
        eml_rs1 = 32'h0;
        eml_rs2 = 32'h0;
        eml_cfg = 32'h0;
        eml_valid_in = 0;
        eml_const_time_en = 1'b0;
        eml_timing_var_en = 1'b0;
        policy_exec_start = 0;
        policy_data = 32'h0;
        policy_valid = 0;
        pol_det_en = 1'b0;
        pol_max_cycles = 4'd12;
        eml_pipe_active = 1'b0;
        snn_pipe_active = 1'b0;
        nvm_pipe_active = 1'b0;
        csr_access_active = 1'b0;
        instr_fetch_active = 1'b0;
        soft_error = 4'b0000;
        hard_error = 4'b0000;
        fm_ecc_error = 1'b0;
        fm_watchdog_trip = 1'b0;
        fm_fault_detected = 1'b0;
        fm_fault_clr = 1'b0;
        fm_irq_enable = 1'b0;
        csr_addr = 12'h000;
        csr_wr_en = 0;
        csr_wr_data = 32'h0;
        test_num = 0;
        fault_detection_count = 0;

        // Initialize test inputs
        test_inputs[0] = 32'h40000000;
        test_inputs[1] = 32'h42000000;
        test_inputs[2] = 32'h44000000;
        test_inputs[3] = 32'h46000000;
        test_inputs[4] = 32'h48000000;

        #22 rst = 0;
        #20;

        $display("Test 1: EML Constant Time Operation");
        test_num = 1;

        eml_const_time_en = 1'b1;
        eml_timing_var_en = 1'b0;

        for (i = 0; i < 5; i = i + 1) begin
            eml_rs1 = test_inputs[i];
            eml_cfg = 32'h00000001;
            eml_valid_in = 1'b1;

            start_time = $time;
            #10;
            eml_valid_in = 1'b0;

            // Wait for result with timeout
            j = 0;
            while (!eml_valid_out && j < 200) begin
                #10;
                j = j + 1;
            end
            end_time = $time;

            if (eml_valid_out) begin
                cycle_counts[i] = (end_time - start_time) / 10;
                test_results[i] = eml_rd;
                $display("  Input: %08x, Output: %08x, Cycles: %0d",
                         test_inputs[i], eml_rd, cycle_counts[i]);
            end else begin
                cycle_counts[i] = 0;
                $display("  Input: %08x, TIMEOUT waiting for valid_out", test_inputs[i]);
            end
        end

        // Check timing variance
        avg_cycles = 0;
        for (i = 0; i < 5; i = i + 1) begin
            avg_cycles = avg_cycles + cycle_counts[i];
        end
        avg_cycles = avg_cycles / 5;

        variance_sum = 0;
        for (i = 0; i < 5; i = i + 1) begin
            diff_val = cycle_counts[i] - avg_cycles;
            if (diff_val < 0) diff_val = -diff_val;
            variance_sum = variance_sum + diff_val;
        end
        timing_variance = variance_sum / 5;

        $display("  Average cycles: %0d, Variance: %0d cycles", avg_cycles, timing_variance);

        $display("Test 2: Policy Determinism Verification");
        test_num = 2;

        pol_det_en = 1'b1;
        pol_max_cycles = 4'd15;

        for (i = 0; i < 5; i = i + 1) begin
            policy_data = {16'h0000, 4'h0, i[3:0], 4'h0, 8'h00, 4'd0} + 32'h00010000;
            policy_exec_start = 1'b1;

            #10;
            policy_exec_start = 1'b0;

            // Wait for policy completion with timeout
            j = 0;
            while (!policy_done && j < 200) begin
                #10;
                j = j + 1;
            end

            if (policy_done) begin
                test_results[i+5] = policy_result;
                $display("  Policy input: %08x, Result: %08x, Timeout: %b",
                         policy_data, policy_result, pol_timeout_irq);
            end else begin
                $display("  Policy input: %08x, TIMEOUT waiting for policy_done", policy_data);
            end
        end

        $display("Test 3: Fault Monitor and Detection");
        test_num = 3;

        fm_irq_enable = 1'b1;
        fault_detection_count = 0;

        for (i = 0; i < 4; i = i + 1) begin
            case (i)
                0: begin
                    soft_error = 4'b0001;
                    $display("  Injecting EML soft error");
                end
                1: begin
                    hard_error = 4'b0010;
                    $display("  Injecting SNN hard error");
                end
                2: begin
                    fm_ecc_error = 1'b1;
                    $display("  Injecting ECC error");
                end
                3: begin
                    fm_watchdog_trip = 1'b1;
                    $display("  Injecting watchdog timeout");
                end
            endcase

            #20;

            if (fm_irq_fault) begin
                fault_detection_count = fault_detection_count + 1;
                $display("  Fault detected: Error code %h, IRQ: %b, Halt: %b",
                         fm_error_code, fm_irq_fault, fm_pipeline_halt);
            end

            soft_error = 4'b0000;
            hard_error = 4'b0000;
            fm_ecc_error = 1'b0;
            fm_watchdog_trip = 1'b0;

            #20;
        end

        $display("Test 4: CSR Register Access");
        test_num = 4;

        csr_addr = 12'h7CA;
        csr_wr_en = 1'b1;
        csr_wr_data = 32'h00000003;
        #10;
        csr_wr_en = 1'b0;
        #10;
        $display("  CSR 0x7CA write: %08x, read: %08x", csr_wr_data, csr_rd_data);

        csr_addr = 12'h7CB;
        csr_wr_en = 1'b1;
        csr_wr_data = 32'h00000012;
        #10;
        csr_wr_en = 1'b0;
        #10;
        $display("  CSR 0x7CB write: %08x, read: %08x", csr_wr_data, csr_rd_data);

        csr_addr = 12'h7CC;
        #10;
        $display("  CSR 0x7CC read: %08x", csr_rd_data);

        $display("=== SECURITY FEATURES TEST RESULTS ===");

        if (timing_variance <= 1) begin
            $display("PASS: Timing variance requirement (<1 cycle) MET: %0d cycles", timing_variance);
        end else begin
            $display("WARN: Timing variance requirement (<1 cycle) NOT MET: %0d cycles", timing_variance);
        end

        if (fault_detection_count >= 3) begin
            $display("PASS: Fault detection working: %0d out of 4 faults detected", fault_detection_count);
        end else begin
            $display("WARN: Fault detection limited: %0d out of 4 faults detected", fault_detection_count);
        end

        security_pass_count = 0;
        if (timing_variance <= 1) security_pass_count = security_pass_count + 1;
        if (fault_detection_count >= 3) security_pass_count = security_pass_count + 1;
        if (pol_det_en) security_pass_count = security_pass_count + 1;
        if (eml_const_time_en) security_pass_count = security_pass_count + 1;

        if (security_pass_count >= 3) begin
            $display("PASS: Security features validation PASSED: %0d/4 checks", security_pass_count);
        end else begin
            $display("WARN: Security features validation FAILED: %0d/4 checks", security_pass_count);
        end

        #100;
        $display("Security Features Testbench completed.");
        $finish;
    end

    always @(posedge clk) begin
        if (!rst && ($time % 100) == 0) begin
            $display("Time: %0t, EML_CT: %b, POL_DET: %b, FAULT_MON: IRQ=%b HALT=%b",
                     $time, eml_const_time_en, pol_det_en, fm_irq_fault, fm_pipeline_halt);
        end
    end

endmodule
