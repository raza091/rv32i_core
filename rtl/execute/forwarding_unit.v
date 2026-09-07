//=============================================================================
// File      : forwarding_unit.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Forwarding unit for the EX stage.
//   Detects data hazards and generates forwarding mux select signals
//   to bypass stale register file values with newer pipeline results.
//
//   Forwarding priority (highest to lowest):
//     1. EX/MEM stage  — result from previous instruction
//     2. MEM/WB stage  — result from two instructions ago
//     3. No forwarding — use register file output directly
//
//   x0 is never forwarded — it is hardwired to zero.
//
//-----------------------------------------------------------------------------
// Port List:
//   rs1_addr_i   : rs1 register address in current EX stage instruction
//   rs2_addr_i   : rs2 register address in current EX stage instruction
//   ex_mem_rd_i  : destination register in EX/MEM pipeline register
//   ex_mem_wr_i  : register write enable in EX/MEM pipeline register
//   mem_wb_rd_i  : destination register in MEM/WB pipeline register
//   mem_wb_wr_i  : register write enable in MEM/WB pipeline register
//   fwd_a_o      : forwarding mux select for ALU operand A (rs1)
//   fwd_b_o      : forwarding mux select for ALU operand B (rs2)
//
//-----------------------------------------------------------------------------
// Forwarding mux encoding (from rv32i_pkg.v):
//   FWD_NONE = 2'b00 : use register file output
//   FWD_MEM  = 2'b01 : forward from EX/MEM stage result
//   FWD_WB   = 2'b10 : forward from MEM/WB stage result
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module forwarding_unit #(
    parameter integer REG_BITS = `REG_BITS
)(
    // current EX stage source registers
    input  wire [REG_BITS-1:0]  rs1_addr_i,
    input  wire [REG_BITS-1:0]  rs2_addr_i,

    // EX/MEM pipeline register
    input  wire [REG_BITS-1:0]  ex_mem_rd_i,
    input  wire                 ex_mem_wr_i,

    // MEM/WB pipeline register
    input  wire [REG_BITS-1:0]  mem_wb_rd_i,
    input  wire                 mem_wb_wr_i,

    // forwarding mux selects
    output reg  [1:0]           fwd_a_o,
    output reg  [1:0]           fwd_b_o
);

    //-------------------------------------------------------------------------
    // Forwarding logic for operand A (rs1)
    // EX/MEM has higher priority than MEM/WB
    // Never forward to/from x0
    //-------------------------------------------------------------------------
    always @(*) begin
        if (ex_mem_wr_i &&
            (ex_mem_rd_i != {REG_BITS{1'b0}}) &&
            (ex_mem_rd_i == rs1_addr_i)) begin
            // forward from EX/MEM — most recent result
            fwd_a_o = `FWD_MEM;

        end else if (mem_wb_wr_i &&
                     (mem_wb_rd_i != {REG_BITS{1'b0}}) &&
                     (mem_wb_rd_i == rs1_addr_i)) begin
            // forward from MEM/WB — result two cycles ago
            fwd_a_o = `FWD_WB;

        end else begin
            // no hazard — use register file output
            fwd_a_o = `FWD_NONE;
        end
    end

    //-------------------------------------------------------------------------
    // Forwarding logic for operand B (rs2)
    // Same priority as operand A
    //-------------------------------------------------------------------------
    always @(*) begin
        if (ex_mem_wr_i &&
            (ex_mem_rd_i != {REG_BITS{1'b0}}) &&
            (ex_mem_rd_i == rs2_addr_i)) begin
            // forward from EX/MEM
            fwd_b_o = `FWD_MEM;

        end else if (mem_wb_wr_i &&
                     (mem_wb_rd_i != {REG_BITS{1'b0}}) &&
                     (mem_wb_rd_i == rs2_addr_i)) begin
            // forward from MEM/WB
            fwd_b_o = `FWD_WB;

        end else begin
            // no hazard
            fwd_b_o = `FWD_NONE;
        end
    end

endmodule