//
// rv_alu.sv
//
// alu
// 32 bit x 32 arithmetic logic unit
//
// 2019/11
// 2022/07/  add rv_fpu
//

`include "logic_types.svh"
import  pkg_rv_decode::*;

module rv_alu #(parameter fpuen = 1) (
  input  logic clk,
  input  logic xreset,
  input  logic rdy,
  input  alu_t alu,
  input  u32_t rrd1,
  input  u32_t rrd2,
  input  u32_t csr_rd,
  output u32_t rwdat,
  output u32_t rwdatx,
  output logic cmpl,
  output logic mulop
  );

  u32_t rwd, rwdx;
  logic cmplm, mulopm;
  rv_muldiv u_rv_muldiv(	// multiply / divide unit
    .clk(clk),   .xreset(xreset), .rdy(rdy),
    .alu(alu),
    .rrd1(rrd1), .rrd2(rrd2),
    .rwdat(rwd), .rwdatx(rwdx),
    .cmpl(cmplm), .mulop(mulopm)
  );

  u32_t rwdatf, rwdatxf;
  logic cmplf, mulopf;

  generate
    if(fpuen) begin
      rv_fpu #(.divfen(1)) u_rv_fpu (
        .clk    (clk),    //input logic clk
        .xreset (xreset), //input logic xreset
        .rdy    (rdy),    //input logic rdy
        .alu    (alu),    //input alu_t alu
        .rrd1   (rrd1),   //input u32_t rrd1
        .rrd2   (rrd2),   //input u32_t rrd2
        .rwdat  (rwdatf), //output u32_t rwdat
        .rwdatx (rwdatxf), //output u32_t rwdatx
        .cmpl   (cmplf),  //output logic cmpl
        .mulop  (mulopf)  //output logic mulop  // 2 cycle op
        );
    end else begin
      assign rwdatf  = 'd0;
      assign rwdatxf = 'd0;
      assign cmplf  = 1'b0;
      assign mulopf = 1'b0;
    end
  endgenerate

  assign mulop = mulopm | mulopf;
  assign cmpl = cmplm | cmplf;
  assign rwdatx = rwdx | rwdatxf;

  always_comb begin
  case(alu)	// rrd1 op rrd2
  ADD:    rwdat = rrd1 + rrd2;  
  S2:     rwdat = rrd2;	
  SLT:    rwdat = s32_t'(rrd1) < s32_t'(rrd2);	
  SLTU:   rwdat = rrd1 < rrd2;	
  XOR:    rwdat = rrd1 ^ rrd2;	
  OR:     rwdat = rrd1 | rrd2;	
  AND:    rwdat = rrd1 & rrd2;	
  SLL:    rwdat = rrd1 << (rrd2 & 6'h3f);	
  SRL:    rwdat = rrd1 >> (rrd2 & 6'h3f);	
  SRA:    rwdat = s32_t'(rrd1) >>> (rrd2 & 6'h3f);	
  SUB:    rwdat = rrd1 - rrd2;	

  CSR:    rwdat = csr_rd;

  DIV:    rwdat = rwd;
  DIVU:   rwdat = rwd;
  REM:    rwdat = rwd;
  REMU:   rwdat = rwd;

  default: rwdat = rwdatf;
    //    printf("ill ALU operation %d.\n", alu);	
  endcase
  end

endmodule


