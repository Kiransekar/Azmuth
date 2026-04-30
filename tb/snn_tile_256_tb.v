// tb/snn_tile_256_tb.v
// Testbench for parameterized snn_tile_256
// Tests: 8-neuron configuration (faster sim), sequential loading, classification
// Verilog-2001 compliant

`timescale 1ns/1ps

module snn_tile_256_tb;

    reg clk;
    reg rst;
    reg classify_en;
    reg ttfs_enable;
    reg [2:0] t_window;
    reg [2:0] refractory_cycles;
    reg [31:0] v_threshold;
    reg [31:0] v_rest;

    // Sequential input loading
    reg [31:0] input_current;
    reg [7:0]  neuron_idx;
    reg        current_valid;

    wire [7:0]  o_class;
    wire [15:0] o_conf;
    wire        o_done;
    wire        o_ready;
    wire [7:0]  o_spike_outs;      // NUM_NEURONS=8, so [7:0]
    wire [7:0]  o_spike_valids;

    // Instantiate DUT with 8 neurons for faster simulation
    snn_tile_256 #(.NUM_NEURONS(8)) dut (
        .i_clk_snn(clk),
        .i_rst(rst),
        .i_classify_en(classify_en),
        .i_ttfs_enable(ttfs_enable),
        .i_t_window(t_window),
        .i_refractory_cycles(refractory_cycles),
        .i_v_threshold(v_threshold),
        .i_v_rest(v_rest),
        .i_input_current(input_current),
        .i_neuron_idx(neuron_idx),
        .i_current_valid(current_valid),
        .o_class(o_class),
        .o_conf(o_conf),
        .o_done(o_done),
        .o_ready(o_ready),
        .o_spike_outs(o_spike_outs),
        .o_spike_valids(o_spike_valids)
    );

    // Clock: 10ns period (100MHz SNN clock)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb/snn_tile_256_tb.vcd");
        $dumpvars(0, snn_tile_256_tb);

        // Initialize
        clk = 0;
        rst = 1;
        classify_en = 0;
        ttfs_enable = 0;
        t_window = 3'b011;  // 100 cycles
        refractory_cycles = 3'b001;
        v_threshold = 32'h40000000;  // 2.0 in Q16.16
        v_rest = 32'h0;
        input_current = 0;
        neuron_idx = 0;
        current_valid = 0;

        // Reset
        #20;
        rst = 0;
        $display("=== SNN Tile 256 TB (8-neuron config) ===");
        $display("Reset released at t=%0t", $time);
        $display("o_ready = %b (expect 1)", o_ready);

        // Trigger classification first, then load currents during LOAD phase
        @(posedge clk);
        classify_en = 1;
        @(posedge clk);
        classify_en = 0;

        $display("Classification triggered at t=%0t", $time);

        // Wait for FSM to enter LOAD state (o_ready goes low)
        wait(o_ready == 0);
        $display("FSM entered LOAD state at t=%0t", $time);

        // Load input currents for 8 neurons during LOAD phase
        // Drive on negedge to avoid race condition with DUT's posedge sampling
        // Make neuron 3 have the strongest input to test winner selection
        neuron_idx = 0;
        repeat (8) begin
            @(negedge clk);
            current_valid = 1;
            // Neuron 0-2: weak input, Neuron 3: strong, Neuron 4-7: weak
            if (neuron_idx == 3)
                input_current = 32'h10000000;  // Strong input (1.0)
            else
                input_current = 32'h04000000;  // Weak input (0.25)
            @(negedge clk);
            neuron_idx = neuron_idx + 1;
        end
        @(negedge clk);
        current_valid = 0;

        $display("Loaded 8 neuron currents at t=%0t", $time);

        // Wait for done
        wait(o_done);
        $display("Classification complete at t=%0t", $time);
        $display("Winner class = %d (expect 3)", o_class);
        $display("Confidence = %d", o_conf);

        // Verify
        if (o_class == 8'd3)
            $display("PASS: Correct winner neuron selected");
        else
            $display("FAIL: Expected class 3, got %d", o_class);

        $display("=== Test complete ===");
        #100;
        $finish;
    end

endmodule
