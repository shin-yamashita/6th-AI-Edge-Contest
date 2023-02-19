
//
// rv_exp_cinsn.sv
// expand C-insn to full insn
// genarated by ./c-insntab.py c-insn.csv
//

`include "logic_types.svh"

`ifndef EXP_CINSN_SVH
`define EXP_CINSN_SVH

typedef enum u4_t {
  type_CR, type_CI, type_CSS, type_CIW, type_CL, type_CS, type_CB, type_CJ
} citype_t;

typedef enum u4_t {
  CX_NA, CX0, CX1, CX2, CRS1, CRS2, CRS1D, CRS2D, CRS2I
} cregs_t;

typedef enum u4_t {
  CIMM_NA, CIMM0, CIMM1, CIMM2, CIMM3, CIMM4, CIMM5, CIMM6, CIMM7, CIMM8, CIMM9, CIMM10
} cimm_t;

typedef struct {
  citype_t itype;
  cimm_t   imm;
  cregs_t  rs2;
  cregs_t  rs1;
  cregs_t  rd;
  logic [6:0] func7;
  logic [2:0] func3;
  logic [6:0] opc;
} c_insn_t;

function u64_t exp_cinsn (input u16_t ir);
  u32_t exir, c_imm;
  c_insn_t c_dec;

  case (ir[15:0]) inside
                    // : c_dec = '{    type,     imm,     rs2,     rs1,      rd,   func7,   func3,     opc,};  // mnemonic
  16'b000???????????00 : c_dec = '{type_CIW,   CIMM9,   CX_NA,     CX2,   CRS2D,    7'h0,    3'h0,   7'h13 };  //  c.ai4sp
  16'b010???????????00 : c_dec = '{ type_CL,   CIMM8,   CX_NA,   CRS1D,   CRS2D,    7'h0,    3'h2,   7'h03 };  //  c.lw
  16'b011???????????00 : c_dec = '{ type_CL,   CIMM8,   CX_NA,   CRS1D,   CRS2D,    7'h0,    3'h2,   7'h07 };  //  c.flw
  16'b110???????????00 : c_dec = '{ type_CS,   CIMM8,   CRS2D,   CRS1D,   CX_NA,    7'h0,    3'h2,   7'h23 };  //  c.sw
  16'b111???????????00 : c_dec = '{ type_CS,   CIMM8,   CRS2D,   CRS1D,   CX_NA,    7'h0,    3'h2,   7'h27 };  //  c.fsw
  16'b0000000000000001 : c_dec = '{ type_CR,   CIMM0,   CX_NA,     CX0,     CX0,    7'h0,    3'h0,   7'h13 };  //  c.nop
  16'b000???????????01 : c_dec = '{ type_CI,  CIMM10,   CX_NA,    CRS1,    CRS1,    7'h0,    3'h0,   7'h13 };  //  c.addi
  16'b001???????????01 : c_dec = '{ type_CJ,   CIMM5,   CX_NA,   CX_NA,     CX1,    7'h0,    3'h0,   7'h6F };  //  c.jal
  16'b010???????????01 : c_dec = '{ type_CI,  CIMM10,   CX_NA,     CX0,    CRS1,    7'h0,    3'h0,   7'h13 };  //  c.li
  16'b011?00010?????01 : c_dec = '{ type_CI,   CIMM7,   CX_NA,     CX2,     CX2,    7'h0,    3'h0,   7'h13 };  //  c.ai16sp
  16'b011???????????01 : c_dec = '{ type_CI,   CIMM6,   CX_NA,   CX_NA,    CRS1,    7'h0,    3'h0,   7'h37 };  //  c.lui
  16'b100?00????????01 : c_dec = '{ type_CI,   CIMM4,   CRS2I,   CRS1D,   CRS1D,   7'h00,    3'h5,   7'h13 };  //  c.srli
  16'b100?01????????01 : c_dec = '{ type_CI,   CIMM4,   CRS2I,   CRS1D,   CRS1D,   7'h20,    3'h5,   7'h13 };  //  c.srai
  16'b100?10????????01 : c_dec = '{ type_CI,  CIMM10,   CX_NA,   CRS1D,   CRS1D,    7'h0,    3'h7,   7'h13 };  //  c.andi
  16'b100011???00???01 : c_dec = '{ type_CL, CIMM_NA,   CRS2D,   CRS1D,   CRS1D,   7'h20,    3'h0,   7'h33 };  //  c.sub
  16'b100011???01???01 : c_dec = '{ type_CL, CIMM_NA,   CRS2D,   CRS1D,   CRS1D,   7'h00,    3'h4,   7'h33 };  //  c.xor
  16'b100011???10???01 : c_dec = '{ type_CL, CIMM_NA,   CRS2D,   CRS1D,   CRS1D,   7'h00,    3'h6,   7'h33 };  //  c.or
  16'b100011???11???01 : c_dec = '{ type_CL, CIMM_NA,   CRS2D,   CRS1D,   CRS1D,   7'h00,    3'h7,   7'h33 };  //  c.and
  16'b101???????????01 : c_dec = '{ type_CJ,   CIMM5,   CX_NA,   CX_NA,     CX0,    7'h0,    3'h0,   7'h6F };  //  c.j
  16'b110???????????01 : c_dec = '{ type_CB,   CIMM3,   CX_NA,   CRS1D,     CX0,    7'h0,    3'h0,   7'h63 };  //  c.beqz
  16'b111???????????01 : c_dec = '{ type_CB,   CIMM3,   CX_NA,   CRS1D,     CX0,    7'h0,    3'h1,   7'h63 };  //  c.bnez
  16'b000???????????10 : c_dec = '{ type_CI,   CIMM4,   CRS2I,    CRS1,    CRS1,   7'h00,    3'h1,   7'h13 };  //  c.slli
  16'b010???????????10 : c_dec = '{ type_CI,   CIMM2,   CX_NA,     CX2,    CRS1,    7'h0,    3'h2,   7'h03 };  //  c.lwsp
  16'b011???????????10 : c_dec = '{ type_CI,   CIMM2,   CX_NA,     CX2,    CRS1,    7'h0,    3'h2,   7'h07 };  //  c.flwsp
  16'b1000?????0000010 : c_dec = '{ type_CI, CIMM_NA,   CX_NA,    CRS1,     CX0,    7'h0,    3'h0,   7'h67 };  //  c.jr
  16'b1000??????????10 : c_dec = '{ type_CR, CIMM_NA,    CRS2,     CX0,    CRS1,   7'h00,    3'h0,   7'h33 };  //  c.mv
  16'b1001000000000010 : c_dec = '{ type_CI, CIMM_NA,     CX1,   CX_NA,   CX_NA,    7'h0,    3'h0,   7'h73 };  //  c.ebreak
  16'b1001?????0000010 : c_dec = '{ type_CR,   CIMM0,   CX_NA,    CRS1,     CX1,    7'h0,    3'h0,   7'h67 };  //  c.jalr
  16'b1001??????????10 : c_dec = '{ type_CR, CIMM_NA,    CRS2,    CRS1,    CRS1,   7'h00,    3'h0,   7'h33 };  //  c.add
  16'b110???????????10 : c_dec = '{type_CSS,   CIMM1,    CRS2,     CX2,   CX_NA,    7'h0,    3'h2,   7'h23 };  //  c.swsp
  16'b111???????????10 : c_dec = '{type_CSS,   CIMM1,    CRS2,     CX2,   CX_NA,    7'h0,    3'h2,   7'h27 };  //  c.fswsp
  default :              c_dec = '{type_CR,  CIMM_NA,   CX_NA,   CX_NA,   CX_NA,    7'h0,    3'h0,   7'h00 };
  endcase

  case (c_dec.imm)
  CIMM0:  c_imm = 'h00000000;
  CIMM1:  c_imm = u32_t'({ir[8:7],ir[12:9],2'b0});
  CIMM2:  c_imm = u32_t'({ir[3:2],ir[12],ir[6:4],2'b0});
  CIMM3:  c_imm = u32_t'(signed'({ir[12],ir[6:5],ir[2],ir[11:10],ir[4:3],1'b0}));
  CIMM4:  c_imm = u32_t'({ir[12],ir[6:2]});
  CIMM5:  c_imm = u32_t'(signed'({ir[12],ir[8],ir[10:9],ir[6],ir[7],ir[2],ir[11],ir[5:3],1'b0}));
  CIMM6:  c_imm = u32_t'(signed'({ir[12],ir[6:2],12'b0}));
  CIMM7:  c_imm = u32_t'(signed'({ir[12],ir[4:3],ir[5],ir[2],ir[6],4'b0}));
  CIMM8:  c_imm = u32_t'({ir[5],ir[12:10],ir[6],2'b0});
  CIMM9:  c_imm = u32_t'({ir[10:7],ir[12],ir[11],ir[5],ir[6],2'b0});
  CIMM10: c_imm = u32_t'(signed'({ir[12],ir[6:2]}));
  default: c_imm = 'h00000000;
  endcase

  case (c_dec.rs1)
  CX0:   exir[19:15] = 5'h0;
  CX2:   exir[19:15] = 5'h2;
  CRS1D: exir[19:15] = {2'h1,ir[9:7]};
  CRS1:  exir[19:15] = ir[11:7];
  default: exir[19:15] = 5'h0;
  endcase

  case (c_dec.rs2)
  CX0:   exir[24:20] = 5'h0;
  CX1:   exir[24:20] = 5'h1;
  CX2:   exir[24:20] = 5'h2;
  CRS2D: exir[24:20] = {2'h1,ir[4:2]};
  CRS2:  exir[24:20] = ir[6:2];
  CRS2I: exir[24:20] = c_imm[4:0];
  default: exir[24:20] = 5'h0;
  endcase

  case (c_dec.rd)
  CX0:   exir[11:7] = 5'h0;
  CX1:   exir[11:7] = 5'h1;
  CX2:   exir[11:7] = 5'h2;
  CRS1:  exir[11:7] = ir[11:7];
  CRS1D: exir[11:7] = {2'h1,ir[9:7]};
  CRS2D: exir[11:7] = {2'h1,ir[4:2]};
  CRS2:  exir[11:7] = ir[11:7];
  default: exir[11:7] = 5'h0;
  endcase

  exir[31:25] = c_dec.func7;
  exir[14:12] = c_dec.func3;
  exir[6:0] = c_dec.opc;

  return {exir, c_imm};

endfunction

`endif
