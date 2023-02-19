
//
// rv_dec_insn.sv
// insn decode table
// genarated by ./insntab.py RV-insn.csv

`include "logic_types.svh"

`ifndef DEC_INSN_SVH
`define DEC_INSN_SVH

typedef enum u3_t {
  type_U, type_UJ, type_I, type_SB, type_S, type_R, type_RF
} itype_t;

typedef enum u3_t {
  ex_I, ex_M, ex_F, ex_E, ex_C, ex_R
} ex_t;

typedef enum u3_t {
  SI, HI, QI, SHI, SQI
} wmode_t;

typedef enum u6_t {
  A_NA, S2, ADD, SLT,  SLTU, XOR, OR, AND,  SLL, SRL, SRA, SUB,
  MUL, MULH, MULHSU, MULHU,  DIV, DIVU, REM, REMU, CSR,
  FADD, FSUB, FMUL, FDIV, FLOAT, FEQ, FLT, FLE, FIX, FSGNJ, FSGNJN, FSGNJX, FMIN, FMAX
} alu_t;

typedef enum u4_t {
  R_NA, X0, RS1, RS2, RD, IMM, PC, WE, RE, MDR, ALU, INC, JMP, BRA, SHAMT
} regs_t;

typedef struct {
  itype_t itype;
  ex_t    ex;
  alu_t   alu;
  wmode_t mode;
  regs_t  mar;
  regs_t  ofs;
  regs_t  mwe;
  regs_t  rrd1;
  regs_t  rrd2;
  regs_t  rwa;
  regs_t  rwd;
  regs_t  pc;
  u5_t    excyc;
} f_insn_t;

function f_insn_t dec_insn(input u32_t ir);
  f_insn_t f_dec;
     //  func7     Rs2[2:0]  func3     opc
  case ({ir[31:25],ir[22:20],ir[14:12],ir[6:0]}) inside
                        // : f_dec = '{   type,     ex,    alu,   mode,    mar,    ofs,    mwe,   rrd1,   rrd2,    rwa,    rwd,     pc,  excyc }; // mnemonic
  20'b??????????0000000011 : f_dec = '{ type_I,   ex_I,   A_NA,    SQI,    RS1,    IMM,     RE,    RS1,   R_NA,     RD,    MDR,   R_NA,   5'd0 }; // "lb"
  20'b??????????0010000011 : f_dec = '{ type_I,   ex_I,   A_NA,    SHI,    RS1,    IMM,     RE,    RS1,   R_NA,     RD,    MDR,   R_NA,   5'd0 }; // "lh"
  20'b??????????0100000011 : f_dec = '{ type_I,   ex_I,   A_NA,     SI,    RS1,    IMM,     RE,    RS1,   R_NA,     RD,    MDR,   R_NA,   5'd0 }; // "lw"
  20'b??????????1000000011 : f_dec = '{ type_I,   ex_I,   A_NA,     QI,    RS1,    IMM,     RE,    RS1,   R_NA,     RD,    MDR,   R_NA,   5'd0 }; // "lbu"
  20'b??????????1010000011 : f_dec = '{ type_I,   ex_I,   A_NA,     HI,    RS1,    IMM,     RE,    RS1,   R_NA,     RD,    MDR,   R_NA,   5'd0 }; // "lhu"
  20'b??????????0000001111 : f_dec = '{ type_I,   ex_I,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   5'd0 }; // "fence"
  20'b??????????0010001111 : f_dec = '{ type_I,   ex_I,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   5'd0 }; // "fence.i"
  20'b??????????0000010011 : f_dec = '{ type_I,   ex_I,    ADD,     SI,   R_NA,   R_NA,   R_NA,    RS1,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "addi"
  20'b??????????0100010011 : f_dec = '{ type_I,   ex_I,    SLT,     SI,   R_NA,   R_NA,   R_NA,    RS1,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "slti"
  20'b??????????0110010011 : f_dec = '{ type_I,   ex_I,   SLTU,     SI,   R_NA,   R_NA,   R_NA,    RS1,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "sltiu"
  20'b??????????1000010011 : f_dec = '{ type_I,   ex_I,    XOR,     SI,   R_NA,   R_NA,   R_NA,    RS1,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "xori"
  20'b??????????1100010011 : f_dec = '{ type_I,   ex_I,     OR,     SI,   R_NA,   R_NA,   R_NA,    RS1,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "ori"
  20'b??????????1110010011 : f_dec = '{ type_I,   ex_I,    AND,     SI,   R_NA,   R_NA,   R_NA,    RS1,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "andi"
  20'b0000000???0010010011 : f_dec = '{ type_R,   ex_I,    SLL,     SI,   R_NA,   R_NA,   R_NA,    RS1,  SHAMT,     RD,    ALU,   R_NA,   5'd0 }; // "slli"
  20'b0000000???1010010011 : f_dec = '{ type_R,   ex_I,    SRL,     SI,   R_NA,   R_NA,   R_NA,    RS1,  SHAMT,     RD,    ALU,   R_NA,   5'd0 }; // "srli"
  20'b0100000???1010010011 : f_dec = '{ type_R,   ex_I,    SRA,     SI,   R_NA,   R_NA,   R_NA,    RS1,  SHAMT,     RD,    ALU,   R_NA,   5'd0 }; // "srai"
  20'b?????????????0010111 : f_dec = '{ type_U,   ex_I,    ADD,     SI,   R_NA,    IMM,   R_NA,     PC,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "auipc"
  20'b??????????0000100011 : f_dec = '{ type_S,   ex_I,   A_NA,     QI,    RS1,    IMM,     WE,    RS1,    RS2,   R_NA,   R_NA,   R_NA,   5'd0 }; // "sb"
  20'b??????????0010100011 : f_dec = '{ type_S,   ex_I,   A_NA,     HI,    RS1,    IMM,     WE,    RS1,    RS2,   R_NA,   R_NA,   R_NA,   5'd0 }; // "sh"
  20'b??????????0100100011 : f_dec = '{ type_S,   ex_I,   A_NA,     SI,    RS1,    IMM,     WE,    RS1,    RS2,   R_NA,   R_NA,   R_NA,   5'd0 }; // "sw"
  20'b0000000???0000110011 : f_dec = '{ type_R,   ex_I,    ADD,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "add"
  20'b0100000???0000110011 : f_dec = '{ type_R,   ex_I,    SUB,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "sub"
  20'b0000000???0010110011 : f_dec = '{ type_R,   ex_I,    SLL,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "sll"
  20'b0000000???0100110011 : f_dec = '{ type_R,   ex_I,    SLT,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "slt"
  20'b0000000???0110110011 : f_dec = '{ type_R,   ex_I,   SLTU,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "sltu"
  20'b0000000???1000110011 : f_dec = '{ type_R,   ex_I,    XOR,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "xor"
  20'b0000000???1010110011 : f_dec = '{ type_R,   ex_I,    SRL,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "srl"
  20'b0100000???1010110011 : f_dec = '{ type_R,   ex_I,    SRA,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "sra"
  20'b0000000???1100110011 : f_dec = '{ type_R,   ex_I,     OR,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "or"
  20'b0000000???1110110011 : f_dec = '{ type_R,   ex_I,    AND,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "and"
  20'b0000001???0000110011 : f_dec = '{ type_R,   ex_M,    MUL,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "mul"
  20'b0000001???0010110011 : f_dec = '{ type_R,   ex_M,   MULH,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "mulh"
  20'b0000001???0100110011 : f_dec = '{ type_R,   ex_M, MULHSU,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "mulhsu"
  20'b0000001???0110110011 : f_dec = '{ type_R,   ex_M,  MULHU,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "mulhu"
  20'b0000001???1000110011 : f_dec = '{ type_R,   ex_M,    DIV,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,  5'd16 }; // "div"
  20'b0000001???1010110011 : f_dec = '{ type_R,   ex_M,   DIVU,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,  5'd16 }; // "divu"
  20'b0000001???1100110011 : f_dec = '{ type_R,   ex_M,    REM,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,  5'd16 }; // "rem"
  20'b0000001???1110110011 : f_dec = '{ type_R,   ex_M,   REMU,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,  5'd16 }; // "remu"
  20'b?????????????0110111 : f_dec = '{ type_U,   ex_I,    ADD,     SI,   R_NA,    IMM,   R_NA,     X0,    IMM,     RD,    ALU,   R_NA,   5'd0 }; // "lui"
  20'b0000000??????1010011 : f_dec = '{ type_R,   ex_M,   FADD,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd1 }; // "fadd"
  20'b0000100??????1010011 : f_dec = '{ type_R,   ex_M,   FSUB,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd1 }; // "fsub"
  20'b0001000??????1010011 : f_dec = '{ type_R,   ex_M,   FMUL,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "fmul"
  20'b0001100??????1010011 : f_dec = '{ type_R,   ex_M,   FDIV,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,  5'd16 }; // "fdiv"
  20'b1100000??????1010011 : f_dec = '{ type_R,   ex_M,    FIX,     SI,   R_NA,   R_NA,   R_NA,    RS1,  SHAMT,     RD,    ALU,   R_NA,   5'd0 }; // "fix"
  20'b1010000???0101010011 : f_dec = '{ type_R,   ex_M,    FEQ,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "feq"
  20'b1010000???0011010011 : f_dec = '{ type_R,   ex_M,    FLT,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "flt"
  20'b1010000???0001010011 : f_dec = '{ type_R,   ex_M,    FLE,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "fle"
  20'b1101000??????1010011 : f_dec = '{ type_R,   ex_M,  FLOAT,     SI,   R_NA,   R_NA,   R_NA,    RS1,  SHAMT,     RD,    ALU,   R_NA,   5'd0 }; // "float"
  20'b0010000???0001010011 : f_dec = '{ type_R,   ex_M,  FSGNJ,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "fsgnj"
  20'b0010000???0011010011 : f_dec = '{ type_R,   ex_M, FSGNJN,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "fsgnjn"
  20'b0010000???0101010011 : f_dec = '{ type_R,   ex_M, FSGNJX,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "fsgnjx"
  20'b0010100???0001010011 : f_dec = '{ type_R,   ex_M,   FMIN,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "fmin"
  20'b0010100???0011010011 : f_dec = '{ type_R,   ex_M,   FMAX,     SI,   R_NA,   R_NA,   R_NA,    RS1,    RS2,     RD,    ALU,   R_NA,   5'd0 }; // "fmax"
  20'b??????????0001100011 : f_dec = '{type_SB,   ex_I,   A_NA,     SI,   R_NA,    IMM,   R_NA,    RS1,    RS2,   R_NA,   R_NA,    BRA,   5'd0 }; // "beq"
  20'b??????????0011100011 : f_dec = '{type_SB,   ex_I,   A_NA,     SI,   R_NA,    IMM,   R_NA,    RS1,    RS2,   R_NA,   R_NA,    BRA,   5'd0 }; // "bne"
  20'b??????????1001100011 : f_dec = '{type_SB,   ex_I,   A_NA,     SI,   R_NA,    IMM,   R_NA,    RS1,    RS2,   R_NA,   R_NA,    BRA,   5'd0 }; // "blt"
  20'b??????????1011100011 : f_dec = '{type_SB,   ex_I,   A_NA,     SI,   R_NA,    IMM,   R_NA,    RS1,    RS2,   R_NA,   R_NA,    BRA,   5'd0 }; // "bge"
  20'b??????????1101100011 : f_dec = '{type_SB,   ex_I,   A_NA,     SI,   R_NA,    IMM,   R_NA,    RS1,    RS2,   R_NA,   R_NA,    BRA,   5'd0 }; // "bltu"
  20'b??????????1111100011 : f_dec = '{type_SB,   ex_I,   A_NA,     SI,   R_NA,    IMM,   R_NA,    RS1,    RS2,   R_NA,   R_NA,    BRA,   5'd0 }; // "bgeu"
  20'b??????????0001100111 : f_dec = '{ type_I,   ex_I,     S2,     SI,   R_NA,    IMM,   R_NA,    RS1,    INC,     RD,    ALU,    JMP,   5'd0 }; // "jalr"
  20'b?????????????1101111 : f_dec = '{type_UJ,   ex_I,     S2,     SI,   R_NA,    IMM,   R_NA,   R_NA,    INC,     RD,    ALU,    JMP,   5'd0 }; // "jal"
  20'b00000000000001110011 : f_dec = '{ type_I,   ex_E,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,    JMP,   5'd0 }; // "ecall"
  20'b00000000010001110011 : f_dec = '{ type_I,   ex_E,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,    JMP,   5'd0 }; // "ebreak"
  20'b00000000100001110011 : f_dec = '{ type_R,   ex_R,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,    JMP,   5'd0 }; // "uret"
  20'b00010000100001110011 : f_dec = '{ type_R,   ex_R,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,    JMP,   5'd0 }; // "sret"
  20'b00110000100001110011 : f_dec = '{ type_R,   ex_R,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,    JMP,   5'd0 }; // "mret"
  20'b??????????0011110011 : f_dec = '{ type_I,   ex_C,    CSR,     SI,   R_NA,   R_NA,   R_NA,    RS1,   R_NA,     RD,    ALU,   R_NA,   5'd0 }; // "csrrw"
  20'b??????????0101110011 : f_dec = '{ type_I,   ex_C,    CSR,     SI,   R_NA,   R_NA,   R_NA,    RS1,   R_NA,     RD,    ALU,   R_NA,   5'd0 }; // "csrrs"
  20'b??????????0111110011 : f_dec = '{ type_I,   ex_C,    CSR,     SI,   R_NA,   R_NA,   R_NA,    RS1,   R_NA,     RD,    ALU,   R_NA,   5'd0 }; // "csrrc"
  20'b??????????1011110011 : f_dec = '{ type_I,   ex_C,    CSR,     SI,   R_NA,   R_NA,   R_NA,  SHAMT,   R_NA,     RD,    ALU,   R_NA,   5'd0 }; // "csrrwi"
  20'b??????????1101110011 : f_dec = '{ type_I,   ex_C,    CSR,     SI,   R_NA,   R_NA,   R_NA,  SHAMT,   R_NA,     RD,    ALU,   R_NA,   5'd0 }; // "csrrsi"
  20'b??????????1111110011 : f_dec = '{ type_I,   ex_C,    CSR,     SI,   R_NA,   R_NA,   R_NA,  SHAMT,   R_NA,     RD,    ALU,   R_NA,   5'd0 }; // "csrrci"
  default                  : f_dec = '{ type_I,   ex_I,   A_NA,     SI,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   R_NA,   5'd0 };
  endcase

  return f_dec;

endfunction

`endif
