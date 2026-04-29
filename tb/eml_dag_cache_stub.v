// tb/eml_dag_cache_stub.v
// Stub for eml_dag_cache (uses 'break' statements that iverilog can't handle)

module eml_dag_cache (
    input wire clk,
    input wire rst,
    input wire enable,
    input wire dag_mode,
    input wire [31:0] expr_hash_in,
    input wire [31:0] expr_result_in,
    input wire expr_valid_in,
    input wire expr_compute_done,
    output reg [31:0] cached_result,
    output reg cache_hit,
    output reg cache_miss,
    output reg [31:0] alloc_addr,
    input wire [31:0] subexpr_hash,
    input wire subexpr_valid,
    output reg subexpr_cached,
    output reg [31:0] subexpr_result,
    output reg [7:0] cache_tag_wr,
    output reg [7:0] cache_data_wr,
    output reg [7:0] cache_lru_wr,
    output reg [7:0] cache_tag_rd,
    output reg [7:0] cache_data_rd,
    output reg [7:0] cache_lru_rd,
    input wire [31:0] cache_data_out,
    input wire [7:0] cache_lru_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cached_result <= 32'h0;
            cache_hit <= 1'b0;
            cache_miss <= 1'b0;
            alloc_addr <= 32'h0;
            subexpr_cached <= 1'b0;
            subexpr_result <= 32'h0;
            cache_tag_wr <= 8'h0;
            cache_data_wr <= 8'h0;
            cache_lru_wr <= 8'h0;
            cache_tag_rd <= 8'h0;
            cache_data_rd <= 8'h0;
            cache_lru_rd <= 8'h0;
        end else begin
            cache_hit <= 1'b0;
            cache_miss <= 1'b0;
            subexpr_cached <= 1'b0;
            cache_tag_wr <= 8'h0;
            cache_data_wr <= 8'h0;
            cache_lru_wr <= 8'h0;
        end
    end

endmodule
