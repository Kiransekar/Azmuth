// nvm_ctrl.v
// Non-Volatile Memory controller for Xcew processor
// Implements ReRAM controller with wear-leveling and ECC

module nvm_ctrl (
    input  wire        i_clk_nvm,
    input  wire        i_rst,
    input  wire [15:0] i_addr,
    input  wire        i_wr_en,
    input  wire [31:0] i_wr_data,
    input  wire        i_rd_en,

    output reg [31:0]  o_rd_data,
    output reg         o_busy,
    output reg         o_ecc_err
);

    // Memory parameters
    localparam ADDR_WIDTH = 16;  // 64KB address space (2^16)
    localparam DATA_WIDTH = 32;
    localparam MEM_SIZE = 65536; // 64K words
    localparam META_SIZE = 65536; // Metadata for ECC

    // Wear leveling parameters
    localparam WL_PTR_WIDTH = 10;  // 1024 wear leveling blocks

    // Memory arrays
    reg [DATA_WIDTH-1:0] mem_array [0:MEM_SIZE-1];
    reg [5:0]            ecc_meta [0:MEM_SIZE-1];  // 6-bit ECC per 32-bit word
    reg [WL_PTR_WIDTH-1:0] wear_ptr;

    // Internal signals
    reg [15:0] effective_addr;
    reg [31:0] read_data;
    reg [5:0]  read_ecc;
    reg [5:0]  calculated_ecc;
    reg [31:0] corrected_data;
    reg        single_bit_err;
    reg        double_bit_err;

    // ECC functions
    function [5:0] calc_ecc;
        input [31:0] data;
        begin
            // Simplified Hamming(32,26) ECC calculation
            // In practice, this would be a more complex Hamming code
            calc_ecc = ^data;  // XOR of all data bits (simplified)
        end
    endfunction

    // Correct single-bit errors
    function [31:0] correct_data;
        input [31:0] data;
        input [5:0]  stored_ecc;
        input [5:0]  calc_ecc;
        input        single_err;
        begin
            correct_data = data;
            if (single_err) begin
                // In a real implementation, this would identify and flip the erroneous bit
                // For simplicity, we'll just return the original data
                correct_data = data;
            end
        end
    endfunction

    // Write buffer (simplified 4-entry buffer)
    reg [31:0] write_buffer_data [0:3];
    reg [15:0] write_buffer_addr [0:3];
    reg [1:0]  write_buffer_head;
    reg [1:0]  write_buffer_tail;
    reg        write_buffer_full;
    reg        write_buffer_empty;

    // Update effective address with wear leveling
    assign effective_addr = i_addr ^ ({6'b0, wear_ptr} << 6);

    always @(posedge i_clk_nvm or posedge i_rst) begin
        if (i_rst) begin
            o_rd_data <= 0;
            o_busy <= 1'b0;
            o_ecc_err <= 1'b0;
            wear_ptr <= 0;

            // Initialize memory with zeros
            for (integer i = 0; i < 1024; i = i + 1) begin
                mem_array[i] <= 0;
                ecc_meta[i] <= 0;
            end

            // Write buffer initialization
            write_buffer_head <= 2'b00;
            write_buffer_tail <= 2'b00;
            write_buffer_full <= 1'b0;
            write_buffer_empty <= 1'b1;
        end else begin
            // Update wear leveling pointer periodically
            if (i_wr_en) begin
                wear_ptr <= wear_ptr + 1'b1;
            end

            // Handle read operations
            if (i_rd_en && !o_busy) begin
                read_data <= mem_array[effective_addr];
                read_ecc <= ecc_meta[effective_addr];
                calculated_ecc <= calc_ecc(read_data);

                // Check for ECC errors
                single_bit_err <= (calculated_ecc != read_ecc) && (&(calculated_ecc ^ read_ecc));  // Simplified
                double_bit_err <= (calculated_ecc != read_ecc) && (~&(calculated_ecc ^ read_ecc)); // Simplified

                // Set error flag if double-bit error detected
                o_ecc_err <= double_bit_err;

                // Correct single-bit errors
                corrected_data = correct_data(read_data, read_ecc, calculated_ecc, single_bit_err);

                // Output the (possibly corrected) data
                o_rd_data <= corrected_data;
            end

            // Handle write operations through buffer
            if (i_wr_en && !o_busy) begin
                // Add to write buffer
                if (!write_buffer_full) begin
                    write_buffer_data[write_buffer_head] <= i_wr_data;
                    write_buffer_addr[write_buffer_head] <= effective_addr;

                    // Calculate and store ECC
                    ecc_meta[effective_addr] <= calc_ecc(i_wr_data);

                    // Update buffer pointers
                    write_buffer_head <= write_buffer_head + 1'b1;
                    if (write_buffer_head == 2'b11) begin
                        write_buffer_full <= 1'b1;
                    end
                    write_buffer_empty <= 1'b0;
                end

                o_busy <= 1'b1;
            end

            // Process write buffer (simplified - one entry per cycle when busy)
            if (o_busy && !write_buffer_empty) begin
                // Write data to memory
                integer write_idx;
                write_idx = write_buffer_tail;

                mem_array[write_buffer_addr[write_idx]] <= write_buffer_data[write_idx];

                // Update buffer pointers
                write_buffer_tail <= write_buffer_tail + 1'b1;
                if (write_buffer_tail == write_buffer_head) begin
                    write_buffer_full <= 1'b0;
                end
                if (write_buffer_tail == write_buffer_head) begin
                    write_buffer_empty <= 1'b1;
                    o_busy <= 1'b0;  // Clear busy when buffer is empty
                end
            end

            // If buffer is empty and not writing, clear busy
            if (!i_wr_en && write_buffer_empty) begin
                o_busy <= 1'b0;
            end
        end
    end

endmodule