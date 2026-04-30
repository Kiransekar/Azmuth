// EML DAG Scheduler module for tracking and reusing nodes
module eml_dag_scheduler (
    input wire clk,
    input wire rst,
    input wire dag_mode,

    // Input expression stream
    input wire [31:0] expr_hash,
    input wire expr_valid,
    output reg reuse_available,
    output reg [31:0] reuse_addr,

    // Node completion feedback
    input wire node_completed,
    input wire [31:0] completed_hash
);

    // Pending node tracking
    reg [31:0] pending_nodes [0:63];
    reg [5:0] pending_indices [0:63];
    reg [5:0] pending_count;
    reg [5:0] oldest_idx;

    integer i, j;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pending_count <= 6'd0;
            oldest_idx <= 6'd0;
            reuse_available <= 1'b0;
            reuse_addr <= 32'h0;

            for (i = 0; i < 64; i = i + 1) begin
                pending_nodes[i] <= 32'h0;
                pending_indices[i] <= 6'd0;
            end
        end
        else begin
            reuse_available <= 1'b0;

            if (dag_mode) begin
                // Check for node reuse opportunity
                for (i = 0; i < 64; i = i + 1) begin
                    if (!reuse_available && i < pending_count && pending_nodes[i] == expr_hash) begin
                        reuse_available <= 1'b1;
                        reuse_addr <= {{26{1'b0}}, pending_indices[i]};
                    end
                end

                // Add new node if not already pending
                if (expr_valid && !reuse_available && {{26{1'b0}}, pending_count} < 64) begin
                    pending_nodes[pending_count] <= expr_hash;
                    pending_indices[pending_count] <= pending_count;  // Simplified addressing
                    pending_count <= pending_count + 1;
                end

                // Remove completed nodes
                if (node_completed) begin
                    for (i = 0; i < 64; i = i + 1) begin
                        if (i < pending_count && pending_nodes[i] == completed_hash) begin
                            for (j = i; j < 63; j = j + 1) begin
                                if (j + 1 < 64) begin
                                    pending_nodes[j] <= pending_nodes[j + 1];
                                    pending_indices[j] <= pending_indices[j + 1];
                                end
                            end
                            pending_count <= pending_count - 1;
                        end
                    end
                end
            end
        end
    end

endmodule
