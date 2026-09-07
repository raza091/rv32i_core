//=============================================================================
// File      : branch_unit.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Branch unit for the EX stage.
//   Evaluates branch conditions using ALU flags and computes branch/jump
//   target address. Produces branch_taken signal to flush the pipeline
//   and load the correct PC.
//
//-----------------------------------------------------------------------------
// Port List:
//   pc_i           : current PC (for JAL/branch target = PC + imm)
//   rs1_data_i     : rs1 value (for JALR target = rs1 + imm)
//   imm_i          : sign extended immediate (branch/jump offset)
//   funct3_i       : branch type from instruction [14:12]
//   zero_i         : ALU zero flag (result == 0)
//   negative_i     : ALU negative flag (result MSB)
//   overflow_i     : ALU signed overflow flag
//   branch_i       : instruction is a branch
//   jump_i         : instruction is JAL or JALR
//   pc_src_i       : 0=JALR (rs1+imm), 1=JAL/branch (PC+imm)
//   branch_taken_o : branch or jump is taken — flush pipeline
//   branch_target_o: computed target address
//
//-----------------------------------------------------------------------------
// Branch condition truth table:
//   BEQ  (000) : taken if zero
//   BNE  (001) : taken if !zero
//   BLT  (100) : taken if negative XOR overflow
//   BGE  (101) : taken if !(negative XOR overflow)
//   BLTU (110) : taken if !zero AND borrow (unsigned less than)
//   BGEU (111) : taken if zero OR !borrow (unsigned greater or equal)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module branch_unit #(
    parameter integer XLEN = `XLEN
)(
    // inputs
    input  wire [XLEN-1:0]  pc_i,
    input  wire [XLEN-1:0]  rs1_data_i,
    input  wire [XLEN-1:0]  imm_i,
    input  wire [2:0]       funct3_i,
    input  wire             zero_i,
    input  wire             negative_i,
    input  wire             overflow_i,
    input  wire             branch_i,
    input  wire             jump_i,
    input  wire             pc_src_i,

    // outputs
    output reg              branch_taken_o,
    output reg  [XLEN-1:0]  branch_target_o
);

    //-------------------------------------------------------------------------
    // Branch condition evaluation
    //-------------------------------------------------------------------------
    reg branch_condition;

    always @(*) begin
        case (funct3_i)
            `F3_BEQ:  branch_condition = zero_i;
            `F3_BNE:  branch_condition = ~zero_i;
            `F3_BLT:  branch_condition = negative_i ^ overflow_i;
            `F3_BGE:  branch_condition = ~(negative_i ^ overflow_i);
            `F3_BLTU: branch_condition = ~zero_i & negative_i;
            `F3_BGEU: branch_condition = zero_i | ~negative_i;
            default:  branch_condition = 1'b0;
        endcase
    end

    //-------------------------------------------------------------------------
    // Branch target address
    // JAL and branch : target = PC + imm
    // JALR           : target = rs1 + imm (LSB forced to 0 per RV32I spec)
    //-------------------------------------------------------------------------
    always @(*) begin
        if (pc_src_i) begin
            // JAL or branch — PC relative
            branch_target_o = pc_i + imm_i;
        end else begin
            // JALR — register relative, clear LSB
            branch_target_o = (rs1_data_i + imm_i) & {{XLEN-1{1'b1}}, 1'b0};
        end
    end

    //-------------------------------------------------------------------------
    // Branch taken decision
    // Jump     → always taken
    // Branch   → taken only if condition is true
    // Neither  → not taken
    //-------------------------------------------------------------------------
    always @(*) begin
        if (jump_i) begin
            branch_taken_o = 1'b1;
        end else if (branch_i) begin
            branch_taken_o = branch_condition;
        end else begin
            branch_taken_o = 1'b0;
        end
    end

endmodule