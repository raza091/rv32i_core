//=============================================================================
// File      : wb_stage.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Writeback stage — selects the correct data to write back to the
//   register file. Pure combinational logic — no registers.
//
//   Three possible writeback sources:
//     1. pc_plus4   — return address for JAL/JALR instructions
//     2. mem_rdata  — data loaded from memory (LB/LH/LW/LBU/LHU)
//     3. alu_result — result of ALU operation (R/I type instructions)
//
//   Priority:
//     jump takes highest priority (JAL/JALR need pc_plus4)
//     mem_rd next (load instructions need memory data)
//     alu_result is the default
//
//-----------------------------------------------------------------------------
// Port List:
//   pc_plus4_i   : PC+4 from MEM/WB register (JAL/JALR return address)
//   alu_result_i : ALU result from MEM/WB register
//   mem_rdata_i  : loaded memory data from MEM/WB register
//   rd_addr_i    : destination register address
//   reg_wr_i     : register write enable
//   mem_rd_i     : instruction was a load
//   jump_i       : instruction was JAL or JALR
//   rd_data_o    : selected writeback data to register file
//   rd_addr_o    : destination register address to register file
//   rd_wr_en_o   : write enable to register file
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module wb_stage #(
    parameter integer XLEN     = `XLEN,
    parameter integer REG_BITS = `REG_BITS
)(
    // inputs from MEM/WB register
    input  wire [XLEN-1:0]      pc_plus4_i,
    input  wire [XLEN-1:0]      alu_result_i,
    input  wire [XLEN-1:0]      mem_rdata_i,
    input  wire [REG_BITS-1:0]  rd_addr_i,
    input  wire                 reg_wr_i,
    input  wire                 mem_rd_i,
    input  wire                 jump_i,

    // outputs to register file
    output reg  [XLEN-1:0]      rd_data_o,
    output wire [REG_BITS-1:0]  rd_addr_o,
    output wire                 rd_wr_en_o
);

    //-------------------------------------------------------------------------
    // Writeback data mux
    // Priority: jump > load > alu
    //-------------------------------------------------------------------------
    always @(*) begin
        if (jump_i) begin
            // JAL/JALR — write return address PC+4 to rd
            rd_data_o = pc_plus4_i;
        end else if (mem_rd_i) begin
            // load instruction — write memory data to rd
            rd_data_o = mem_rdata_i;
        end else begin
            // R/I type — write ALU result to rd
            rd_data_o = alu_result_i;
        end
    end

    //-------------------------------------------------------------------------
    // Pass through address and write enable directly
    //-------------------------------------------------------------------------
    assign rd_addr_o   = rd_addr_i;
    assign rd_wr_en_o  = reg_wr_i;

endmodule