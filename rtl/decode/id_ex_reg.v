//=============================================================================
// File      : id_ex_reg.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   ID/EX pipeline register — sits between Decode and Execute stages.
//   Latches all data and control signals produced by the decode stage.
//   Supports stall (hold) and flush (insert bubble/NOP).
//
//-----------------------------------------------------------------------------
// Port List:
//   clk_i        : system clock
//   rst_ni       : asynchronous active-low reset
//   stall_i      : hold all register contents
//   flush_i      : clear all registers — insert bubble
//
//   — Data inputs from decode stage:
//   pc_i         : current PC
//   pc_plus4_i   : PC+4 (return address for JAL/JALR)
//   rs1_data_i   : register file read port 1 data
//   rs2_data_i   : register file read port 2 data
//   imm_i        : sign extended immediate
//   rs1_addr_i   : rs1 register address (for forwarding)
//   rs2_addr_i   : rs2 register address (for forwarding)
//   rd_addr_i    : destination register address
//
//   — Control inputs from decoder:
//   alu_op_i     : ALU operation
//   alu_src_i    : ALU source select
//   reg_wr_i     : register write enable
//   mem_rd_i     : memory read enable
//   mem_wr_i     : memory write enable
//   mem_width_i  : memory access width
//   mem_sign_i   : signed/unsigned load
//   branch_i     : branch instruction
//   jump_i       : jump instruction
//   pc_src_i     : PC source select
//
//   — All outputs same signals with _o suffix
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module id_ex_reg #(
    parameter integer XLEN     = `XLEN,
    parameter integer REG_BITS = `REG_BITS
)(
    // clock and reset
    input  wire                  clk_i,
    input  wire                  rst_ni,

    // pipeline control
    input  wire                  stall_i,
    input  wire                  flush_i,

    // data inputs
    input  wire [XLEN-1:0]       pc_i,
    input  wire [XLEN-1:0]       pc_plus4_i,
    input  wire [XLEN-1:0]       rs1_data_i,
    input  wire [XLEN-1:0]       rs2_data_i,
    input  wire [XLEN-1:0]       imm_i,
    input  wire [REG_BITS-1:0]   rs1_addr_i,
    input  wire [REG_BITS-1:0]   rs2_addr_i,
    input  wire [REG_BITS-1:0]   rd_addr_i,

    // control inputs
    input  wire [3:0]            alu_op_i,
    input  wire                  alu_src_i,
    input  wire                  reg_wr_i,
    input  wire                  mem_rd_i,
    input  wire                  mem_wr_i,
    input  wire [1:0]            mem_width_i,
    input  wire                  mem_sign_i,
    input  wire                  branch_i,
    input  wire                  jump_i,
    input  wire                  pc_src_i,

    // data outputs
    output reg  [XLEN-1:0]       pc_o,
    output reg  [XLEN-1:0]       pc_plus4_o,
    output reg  [XLEN-1:0]       rs1_data_o,
    output reg  [XLEN-1:0]       rs2_data_o,
    output reg  [XLEN-1:0]       imm_o,
    output reg  [REG_BITS-1:0]   rs1_addr_o,
    output reg  [REG_BITS-1:0]   rs2_addr_o,
    output reg  [REG_BITS-1:0]   rd_addr_o,

    // control outputs
    output reg  [3:0]            alu_op_o,
    output reg                   alu_src_o,
    output reg                   reg_wr_o,
    output reg                   mem_rd_o,
    output reg                   mem_wr_o,
    output reg  [1:0]            mem_width_o,
    output reg                   mem_sign_o,
    output reg                   branch_o,
    output reg                   jump_o,
    output reg                   pc_src_o
);

    //-------------------------------------------------------------------------
    // Pipeline register
    // Priority: reset > flush > stall > normal
    //-------------------------------------------------------------------------
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            // data
            pc_o        <= {XLEN{1'b0}};
            pc_plus4_o  <= {XLEN{1'b0}};
            rs1_data_o  <= {XLEN{1'b0}};
            rs2_data_o  <= {XLEN{1'b0}};
            imm_o       <= {XLEN{1'b0}};
            rs1_addr_o  <= {REG_BITS{1'b0}};
            rs2_addr_o  <= {REG_BITS{1'b0}};
            rd_addr_o   <= {REG_BITS{1'b0}};
            // control
            alu_op_o    <= 4'b0;
            alu_src_o   <= 1'b0;
            reg_wr_o    <= 1'b0;
            mem_rd_o    <= 1'b0;
            mem_wr_o    <= 1'b0;
            mem_width_o <= 2'b0;
            mem_sign_o  <= 1'b0;
            branch_o    <= 1'b0;
            jump_o      <= 1'b0;
            pc_src_o    <= 1'b0;

        end else if (flush_i) begin
            // insert bubble — clear all control signals
            // data can hold or clear — clear is safer
            pc_o        <= {XLEN{1'b0}};
            pc_plus4_o  <= {XLEN{1'b0}};
            rs1_data_o  <= {XLEN{1'b0}};
            rs2_data_o  <= {XLEN{1'b0}};
            imm_o       <= {XLEN{1'b0}};
            rs1_addr_o  <= {REG_BITS{1'b0}};
            rs2_addr_o  <= {REG_BITS{1'b0}};
            rd_addr_o   <= {REG_BITS{1'b0}};
            // control — all deasserted = NOP
            alu_op_o    <= 4'b0;
            alu_src_o   <= 1'b0;
            reg_wr_o    <= 1'b0;
            mem_rd_o    <= 1'b0;
            mem_wr_o    <= 1'b0;
            mem_width_o <= 2'b0;
            mem_sign_o  <= 1'b0;
            branch_o    <= 1'b0;
            jump_o      <= 1'b0;
            pc_src_o    <= 1'b0;

        end else if (stall_i) begin
            // hold all outputs — do not update
            pc_o        <= pc_o;
            pc_plus4_o  <= pc_plus4_o;
            rs1_data_o  <= rs1_data_o;
            rs2_data_o  <= rs2_data_o;
            imm_o       <= imm_o;
            rs1_addr_o  <= rs1_addr_o;
            rs2_addr_o  <= rs2_addr_o;
            rd_addr_o   <= rd_addr_o;
            alu_op_o    <= alu_op_o;
            alu_src_o   <= alu_src_o;
            reg_wr_o    <= reg_wr_o;
            mem_rd_o    <= mem_rd_o;
            mem_wr_o    <= mem_wr_o;
            mem_width_o <= mem_width_o;
            mem_sign_o  <= mem_sign_o;
            branch_o    <= branch_o;
            jump_o      <= jump_o;
            pc_src_o    <= pc_src_o;

        end else begin
            // normal operation — latch inputs
            pc_o        <= pc_i;
            pc_plus4_o  <= pc_plus4_i;
            rs1_data_o  <= rs1_data_i;
            rs2_data_o  <= rs2_data_i;
            imm_o       <= imm_i;
            rs1_addr_o  <= rs1_addr_i;
            rs2_addr_o  <= rs2_addr_i;
            rd_addr_o   <= rd_addr_i;
            alu_op_o    <= alu_op_i;
            alu_src_o   <= alu_src_i;
            reg_wr_o    <= reg_wr_i;
            mem_rd_o    <= mem_rd_i;
            mem_wr_o    <= mem_wr_i;
            mem_width_o <= mem_width_i;
            mem_sign_o  <= mem_sign_i;
            branch_o    <= branch_i;
            jump_o      <= jump_i;
            pc_src_o    <= pc_src_i;
        end
    end

endmodule