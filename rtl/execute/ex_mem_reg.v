//=============================================================================
// File      : ex_mem_reg.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   EX/MEM pipeline register — sits between Execute and Memory stages.
//   Latches ALU result, store data, and control signals.
//   No stall needed at this stage — only flush for branch misprediction.
//
//-----------------------------------------------------------------------------
// Port List:
//   clk_i        : system clock
//   rst_ni       : asynchronous active-low reset
//   flush_i      : clear register — insert bubble
//
//   — Data inputs from EX stage:
//   pc_plus4_i   : PC+4 (writeback data for JAL/JALR)
//   alu_result_i : ALU computation result
//   rs2_data_i   : rs2 value (store data for SW/SH/SB)
//   rd_addr_i    : destination register address
//
//   — Control inputs from EX stage:
//   reg_wr_i     : register write enable
//   mem_rd_i     : memory read enable (load)
//   mem_wr_i     : memory write enable (store)
//   mem_width_i  : memory access width byte/half/word
//   mem_sign_i   : signed/unsigned load
//   jump_i       : select pc_plus4 as writeback data
//
//   — All outputs same signals with _o suffix
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module ex_mem_reg #(
    parameter integer XLEN     = `XLEN,
    parameter integer REG_BITS = `REG_BITS
)(
    // clock and reset
    input  wire                  clk_i,
    input  wire                  rst_ni,

    // pipeline control
    input  wire                  flush_i,

    // data inputs
    input  wire [XLEN-1:0]       pc_plus4_i,
    input  wire [XLEN-1:0]       alu_result_i,
    input  wire [XLEN-1:0]       rs2_data_i,
    input  wire [REG_BITS-1:0]   rd_addr_i,

    // control inputs
    input  wire                  reg_wr_i,
    input  wire                  mem_rd_i,
    input  wire                  mem_wr_i,
    input  wire [1:0]            mem_width_i,
    input  wire                  mem_sign_i,
    input  wire                  jump_i,

    // data outputs
    output reg  [XLEN-1:0]       pc_plus4_o,
    output reg  [XLEN-1:0]       alu_result_o,
    output reg  [XLEN-1:0]       rs2_data_o,
    output reg  [REG_BITS-1:0]   rd_addr_o,

    // control outputs
    output reg                   reg_wr_o,
    output reg                   mem_rd_o,
    output reg                   mem_wr_o,
    output reg  [1:0]            mem_width_o,
    output reg                   mem_sign_o,
    output reg                   jump_o
);

    //-------------------------------------------------------------------------
    // Pipeline register
    // Priority: reset > flush > normal
    // No stall at this stage
    //-------------------------------------------------------------------------
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            // data
            pc_plus4_o   <= {XLEN{1'b0}};
            alu_result_o <= {XLEN{1'b0}};
            rs2_data_o   <= {XLEN{1'b0}};
            rd_addr_o    <= {REG_BITS{1'b0}};
            // control
            reg_wr_o     <= 1'b0;
            mem_rd_o     <= 1'b0;
            mem_wr_o     <= 1'b0;
            mem_width_o  <= 2'b0;
            mem_sign_o   <= 1'b0;
            jump_o       <= 1'b0;

        end else if (flush_i) begin
            // insert bubble — deassert all control signals
            pc_plus4_o   <= {XLEN{1'b0}};
            alu_result_o <= {XLEN{1'b0}};
            rs2_data_o   <= {XLEN{1'b0}};
            rd_addr_o    <= {REG_BITS{1'b0}};
            reg_wr_o     <= 1'b0;
            mem_rd_o     <= 1'b0;
            mem_wr_o     <= 1'b0;
            mem_width_o  <= 2'b0;
            mem_sign_o   <= 1'b0;
            jump_o       <= 1'b0;

        end else begin
            // normal operation — latch inputs
            pc_plus4_o   <= pc_plus4_i;
            alu_result_o <= alu_result_i;
            rs2_data_o   <= rs2_data_i;
            rd_addr_o    <= rd_addr_i;
            reg_wr_o     <= reg_wr_i;
            mem_rd_o     <= mem_rd_i;
            mem_wr_o     <= mem_wr_i;
            mem_width_o  <= mem_width_i;
            mem_sign_o   <= mem_sign_i;
            jump_o       <= jump_i;
        end
    end

endmodule