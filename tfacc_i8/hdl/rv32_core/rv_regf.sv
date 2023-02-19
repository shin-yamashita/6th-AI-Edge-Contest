//
// rv_regf.sv
//
// register file
// 32 bit x Nregs register
// 2 read port, 1 write
//
// 2019/11
//

`timescale 1ns/1ns
`include "logic_types.svh"

module rv_regf 
  # (parameter Nregs = 16)
  (
  input  logic clk,

  input  u5_t  ars1,	// read addr 1
  input  u5_t  ars2,	// read addr 2
  output u32_t rs1,	// read data 1
  output u32_t rs2,	// read data 2

  input  u5_t  awd,	// write addr
  input  logic we,	// write enable
  input  u32_t wd	// write data
  );
  
  u32_t regf[Nregs];	// 32bit x Nregs register array

  always @(posedge clk) begin
    if(awd > 0 && we)
      regf[awd] <= wd;
  end

  always_comb begin
    if(ars1 == 5'd0)
      rs1 <= 32'd0;
    else
      rs1 <= regf[ars1];
    if(ars2 == 5'd0)
      rs2 <= 32'd0;
    else
      rs2 <= regf[ars2];
  end
endmodule


