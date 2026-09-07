//=============================================================================
// File      : hazard_unit.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Hazard detection unit for the pipeline.
//   Detects two types of hazards and generates stall/flush signals:
//
//   1. Load-Use Hazard (data hazard):
//      Occurs when a load instruction is followed immediately by an
//      instruction that uses the loaded value. Forwarding cannot resolve
//      this because the memory data is not available until end of MEM stage.
//      Fix: stall IF and ID for one cycle, insert bubble in EX.
//
//   2. Control Hazard (branch/jump):
//      Occurs when a branch or jump is taken. Instructions fetched after
//      the branch are wrong and must be flushed.
//      Fix: flush IF/ID stage when branch_taken is asserted.
//
//-----------------------------------------------------------------------------
// Port List:
//   id_rs1_addr_i  : rs1 address of instruction currently in ID stage
//   id_rs2_addr_i  : rs2 address of instruction currently in ID stage
//   ex_rd_addr_i   : destination register of instruction in EX stage
//   ex_mem_rd_i    : instruction in EX stage is a load
//   branch_taken_i : branch or jump was taken (from branch unit in EX)
//   stall_o        : stall PC and IF/ID register (hold for one cycle)
//   flush_ex_o     : flush ID/EX register — insert NOP bubble in EX
//   flush_id_o     : flush IF/ID register — discard wrong-path instructions
//
//-----------------------------------------------------------------------------
// Load-Use Hazard condition:
//   ex_mem_rd  == 1           (EX stage instruction is a load)
//   ex_rd      != x0          (destination is not x0)
//   ex_rd      == id_rs1      (load destination matches rs1 in ID)
//   OR
//   ex_rd      == id_rs2      (load destination matches rs2 in ID)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module hazard_unit #(
    parameter integer REG_BITS = `REG_BITS
)(
    // ID stage source registers
    input  wire [REG_BITS-1:0]  id_rs1_addr_i,
    input  wire [REG_BITS-1:0]  id_rs2_addr_i,

    // EX stage destination register
    input  wire [REG_BITS-1:0]  ex_rd_addr_i,
    input  wire                 ex_mem_rd_i,

    // branch/jump control
    input  wire                 branch_taken_i,

    // hazard control outputs
    output wire                 stall_o,
    output wire                 flush_ex_o,
    output wire                 flush_id_o
);

    //-------------------------------------------------------------------------
    // Load-use hazard detection
    // EX stage is a load AND its destination matches rs1 or rs2 in ID
    // x0 is never a real destination — exclude it
    //-------------------------------------------------------------------------
    wire load_use_hazard;

    assign load_use_hazard = ex_mem_rd_i &&
                             (ex_rd_addr_i != {REG_BITS{1'b0}}) &&
                             ((ex_rd_addr_i == id_rs1_addr_i) ||
                              (ex_rd_addr_i == id_rs2_addr_i));

    //-------------------------------------------------------------------------
    // Stall — hold PC and IF/ID register for one cycle
    // Only needed for load-use hazard
    //-------------------------------------------------------------------------
    assign stall_o = load_use_hazard;

    //-------------------------------------------------------------------------
    // Flush EX stage — insert bubble into ID/EX register
    // Needed for load-use hazard (replace wrong instruction with NOP)
    //-------------------------------------------------------------------------
    assign flush_ex_o = load_use_hazard;

    //-------------------------------------------------------------------------
    // Flush ID stage — clear IF/ID register
    // Needed when branch or jump is taken
    // Wrong-path instructions fetched after branch must be discarded
    //-------------------------------------------------------------------------
    assign flush_id_o = branch_taken_i;

endmodule