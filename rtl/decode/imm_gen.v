//=============================================================================
// File      : imm_gen.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Immediate generator for the ID stage.
//   Extracts and sign-extends the immediate value from the instruction word
//   based on the RV32I instruction format selected by the decoder.
//
//   RV32I has 5 immediate formats:
//     I-type : loads, arithmetic immediate, JALR
//     S-type : stores
//     B-type : branches (scaled by 2 — LSB always 0)
//     U-type : LUI, AUIPC (upper 20 bits)
//     J-type : JAL (scaled by 2 — LSB always 0)
//
//-----------------------------------------------------------------------------
// Port List:
//   instr_i   : full 32-bit instruction word
//   imm_sel_i : immediate format select from decoder
//   imm_o     : sign-extended immediate output
//
//-----------------------------------------------------------------------------
// Parameters:
//   XLEN : data width (default 32)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module imm_gen #(
    parameter integer XLEN = `XLEN
)(
    input  wire [31:0]      instr_i,
    input  wire [2:0]       imm_sel_i,
    output reg  [XLEN-1:0]  imm_o
);

    always @(*) begin
        case (imm_sel_i)

            //------------------------------------------------------------------
            // I-type immediate
            // Used by: ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI
            //          LB, LH, LW, LBU, LHU, JALR
            // Bits: instr[31:20]
            // Sign bit: instr[31]
            //------------------------------------------------------------------
            `IMM_I: begin
                imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
            end

            //------------------------------------------------------------------
            // S-type immediate
            // Used by: SB, SH, SW
            // Bits: instr[31:25] | instr[11:7]
            // Sign bit: instr[31]
            //------------------------------------------------------------------
            `IMM_S: begin
                imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
            end

            //------------------------------------------------------------------
            // B-type immediate
            // Used by: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // Bits: instr[31] | instr[7] | instr[30:25] | instr[11:8] | 0
            // LSB is always 0 (instructions are 4-byte aligned)
            // Sign bit: instr[31]
            //------------------------------------------------------------------
            `IMM_B: begin
                imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7],
                          instr_i[30:25], instr_i[11:8], 1'b0};
            end

            //------------------------------------------------------------------
            // U-type immediate
            // Used by: LUI, AUIPC
            // Bits: instr[31:12] placed in upper 20 bits
            // Lower 12 bits are zero
            //------------------------------------------------------------------
            `IMM_U: begin
                imm_o = {instr_i[31:12], 12'b0};
            end

            //------------------------------------------------------------------
            // J-type immediate
            // Used by: JAL
            // Bits: instr[31] | instr[19:12] | instr[20] | instr[30:21] | 0
            // LSB is always 0 (instructions are 4-byte aligned)
            // Sign bit: instr[31]
            //------------------------------------------------------------------
            `IMM_J: begin
                imm_o = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12],
                          instr_i[20], instr_i[30:21], 1'b0};
            end

            //------------------------------------------------------------------
            // Default — zero immediate
            //------------------------------------------------------------------
            default: begin
                imm_o = {XLEN{1'b0}};
            end

        endcase
    end

endmodule