// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// xcie_csr.v
// Custom Control and Status Registers for Xcew processor
// Implements CSR addresses as specified in the architecture document

module xcie_csr (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [11:0] i_rd_addr,
    input  wire        i_wr_en,
    input  wire [31:0] i_wr_data,

    output reg [31:0]  o_rd_data,
    output reg [3:0]   o_irq_mask
);

    // CSR addresses
    localparam XCEW_CFG_ADDR   = 12'h7C0;  // Configuration register
    localparam XCEW_STATUS_ADDR = 12'h7C1; // Status register

    // Internal CSR storage
    reg [31:0] xcew_cfg_reg;   // RW - Configuration register
    reg [31:0] xcew_status_reg; // RO - Status register

    // Configuration register bit definitions
    // [31:16] - Reserved (read as 0)
    // [15]    - COMPLEX_MODE (0=real, 1=complex)
    // [14:12] - MAX_DEPTH (Actual depth = field + 1)
    // [11:8]  - PRECISION (0=BF16, 1=FP16, 2=Q15.16)
    // [7]     - BRANCH_CUT (0=trap, 1=clip to ±inf)
    // [6:0]   - Reserved (read as 0)

    // Status register bit definitions
    // [31:4]  - PIPELINE_STAGE (Current EML stage)
    // [3]     - IRQ_PENDING
    // [2]     - NVM_BUSY
    // [1]     - OVERFLOW
    // [0]     - NaN_FLAG

    // CSR write logic
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            xcew_cfg_reg <= 32'h0000_0000;  // Default configuration
            xcew_status_reg <= 32'h0000_0000;  // Default status
        end else begin
            if (i_wr_en) begin
                case (i_rd_addr)
                    XCEW_CFG_ADDR: begin
                        // Only update writable bits, preserve read-only and reserved
                        xcew_cfg_reg <= {16'h0,                             // [31:16] Reserved
                                         i_wr_data[15],                      // [15] COMPLEX_MODE
                                         i_wr_data[14:12],                   // [14:12] MAX_DEPTH
                                         i_wr_data[11:8],                    // [11:8] PRECISION
                                         i_wr_data[7],                       // [7] BRANCH_CUT
                                         7'h0};                             // [6:0] Reserved
                    end
                    // XCEW_STATUS_ADDR is read-only, so no write action
                    default: begin
                        // Do nothing for other addresses
                    end
                endcase
            end
        end
    end

    // CSR read logic
    always @(*) begin
        case (i_rd_addr)
            XCEW_CFG_ADDR:   o_rd_data = xcew_cfg_reg;
            XCEW_STATUS_ADDR: o_rd_data = xcew_status_reg;  // Note: this would normally be updated with real status signals
            default:         o_rd_data = 32'h0;  // Return 0 for undefined CSRs
        endcase
    end

    // Output IRQ mask (currently unused, set to 0)
    assign o_irq_mask = 4'b0000;

    // Make cfg register available for other modules
    assign xcew_cfg = xcew_cfg_reg;

endmodule