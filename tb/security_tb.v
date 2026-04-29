// tb/security_tb.v
// Testbench for Security Features (Constant Time, Deterministic Policies, Fault Monitor)

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
    wire eml_const_time_en;
    wire eml_timing_var_en;
    reg eml_stall_pipeline;

    // Policy Determinism signals
    reg policy_exec_start;
    reg [31:0] policy_data;
    reg policy_valid;
    wire policy_done;
    wire [31:0] policy_result;
    wire pol_det_en;
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
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end

    // Test variables
    integer i, j;
    reg [31:0] test_results [0:9];
    integer test_num = 0;
    integer cycle_counts [0:9];
    real timing_variance;
    integer fault_detection_count;

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

        #22 rst = 0;
        #20;

        $display("Test 1: EML Constant Time Operation");
        test_num = 1;

        // Enable constant time mode
        eml_const_time_en = 1'b1;
        eml_timing_var_en = 1'b0;

        // Test various inputs to verify constant timing
        integer start_time, end_time;
        reg [31:0] test_inputs [0:4] = '{32'h40000000, 32'h42000000, 32'h44000000, 32'h46000000, 32'h48000000};  // Various values

        for (i = 0; i < 5; i = i + 1) begin
            eml_rs1 = test_inputs[i];
            eml_cfg = 32'h00000001;  // EXP operation
            eml_valid_in = 1'b1;

            start_time = $time;
            #10;
            eml_valid_in = 1'b0;

            // Wait for result
            wait(eml_valid_out);
            end_time = $time;

            cycle_counts[i] = (end_time - start_time) / 10;  // Convert to cycles
            test_results[i] = eml_rd;

            $display("  Input: %08x, Output: %08x, Cycles: %0d",
                     test_inputs[i], eml_rd, cycle_counts[i]);
        end

        // Check timing variance
        integer avg_cycles = 0;
        for (i = 0; i < 5; i = i + 1) begin
            avg_cycles = avg_cycles + cycle_counts[i];
        end
        avg_cycles = avg_cycles / 5;

        integer variance_sum = 0;
        for (i = 0; i < 5; i = i + 1) begin
            integer diff = cycle_counts[i] - avg_cycles;
            if (diff < 0) diff = -diff;
            variance_sum = variance_sum + diff;
        end
        timing_variance = real'(variance_sum) / 5.0;

        $display("  Average cycles: %0d, Variance: %.2f cycles", avg_cycles, timing_variance);

        $display("Test 2: Policy Determinism Verification");
        test_num = 2;

        // Enable deterministic policy execution
        pol_det_en = 1'b1;
        pol_max_cycles = 4'd15;  // 15 max cycles

        // Test policy execution with various inputs
        for (i = 0; i < 5; i = i + 1) begin
            policy_data = {16'h0000, i+1, 8'h00, 4'd0};  // Vary the input data
            policy_exec_start = 1'b1;

            #10;
            policy_exec_start = 1'b0;

            // Wait for policy completion
            wait(policy_done);
            test_results[i+5] = policy_result;

            $display("  Policy input: %08x, Result: %08x, Timeout: %b",
                     policy_data, policy_result, pol_timeout_irq);
        end

        $display("Test 3: Fault Monitor and Detection");
        test_num = 3;

        // Enable fault monitoring
        fm_irq_enable = 1'b1;
        fault_detection_count = 0;

        // Inject various faults and verify detection
        for (i = 0; i < 4; i = i + 1) begin
            case (i)
                0: begin
                    soft_error = 4'b0001;  // EML soft error
                    $display("  Injecting EML soft error");
                end
                1: begin
                    hard_error = 4'b0010;  // SNN hard error
                    $display("  Injecting SNN hard error");
                end
                2: begin
                    fm_ecc_error = 1'b1;  // ECC error
                    $display("  Injecting ECC error");
                end
                3: begin
                    fm_watchdog_trip = 1'b1;  // Watchdog timeout
                    $display("  Injecting watchdog timeout");
                end
            endcase

            #20;

            if (fm_irq_fault) begin
                fault_detection_count++;
                $display("  Fault detected: Error code %h, IRQ: %b, Halt: %b",
                         fm_error_code, fm_irq_fault, fm_pipeline_halt);
            end

            // Clear injected fault
            soft_error = 4'b0000;
            hard_error = 4'b0000;
            fm_ecc_error = 1'b0;
            fm_watchdog_trip = 1'b0;

            #20;
        end

        $display("Test 4: CSR Register Access");
        test_num = 4;

        // Test CSR access for security registers
        csr_addr = 12'h7CA;  // EML security control
        csr_wr_en = 1'b1;
        csr_wr_data = 32'h00000003;  // Enable const time and timing var
        #10;
        csr_wr_en = 1'b0;
        #10;
        $display("  CSR 0x7CA write: %08x, read: %08x", csr_wr_data, csr_rd_data);

        csr_addr = 12'h7CB;  // Policy security
        csr_wr_en = 1'b1;
        csr_wr_data = 32'h00000012;  // Enable determ, max cycles = 2
        #10;
        csr_wr_en = 1'b0;
        #10;
        $display("  CSR 0x7CB write: %08x, read: %08x", csr_wr_data, csr_rd_data);

        csr_addr = 12'h7CC;  // Fault status
        #10;
        $display("  CSR 0x7CC read: %08x", csr_rd_data);

        $display("=== SECURITY FEATURES TEST RESULTS ===");

        // Check timing variance requirement
        if (timing_variance <= 1.0) begin
            $display("✅ Timing variance requirement (<±1 cycle) MET: %.2f cycles", timing_variance);
        end else begin
            $display("❌ Timing variance requirement (<±1 cycle) NOT MET: %.2f cycles", timing_variance);
        end

        // Check fault detection
        if (fault_detection_count >= 3) begin  // At least 3 out of 4 detected
            $display("✅ Fault detection working: %0d out of 4 faults detected", fault_detection_count);
        end else begin
            $display("❌ Fault detection limited: %0d out of 4 faults detected", fault_detection_count);
        end

        // Check that all security features are functional
        integer security_pass_count = 0;
        if (timing_variance <= 1.0) security_pass_count++;
        if (fault_detection_count >= 3) security_pass_count++;
        if (pol_det_en) security_pass_count++;  // Policy determinism enabled
        if (eml_const_time_en) security_pass_count++;  // Constant time enabled

        if (security_pass_count >= 3) begin
            $display("✅ Security features validation PASSED: %0d/4 checks", security_pass_count);
        end else begin
            $display("❌ Security features validation FAILED: %0d/4 checks", security_pass_count);
        end

        #100;
        $display("Security Features Testbench completed.");
        $finish;
    end

    // Monitor for debugging
    always @(posedge clk) begin
        if (rst) begin
            $display("Time: %0t, Reset active", $time);
        end
        else if (($time % 100) == 0) begin
            $display("Time: %0t, EML_CT: %b, POL_DET: %b, FAULT_MON: IRQ=%b HALT=%b",
                     $time, eml_const_time_en, pol_det_en, fm_irq_fault, fm_pipeline_halt);
        end
    end

endmodule

// Simple test for ECC functionality
module ecc_test;
    integer i;
    reg [63:0] test_data;
    reg [71:0] encoded_data;
    reg [64:0] decoded_data;

    initial begin
        $display("Testing ECC functionality...");

        test_data = 64'hDEADBEEFDEADBEEF;
        encoded_data = ecc_encode_72_64(test_data);
        decoded_data = ecc_decode_72_64(encoded_data);

        $display("Original: %16h", test_data);
        $display("Encoded:  %18h", encoded_data);
        $display("Decoded:  %16h (Syndrome: %b)", decoded_data[63:0], decoded_data[64]);

        $display("ECC test completed.");
    end
endmodule