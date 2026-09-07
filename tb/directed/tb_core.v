//=============================================================================
// File      : tb_core.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Top-level testbench for the RV32I pipelined core.
//   Provides instruction and data memory models.
//   Loads a small test program and verifies correct execution.
//
//   Test program:
//     ADDI x1, x0, 5    — x1 = 5
//     ADDI x2, x0, 10   — x2 = 10
//     ADD  x3, x1, x2   — x3 = 15
//     SW   x3, 0(x0)    — mem[0] = 15
//     LW   x4, 0(x0)    — x4 = mem[0] = 15
//     NOP loop           — halt
//
//   Expected results:
//     x1 = 32'h00000005
//     x2 = 32'h0000000A
//     x3 = 32'h0000000F
//     x4 = 32'h0000000F
//     dmem[0] = 32'h0000000F
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/core_top.v and all submodules
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module tb_core;

    //=========================================================================
    // Parameters
    //=========================================================================
    parameter integer CLK_PERIOD  = 10;    // 100 MHz clock
    parameter integer MEM_DEPTH   = 1024;  // 1K words = 4KB
    parameter integer XLEN        = 32;
    parameter integer RESET_CYCLE = 5;     // reset held for 5 cycles

    //=========================================================================
    // Signal declarations
    //=========================================================================
    reg              clk;
    reg              rst_n;

    // instruction memory interface
    wire [XLEN-1:0]  imem_addr;
    reg  [XLEN-1:0]  imem_rdata;

    // data memory interface
    wire [XLEN-1:0]  dmem_addr;
    wire [XLEN-1:0]  dmem_wdata;
    wire [3:0]       dmem_wr_en;
    wire             dmem_rd_en;
    wire [XLEN-1:0]  dmem_rdata;

    //=========================================================================
    // Memory arrays
    //=========================================================================
    reg [XLEN-1:0] imem [0:MEM_DEPTH-1];
    reg [XLEN-1:0] dmem [0:MEM_DEPTH-1];

    //=========================================================================
    // DUT instantiation
    //=========================================================================
    core_top #(
        .XLEN         (XLEN),
        .RESET_VECTOR (32'h0000_0000)
    ) u_core_top (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .imem_rdata_i (imem_rdata),
        .imem_addr_o  (imem_addr),
        .dmem_rdata_i (dmem_rdata),
        .dmem_addr_o  (dmem_addr),
        .dmem_wdata_o (dmem_wdata),
        .dmem_wr_en_o (dmem_wr_en),
        .dmem_rd_en_o (dmem_rd_en)
    );

    //=========================================================================
    // Clock generation — 100 MHz
    //=========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //=========================================================================
    // Instruction memory model — synchronous read
    //=========================================================================
    always @(posedge clk) begin
        imem_rdata <= imem[imem_addr[XLEN-1:2]];
    end

    //=========================================================================
    // Data memory model
    // Read — synchronous
    // Write — byte enable controlled
    //=========================================================================
    assign dmem_rdata = dmem[dmem_addr[XLEN-1:2]];

    always @(posedge clk) begin
    // write with byte enables only
        if (dmem_wr_en[0]) dmem[dmem_addr[XLEN-1:2]][7:0]   <= dmem_wdata[7:0];
        if (dmem_wr_en[1]) dmem[dmem_addr[XLEN-1:2]][15:8]  <= dmem_wdata[15:8];
        if (dmem_wr_en[2]) dmem[dmem_addr[XLEN-1:2]][23:16] <= dmem_wdata[23:16];
        if (dmem_wr_en[3]) dmem[dmem_addr[XLEN-1:2]][31:24] <= dmem_wdata[31:24];
    end

    //=========================================================================
    // Test program — load into instruction memory
    // RV32I machine code
    //=========================================================================
    integer i;

    initial begin
        // clear all memory
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            imem[i] = 32'h0000_0013;  // NOP = ADDI x0, x0, 0
            dmem[i] = 32'h0000_0000;
        end

        // test program
        // addr 0x00: ADDI x1, x0, 5    — x1 = 5
        imem[0] = 32'h0050_0093;

        // addr 0x04: ADDI x2, x0, 10   — x2 = 10
        imem[1] = 32'h00A0_0113;

        // addr 0x08: ADD x3, x1, x2    — x3 = x1 + x2 = 15
        imem[2] = 32'h0020_81B3;

        // addr 0x0C: SW x3, 0(x0)      — mem[0x0] = x3 = 15
        imem[3] = 32'h0030_2023;

        // addr 0x10: LW x4, 0(x0)      — x4 = mem[0x0] = 15
        imem[4] = 32'h0000_2203;

        // addr 0x14: ADDI x5, x0, 1    — x5 = 1 (marker)
        imem[5] = 32'h0010_0293;

        // addr 0x18 onwards: NOP loop
        imem[6] = 32'h0000_0013;
        imem[7] = 32'h0000_0013;
    end

    //=========================================================================
    // Reset sequence
    //=========================================================================
    initial begin
        rst_n = 1'b0;
        repeat(RESET_CYCLE) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        $display("[%0t] Reset released", $time);
    end

    //=========================================================================
    // VCD dump for GTKWave
    //=========================================================================
    initial begin
        $dumpfile("sim/core.vcd");
        $dumpvars(0, tb_core);
    end

    //=========================================================================
    // Monitor — print register file writes
    //=========================================================================
    always @(posedge clk) begin
        if (u_core_top.u_regfile.rd_wr_en_i &&
            u_core_top.u_regfile.rd_addr_i != 5'h0) begin
            $display("[%0t] REG WRITE: x%0d = 0x%08X",
                     $time,
                     u_core_top.u_regfile.rd_addr_i,
                     u_core_top.u_regfile.rd_data_i);
        end
    end

    //=========================================================================
    // Monitor — data memory writes
    //=========================================================================
    always @(posedge clk) begin
        if (|dmem_wr_en) begin
            $display("[%0t] MEM WRITE: addr=0x%08X data=0x%08X en=%b",
                     $time, dmem_addr, dmem_wdata, dmem_wr_en);
        end
    end

    //=========================================================================
    // Self-checking — verify results after enough cycles
    //=========================================================================
    initial begin
        // wait for reset + enough cycles for all instructions to complete
        // 5 reset + 5 pipeline fill + 7 instructions * 1 cycle = ~20 cycles
        repeat(RESET_CYCLE + 60) @(posedge clk);

        $display("");
        $display("========================================");
        $display("  RV32I Core Simulation Results");
        $display("========================================");

        // check x1 = 5
        if (u_core_top.u_regfile.regs[1] === 32'h0000_0005)
            $display("  PASS: x1 = 0x%08X (expected 0x00000005)",
                     u_core_top.u_regfile.regs[1]);
        else
            $display("  FAIL: x1 = 0x%08X (expected 0x00000005)",
                     u_core_top.u_regfile.regs[1]);

        // check x2 = 10
        if (u_core_top.u_regfile.regs[2] === 32'h0000_000A)
            $display("  PASS: x2 = 0x%08X (expected 0x0000000A)",
                     u_core_top.u_regfile.regs[2]);
        else
            $display("  FAIL: x2 = 0x%08X (expected 0x0000000A)",
                     u_core_top.u_regfile.regs[2]);

        // check x3 = 15
        if (u_core_top.u_regfile.regs[3] === 32'h0000_000F)
            $display("  PASS: x3 = 0x%08X (expected 0x0000000F)",
                     u_core_top.u_regfile.regs[3]);
        else
            $display("  FAIL: x3 = 0x%08X (expected 0x0000000F)",
                     u_core_top.u_regfile.regs[3]);

        // check x4 = 15 (loaded from memory)
        if (u_core_top.u_regfile.regs[4] === 32'h0000_000F)
            $display("  PASS: x4 = 0x%08X (expected 0x0000000F)",
                     u_core_top.u_regfile.regs[4]);
        else
            $display("  FAIL: x4 = 0x%08X (expected 0x0000000F)",
                     u_core_top.u_regfile.regs[4]);

        // check dmem[0] = 15
        if (dmem[0] === 32'h0000_000F)
            $display("  PASS: dmem[0] = 0x%08X (expected 0x0000000F)",
                     dmem[0]);
        else
            $display("  FAIL: dmem[0] = 0x%08X (expected 0x0000000F)",
                     dmem[0]);

        $display("========================================");
        $display("");
        $finish;
    end

endmodule