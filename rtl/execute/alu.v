//=============================================================================
// File      : alu.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Arithmetic Logic Unit for the EX stage.
//   Performs all RV32I integer operations.
//   Pure combinational logic — no registers.
//   Produces result and status flags used by branch unit.
//
//-----------------------------------------------------------------------------
// Port List:
//   operand_a_i  : first operand (rs1 or PC for AUIPC/JAL)
//   operand_b_i  : second operand (rs2 or immediate)
//   alu_op_i     : operation select from decoder
//   result_o     : ALU result
//   zero_o       : result is zero (used by BEQ/BNE)
//   negative_o   : result MSB is 1 (used by BLT/BGE)
//   overflow_o   : signed overflow occurred
//
//-----------------------------------------------------------------------------
// Parameters:
//   XLEN : data width (default 32)
//
//-----------------------------------------------------------------------------
// Supported operations:
//   ALU_ADD   : result = a + b
//   ALU_SUB   : result = a - b
//   ALU_AND   : result = a & b
//   ALU_OR    : result = a | b
//   ALU_XOR   : result = a ^ b
//   ALU_SLL   : result = a << b[4:0]
//   ALU_SRL   : result = a >> b[4:0]        (logical)
//   ALU_SRA   : result = a >>> b[4:0]       (arithmetic)
//   ALU_SLT   : result = (signed a < signed b) ? 1 : 0
//   ALU_SLTU  : result = (a < b) ? 1 : 0   (unsigned)
//   ALU_PASS_B: result = b                  (for LUI)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module alu #(
    parameter integer XLEN = `XLEN
)(
    input  wire [XLEN-1:0]  operand_a_i,
    input  wire [XLEN-1:0]  operand_b_i,
    input  wire [3:0]       alu_op_i,

    output reg  [XLEN-1:0]  result_o,
    output wire             zero_o,
    output wire             negative_o,
    output wire             overflow_o
);

    //-------------------------------------------------------------------------
    // Internal signals for overflow detection
    //-------------------------------------------------------------------------
    wire [XLEN-1:0] add_result;
    wire [XLEN-1:0] sub_result;

    assign add_result = operand_a_i + operand_b_i;
    assign sub_result = operand_a_i - operand_b_i;

    //-------------------------------------------------------------------------
    // ALU operations — combinational
    //-------------------------------------------------------------------------
    always @(*) begin
        case (alu_op_i)

            `ALU_ADD: begin
                result_o = add_result;
            end

            `ALU_SUB: begin
                result_o = sub_result;
            end

            `ALU_AND: begin
                result_o = operand_a_i & operand_b_i;
            end

            `ALU_OR: begin
                result_o = operand_a_i | operand_b_i;
            end

            `ALU_XOR: begin
                result_o = operand_a_i ^ operand_b_i;
            end

            `ALU_SLL: begin
                // shift amount is lower 5 bits of operand_b
                result_o = operand_a_i << operand_b_i[4:0];
            end

            `ALU_SRL: begin
                // logical right shift — fills with 0
                result_o = operand_a_i >> operand_b_i[4:0];
            end

            `ALU_SRA: begin
                // arithmetic right shift — fills with sign bit
                result_o = $signed(operand_a_i) >>> operand_b_i[4:0];
            end

            `ALU_SLT: begin
                // signed comparison
                result_o = ($signed(operand_a_i) < $signed(operand_b_i))
                           ? {{XLEN-1{1'b0}}, 1'b1}
                           : {XLEN{1'b0}};
            end

            `ALU_SLTU: begin
                // unsigned comparison
                result_o = (operand_a_i < operand_b_i)
                           ? {{XLEN-1{1'b0}}, 1'b1}
                           : {XLEN{1'b0}};
            end

            `ALU_PASS_B: begin
                // pass operand B directly — used for LUI
                result_o = operand_b_i;
            end

            default: begin
                result_o = {XLEN{1'b0}};
            end

        endcase
    end

    //-------------------------------------------------------------------------
    // Status flags
    //-------------------------------------------------------------------------

    // zero flag — used by BEQ (branch if zero) and BNE (branch if not zero)
    assign zero_o     = (result_o == {XLEN{1'b0}});

    // negative flag — MSB of result (used by BLT/BGE)
    assign negative_o = result_o[XLEN-1];

    // signed overflow detection for ADD and SUB
    // ADD overflow: both operands same sign, result different sign
    // SUB overflow: operands different sign, result sign differs from a
    assign overflow_o = ((alu_op_i == `ALU_ADD) &&
                         (operand_a_i[XLEN-1] == operand_b_i[XLEN-1]) &&
                         (result_o[XLEN-1]    != operand_a_i[XLEN-1]))
                        ||
                        ((alu_op_i == `ALU_SUB) &&
                         (operand_a_i[XLEN-1] != operand_b_i[XLEN-1]) &&
                         (result_o[XLEN-1]    != operand_a_i[XLEN-1]));

endmodule