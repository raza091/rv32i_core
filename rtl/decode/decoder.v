//=============================================================================
// File      : decoder.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Instruction decoder for the ID stage.
//   Decodes the 32-bit RV32I instruction and generates all control signals
//   for the rest of the pipeline. Pure combinational logic — no registers.
//
//-----------------------------------------------------------------------------
// Port List:
//   instr_i      : 32-bit instruction from IF/ID register
//   alu_op_o     : ALU operation select
//   imm_sel_o    : immediate type select
//   reg_wr_o     : register file write enable
//   mem_rd_o     : memory read enable (load instructions)
//   mem_wr_o     : memory write enable (store instructions)
//   mem_width_o  : memory access width (byte/half/word)
//   mem_sign_o   : 1=signed load, 0=unsigned load
//   alu_src_o    : ALU second operand — 0=rs2, 1=immediate
//   branch_o     : instruction is a branch
//   jump_o       : instruction is JAL or JALR
//   pc_src_o     : jump base — 0=rs1+imm (JALR), 1=PC+imm (JAL)
//   rd_o         : destination register address
//   rs1_o        : source register 1 address
//   rs2_o        : source register 2 address
//   illegal_o    : illegal/unsupported instruction
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module decoder (
    // instruction input
    input  wire [31:0]  instr_i,

    // control outputs
    output reg  [3:0]   alu_op_o,
    output reg  [2:0]   imm_sel_o,
    output reg          reg_wr_o,
    output reg          mem_rd_o,
    output reg          mem_wr_o,
    output reg  [1:0]   mem_width_o,
    output reg          mem_sign_o,
    output reg          alu_src_o,
    output reg          branch_o,
    output reg          jump_o,
    output reg          pc_src_o,
    output wire [4:0]   rd_o,
    output wire [4:0]   rs1_o,
    output wire [4:0]   rs2_o,
    output reg          illegal_o
);

    //-------------------------------------------------------------------------
    // Instruction field extraction
    //-------------------------------------------------------------------------
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;

    assign opcode  = instr_i[6:0];
    assign rd_o    = instr_i[11:7];
    assign funct3  = instr_i[14:12];
    assign rs1_o   = instr_i[19:15];
    assign rs2_o   = instr_i[24:20];
    assign funct7  = instr_i[31:25];

    //-------------------------------------------------------------------------
    // Decode logic — combinational
    //-------------------------------------------------------------------------
    always @(*) begin
        // default values — safe NOP state
        alu_op_o    = `ALU_ADD;
        imm_sel_o   = `IMM_I;
        reg_wr_o    = 1'b0;
        mem_rd_o    = 1'b0;
        mem_wr_o    = 1'b0;
        mem_width_o = `MEM_WORD;
        mem_sign_o  = 1'b1;
        alu_src_o   = 1'b0;
        branch_o    = 1'b0;
        jump_o      = 1'b0;
        pc_src_o    = 1'b0;
        illegal_o   = 1'b0;

        case (opcode)

            //------------------------------------------------------------------
            // LUI — Load Upper Immediate
            // rd = imm[31:12] << 12
            //------------------------------------------------------------------
            `OPC_LUI: begin
                alu_op_o  = `ALU_PASS_B;  // pass immediate to output
                imm_sel_o = `IMM_U;
                reg_wr_o  = 1'b1;
                alu_src_o = 1'b1;          // use immediate
            end

            //------------------------------------------------------------------
            // AUIPC — Add Upper Immediate to PC
            // rd = PC + imm[31:12] << 12
            //------------------------------------------------------------------
            `OPC_AUIPC: begin
                alu_op_o  = `ALU_ADD;
                imm_sel_o = `IMM_U;
                reg_wr_o  = 1'b1;
                alu_src_o = 1'b1;
            end

            //------------------------------------------------------------------
            // JAL — Jump and Link
            // rd = PC+4, PC = PC + imm
            //------------------------------------------------------------------
            `OPC_JAL: begin
                alu_op_o  = `ALU_ADD;
                imm_sel_o = `IMM_J;
                reg_wr_o  = 1'b1;
                jump_o    = 1'b1;
                pc_src_o  = 1'b1;          // PC + imm
                alu_src_o = 1'b1;
            end

            //------------------------------------------------------------------
            // JALR — Jump and Link Register
            // rd = PC+4, PC = rs1 + imm
            //------------------------------------------------------------------
            `OPC_JALR: begin
                alu_op_o  = `ALU_ADD;
                imm_sel_o = `IMM_I;
                reg_wr_o  = 1'b1;
                jump_o    = 1'b1;
                pc_src_o  = 1'b0;          // rs1 + imm
                alu_src_o = 1'b1;
            end

            //------------------------------------------------------------------
            // BRANCH — BEQ BNE BLT BGE BLTU BGEU
            //------------------------------------------------------------------
            `OPC_BRANCH: begin
                imm_sel_o = `IMM_B;
                branch_o  = 1'b1;
                alu_src_o = 1'b0;          // compare rs1 and rs2
                case (funct3)
                    `F3_BEQ:  alu_op_o = `ALU_SUB;   // zero flag
                    `F3_BNE:  alu_op_o = `ALU_SUB;
                    `F3_BLT:  alu_op_o = `ALU_SLT;
                    `F3_BGE:  alu_op_o = `ALU_SLT;
                    `F3_BLTU: alu_op_o = `ALU_SLTU;
                    `F3_BGEU: alu_op_o = `ALU_SLTU;
                    default:  illegal_o = 1'b1;
                endcase
            end

            //------------------------------------------------------------------
            // LOAD — LB LH LW LBU LHU
            //------------------------------------------------------------------
            `OPC_LOAD: begin
                alu_op_o  = `ALU_ADD;      // address = rs1 + imm
                imm_sel_o = `IMM_I;
                reg_wr_o  = 1'b1;
                mem_rd_o  = 1'b1;
                alu_src_o = 1'b1;
                case (funct3)
                    `F3_LB:  begin mem_width_o = `MEM_BYTE; mem_sign_o = 1'b1; end
                    `F3_LH:  begin mem_width_o = `MEM_HALF; mem_sign_o = 1'b1; end
                    `F3_LW:  begin mem_width_o = `MEM_WORD; mem_sign_o = 1'b1; end
                    `F3_LBU: begin mem_width_o = `MEM_BYTE; mem_sign_o = 1'b0; end
                    `F3_LHU: begin mem_width_o = `MEM_HALF; mem_sign_o = 1'b0; end
                    default: illegal_o = 1'b1;
                endcase
            end

            //------------------------------------------------------------------
            // STORE — SB SH SW
            //------------------------------------------------------------------
            `OPC_STORE: begin
                alu_op_o  = `ALU_ADD;      // address = rs1 + imm
                imm_sel_o = `IMM_S;
                mem_wr_o  = 1'b1;
                alu_src_o = 1'b1;
                case (funct3)
                    `F3_SB:  mem_width_o = `MEM_BYTE;
                    `F3_SH:  mem_width_o = `MEM_HALF;
                    `F3_SW:  mem_width_o = `MEM_WORD;
                    default: illegal_o   = 1'b1;
                endcase
            end

            //------------------------------------------------------------------
            // OP-IMM — ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI
            //------------------------------------------------------------------
            `OPC_OP_IMM: begin
                imm_sel_o = `IMM_I;
                reg_wr_o  = 1'b1;
                alu_src_o = 1'b1;
                case (funct3)
                    `F3_ADD_SUB: alu_op_o = `ALU_ADD;
                    `F3_SLT:     alu_op_o = `ALU_SLT;
                    `F3_SLTU:    alu_op_o = `ALU_SLTU;
                    `F3_XOR:     alu_op_o = `ALU_XOR;
                    `F3_OR:      alu_op_o = `ALU_OR;
                    `F3_AND:     alu_op_o = `ALU_AND;
                    `F3_SLL:     alu_op_o = `ALU_SLL;
                    `F3_SRL_SRA: begin
                        if (funct7 == `F7_ALT)
                            alu_op_o = `ALU_SRA;
                        else
                            alu_op_o = `ALU_SRL;
                    end
                    default: illegal_o = 1'b1;
                endcase
            end

            //------------------------------------------------------------------
            // OP — ADD SUB SLL SLT SLTU XOR SRL SRA OR AND
            //------------------------------------------------------------------
            `OPC_OP: begin
                reg_wr_o  = 1'b1;
                alu_src_o = 1'b0;          // use rs2
                case (funct3)
                    `F3_ADD_SUB: begin
                        if (funct7 == `F7_ALT)
                            alu_op_o = `ALU_SUB;
                        else
                            alu_op_o = `ALU_ADD;
                    end
                    `F3_SLT:     alu_op_o = `ALU_SLT;
                    `F3_SLTU:    alu_op_o = `ALU_SLTU;
                    `F3_XOR:     alu_op_o = `ALU_XOR;
                    `F3_OR:      alu_op_o = `ALU_OR;
                    `F3_AND:     alu_op_o = `ALU_AND;
                    `F3_SLL:     alu_op_o = `ALU_SLL;
                    `F3_SRL_SRA: begin
                        if (funct7 == `F7_ALT)
                            alu_op_o = `ALU_SRA;
                        else
                            alu_op_o = `ALU_SRL;
                    end
                    default: illegal_o = 1'b1;
                endcase
            end

            //------------------------------------------------------------------
            // FENCE — treat as NOP
            //------------------------------------------------------------------
            `OPC_FENCE: begin
                // NOP — all defaults apply
            end

            //------------------------------------------------------------------
            // Illegal / unsupported instruction
            //------------------------------------------------------------------
            default: begin
                illegal_o = 1'b1;
            end

        endcase
    end

endmodule