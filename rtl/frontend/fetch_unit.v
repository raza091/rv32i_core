//=============================================================================
// File      : fetch_unit.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Instruction Fetch Unit for the IF stage.
//   Instantiates the PC register and computes PC+4.
//   Selects next PC from either sequential (PC+4) or
//   branch/jump target based on control signals.
//
//-----------------------------------------------------------------------------
// Port List:
//   clk_i          : system clock
//   rst_ni         : asynchronous active-low reset
//   stall_i        : stall from hazard unit — hold PC
//   flush_i        : flush from branch/jump — select branch target
//   branch_taken_i : branch decision from EX stage
//   branch_target_i: branch or jump target address
//   pc_o           : current PC to IF/ID pipeline register
//   pc_plus4_o     : PC+4 passed to ID stage (return addr for JAL)
//
//-----------------------------------------------------------------------------
// Parameters:
//   XLEN         : data width (default 32)
//   RESET_VECTOR : boot address (default 0x00000000)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//   rtl/frontend/pc_reg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module fetch_unit #(
    parameter   integer XLEN            =   `XLEN,
                integer RESET_VECTOR    =   32'h0000_0000
) (
    // clock and reset
    input   wire                clk_i,
    input   wire                rst_ni,

    // Control
    input   wire                stall_i,
    input   wire                flush_i,
    input   wire                branch_taken_i,
    input   wire [XLEN-1:0]     branch_target_i,

    // Outputs
    output  wire [XLEN-1:0]     pc_o,
    output  wire [XLEN-1:0]     pc_plus4_o
);

//-------------------------------------------------------------------------
// Internal signals
//-------------------------------------------------------------------------
    wire [XLEN-1:0] pc_current;
    wire [XLEN-1:0] pc_plus4;
    wire [XLEN-1:0] pc_next;

//-------------------------------------------------------------------------
// PC + 4 — next sequential instruction address
//-------------------------------------------------------------------------
    assign pc_plus4 = pc_current + 32'd4;

//-------------------------------------------------------------------------
// Next PC mux
// flush or branch taken → jump to branch target
// otherwise            → sequential PC+4
//-------------------------------------------------------------------------
    assign pc_next = (flush_i || branch_taken_i) ? branch_target_i : pc_plus4;

//-------------------------------------------------------------------------
// PC register instantiation
//-------------------------------------------------------------------------
    pc_reg #(
        .XLEN           (XLEN),
        .RESET_VECTOR   (RESET_VECTOR)
    ) u_pc_reg (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .stall_i(stall_i),
        .pc_next_i(pc_next),
        .pc_o(pc_current)
    );

//-------------------------------------------------------------------------
// Output assignments
//-------------------------------------------------------------------------
    assign  pc_o        =   pc_current;
    assign  oc_plus4_o  =   pc_plus4;   

endmodule