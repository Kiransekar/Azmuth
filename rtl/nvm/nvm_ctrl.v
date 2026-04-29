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
    reg [6:0]            ecc_meta [0:MEM_SIZE-1];  // 7-bit SECDED ECC per 32-bit word
    reg [WL_PTR_WIDTH-1:0] wear_ptr;

    // Internal signals
    wire [15:0] effective_addr;
    reg [31:0] read_data;
    reg [6:0]  read_ecc;
    reg [6:0]  calculated_ecc;
    reg [31:0] corrected_data;
    reg        single_bit_err;
    reg        double_bit_err;
    reg [1:0]  temp_write_idx;  // For avoiding local declaration
    integer init_idx;            // For memory initialization loop

    // ECC functions - Hamming(38,32) SECDED code
    // Check bits at Hamming positions 1,2,4,8,16,32 (bits [5:0])
    // Overall parity bit at position 0 (bit [6])
    // Data bits at remaining positions 3,5,6,7,9,...,31,33,...,38
    function [6:0] calc_ecc;
        input [31:0] data;
        integer pos, d_idx, k;
        reg [5:0] ecc_bits;
        reg       overall_parity;
        begin
            ecc_bits = 6'b0;
            overall_parity = 1'b0;
            d_idx = 0;
            for (pos = 1; pos <= 38; pos = pos + 1) begin
                // Skip check bit positions (powers of 2)
                if (pos != 1 && pos != 2 && pos != 4 && pos != 8 && pos != 16 && pos != 32) begin
                    // This is a data position - each check bit k XORs data if pos has bit k set
                    for (k = 0; k < 6; k = k + 1) begin
                        if (pos[k] && d_idx < 32) begin
                            ecc_bits[k] = ecc_bits[k] ^ data[d_idx];
                        end
                    end
                    if (d_idx < 32) begin
                        overall_parity = overall_parity ^ data[d_idx];
                    end
                    d_idx = d_idx + 1;
                end
            end
            // Overall parity covers all data bits AND all check bits
            calc_ecc = {overall_parity ^ (^ecc_bits), ecc_bits};
        end
    endfunction

    // Correct single-bit errors using syndrome decoding with SECDED
    // Syndrome = stored_ecc[5:0] XOR calc_ecc[5:0] gives error position in Hamming space
    // Overall parity = stored_ecc[6] XOR calc_ecc[6]:
    //   Odd parity  + non-zero syndrome = single-bit error (correctable)
    //   Even parity + non-zero syndrome = double-bit error (detectable only)
    function [31:0] correct_data;
        input [31:0] data;
        input [6:0]  stored_ecc;
        input [6:0]  calc_ecc_val;
        input        single_err;
        reg [5:0]  syndrome;
        reg        parity_err;
        integer    pos, d_idx, err_pos;
        begin
            correct_data = data;
            syndrome = stored_ecc[5:0] ^ calc_ecc_val[5:0];
            parity_err = stored_ecc[6] ^ calc_ecc_val[6];

            if (single_err && syndrome != 6'b0 && parity_err) begin
                // Single-bit error: syndrome gives Hamming position
                // Convert Hamming position to data bit index
                if (syndrome != 1 && syndrome != 2 && syndrome != 4 &&
                    syndrome != 8 && syndrome != 16 && syndrome != 32) begin
                    // Error is in a data bit - find which one
                    d_idx = 0;
                    err_pos = -1;
                    for (pos = 1; pos <= 38; pos = pos + 1) begin
                        if (pos != 1 && pos != 2 && pos != 4 && pos != 8 && pos != 16 && pos != 32) begin
                            if (pos == syndrome) begin
                                err_pos = d_idx;
                            end
                            d_idx = d_idx + 1;
                        end
                    end
                    // Flip the erroneous bit
                    if (err_pos >= 0 && err_pos < 32) begin
                        correct_data[err_pos] = ~data[err_pos];
                    end
                end
                // If syndrome points to a check bit position, data is fine
            end
            // If syndrome != 0 but parity_err == 0 → double-bit error (uncorrectable)
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
            for (init_idx = 0; init_idx < MEM_SIZE; init_idx = init_idx + 1) begin
                mem_array[init_idx] <= 0;
                ecc_meta[init_idx] <= 0;
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

                // Check for ECC errors using SECDED syndrome + overall parity
                // Non-zero syndrome with odd parity = single-bit error (correctable)
                // Non-zero syndrome with even parity = double-bit error (detectable only)
                // Zero syndrome = no error
                single_bit_err <= (calculated_ecc[5:0] != read_ecc[5:0]) &&
                                  (calculated_ecc[6] != read_ecc[6]);  // Odd parity → single error
                double_bit_err <= (calculated_ecc[5:0] != read_ecc[5:0]) &&
                                  (calculated_ecc[6] == read_ecc[6]);  // Even parity → double error

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
                temp_write_idx = write_buffer_tail;

                mem_array[write_buffer_addr[temp_write_idx]] <= write_buffer_data[temp_write_idx];

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