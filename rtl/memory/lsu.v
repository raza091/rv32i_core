//=============================================================================
// File      : lsu.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Load Store Unit for the MEM stage.
//   Handles all memory read and write operations.
//   Generates byte enable strobes for sub-word writes.
//   Sign or zero extends loaded data based on instruction type.
//   Pure combinational logic — no registers.
//
//-----------------------------------------------------------------------------
// Port List:
//   addr_i       : memory address from ALU result
//   wdata_i      : store data from rs2
//   mem_rd_i     : memory read enable
//   mem_wr_i     : memory write enable
//   mem_width_i  : access width — byte(00) half(01) word(10)
//   mem_sign_i   : 1=signed load, 0=unsigned load
//   dmem_rdata_i : raw data read from data memory
//   dmem_addr_o  : address to data memory
//   dmem_wdata_o : write data to data memory (byte replicated)
//   dmem_wr_en_o : byte write enable strobe [3:0]
//   dmem_rd_en_o : read enable to data memory
//   rdata_o      : sign/zero extended load result
//
//-----------------------------------------------------------------------------
// Byte enable encoding:
//   SB addr[1:0]=00 → 4'b0001
//   SB addr[1:0]=01 → 4'b0010
//   SB addr[1:0]=10 → 4'b0100
//   SB addr[1:0]=11 → 4'b1000
//   SH addr[1]=0    → 4'b0011
//   SH addr[1]=1    → 4'b1100
//   SW              → 4'b1111
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module lsu #(
    parameter integer XLEN = `XLEN
)(
    // address and data
    input  wire [XLEN-1:0]  addr_i,
    input  wire [XLEN-1:0]  wdata_i,

    // control
    input  wire             mem_rd_i,
    input  wire             mem_wr_i,
    input  wire [1:0]       mem_width_i,
    input  wire             mem_sign_i,

    // data memory interface
    input  wire [XLEN-1:0]  dmem_rdata_i,
    output wire [XLEN-1:0]  dmem_addr_o,
    output reg  [XLEN-1:0]  dmem_wdata_o,
    output reg  [3:0]       dmem_wr_en_o,
    output wire             dmem_rd_en_o,

    // load result
    output reg  [XLEN-1:0]  rdata_o
);

    //-------------------------------------------------------------------------
    // Pass address and read enable directly to memory
    //-------------------------------------------------------------------------
    assign dmem_addr_o  = addr_i;
    assign dmem_rd_en_o = mem_rd_i;

    //-------------------------------------------------------------------------
    // Write strobe and write data generation
    // Data is replicated across all byte lanes
    // Memory uses byte enables to select correct lane
    //-------------------------------------------------------------------------
    always @(*) begin
        dmem_wr_en_o = 4'b0000;
        dmem_wdata_o = {XLEN{1'b0}};

        if (mem_wr_i) begin
            case (mem_width_i)

                `MEM_BYTE: begin
                    // replicate byte across all lanes
                    dmem_wdata_o = {4{wdata_i[7:0]}};
                    case (addr_i[1:0])
                        2'b00: dmem_wr_en_o = 4'b0001;
                        2'b01: dmem_wr_en_o = 4'b0010;
                        2'b10: dmem_wr_en_o = 4'b0100;
                        2'b11: dmem_wr_en_o = 4'b1000;
                        default: dmem_wr_en_o = 4'b0000;
                    endcase
                end

                `MEM_HALF: begin
                    // replicate halfword across both lane pairs
                    dmem_wdata_o = {2{wdata_i[15:0]}};
                    case (addr_i[1])
                        1'b0: dmem_wr_en_o = 4'b0011;  // lower halfword
                        1'b1: dmem_wr_en_o = 4'b1100;  // upper halfword
                        default: dmem_wr_en_o = 4'b0000;
                    endcase
                end

                `MEM_WORD: begin
                    // full word write
                    dmem_wdata_o = wdata_i;
                    dmem_wr_en_o = 4'b1111;
                end

                default: begin
                    dmem_wdata_o = {XLEN{1'b0}};
                    dmem_wr_en_o = 4'b0000;
                end

            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Read data sign/zero extension
    // Select correct byte lane then extend to XLEN
    //-------------------------------------------------------------------------
    always @(*) begin
        rdata_o = {XLEN{1'b0}};

        if (mem_rd_i) begin
            case (mem_width_i)

                `MEM_BYTE: begin
                    // select byte lane based on address bits [1:0]
                    case (addr_i[1:0])
                        2'b00: begin
                            rdata_o = mem_sign_i ?
                                {{24{dmem_rdata_i[7]}},  dmem_rdata_i[7:0]}   :
                                {{24{1'b0}},             dmem_rdata_i[7:0]};
                        end
                        2'b01: begin
                            rdata_o = mem_sign_i ?
                                {{24{dmem_rdata_i[15]}}, dmem_rdata_i[15:8]}  :
                                {{24{1'b0}},             dmem_rdata_i[15:8]};
                        end
                        2'b10: begin
                            rdata_o = mem_sign_i ?
                                {{24{dmem_rdata_i[23]}}, dmem_rdata_i[23:16]} :
                                {{24{1'b0}},             dmem_rdata_i[23:16]};
                        end
                        2'b11: begin
                            rdata_o = mem_sign_i ?
                                {{24{dmem_rdata_i[31]}}, dmem_rdata_i[31:24]} :
                                {{24{1'b0}},             dmem_rdata_i[31:24]};
                        end
                        default: rdata_o = {XLEN{1'b0}};
                    endcase
                end

                `MEM_HALF: begin
                    // select halfword lane based on address bit [1]
                    case (addr_i[1])
                        1'b0: begin
                            rdata_o = mem_sign_i ?
                                {{16{dmem_rdata_i[15]}}, dmem_rdata_i[15:0]}  :
                                {{16{1'b0}},             dmem_rdata_i[15:0]};
                        end
                        1'b1: begin
                            rdata_o = mem_sign_i ?
                                {{16{dmem_rdata_i[31]}}, dmem_rdata_i[31:16]} :
                                {{16{1'b0}},             dmem_rdata_i[31:16]};
                        end
                        default: rdata_o = {XLEN{1'b0}};
                    endcase
                end

                `MEM_WORD: begin
                    // full word — pass through directly
                    rdata_o = dmem_rdata_i;
                end

                default: begin
                    rdata_o = {XLEN{1'b0}};
                end

            endcase
        end
    end

endmodule