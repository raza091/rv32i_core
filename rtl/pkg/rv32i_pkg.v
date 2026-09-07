//=============================================================================
// rv32i_pkg.v — Central parameter and define file for RV32I core
// All modules `include this file at the top
// Do NOT instantiate anything here — parameters and defines only
//=============================================================================

`ifndef RV32I_PKG_V
`define RV32I_PKG_V

//-----------------------------------------------------------------------------
// Core configuration
//-----------------------------------------------------------------------------

`define XLEN          32    // data width
`define ILEN          32    // instruction width
`define REG_BITS      5     // log2(32 registers)
`define NR_REGS       32    // number of registers

//-----------------------------------------------------------------------------
// ALU operation codes
//-----------------------------------------------------------------------------
`define ALU_ADD       4'h0
`define ALU_SUB       4'h1
`define ALU_AND       4'h2
`define ALU_OR        4'h3
`define ALU_XOR       4'h4
`define ALU_SLL       4'h5
`define ALU_SRL       4'h6
`define ALU_SRA       4'h7
`define ALU_SLT       4'h8
`define ALU_SLTU      4'h9
`define ALU_PASS_B    4'hA  // pass operand B (used for LUI)

//-----------------------------------------------------------------------------
// RV32I opcode definitions (bits [6:0] of instruction)
//-----------------------------------------------------------------------------
`define OPC_LUI       7'b0110111
`define OPC_AUIPC     7'b0010111
`define OPC_JAL       7'b1101111
`define OPC_JALR      7'b1100111
`define OPC_BRANCH    7'b1100011
`define OPC_LOAD      7'b0000011
`define OPC_STORE     7'b0100011
`define OPC_OP_IMM    7'b0010011
`define OPC_OP        7'b0110011
`define OPC_SYSTEM    7'b1110011
`define OPC_FENCE     7'b0001111

//-----------------------------------------------------------------------------
// funct3 codes — branch
//-----------------------------------------------------------------------------
`define F3_BEQ        3'b000
`define F3_BNE        3'b001
`define F3_BLT        3'b100
`define F3_BGE        3'b101
`define F3_BLTU       3'b110
`define F3_BGEU       3'b111

//-----------------------------------------------------------------------------
// funct3 codes — load
//-----------------------------------------------------------------------------
`define F3_LB         3'b000
`define F3_LH         3'b001
`define F3_LW         3'b010
`define F3_LBU        3'b100
`define F3_LHU        3'b101

//-----------------------------------------------------------------------------
// funct3 codes — store
//-----------------------------------------------------------------------------
`define F3_SB         3'b000
`define F3_SH         3'b001
`define F3_SW         3'b010

//-----------------------------------------------------------------------------
// funct3 codes — integer immediate and register
//-----------------------------------------------------------------------------
`define F3_ADD_SUB    3'b000
`define F3_SLL        3'b001
`define F3_SLT        3'b010
`define F3_SLTU       3'b011
`define F3_XOR        3'b100
`define F3_SRL_SRA    3'b101
`define F3_OR         3'b110
`define F3_AND        3'b111

//-----------------------------------------------------------------------------
// funct7 codes
//-----------------------------------------------------------------------------
`define F7_NORMAL     7'b0000000
`define F7_ALT        7'b0100000  // SUB, SRA

//-----------------------------------------------------------------------------
// Forwarding mux select
//-----------------------------------------------------------------------------
`define FWD_NONE      2'b00  // no forwarding — use register file output
`define FWD_MEM       2'b01  // forward from MEM/WB stage
`define FWD_WB        2'b10  // forward from WB stage

//-----------------------------------------------------------------------------
// PC select
//-----------------------------------------------------------------------------
`define PC_PLUS4      2'b00  // normal sequential execution
`define PC_BRANCH     2'b01  // taken branch
`define PC_JAL        2'b10  // JAL/JALR target
`define PC_TRAP       2'b11  // trap/exception (future use)

//-----------------------------------------------------------------------------
// Immediate type select
//-----------------------------------------------------------------------------
`define IMM_I         3'b000  // I-type: loads, arithmetic immediate, JALR
`define IMM_S         3'b001  // S-type: stores
`define IMM_B         3'b010  // B-type: branches
`define IMM_U         3'b011  // U-type: LUI, AUIPC
`define IMM_J         3'b100  // J-type: JAL

//-----------------------------------------------------------------------------
// Memory access width
//-----------------------------------------------------------------------------
`define MEM_BYTE      2'b00
`define MEM_HALF      2'b01
`define MEM_WORD      2'b10

`endif // RV32I_PKG_V
