// SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
// step_tb.v
// Single-step debug testbench — black-box via DMI
// Verifies dcsr.step bit causes CPU to halt after one instruction

`timescale 1ns/1ps

module step_tb;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // DMI interface
    reg dmi_req;
    reg dmi_wr;
    reg [6:0] dmi_addr;
    reg [31:0] dmi_wdata;
    wire [31:0] dmi_rdata;
    wire dmi_ack;
    
    // Core interface (from mock CPU)
    wire dm_halt_req;
    wire dm_resume_req;
    wire dm_reset_req;
    wire dm_ndmreset;
    wire [15:0] dm_hartsel;
    wire core_reg_req;
    wire core_reg_wr;
    wire [15:0] core_reg_addr;
    wire [31:0] core_reg_wdata;
    
    reg [31:0] core_reg_rdata;
    reg core_reg_ack;
    
    reg [31:0] core_pc;
    reg core_halted;
    reg core_running;
    reg core_has_reset;
    
    wire [31:0] progbuf0;
    wire [31:0] progbuf1;
    wire trigger_hit;
    wire [11:0] debug_rom_addr;
    reg [31:0] debug_rom_instr;
    
    // DUT
    dm_top u_dm_top (
        .clk(clk),
        .rst_n(rst_n),
        .dmi_req(dmi_req),
        .dmi_wr(dmi_wr),
        .dmi_addr(dmi_addr),
        .dmi_wdata(dmi_wdata),
        .dmi_rdata(dmi_rdata),
        .dmi_ack(dmi_ack),
        .core_pc(core_pc),
        .core_halted(core_halted),
        .core_running(core_running),
        .core_has_reset(core_has_reset),
        .dm_halt_req(dm_halt_req),
        .dm_resume_req(dm_resume_req),
        .dm_reset_req(dm_reset_req),
        .dm_ndmreset(dm_ndmreset),
        .dm_hartsel(dm_hartsel),
        .core_reg_req(core_reg_req),
        .core_reg_wr(core_reg_wr),
        .core_reg_addr(core_reg_addr),
        .core_reg_wdata(core_reg_wdata),
        .core_reg_rdata(core_reg_rdata),
        .core_reg_ack(core_reg_ack),
        .progbuf0(progbuf0),
        .progbuf1(progbuf1),
        .trigger_hit(trigger_hit),
        .debug_rom_addr(debug_rom_addr),
        .debug_rom_instr(debug_rom_instr)
    );
    
    // Mock core state
    reg [31:0] dcsr;
    reg [31:0] dpc;
    reg step_pending;
    integer exec_count;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Mock core behavior - single always block for coherent state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            core_pc <= 32'h0000_0000;
            core_halted <= 0;
            core_running <= 1; // Core starts running
            core_has_reset <= 1;
            core_reg_ack <= 0;
            core_reg_rdata <= 32'h0;
            dcsr <= 32'h0;
            dpc <= 32'h0;
            step_pending <= 0;
            exec_count <= 0;
            debug_rom_instr <= 32'h0000_0013;
        end else begin
            // Handle register access requests (priority over execution)
            if (core_reg_req && !core_reg_ack) begin
                core_reg_ack <= 1;
                if (core_reg_wr) begin
                    // Any abstract command write goes to dcsr (mock simplification)
                    dcsr <= core_reg_wdata;
                    if (core_reg_wdata[2]) step_pending <= 1;
                    else step_pending <= 0;
                    $display("[CORE] Abstract write to dcsr: 0x%08x, step_pending=%0b", core_reg_wdata, core_reg_wdata[2]);
                end else begin
                    // Read from register
                    case (core_reg_addr)
                        16'h1000: core_reg_rdata <= dcsr;
                        16'h1001: core_reg_rdata <= dpc;
                        default: core_reg_rdata <= 32'h0;
                    endcase
                end
            end else if (core_reg_ack && !core_reg_req) begin
                core_reg_ack <= 0;
            end
            
            // Handle halt request (from DM)
            if (dm_halt_req && core_running && !core_halted) begin
                core_running <= 0;
                core_halted <= 1;
                dpc <= core_pc;
                dcsr[8] <= 1; // halt flag
                $display("[CORE] Halt requested, halting at PC=0x%08x", core_pc);
            end
            
            // Resume request takes priority over execution
            if (dm_resume_req && core_halted) begin
                core_halted <= 0;
                core_running <= 1;
                dcsr[8] <= 0;
                exec_count <= 1; // Start at 1 so step logic triggers immediately
                
                // If step bit set in dcsr, enable single-step
                if (dcsr[2]) begin
                    step_pending <= 1;
                    $display("[CORE] Resume with step mode, step_pending=1, dcsr=0x%08x", dcsr);
                end else begin
                    step_pending <= 0;
                    $display("[CORE] Resume without step mode, dcsr=0x%08x", dcsr);
                end
            end
            
            // Execute instructions (only if not just resumed)
            if (core_running && !core_halted && !dm_resume_req) begin
                core_pc <= core_pc + 4;
                exec_count <= exec_count + 1;
                
                // If single-step mode, halt after first instruction
                if (step_pending && exec_count == 1) begin
                    core_running <= 0;
                    core_halted <= 1;
                    dcsr[8] <= 1;
                    step_pending <= 0;
                end
            end
            
            // Debug ROM
            case (debug_rom_addr)
                12'h000: debug_rom_instr <= 32'h0000_0013; // NOP
                12'h004: debug_rom_instr <= 32'h0000_0067; // RET
                default: debug_rom_instr <= 32'h0000_0013;
            endcase
        end
    end
    
    // DMI write task
    task dmi_write;
        input [6:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            #1;
            dmi_addr = addr;
            dmi_wdata = data;
            dmi_wr = 1;
            dmi_req = 1;
            @(posedge clk);
            #1;
            while (!dmi_ack) @(posedge clk);
            dmi_req = 0;
            dmi_wr = 0;
            @(posedge clk);
            #1;
        end
    endtask
    
    // DMI read task
    task dmi_read;
        input [6:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            #1;
            dmi_addr = addr;
            dmi_wr = 0;
            dmi_req = 1;
            @(posedge clk);
            #1;
            while (!dmi_ack) @(posedge clk);
            data = dmi_rdata;
            dmi_req = 0;
            @(posedge clk);
            #1;
        end
    endtask
    
    // Test variables
    integer test_num;
    integer pass_count;
    integer fail_count;
    reg [31:0] pc_before;
    reg [31:0] pc_after;
    reg [31:0] dmstatus;
    reg [31:0] dmcontrol;
    reg [31:0] data0;
    
    initial begin
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Reset
        rst_n = 0;
        dmi_req = 0;
        dmi_wr = 0;
        dmi_addr = 0;
        dmi_wdata = 0;
        
        #100;
        rst_n = 1;
        #100;
        
        $display("==========================================");
        $display("Single-Step Debug Testbench");
        $display("==========================================");
        
        // Activate debug module
        dmi_write(7'h10, 32'h0001_0001); // dmcontrol: dmactive=1, haltreq=0
        
        // Test 1: Halt the core
        test_num = 1;
        $display("\n--- Test %0d: Halt Core ---", test_num);
        $display("  Before: core_running=%0b, core_halted=%0b", core_running, core_halted);
        
        dmi_write(7'h10, 32'h0001_8001); // dmcontrol: dmactive=1, haltreq=1
        
        $display("  After DMI write: core_running=%0b, core_halted=%0b, dm_halt_req=%0b", 
                 core_running, core_halted, dm_halt_req);
        
        #1000;
        
        $display("  After wait: core_running=%0b, core_halted=%0b, dm_halt_req=%0b", 
                 core_running, core_halted, dm_halt_req);
        
        dmi_read(7'h04, dmstatus); // dmstatus
        
        $display("  dmstatus=0x%08x", dmstatus);
        
        if (dmstatus[8] || dmstatus[7]) begin // anyhalted/allhalted
            $display("  PASS: Core is halted (dmstatus[anyhalted]=%0b)", dmstatus[7]);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Core not halted (dmstatus=0x%08x)", dmstatus);
            fail_count = fail_count + 1;
        end
        
        // Test 2: Resume with step mode (set step=1 first via DMI)
        test_num = 2;
        $display("\n--- Test %0d: Set Step Mode via Abstract Command ---", test_num);
        
        // Write to DATA0 first (this becomes dcsr value)
        dmi_write(7'h04, 32'h0000_0004); // data0: step=1, cause=0
        
        // Issue abstract command: Access Register, write=1, aarsize=2, transfer=1
        // Encoding per Debug Spec 0.13.2:
        // bits 23:20 = 0 (cmdtype)
        // bits 19:16 = 0010 (aarsize=2)  
        // bit 15 = 1 (write)
        // bit 14 = 0 (postexec=0)
        // bit 13 = 1 (transfer=1)
        // bits 12 = 0 (reserved)
        // bits 11:0 = 0x000 (x0 GPR - will be intercepted by mock as dcsr write)
        dmi_write(7'h17, 32'h0002_A000); // abstract cmd: write=1 (bit15), aarsize=2, transfer=1, x0
        
        #200;
        
        // Test 3: Resume core with step mode active
        test_num = 3;
        $display("\n--- Test %0d: Resume Core (Step Mode Active) ---", test_num);
        
        pc_before = core_pc;
        $display("  PC before step: 0x%08x", pc_before);
        
        // Set dcsr.step directly by writing to control register
        // Then resume
        dmi_write(7'h10, 32'h0001_0001 | (1<<16)); // dmcontrol: resumereq=1
        #1000;
        
        pc_after = core_pc;
        $display("  PC after step:  0x%08x", pc_after);
        $display("  Core halted:    %0b", core_halted);
        
        if (core_halted && (pc_after == pc_before + 4)) begin
            $display("  PASS: Single step executed correctly (PC advanced by 4, then halted)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Step failed");
            if (!core_halted) begin
                $display("    Core did not halt after instruction");
            end
            if (pc_after != pc_before + 4) begin
                $display("    Expected PC +4, got +%0d", pc_after - pc_before);
            end
            fail_count = fail_count + 1;
        end
        
        // Test 4: Multiple single steps
        test_num = 4;
        $display("\n--- Test %0d: Multiple Single Steps (3x) ---", test_num);
        
        pc_before = core_pc;
        repeat (3) begin
            dmi_write(7'h10, 32'h0001_0001 | (1<<16)); // resumereq=1
            #1000;
        end
        
        pc_after = core_pc;
        $display("  PC before: 0x%08x", pc_before);
        $display("  PC after:  0x%08x (expected 0x%08x)", pc_after, pc_before + 12);
        
        if (core_halted && (pc_after == pc_before + 12)) begin
            $display("  PASS: 3 single steps executed correctly");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Multiple steps failed");
            $display("    Halted: %0b (expected 1)", core_halted);
            $display("    PC advance: %0d (expected 12)", pc_after - pc_before);
            fail_count = fail_count + 1;
        end
        
        // Test 5: Clear step bit and run normally
        test_num = 5;
        $display("\n--- Test %0d: Clear Step, Run Normally ---", test_num);
        
        // Halt core first
        dmi_write(7'h10, 32'h0001_8001); // haltreq=1
        #500;
        
        // Clear step bit in dcsr
        dmi_write(7'h04, 32'h0000_0000); // data0: step=0
        dmi_write(7'h17, 32'h0002_B000); // write to x0 via abstract cmd (write=1)
        #200;
        
        pc_before = core_pc;
        dmi_write(7'h10, 32'h0001_0001 | (1<<16)); // resumereq=1
        #2000;
        
        // Now halt it
        dmi_write(7'h10, 32'h0001_8001); // haltreq=1
        #500;
        
        pc_after = core_pc;
        $display("  PC before: 0x%08x", pc_before);
        $display("  PC after:  0x%08x", pc_after);
        
        if (core_halted && (pc_after > pc_before + 12)) begin
            $display("  PASS: Core ran multiple instructions before halt");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Core didn't run normally");
            $display("    Instructions executed: %0d (expected >3)", (pc_after - pc_before) / 4);
            fail_count = fail_count + 1;
        end
        
        // Summary
        $display("\n==========================================");
        $display("Test Summary");
        $display("==========================================");
        $display("  Tests passed: %0d / %0d", pass_count, test_num);
        $display("  Tests failed: %0d", fail_count);
        $display("==========================================");
        
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
            $finish(0);
        end else begin
            $display("SOME TESTS FAILED");
            $finish(1);
        end
    end
    
    // Timeout watchdog
    initial begin
        #50000;
        $display("ERROR: Simulation timeout");
        $finish(1);
    end
    
    // VCD dump
    initial begin
        $dumpfile("step_tb.vcd");
        $dumpvars(0, step_tb);
    end

endmodule
