//=============================================================================
// File      : if_id_reg.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   IF/ID pipeline register — sits between Fetch and Decode stages.
//   Latches PC, PC+4 and instruction word on every clock cycle.
//   Supports stall (hold) and flush (insert NOP/bubble).
//
//-----------------------------------------------------------------------------
// Port List:
//   clk_i       : system clock
//   rst_ni      : asynchronous active-low reset
//   stall_i     : hold register contents (from hazard unit)
//   flush_i     : clear register — insert bubble (from branch logic)
//   pc_i        : current PC from fetch unit
//   pc_plus4_i  : PC+4 from fetch unit
//   instr_i     : instruction word from instruction memory
//   pc_o        : registered PC to decode stage
//   pc_plus4_o  : registered PC+4 to decode stage
//   instr_o     : registered instruction to decode stage
//
//-----------------------------------------------------------------------------
// Parameters:
//   XLEN : data width (default 32)
//   ILEN : instruction width (default 32)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module if_id_reg #(
    parameter integer XLEN = `XLEN,
    parameter integer ILEN = `ILEN
)(
    // clock and reset
    input  wire             clk_i,
    input  wire             rst_ni,

    // control
    input  wire             stall_i,
    input  wire             flush_i,

    // inputs from fetch stage
    input  wire [XLEN-1:0]  pc_i,
    input  wire [XLEN-1:0]  pc_plus4_i,
    input  wire [ILEN-1:0]  instr_i,

    // outputs to decode stage
    output reg  [XLEN-1:0]  pc_o,
    output reg  [XLEN-1:0]  pc_plus4_o,
    output reg  [ILEN-1:0]  instr_o
);

    //-------------------------------------------------------------------------
    // Pipeline register
    // Priority: reset > flush > stall > normal
    //
    // flush inserts a bubble — all fields cleared to 0
    // A cleared instruction = 0x00000000 which is an
    // illegal instruction in RV32I — safe NOP behaviour
    //-------------------------------------------------------------------------
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pc_o      <= {XLEN{1'b0}};
            pc_plus4_o <= {XLEN{1'b0}};
            instr_o   <= {ILEN{1'b0}};
        end else if (flush_i) begin
            pc_o      <= {XLEN{1'b0}};
            pc_plus4_o <= {XLEN{1'b0}};
            instr_o   <= {ILEN{1'b0}};  // bubble — NOP
        end else if (stall_i) begin
            pc_o      <= pc_o;           // hold
            pc_plus4_o <= pc_plus4_o;    // hold
            instr_o   <= instr_o;        // hold
        end else begin
            pc_o      <= pc_i;
            pc_plus4_o <= pc_plus4_i;
            instr_o   <= instr_i;
        end
    end

endmodule