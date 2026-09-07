//=============================================================================
// File      : regfile.v
// Project   : RV32I Pipelined Processor
// Author    : Ali Raza Tariq
// Date      : September 2026
//-----------------------------------------------------------------------------
// Description:
//   Register file for the ID stage.
//   32 general purpose registers x0-x31, each XLEN bits wide.
//   x0 is hardwired to zero — writes to x0 are ignored.
//   Two asynchronous read ports, one synchronous write port.
//   Read-after-write: if read and write address match in same cycle,
//   the NEW value is returned (forwarding within regfile).
//
//-----------------------------------------------------------------------------
// Port List:
//   clk_i       : system clock
//   rst_ni      : asynchronous active-low reset
//   rs1_addr_i  : read port 1 register address
//   rs2_addr_i  : read port 2 register address
//   rd_addr_i   : write port register address
//   rd_data_i   : write data
//   rd_wr_en_i  : write enable
//   rs1_data_o  : read port 1 data output
//   rs2_data_o  : read port 2 data output
//
//-----------------------------------------------------------------------------
// Parameters:
//   XLEN     : data width (default 32)
//   REG_BITS : register address width (default 5 for 32 registers)
//   NR_REGS  : number of registers (default 32)
//
//-----------------------------------------------------------------------------
// Dependencies:
//   rtl/pkg/rv32i_pkg.v
//=============================================================================

`timescale 1ns/1ps
`include "rv32i_pkg.v"

module regfile #(
    parameter integer XLEN     = `XLEN,
    parameter integer REG_BITS = `REG_BITS,
    parameter integer NR_REGS  = `NR_REGS
)(
    // clock and reset
    input  wire                  clk_i,
    input  wire                  rst_ni,

    // read port 1
    input  wire [REG_BITS-1:0]   rs1_addr_i,
    output wire [XLEN-1:0]       rs1_data_o,

    // read port 2
    input  wire [REG_BITS-1:0]   rs2_addr_i,
    output wire [XLEN-1:0]       rs2_data_o,

    // write port
    input  wire [REG_BITS-1:0]   rd_addr_i,
    input  wire [XLEN-1:0]       rd_data_i,
    input  wire                  rd_wr_en_i
);

    //-------------------------------------------------------------------------
    // Register array
    // regs[0] = x0 = always zero (enforced in read and write logic)
    //-------------------------------------------------------------------------
    integer i;
    reg [XLEN-1:0] regs [0:NR_REGS-1];

    //-------------------------------------------------------------------------
    // Write port — synchronous
    // x0 is hardwired to 0 — ignore writes to address 0
    //-------------------------------------------------------------------------
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (i = 0; i < NR_REGS; i = i + 1) begin
                regs[i] <= {XLEN{1'b0}};
            end
        end else begin
            if (rd_wr_en_i && (rd_addr_i != {REG_BITS{1'b0}})) begin
                regs[rd_addr_i] <= rd_data_i;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Read port 1 — asynchronous with write-through forwarding
    // If read and write address match in same cycle → return new value
    // x0 always returns 0
    //-------------------------------------------------------------------------
    assign rs1_data_o = (rs1_addr_i == {REG_BITS{1'b0}}) ? {XLEN{1'b0}} :
                        (rd_wr_en_i && (rd_addr_i == rs1_addr_i)) ? rd_data_i :
                        regs[rs1_addr_i];

    //-------------------------------------------------------------------------
    // Read port 2 — asynchronous with write-through forwarding
    // If read and write address match in same cycle → return new value
    // x0 always returns 0
    //-------------------------------------------------------------------------
    assign rs2_data_o = (rs2_addr_i == {REG_BITS{1'b0}}) ? {XLEN{1'b0}} :
                        (rd_wr_en_i && (rd_addr_i == rs2_addr_i)) ? rd_data_i :
                        regs[rs2_addr_i];

endmodule