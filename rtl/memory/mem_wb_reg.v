//=============================================================================
// File      : mem_wb_reg.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   MEM/WB pipeline register — sits between Memory and Writeback stages.
//   Latches ALU result, memory read data, and control signals.
//   No stall or flush needed at this stage — always advances.
//
//-----------------------------------------------------------------------------
// Port List:
//   clk_i        : system clock
//   rst_ni       : asynchronous active-low reset
//
//   — Data inputs from MEM stage:
//   pc_plus4_i   : PC+4 (return address for JAL/JALR writeback)
//   alu_result_i : ALU result (for R/I type writeback)
//   mem_rdata_i  : data loaded from memory (for load writeback)
//   rd_addr_i    : destination register address
//
//   — Control inputs from MEM stage:
//   reg_wr_i     : register write enable
//   mem_rd_i     : instruction was a load — select mem_rdata for writeback
//   jump_i       : instruction was JAL/JALR — select pc_plus4 for writeback
//
//   — All outputs same signals with _o suffix
//
//-----------------------------------------------------------------------------
// Writeback data mux (in writeback stage):
//   jump  = 1 → writeback pc_plus4  (JAL/JALR return address)
//   mem_rd= 1 → writeback mem_rdata (load result)
//   else      → writeback alu_result (R/I type result)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module mem_wb_reg #(
    parameter integer XLEN     = `XLEN,
    parameter integer REG_BITS = `REG_BITS
)(
    // clock and reset
    input  wire                  clk_i,
    input  wire                  rst_ni,

    // data inputs
    input  wire [XLEN-1:0]       pc_plus4_i,
    input  wire [XLEN-1:0]       alu_result_i,
    input  wire [XLEN-1:0]       mem_rdata_i,
    input  wire [REG_BITS-1:0]   rd_addr_i,

    // control inputs
    input  wire                  reg_wr_i,
    input  wire                  mem_rd_i,
    input  wire                  jump_i,

    // data outputs
    output reg  [XLEN-1:0]       pc_plus4_o,
    output reg  [XLEN-1:0]       alu_result_o,
    output reg  [XLEN-1:0]       mem_rdata_o,
    output reg  [REG_BITS-1:0]   rd_addr_o,

    // control outputs
    output reg                   reg_wr_o,
    output reg                   mem_rd_o,
    output reg                   jump_o
);

    //-------------------------------------------------------------------------
    // Pipeline register
    // No stall or flush at this stage
    // Priority: reset > normal
    //-------------------------------------------------------------------------
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            // data
            pc_plus4_o   <= {XLEN{1'b0}};
            alu_result_o <= {XLEN{1'b0}};
            mem_rdata_o  <= {XLEN{1'b0}};
            rd_addr_o    <= {REG_BITS{1'b0}};
            // control
            reg_wr_o     <= 1'b0;
            mem_rd_o     <= 1'b0;
            jump_o       <= 1'b0;

        end else begin
            // normal operation — latch inputs
            pc_plus4_o   <= pc_plus4_i;
            alu_result_o <= alu_result_i;
            mem_rdata_o  <= mem_rdata_i;
            rd_addr_o    <= rd_addr_i;
            reg_wr_o     <= reg_wr_i;
            mem_rd_o     <= mem_rd_i;
            jump_o       <= jump_i;
        end
    end

endmodule