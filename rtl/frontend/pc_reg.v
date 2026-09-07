//=============================================================================
// File      : pc_reg.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
// -----------------------------------------------------------------------------
// Description:
//   Program Counter register for the IF stage.
//   Holds the current PC value and updates it on every clock cycle.
//   Supports synchronous stall (hold) and asynchronous active-low reset.
//
// -----------------------------------------------------------------------------
// Port List:
//   clk_i       : system clock (rising edge triggered)
//   rst_ni      : asynchronous active-low reset
//   stall_i     : stall signal from hazard unit (hold PC when high)
//   pc_next_i   : next PC value (from fetch or branch unit)
//   pc_o        : current PC output to instruction memory
//
// -----------------------------------------------------------------------------
// Parameters:
//   XLEN         : data width (default 32)
//   RESET_VECTOR : address CPU boots from (default 0x00000000)
//
// -----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module pc_reg #(
    parameter   XLEN            =   `XLEN,
                RESET_VECTOR    =   32'h00000000
) (
    input   wire                clk_i,
    input   wire                rst_ni,
    input   wire                stall_i,
    input   wire [XLEN-1:0]     pc_next_i,
    output  reg  [XLEN-1:0]     pc_o
);  

//-------------------------------------------------------------------------
// PC register
// - asynchronous active-low reset → PC = RESET_VECTOR
// - stall high → hold current PC
// - otherwise  → update to pc_next_i
//-----------------------------------------------------------------------
always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
        pc_o    <=  RESET_VECTOR;
    end else if (stall_i) begin
        pc_o    <=  pc_o;
    end else begin
        pc_o    <=  pc_next_i;
    end
end
endmodule