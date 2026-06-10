// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// Copyright (c) 2026 Kiransekar. All rights reserved.
// dm_regfile.v
// Debug Module register file
// Verilog-2001 compliant, synthesizable

`timescale 1ns/1ps

module dm_regfile (
    input  wire        clk,
    input  wire        rst_n,
    // DMI interface
    input  wire        dmi_req,
    input  wire        dmi_wr,
    input  wire [6:0]  dmi_addr,
    input  wire [31:0] dmi_wdata,
    output reg  [31:0] dmi_rdata,
    output reg         dmi_ack,
    // Status inputs
    input  wire        hart_halted,
    input  wire        hart_running,
    input  wire        hart_has_reset,
    // Outputs to DM control
    output reg         dm_halt_req,
    output reg         dm_resume_req,
    output reg         dm_reset_req,
    output reg         dm_ndmreset,
    output reg [15:0]  dm_hartsel,
    // SBA (System Bus Access) - not implemented in v1.1
    output reg         sba_enable
);

    // DM register addresses (per RISC-V Debug Spec 0.13.2)
    localparam DMSTATUS     = 7'h04;
    localparam DMCONTROL    = 7'h10;
    localparam HARTINFO     = 7'h11;
    localparam HALTSUM0     = 7'h12;
    localparam ABSTRACTCS   = 7'h16; // Handled by abstract_cmd
    localparam COMMAND      = 7'h17; // Handled by abstract_cmd
    localparam PROGBUF0     = 7'h20;
    localparam PROGBUF1     = 7'h21;
    localparam DATA0        = 7'h04; // Overlaps with abstract data
    localparam SBCS         = 7'h38; // System Bus Access Control

    reg [31:0] dmstatus;
    reg [31:0] dmcontrol;
    reg [31:0] hartinfo;
    reg [31:0] haltsum0;
    reg [31:0] sbcs;

    // DMSTATUS reset value: version=1 (0.13.2), authbusy=0, authenticated=0,
    // auth=0, hasresethaltreq=1, confstrptrvalid=0, allhavereset=0, anyhavereset=0,
    // allhalted=0, anyhalted=0, allrunning=0, anyrunning=1, impebreak=0
    localparam DMSTATUS_RESET = 32'h02800800;

    // HARTINFO: nscratch=2, dataaccess=0 (no SBA), datasize=0, dataaddr=0
    localparam HARTINFO_VAL = 32'h00000002;

    // SBCS: SBA not implemented
    localparam SBCS_VAL = 32'h00000000;

    reg dm_halt_req_pulse;
    reg dm_resume_req_pulse;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmstatus   <= DMSTATUS_RESET;
            dmcontrol  <= 32'h0;
            hartinfo   <= HARTINFO_VAL;
            haltsum0   <= 32'h0;
            sbcs       <= SBCS_VAL;
            dm_halt_req   <= 1'b0;
            dm_halt_req_pulse <= 1'b0;
            dm_resume_req <= 1'b0;
            dm_resume_req_pulse <= 1'b0;
            dm_reset_req  <= 1'b0;
            dm_ndmreset   <= 1'b0;
            dm_hartsel    <= 16'h0; // Select hart 0
            sba_enable    <= 1'b0;
            dmi_rdata <= 32'h0;
        end else begin
            dmi_ack <= dmi_req;

            // Update status bits from hart
            dmstatus[10] <= hart_has_reset;  // allhavereset
            dmstatus[9]  <= hart_has_reset;  // anyhavereset
            dmstatus[8]  <= hart_halted;     // allhalted
            dmstatus[7]  <= hart_halted;     // anyhalted
            dmstatus[6]  <= hart_running;    // allrunning
            dmstatus[5]  <= hart_running;    // anyrunning

            haltsum0[0] <= hart_halted;
            
            // Clear pulse signals every cycle (they're one-cycle pulses)
            dm_halt_req_pulse <= 1'b0;
            dm_resume_req_pulse <= 1'b0;

            if (dmi_req && dmi_wr) begin
                case (dmi_addr)
                    DMCONTROL: begin
                        dmcontrol <= dmi_wdata;
                        // Generate one-cycle pulses for halt/resume requests
                        if (dmi_wdata[15]) dm_halt_req_pulse <= 1'b1;   // haltreq pulse
                        if (dmi_wdata[16]) dm_resume_req_pulse <= 1'b1; // resumereq pulse
                        dm_reset_req  <= dmi_wdata[17];   // hartreset (level)
                        dm_ndmreset   <= dmi_wdata[30];   // ndmreset (level)
                        dm_hartsel    <= dmi_wdata[25:6]; // hartsel[19:0]
                    end
                    SBCS: begin
                        sbcs <= dmi_wdata;
                        sba_enable <= dmi_wdata[21]; // sbaenable bit
                    end
                    default: ;
                endcase
            end
            
            // DMI reads
            if (dmi_req && !dmi_wr) begin
                case (dmi_addr)
                    DMSTATUS:   dmi_rdata <= dmstatus;
                    DMCONTROL:  dmi_rdata <= dmcontrol;
                    HARTINFO:   dmi_rdata <= hartinfo;
                    HALTSUM0:   dmi_rdata <= haltsum0;
                    SBCS:       dmi_rdata <= sbcs;
                    PROGBUF0:   dmi_rdata <= 32'h0; // Handled by progbuf module
                    PROGBUF1:   dmi_rdata <= 32'h0;
                    default:    dmi_rdata <= 32'h0;
                endcase
            end
            
            // Pulse output
            dm_halt_req <= dm_halt_req_pulse;
            dm_resume_req <= dm_resume_req_pulse;
        end
    end

endmodule