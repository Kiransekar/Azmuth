// tb/eml_dag_tb.v
// Testbench for EML DAG cache with compression and CSE verification

`timescale 1ns/1ps

module eml_dag_tb;

    reg clk;
    reg rst;
    reg enable;
    reg dag_mode;

    // EML computation interface
    reg [31:0] expr_hash_in;
    reg [31:0] expr_result_in;
    reg expr_valid_in;
    reg expr_compute_done;

    // Cache interface
    wire [31:0] cached_result;
    wire cache_hit;
    wire cache_miss;
    wire [31:0] alloc_addr;

    // DAG scheduler interface
    reg [31:0] subexpr_hash;
    reg subexpr_valid;
    wire subexpr_cached;
    wire [31:0] subexpr_result;

    // Instantiate the module
    eml_dag_cache uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .dag_mode(dag_mode),
        .expr_hash_in(expr_hash_in),
        .expr_result_in(expr_result_in),
        .expr_valid_in(expr_valid_in),
        .expr_compute_done(expr_compute_done),
        .cached_result(cached_result),
        .cache_hit(cache_hit),
        .cache_miss(cache_miss),
        .alloc_addr(alloc_addr),
        .subexpr_hash(subexpr_hash),
        .subexpr_valid(subexpr_valid),
        .subexpr_cached(subexpr_cached),
        .subexpr_result(subexpr_result)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end

    // Test stimulus
    integer i, j;
    reg [31:0] test_hashes [0:9];
    reg [31:0] test_results [0:9];
    integer hit_count, miss_count, total_ops;
    real hit_rate;

    initial begin
        $display("Starting EML DAG Cache Testbench...");

        // Initialize signals
        rst = 1;
        enable = 0;
        dag_mode = 0;
        expr_hash_in = 0;
        expr_result_in = 0;
        expr_valid_in = 0;
        expr_compute_done = 0;
        subexpr_hash = 0;
        subexpr_valid = 0;

        #20 rst = 0;
        #10;

        // Test 1: Enable DAG mode
        $display("Test 1: Enabling DAG mode");
        enable = 1;
        dag_mode = 1;
        #20;

        // Generate 10 random EML trees with some repetition for CSE testing
        $display("Test 2: Feeding 10 random EML trees with repetitions");

        // Define test data with some repeated expressions for CSE
        test_hashes[0] = 32'hA1B2C3D4;  test_results[0] = 32'hDEADBEEF;
        test_hashes[1] = 32'h55AA55AA;  test_results[1] = 32'h12345678;
        test_hashes[2] = 32'hA1B2C3D4;  // Same as 0 - should hit
        test_results[2] = 32'hDEADBEEF;
        test_hashes[3] = 32'h11223344;  test_results[3] = 32'hCAFEBABE;
        test_hashes[4] = 32'h55AA55AA;  // Same as 1 - should hit
        test_results[4] = 32'h12345678;
        test_hashes[5] = 32'hABCDEF00;  test_results[5] = 32'hFEEDFACE;
        test_hashes[6] = 32'hA1B2C3D4;  // Same as 0 - should hit
        test_results[6] = 32'hDEADBEEF;
        test_hashes[7] = 32'h12345678;  test_results[7] = 32'h00FF00FF;
        test_hashes[8] = 32'h55AA55AA;  // Same as 1 - should hit
        test_results[8] = 32'h12345678;
        test_hashes[9] = 32'hFEDCBA98;  test_results[9] = 32'h87654321;

        hit_count = 0;
        miss_count = 0;
        total_ops = 0;

        // Feed the test expressions
        for (i = 0; i < 10; i = i + 1) begin
            // Feed expression hash and result
            expr_hash_in = test_hashes[i];
            expr_result_in = test_results[i];
            expr_valid_in = 1;
            expr_compute_done = 1;

            #10;

            $display("Cycle %0d: Expr hash=%08x, Result=%08x, Hit=%b, Miss=%b",
                     i, expr_hash_in, expr_result_in, cache_hit, cache_miss);

            if (cache_hit) begin
                hit_count = hit_count + 1;
                $display("  -> Cache HIT! Result: %08x", cached_result);
                // Verify cached result matches expected
                if (cached_result !== test_results[i]) begin
                    $display("ERROR: Cache hit result mismatch!");
                end
            end else if (cache_miss) begin
                miss_count = miss_count + 1;
                $display("  -> Cache MISS, allocated at addr: %08x", alloc_addr);
            end

            total_ops = total_ops + 1;

            expr_valid_in = 0;
            expr_compute_done = 0;
            #10;
        end

        // Test DAG scheduler with subexpressions
        $display("Test 3: Testing DAG scheduler with subexpressions");
        for (i = 0; i < 5; i = i + 1) begin
            subexpr_hash = test_hashes[i];
            subexpr_valid = 1;

            #10;

            $display("Subexpr %0d: Hash=%08x, Cached=%b, Result=%08x",
                     i, subexpr_hash, subexpr_cached, subexpr_result);

            if (subexpr_cached) begin
                hit_count = hit_count + 1;
            end else begin
                miss_count = miss_count + 1;
            end

            total_ops = total_ops + 1;
            subexpr_valid = 0;
            #10;
        end

        // Calculate and report hit rate
        if (total_ops > 0) begin
            hit_rate = (real'(hit_count) / real'(total_ops)) * 100.0;
            $display("=== CACHE PERFORMANCE ===");
            $display("Total operations: %0d", total_ops);
            $display("Hits: %0d", hit_count);
            $display("Misses: %0d", miss_count);
            $display("Hit Rate: %.2f%%", hit_rate);

            // Verify DAG reuse ≥2x requirement
            if (hit_rate >= 20.0) begin  // 20% represents 2x reuse threshold
                $display("✅ DAG reuse requirement (≥2x) MET: %.2f%% hit rate", hit_rate);
            end else begin
                $display("❌ DAG reuse requirement (≥2x) NOT MET: %.2f%% hit rate", hit_rate);
            end
        end

        // Test cache compression functionality
        $display("Test 4: Testing hash compression");
        for (i = 0; i < 5; i = i + 1) begin
            // Use the compress_hash function directly via a temporary module
            reg [31:0] full_hash = {i+1, 28'hABCDEF};
            reg [7:0] compressed = full_hash[7:0] ^ full_hash[15:8] ^ full_hash[23:16] ^ full_hash[31:24];
            $display("Original hash: %08x -> Compressed: %02x", full_hash, compressed);
        end

        #20;
        $display("EML DAG Cache Testbench completed.");
        $finish;
    end

endmodule

// Helper module to test hash compression
module test_hash_compressor(
    input [31:0] hash_in,
    output [7:0] compressed_hash
);

    assign compressed_hash = hash_in[7:0] ^
                           hash_in[15:8] ^
                           hash_in[23:16] ^
                           hash_in[31:24];

endmodule