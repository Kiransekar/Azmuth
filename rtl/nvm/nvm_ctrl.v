// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
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
    wire [6:0] calculated_ecc;     // Combinational ECC from registered read_data
    wire [5:0] syndrome;           // Syndrome for error location
    wire       codeword_parity;    // Parity of entire read codeword (data+check+P0)
    wire       single_bit_err;     // Combinational: single-bit error detected
    wire       double_bit_err;     // Combinational: double-bit error detected
    reg [31:0] corrected_data;
    reg        read_valid;         // Pipeline: data captured, ready for ECC output
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

    // Combinational ECC computation from registered read_data
    assign calculated_ecc = calc_ecc(read_data);

    // SECDED error detection using codeword parity
    // Codeword parity = XOR of all bits in the read codeword (data + check bits + P0)
    // Stored codeword has even parity. Single-bit error → odd parity, double-bit → even.
    assign codeword_parity = (^read_data) ^ (^read_ecc[5:0]) ^ read_ecc[6];
    assign syndrome = read_ecc[5:0] ^ calculated_ecc[5:0];
    assign single_bit_err = (syndrome != 6'b0) && codeword_parity;
    assign double_bit_err = (syndrome != 6'b0) && !codeword_parity;

    // Correct single-bit errors using syndrome decoding with SECDED
    // Syndrome = stored_ecc[5:0] XOR calc_ecc[5:0] gives error position in Hamming space
    // Codeword parity (odd = single-bit, even = double-bit)
    function [31:0] correct_data;
        input [31:0] data;
        input [6:0]  stored_ecc;
        input [6:0]  calc_ecc_val;
        input        single_err;
        reg [5:0]  syndrome_local;
        reg        parity_err;
        integer    pos, d_idx, err_pos;
        begin
            correct_data = data;
            syndrome_local = stored_ecc[5:0] ^ calc_ecc_val[5:0];
            // Codeword parity: XOR of all bits in stored codeword
            parity_err = (^data) ^ (^stored_ecc[5:0]) ^ stored_ecc[6];

            if (single_err && syndrome_local != 6'b0 && parity_err) begin
                // Single-bit error: syndrome gives Hamming position
                // Convert Hamming position to data bit index
                if (syndrome_local != 1 && syndrome_local != 2 && syndrome_local != 4 &&
                    syndrome_local != 8 && syndrome_local != 16 && syndrome_local != 32) begin
                    // Error is in a data bit - find which one
                    d_idx = 0;
                    err_pos = -1;
                    for (pos = 1; pos <= 38; pos = pos + 1) begin
                        if (pos != 1 && pos != 2 && pos != 4 && pos != 8 && pos != 16 && pos != 32) begin
                            if (pos == {{26{1'b0}}, syndrome_local}) begin
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

    // Update effective address with wear leveling
    assign effective_addr = i_addr ^ ({6'b0, wear_ptr} << 6);

    always @(posedge i_clk_nvm or posedge i_rst) begin
        if (i_rst) begin
            o_rd_data <= 0;
            o_busy <= 1'b0;
            o_ecc_err <= 1'b0;
            wear_ptr <= 0;
            read_valid <= 1'b0;

            // Initialize memory with zeros
            for (init_idx = 0; init_idx < MEM_SIZE; init_idx = init_idx + 1) begin
                mem_array[init_idx] <= 0;
                ecc_meta[init_idx] <= 0;
            end

        end else begin
            // Stage 1: Capture read data from memory
            if (i_rd_en && !o_busy) begin
                read_data <= mem_array[effective_addr];
                read_ecc <= ecc_meta[effective_addr];
                read_valid <= 1'b1;
            end

            // Stage 2: Compute ECC and output corrected data
            if (read_valid) begin
                // calculated_ecc is combinational from registered read_data
                // syndrome, single_bit_err, double_bit_err are combinational

                // Set error flag if double-bit error detected
                o_ecc_err <= double_bit_err;

                // Correct single-bit errors using combinational signals
                corrected_data = correct_data(read_data, read_ecc, calculated_ecc, single_bit_err);

                // Output the (possibly corrected) data
                o_rd_data <= corrected_data;

                read_valid <= 1'b0;
            end

            // Handle write operations - direct write with ECC
            if (i_wr_en) begin
                // Write data and ECC directly to memory arrays
                mem_array[effective_addr] <= i_wr_data;
                ecc_meta[effective_addr] <= calc_ecc(i_wr_data);

                // Update wear leveling pointer
                wear_ptr <= wear_ptr + 1'b1;

                // Assert busy for one cycle
                o_busy <= 1'b1;
            end else begin
                o_busy <= 1'b0;
            end
        end
    end

endmodule