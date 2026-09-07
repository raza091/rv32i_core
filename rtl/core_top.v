//=============================================================================
// File      : core_top.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Top-level integration of the RV32I 5-stage pipelined processor.
//   Instantiates and connects all pipeline stages and control units.
//
//   Pipeline stages:
//     IF  — Instruction Fetch  (fetch_unit, if_id_reg)
//     ID  — Instruction Decode (decoder, regfile, imm_gen, id_ex_reg)
//     EX  — Execute            (alu, branch_unit, forwarding_unit, ex_mem_reg)
//     MEM — Memory Access      (lsu, mem_wb_reg)
//     WB  — Write Back         (wb_stage)
//
//   Control units:
//     hazard_unit     — load-use stall and control hazard flush
//     forwarding_unit — data hazard bypass
//
//-----------------------------------------------------------------------------
// External Memory Interface:
//   Instruction memory : single read port, word addressed
//   Data memory        : separate read/write ports with byte enables
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v and all stage modules
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module core_top #(
    parameter integer XLEN         = `XLEN,
    parameter integer REG_BITS     = `REG_BITS,
    parameter integer NR_REGS      = `NR_REGS,
    parameter integer RESET_VECTOR = 32'h0000_0000
)(
    input  wire             clk_i,
    input  wire             rst_ni,

    // instruction memory interface
    input  wire [XLEN-1:0]  imem_rdata_i,
    output wire [XLEN-1:0]  imem_addr_o,

    // data memory interface
    input  wire [XLEN-1:0]  dmem_rdata_i,
    output wire [XLEN-1:0]  dmem_addr_o,
    output wire [XLEN-1:0]  dmem_wdata_o,
    output wire [3:0]       dmem_wr_en_o,
    output wire             dmem_rd_en_o
);

    //=========================================================================
    // Wire declarations — grouped by pipeline stage
    //=========================================================================

    //-------------------------------------------------------------------------
    // IF stage wires
    //-------------------------------------------------------------------------
    wire [XLEN-1:0]     if_pc;
    wire [XLEN-1:0]     if_pc_plus4;

    //-------------------------------------------------------------------------
    // IF/ID register outputs
    //-------------------------------------------------------------------------
    wire [XLEN-1:0]     id_pc;
    wire [XLEN-1:0]     id_pc_plus4;
    wire [XLEN-1:0]     id_instr;

    //-------------------------------------------------------------------------
    // ID stage wires — decoder outputs
    //-------------------------------------------------------------------------
    wire [3:0]          id_alu_op;
    wire [2:0]          id_imm_sel;
    wire                id_reg_wr;
    wire                id_mem_rd;
    wire                id_mem_wr;
    wire [1:0]          id_mem_width;
    wire                id_mem_sign;
    wire                id_alu_src;
    wire                id_branch;
    wire                id_jump;
    wire                id_pc_src;
    wire [REG_BITS-1:0] id_rd_addr;
    wire [REG_BITS-1:0] id_rs1_addr;
    wire [REG_BITS-1:0] id_rs2_addr;
    wire                id_illegal;

    // register file outputs
    wire [XLEN-1:0]     id_rs1_data;
    wire [XLEN-1:0]     id_rs2_data;

    // immediate generator output
    wire [XLEN-1:0]     id_imm;

    //-------------------------------------------------------------------------
    // ID/EX register outputs
    //-------------------------------------------------------------------------
    wire [XLEN-1:0]     ex_pc;
    wire [XLEN-1:0]     ex_pc_plus4;
    wire [XLEN-1:0]     ex_rs1_data;
    wire [XLEN-1:0]     ex_rs2_data;
    wire [XLEN-1:0]     ex_imm;
    wire [REG_BITS-1:0] ex_rs1_addr;
    wire [REG_BITS-1:0] ex_rs2_addr;
    wire [REG_BITS-1:0] ex_rd_addr;
    wire [3:0]          ex_alu_op;
    wire                ex_alu_src;
    wire                ex_reg_wr;
    wire                ex_mem_rd;
    wire                ex_mem_wr;
    wire [1:0]          ex_mem_width;
    wire                ex_mem_sign;
    wire                ex_branch;
    wire                ex_jump;
    wire                ex_pc_src;

    //-------------------------------------------------------------------------
    // EX stage wires
    //-------------------------------------------------------------------------
    wire [1:0]          fwd_a;
    wire [1:0]          fwd_b;
    wire [XLEN-1:0]     ex_operand_a;
    wire [XLEN-1:0]     ex_operand_b;
    wire [XLEN-1:0]     ex_alu_result;
    wire                ex_zero;
    wire                ex_negative;
    wire                ex_overflow;
    wire                ex_branch_taken;
    wire [XLEN-1:0]     ex_branch_target;
    wire [XLEN-1:0]     ex_alu_operand_b;

    //-------------------------------------------------------------------------
    // EX/MEM register outputs
    //-------------------------------------------------------------------------
    wire [XLEN-1:0]     mem_pc_plus4;
    wire [XLEN-1:0]     mem_alu_result;
    wire [XLEN-1:0]     mem_rs2_data;
    wire [REG_BITS-1:0] mem_rd_addr;
    wire                mem_reg_wr;
    wire                mem_mem_rd;
    wire                mem_mem_wr;
    wire [1:0]          mem_mem_width;
    wire                mem_mem_sign;
    wire                mem_jump;

    //-------------------------------------------------------------------------
    // MEM stage wires
    //-------------------------------------------------------------------------
    wire [XLEN-1:0]     mem_rdata;

    //-------------------------------------------------------------------------
    // MEM/WB register outputs
    //-------------------------------------------------------------------------
    wire [XLEN-1:0]     wb_pc_plus4;
    wire [XLEN-1:0]     wb_alu_result;
    wire [XLEN-1:0]     wb_mem_rdata;
    wire [REG_BITS-1:0] wb_rd_addr;
    wire                wb_reg_wr;
    wire                wb_mem_rd;
    wire                wb_jump;

    //-------------------------------------------------------------------------
    // WB stage wires
    //-------------------------------------------------------------------------
    wire [XLEN-1:0]     wb_rd_data;
    wire [REG_BITS-1:0] wb_rd_addr_out;
    wire                wb_wr_en;

    //-------------------------------------------------------------------------
    // Hazard unit wires
    //-------------------------------------------------------------------------
    wire                stall;
    wire                flush_ex;
    wire                flush_id;

    //=========================================================================
    // Forwarding muxes for ALU operands
    // Select between register file, EX/MEM forward, MEM/WB forward
    //=========================================================================
    assign ex_operand_a = (fwd_a == `FWD_MEM) ? mem_alu_result :
                          (fwd_a == `FWD_WB)  ? wb_rd_data     :
                                                 ex_rs1_data;

    assign ex_operand_b = (fwd_b == `FWD_MEM) ? mem_alu_result :
                          (fwd_b == `FWD_WB)  ? wb_rd_data     :
                                                 ex_rs2_data;

    // ALU second operand mux — register or immediate
    assign ex_alu_operand_b = ex_alu_src ? ex_imm : ex_operand_b;

    //=========================================================================
    // IF stage
    //=========================================================================
    fetch_unit #(
        .XLEN         (XLEN),
        .RESET_VECTOR (RESET_VECTOR)
    ) u_fetch_unit (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .stall_i        (stall),
        .flush_i        (flush_id),
        .branch_taken_i (ex_branch_taken),
        .branch_target_i(ex_branch_target),
        .pc_o           (if_pc),
        .pc_plus4_o     (if_pc_plus4)
    );

    // instruction memory address
    assign imem_addr_o = if_pc;

    //=========================================================================
    // IF/ID pipeline register
    //=========================================================================
    if_id_reg #(
        .XLEN (XLEN),
        .ILEN (XLEN)
    ) u_if_id_reg (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .stall_i    (stall),
        .flush_i    (flush_id),
        .pc_i       (if_pc),
        .pc_plus4_i (if_pc_plus4),
        .instr_i    (imem_rdata_i),
        .pc_o       (id_pc),
        .pc_plus4_o (id_pc_plus4),
        .instr_o    (id_instr)
    );

    //=========================================================================
    // ID stage — decoder
    //=========================================================================
    decoder u_decoder (
        .instr_i      (id_instr),
        .alu_op_o     (id_alu_op),
        .imm_sel_o    (id_imm_sel),
        .reg_wr_o     (id_reg_wr),
        .mem_rd_o     (id_mem_rd),
        .mem_wr_o     (id_mem_wr),
        .mem_width_o  (id_mem_width),
        .mem_sign_o   (id_mem_sign),
        .alu_src_o    (id_alu_src),
        .branch_o     (id_branch),
        .jump_o       (id_jump),
        .pc_src_o     (id_pc_src),
        .rd_o         (id_rd_addr),
        .rs1_o        (id_rs1_addr),
        .rs2_o        (id_rs2_addr),
        .illegal_o    (id_illegal)
    );

    //=========================================================================
    // ID stage — register file
    //=========================================================================
    regfile #(
        .XLEN     (XLEN),
        .REG_BITS (REG_BITS),
        .NR_REGS  (NR_REGS)
    ) u_regfile (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .rs1_addr_i (id_rs1_addr),
        .rs2_addr_i (id_rs2_addr),
        .rd_addr_i  (wb_rd_addr_out),
        .rd_data_i  (wb_rd_data),
        .rd_wr_en_i (wb_wr_en),
        .rs1_data_o (id_rs1_data),
        .rs2_data_o (id_rs2_data)
    );

    //=========================================================================
    // ID stage — immediate generator
    //=========================================================================
    imm_gen #(
        .XLEN (XLEN)
    ) u_imm_gen (
        .instr_i   (id_instr),
        .imm_sel_i (id_imm_sel),
        .imm_o     (id_imm)
    );

    //=========================================================================
    // ID/EX pipeline register
    //=========================================================================
    id_ex_reg #(
        .XLEN     (XLEN),
        .REG_BITS (REG_BITS)
    ) u_id_ex_reg (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .stall_i     (stall),
        .flush_i     (flush_ex),
        .pc_i        (id_pc),
        .pc_plus4_i  (id_pc_plus4),
        .rs1_data_i  (id_rs1_data),
        .rs2_data_i  (id_rs2_data),
        .imm_i       (id_imm),
        .rs1_addr_i  (id_rs1_addr),
        .rs2_addr_i  (id_rs2_addr),
        .rd_addr_i   (id_rd_addr),
        .alu_op_i    (id_alu_op),
        .alu_src_i   (id_alu_src),
        .reg_wr_i    (id_reg_wr),
        .mem_rd_i    (id_mem_rd),
        .mem_wr_i    (id_mem_wr),
        .mem_width_i (id_mem_width),
        .mem_sign_i  (id_mem_sign),
        .branch_i    (id_branch),
        .jump_i      (id_jump),
        .pc_src_i    (id_pc_src),
        .pc_o        (ex_pc),
        .pc_plus4_o  (ex_pc_plus4),
        .rs1_data_o  (ex_rs1_data),
        .rs2_data_o  (ex_rs2_data),
        .imm_o       (ex_imm),
        .rs1_addr_o  (ex_rs1_addr),
        .rs2_addr_o  (ex_rs2_addr),
        .rd_addr_o   (ex_rd_addr),
        .alu_op_o    (ex_alu_op),
        .alu_src_o   (ex_alu_src),
        .reg_wr_o    (ex_reg_wr),
        .mem_rd_o    (ex_mem_rd),
        .mem_wr_o    (ex_mem_wr),
        .mem_width_o (ex_mem_width),
        .mem_sign_o  (ex_mem_sign),
        .branch_o    (ex_branch),
        .jump_o      (ex_jump),
        .pc_src_o    (ex_pc_src)
    );

    //=========================================================================
    // EX stage — forwarding unit
    //=========================================================================
    forwarding_unit #(
        .REG_BITS (REG_BITS)
    ) u_forwarding_unit (
        .rs1_addr_i  (ex_rs1_addr),
        .rs2_addr_i  (ex_rs2_addr),
        .ex_mem_rd_i (mem_rd_addr),
        .ex_mem_wr_i (mem_reg_wr),
        .mem_wb_rd_i (wb_rd_addr),
        .mem_wb_wr_i (wb_reg_wr),
        .fwd_a_o     (fwd_a),
        .fwd_b_o     (fwd_b)
    );

    //=========================================================================
    // EX stage — ALU
    //=========================================================================
    alu #(
        .XLEN (XLEN)
    ) u_alu (
        .operand_a_i (ex_operand_a),
        .operand_b_i (ex_alu_operand_b),
        .alu_op_i    (ex_alu_op),
        .result_o    (ex_alu_result),
        .zero_o      (ex_zero),
        .negative_o  (ex_negative),
        .overflow_o  (ex_overflow)
    );

    //=========================================================================
    // EX stage — branch unit
    //=========================================================================
    branch_unit #(
        .XLEN (XLEN)
    ) u_branch_unit (
        .pc_i           (ex_pc),
        .rs1_data_i     (ex_operand_a),
        .imm_i          (ex_imm),
        .funct3_i       (id_instr[14:12]),
        .zero_i         (ex_zero),
        .negative_i     (ex_negative),
        .overflow_i     (ex_overflow),
        .branch_i       (ex_branch),
        .jump_i         (ex_jump),
        .pc_src_i       (ex_pc_src),
        .branch_taken_o (ex_branch_taken),
        .branch_target_o(ex_branch_target)
    );

    //=========================================================================
    // EX/MEM pipeline register
    //=========================================================================
    ex_mem_reg #(
        .XLEN     (XLEN),
        .REG_BITS (REG_BITS)
    ) u_ex_mem_reg (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .flush_i     (1'b0),
        .pc_plus4_i  (ex_pc_plus4),
        .alu_result_i(ex_alu_result),
        .rs2_data_i  (ex_operand_b),
        .rd_addr_i   (ex_rd_addr),
        .reg_wr_i    (ex_reg_wr),
        .mem_rd_i    (ex_mem_rd),
        .mem_wr_i    (ex_mem_wr),
        .mem_width_i (ex_mem_width),
        .mem_sign_i  (ex_mem_sign),
        .jump_i      (ex_jump),
        .pc_plus4_o  (mem_pc_plus4),
        .alu_result_o(mem_alu_result),
        .rs2_data_o  (mem_rs2_data),
        .rd_addr_o   (mem_rd_addr),
        .reg_wr_o    (mem_reg_wr),
        .mem_rd_o    (mem_mem_rd),
        .mem_wr_o    (mem_mem_wr),
        .mem_width_o (mem_mem_width),
        .mem_sign_o  (mem_mem_sign),
        .jump_o      (mem_jump)
    );

    //=========================================================================
    // MEM stage — LSU
    //=========================================================================
    lsu #(
        .XLEN (XLEN)
    ) u_lsu (
        .addr_i      (mem_alu_result),
        .wdata_i     (mem_rs2_data),
        .mem_rd_i    (mem_mem_rd),
        .mem_wr_i    (mem_mem_wr),
        .mem_width_i (mem_mem_width),
        .mem_sign_i  (mem_mem_sign),
        .dmem_rdata_i(dmem_rdata_i),
        .dmem_addr_o (dmem_addr_o),
        .dmem_wdata_o(dmem_wdata_o),
        .dmem_wr_en_o(dmem_wr_en_o),
        .dmem_rd_en_o(dmem_rd_en_o),
        .rdata_o     (mem_rdata)
    );

    //=========================================================================
    // MEM/WB pipeline register
    //=========================================================================
    mem_wb_reg #(
        .XLEN     (XLEN),
        .REG_BITS (REG_BITS)
    ) u_mem_wb_reg (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .pc_plus4_i  (mem_pc_plus4),
        .alu_result_i(mem_alu_result),
        .mem_rdata_i (mem_rdata),
        .rd_addr_i   (mem_rd_addr),
        .reg_wr_i    (mem_reg_wr),
        .mem_rd_i    (mem_mem_rd),
        .jump_i      (mem_jump),
        .pc_plus4_o  (wb_pc_plus4),
        .alu_result_o(wb_alu_result),
        .mem_rdata_o (wb_mem_rdata),
        .rd_addr_o   (wb_rd_addr),
        .reg_wr_o    (wb_reg_wr),
        .mem_rd_o    (wb_mem_rd),
        .jump_o      (wb_jump)
    );

    //=========================================================================
    // WB stage
    //=========================================================================
    wb_stage #(
        .XLEN     (XLEN),
        .REG_BITS (REG_BITS)
    ) u_wb_stage (
        .pc_plus4_i  (wb_pc_plus4),
        .alu_result_i(wb_alu_result),
        .mem_rdata_i (wb_mem_rdata),
        .rd_addr_i   (wb_rd_addr),
        .reg_wr_i    (wb_reg_wr),
        .mem_rd_i    (wb_mem_rd),
        .jump_i      (wb_jump),
        .rd_data_o   (wb_rd_data),
        .rd_addr_o   (wb_rd_addr_out),
        .rd_wr_en_o  (wb_wr_en)
    );

    //=========================================================================
    // Hazard detection unit
    //=========================================================================
    hazard_unit #(
        .REG_BITS (REG_BITS)
    ) u_hazard_unit (
        .id_rs1_addr_i  (id_rs1_addr),
        .id_rs2_addr_i  (id_rs2_addr),
        .ex_rd_addr_i   (ex_rd_addr),
        .ex_mem_rd_i    (ex_mem_rd),
        .branch_taken_i (ex_branch_taken),
        .stall_o        (stall),
        .flush_ex_o     (flush_ex),
        .flush_id_o     (flush_id)
    );

endmodule