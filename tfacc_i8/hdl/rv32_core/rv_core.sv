//
// rv_core
// 
//

`timescale 1ns/1ns
`include "logic_types.svh"
//import  pkg_rv_decode::*;


module rv_core #(parameter Nregs = 16,
                 parameter debug = 0,
                 parameter fpuen = 1 ) (
  input  logic clk,
  input  logic xreset,

  output u32_t i_adr,	// insn addr
  input  u32_t i_dr,	// insn read data
  output logic i_re,	// insn read enable
  input  logic i_rdy,	// insn data ready

  output u32_t d_adr,	// mem addr
  input  u32_t d_dr,	// mem read data
  output logic d_re,	// mem read enable
  output u32_t d_dw,	// mem write data
  output u4_t  d_we,	// mem write enable
  input  logic d_rdy,	// mem data ready
  input  logic d_be,	// mem bus big endian

  input  logic irq  // interrupt request
  );

import  pkg_rv_decode::*;

//---- branch destination calc ----
function logic [32:0] bra_dest(logic bra_stall, f_insn_t f_dec, u3_t func3,
                               u32_t rs1, u32_t rs2, u32_t imm, u32_t bdst, u32_t pc, u4_t pcinc,
                               u32_t vec, u32_t epc);
  logic bra;
  u32_t pc_nxt;

  bra = 1'b0;
  if(bra_stall) begin
    pc_nxt = pc + pcinc;
    return {bra,pc_nxt};
  end
  if(f_dec.pc == BRA) begin
    case(func3)
    3'd0: if(rs1 == rs2) bra = 1'b1;   // beq
    3'd1: if(rs1 != rs2) bra = 1'b1;   // bne
    3'd4: if(s32_t'(rs1) < s32_t'(rs2)) bra = 1'b1;  // blt
    3'd5: if(s32_t'(rs1) >= s32_t'(rs2)) bra = 1'b1; // bge
    3'd6: if(rs1 < rs2)  bra = 1'b1;   // bltu
    3'd7: if(rs1 >= rs2) bra = 1'b1;   // bgeu
    endcase
    if(bra) begin
      pc_nxt = bdst;
    end else begin
      pc_nxt = pc + pcinc;
    end
  end else if(f_dec.pc == JMP) begin
    if(f_dec.ex == ex_E) begin  // ecall
      pc_nxt = vec;
    end else if(f_dec.ex == ex_R) begin // mret
      pc_nxt = epc;
    end else begin
      pc_nxt = f_dec.rrd1 == RS1 ? (rs1 + imm) : bdst;
    end
    bra = 1'b1;
  end else begin
    pc_nxt = pc + pcinc;
  end
  return {bra,pc_nxt};        // bra_stall, bra_dest
endfunction

function logic [32:0] Reg_fwd(u5_t ix, u32_t rd, u32_t mdr, u5_t rwa[3], regs_t rwd[3], logic rwdx[3], u32_t rwdat[3]); // Register read with fowarding
  logic d_stall;
  u32_t rdi;
  rdi = rd;
  d_stall = 1'b0;
  if(ix == 5'd0) return 'd0;
  if(rwa[0] == ix) begin
    if(rwd[0] == ALU && rwdx[0]) d_stall = 1'b1;
    else if(rwd[0] == ALU) rdi = rwdat[0];
    else if(rwd[0] == MDR) d_stall = 1'b1;
  end else if(rwa[1] == ix) begin
    if(rwd[1] == ALU) rdi = rwdat[1];
    else if(rwd[1] == MDR) d_stall = 1'b1;
  end else if(rwa[2] == ix) begin
    if(rwd[2] == ALU) rdi = rwdat[2];
    else if(rwd[2] == MDR) rdi = mdr;
  end
  return {d_stall,rdi};
endfunction

function u32_t dec_imm(f_insn_t f_dec, u32_t insn);
  u32_t f_imm;
  case (f_dec.itype)
  type_I  : f_imm = u32_t'(signed'(insn[31:20]));
  type_S  : f_imm = u32_t'(signed'({insn[31:25],insn[11:7]}));
  type_SB : f_imm = u32_t'(signed'({insn[31],insn[7],insn[30:25],insn[11:8],1'b0}));
  type_U  : f_imm = {insn[31:12],12'h0};
  type_UJ : f_imm = u32_t'(signed'({insn[31],insn[19:12],insn[20],insn[30:21],1'b0}));
  type_R  : f_imm = 'h00000000;
  type_RF : f_imm = 'h00000000;
  default : f_imm = 'h00000000;
  endcase
  return f_imm;
endfunction

logic   rdy, cmpl, mulop;
logic   bstall, ds1, ds2; // stall signal
u3_t    issue_int;

assign rdy = i_rdy & d_rdy;
assign i_re = 1'b1;
//assign d_re = 1'b1;

//---- register file ----
  u5_t    ars1, ars2, awd;
  u32_t   wd, rs1, rs2;
  logic   we;

  rv_regf #(.Nregs(Nregs)) u_rv_regf (
    .clk   (clk),
    .ars1  (ars1),   .ars2  (ars2),  .rs1   (rs1),    .rs2   (rs2),
    .awd   (rwa[2]), .we    (we),    .wd    (wd)
  );

//---- registers ---
  u32_t   IR, ir, irh;	// insn register
  u32_t   pc,  pca, pc1, bdst;
  u32_t   mar, mdr, mdr1, mdw;
  u2_t    mar1[2];
  wmode_t mmd, mmd1[2];	// mem-mode
  regs_t  mwe, mwe1[2];	// mem-we
  u32_t   rrd1, rrd2;	// regs read data
  u5_t    rwa[3];	// regs write adr
  regs_t  rwd[3];	// regs write data mode
  logic   rwdx[3];	// regs write data mode (mul op)
  u32_t   rwdat[3];	// alu out data
  u32_t   rwdat1;	// alu out data
  u32_t   rwdatx;	// alu out data (mul op)
  alu_t   alu;		// alu mode
  logic   bra_stall;	// branch stall
  logic   d_stall;	// data stall
  logic   ex_stall;	// exec stall
  logic   stall;

  //---- csr regs
  u32_t   mtvec, mepc;
  u16_t   mip, mie;
  u32_t   mcause;
  assign stall = bra_stall | d_stall | ex_stall;

//---- fetch ----
  logic   rdy1;
  u4_t    pcinc, pcinca;
  u32_t   ira, irah;
//  u16_t   i_dr1;
  assign  ira = rdy1 ? i_dr : irah;
//  assign  i_adr = rdy ? pca : pc;
  assign  i_adr = pca;

  always_ff @ (posedge clk) begin
    if(!xreset) begin
      ir <= 'd0;
      irh <= 'd0;
    end else if(rdy) begin
      ir <= ira;
      if(!(ex_stall || d_stall))
        irh <= ir;
    end
    rdy1 <= rdy;
    if(rdy1) begin
      irah <= ira;

    end
  end
  assign IR = (ex_stall || d_stall) ? irh : ir;

//---- decode ----
  logic c_insn, c_insna;
  f_insn_t f_dec;
  u32_t c_imm, f_imm, imm;
  u32_t exir, eir;
  u3_t func3;
//  logic ins_ecall;

  parameter ECALL = 32'h00000073;

  assign c_insn = IR[1:0] != 2'b11;
  assign c_insna = ira[1:0] != 2'b11;
  assign pcinc = c_insn ? 'd2 : 'd4;
  assign pcinca = c_insna ? 'd2 : 'd4;
  assign {eir, c_imm} = exp_cinsn(IR[15:0]);
  assign f_imm = dec_imm(f_dec, IR);
  assign imm  = c_insn ? c_imm : f_imm;
  assign exir = issue_int ? ECALL : (c_insn ? eir : IR);  // 
  assign f_dec = dec_insn(exir);
  assign func3 = exir[14:12];
// : f_dec = '{   type,     ex,    alu,   mode,    mar,    ofs,    mwe,   rrd1,   rrd2,    rwa,    rwd,     pc,  excyc }; // mnemonic

  assign ars1 = f_dec.rrd1 == RS1 ? exir[19:15] : 'd0;
  assign ars2 = f_dec.rrd2 == RS2 ? exir[24:20] : 'd0;
//  assign ars1 = exir[19:15];
//  assign ars2 = exir[24:20];
  assign awd  = exir[10:7];

  u32_t rrd1a, rrd2a, bdsta;
  u32_t rs1f, rs2f;

//  assign {ds1,rs1f} = bra_stall ? 'd0 : Reg_fwd(ars1, rs1, mdr, rwa, rwd, rwdx, rwdat);
//  assign {ds2,rs2f} = bra_stall ? 'd0 : Reg_fwd(ars2, rs2, mdr, rwa, rwd, rwdx, rwdat);

  assign {ds1,rs1f} = Reg_fwd(ars1, rs1, mdr, rwa, rwd, rwdx, rwdat) & ~{bra_stall, 32'd0};
  assign {ds2,rs2f} = Reg_fwd(ars2, rs2, mdr, rwa, rwd, rwdx, rwdat) & ~{bra_stall, 32'd0};

  assign rrd1a = f_dec.rrd1 == PC ? pc1 :
                (f_dec.rrd1 == X0 ? 'd0 :
                (f_dec.rrd1 == SHAMT ? exir[19:15] : rs1f));

  assign rrd2a = f_dec.rrd2 == IMM ? imm :
            //  (f_dec.rrd2 == INC ? pc1 + pcinc : 
                (f_dec.rrd2 == INC ? pc1 + (d_stall ? 'd0 : pcinc) :  // 220509 jalr-bug
                (f_dec.rrd2 == SHAMT ? exir[24:20] : rs2f));

  assign bdsta = d_stall ? bdst : pc1 + imm;
  
  assign {bstall,pca} = xreset ? 
          (ds1|ds2|(ex_stall&!cmpl) ? {1'b0,pc} : 
                  bra_dest(bra_stall, f_dec, func3, rs1f, rs2f, imm, bdsta, pc, pcinca, mtvec, mepc)) : 'd0;

//---- exec ----

  u32_t csr_rd;

  rv_alu #(.fpuen(fpuen)) u_rv_alu (
    .clk    (clk),
    .xreset (xreset),
    .rdy    (rdy),
    .alu    (alu),
    .rrd1   (rrd1),
    .rrd2   (rrd2),
    .csr_rd (csr_rd),
    .rwdat  (rwdat[0]),	// out
    .rwdatx (rwdatx),	// out
    .cmpl   (cmpl),	  // out
    .mulop  (mulop)	  // out
  );

//---- CSR ----
//#define mtime    ((volatile u64*)0xffff8000)
//#define mtimecmp ((volatile u64*)0xffff8008)
parameter MTIME    = 32'hffff8000;
parameter MTIMECMP = 32'hffff8008;
  u64_t   mtime, mtimecmp;
  logic   mtirq;
  logic [1:0] irq_s;

  typedef enum logic [1:0] { RW, SET, CLR, NOP } csrmd_t;
  logic   csren;
  u12_t   csr_adr;
  csrmd_t csrmd;
  logic   mret;
  logic   zmip;

  function csrmd_t csr_mode(logic csren, u3_t func3);
    if(csren)
      case(func3)
      3'd1: return RW;
      3'd2: return SET;
      3'd3: return CLR;
      3'd5: return RW;
      3'd6: return SET;
      3'd7: return CLR;
      default: return NOP;
      endcase
    else 
      return NOP;
  endfunction
  function u32_t csr_wsc(csrmd_t csrmd, u32_t csr, u32_t rrd1);
    case(csrmd)
    RW:  return rrd1;
    SET: return csr | rrd1;
    CLR: return csr & ~rrd1;
    default: return csr;
    endcase
  endfunction

  function u32_t csr_rd_sel(csrmd_t md, u12_t adr);
    u32_t csr_rd;
    if(md != NOP)
      case(adr)
      12'h305: csr_rd = mtvec;
      12'h304: csr_rd = mie;
      12'h344: csr_rd = mip;
      12'h341: csr_rd = mepc;
      12'h342: csr_rd = mcause;
      12'hc01: csr_rd = mtime[31:0];  // time
      12'hc81: csr_rd = mtime[63:32]; // timeh
      default: csr_rd = 'd0;
      endcase
    else
      csr_rd = 'd0;
    return csr_rd;
  endfunction

  assign csren = f_dec.ex == ex_C;

  always_ff @ (posedge clk) begin
    if(!xreset) begin
      mtvec <= 'd0;
      mepc  <= 'd0;
      mie   <= 'd0;
      mip   <= 'd0;
      zmip  <= 1'b1;
      mcause<= 'd0;
    end else if(rdy) begin
      csrmd   <= csr_mode(csren, func3);
      csr_adr <= IR[31:20];
      csr_rd  <= csr_rd_sel(csr_mode(csren, func3), IR[31:20]);

      mtirq <= s32_t'(mtimecmp - mtime) < 0;  // timer expire interrupt request
      irq_s <= {irq_s[0], irq};
      mret  <= f_dec.ex == ex_R;
       
      if(csr_adr == 12'h304 && csrmd != NOP)  // mie
        mie <= csr_wsc(csrmd, mie, rrd1) & 32'b100010001000;
      else begin
        mie[7] <= mie[7] & ~issue_int[1];
        mie[11] <= mie[11] & ~issue_int[2];
      end
      if(csr_adr == 12'h344 && csrmd != NOP) begin // mip
        mip <= csr_wsc(csrmd, mip, rrd1) & 32'b100010001000;
        zmip <= (csr_wsc(csrmd, mip, rrd1) & 32'b100010001000) == 'd0;
      end else begin
        mip[7] <= (mip[7] | issue_int[1]) & ~mret; 
        mip[11] <= (mip[11] | issue_int[2]) & ~mret; 
        zmip <= ~((mip[7] | issue_int[1]) & ~mret || (mip[11] | issue_int[2]) & ~mret);
      end
      if(csrmd != NOP) begin
        case(csr_adr)
        12'h305: mtvec <= csr_wsc(csrmd, mtvec, rrd1);
        12'h342: mcause<= csr_wsc(csrmd, mcause, rrd1);
        default: ;
        endcase
      end
      if(issue_int) mepc <= pc1;
    end
  //  ins_ecall <= issue_int != 'd0;
  end
  assign issue_int[0] = 1'b0;
  assign issue_int[1] = !mip && (mie[7]  && mtirq) && !stall;
  assign issue_int[2] = !mip && (mie[11] && irq_s[1]) && !stall;

//---- mtime register ----
  u32_t d_dr1;
  always_ff @ (posedge clk) begin
    if(!xreset) begin
      mtime     <= 'd0;
      mtimecmp  <= 'd0;
      d_dr1     <= 'd0;
    end else begin
      if(rdy && (d_we != 'd0)) begin
        case(d_adr)
        MTIME:        mtime[31:0]   <= d_dw;
        MTIME+'d4:    mtime[63:32]  <= d_dw;
        default:      mtime <= mtime + 'd1;
        endcase
        case(d_adr)
        MTIMECMP:     mtimecmp[31:0]  <= d_dw;
        MTIMECMP+'d4: mtimecmp[63:32] <= d_dw;
        endcase
      end else begin
        mtime <= mtime + 'd1;
      end
      if(rdy) begin
        if(d_re) begin
          case(d_adr)
          MTIME:        d_dr1 <= mtime[31:0];
          MTIME+'d4:    d_dr1 <= mtime[63:32];
          MTIMECMP:     d_dr1 <= mtimecmp[31:0];
          MTIMECMP+'d4: d_dr1 <= mtimecmp[63:32];
          default:      d_dr1 <= 'd0;
          endcase
        end else begin
          d_dr1 <= 'd0;
        end
      end
    end
  end

//---- memory access ----
// mwe  R_NA, RE, WE
// mmd  SI, HI, QI, SHI, SQI
  logic d_be1[2];

  function u32_t mem_rdata(u32_t mrd, regs_t mwe, wmode_t mmd, u2_t ma, logic be);
    u32_t rd;
    u2_t mar;
    mar = be ? ~ma : ma;
    case(mmd)
    HI:  rd = u32_t'(mar[1] ? mrd[31:16] : mrd[15:0]);
    SHI: rd = u32_t'(signed'((mar[1] ? mrd[31:16] : mrd[15:0])));
    QI:
        case(mar)
        2'd0:  rd = u32_t'(mrd[7:0]);
        2'd1:  rd = u32_t'(mrd[15:8]);
        2'd2:  rd = u32_t'(mrd[23:16]);
        2'd3:  rd = u32_t'(mrd[31:24]);
        endcase
    SQI:
        case(mar)
        2'd0:  rd = u32_t'(signed'(mrd[7:0]));
        2'd1:  rd = u32_t'(signed'(mrd[15:8]));
        2'd2:  rd = u32_t'(signed'(mrd[23:16]));
        2'd3:  rd = u32_t'(signed'(mrd[31:24]));
        endcase
    default: rd = mrd;
    endcase
    return rd;
  endfunction
  
  function u32_t mem_wdata(u32_t mdw, regs_t mwe, wmode_t mmd, u2_t ma, logic be);
    u32_t wd;
    u2_t mar;
    mar = be ? ~ma : ma;
    case(mmd)
    HI:   wd = mar[1] ? {mdw[15:0], 16'd0} : {16'd0, mdw[15:0]};
    SHI:  wd = mar[1] ? {mdw[15:0], 16'd0} : {16'd0, mdw[15:0]};
    QI:   wd = mdw[7:0] << {mar,3'd0};
    SQI:  wd = mdw[7:0] << {mar,3'd0};
    SI:   wd = mdw;
    endcase
    return wd;
  endfunction
  
  function u4_t mem_we(regs_t mwe, wmode_t mmd, u2_t ma, logic be);
    u4_t we;
    u2_t mar;
    mar = be ? ~ma : ma;
    case(mmd)
    SI:   we = 4'b1111;
    HI:   we = mar[1] ? 4'b1100 : 4'b0011;
    SHI:  we = mar[1] ? 4'b1100 : 4'b0011;
    QI:   we = 4'b0001 << mar;
    SQI:  we = 4'b0001 << mar;
    endcase
    return mwe == WE ? we : 'd0;
  endfunction
  
  assign d_adr = mar;
  assign d_dw = mem_wdata(mdw, mwe, mmd, mar[1:0], d_be);
  assign mdr  = mem_rdata(mdr1, mwe1[1], mmd1[1], mar1[1], d_be1[1]);
  assign d_we = mem_we(mwe, mmd, mar[1:0], d_be);
  assign d_re = mwe == RE;
//  assign d_re = 1'b1;

//---- wback ----
  always_comb begin
    case(rwd[2])	// write reg address
    ALU: begin
         we = 1'b1;
         wd = rwdat[2];
         end
    MDR: begin
         we = 1'b1;
         wd = mdr;
         end
    default: begin
         we = 1'b0;
         wd = 'd0;
         end
    endcase
  end

  assign rwdat[1] = rwdx[1] ? rwdatx : rwdat1;
  assign rwdx[0] = mulop;

//  logic maren, mdwen;
  u32_t marp, mdwp, immp;

  always_ff @ (posedge clk) begin
    if(rdy1) begin
      mdr1 <= d_dr | d_dr1;
    end
    if(rdy || !xreset) begin
      bra_stall <= bra_stall ? 1'b0 : bstall;
      if(!xreset)
        ex_stall <= 1'b0;     
      else if(cmpl)
        ex_stall <= 1'b0;
      else if(!bra_stall && f_dec.excyc > 0)
        ex_stall <= 1'b1;
  
      d_stall <= (ds1 | ds2);
      if(f_dec.excyc == 0 || cmpl || bra_stall)
              pc  <= pca;

      pc1 <= pc;
      rwdat1   <= rwdat[0];
      rwdat[2] <= rwdat[1];
      rwd[1]   <= rwd[0];
      rwd[2]   <= rwd[1];
      rwdx[1]  <= rwdx[0];
      rwdx[2]  <= rwdx[1];
      rwa[1]   <= rwa[0];
      rwa[2]   <= rwa[1];
      mmd1[0] <= mmd;
      mmd1[1] <= mmd1[0];
      mwe1[0] <= mwe;
      mwe1[1] <= mwe1[0];
      mar1[0] <= mar[1:0];
      mar1[1] <= mar1[0];
      d_be1[0] <= d_be;
      d_be1[1] <= d_be1[0];
    //  mdr1 <= d_dr | d_dr1;

      if(!(bra_stall)) begin
        if(!(ex_stall && !d_stall)) begin
            rrd1 <= rrd1a;
            rrd2 <= rrd2a;
        end
        bdst <= bdsta;
        
        ////mar    <= ds1 | ds2 ? -2   : (f_dec.mar == RS1 ? rrd1a + imm : 'd0);
        ////mdw    <= ds1 | ds2 ? -1   : (f_dec.mwe == WE ? rrd2a : 'd0);
        mdw    <= (f_dec.mwe == WE ? rs2f : 'd0);
        marp   <= rs1f;
        immp   <= imm;
      //  mdwp   <= rs2f;
      //  maren  <= f_dec.mar == RS1;
      //  mdwen  <= f_dec.mwe == WE;

        rwa[0] <= ds1 | ds2 ? R_NA : (f_dec.rwa == RD ? awd : 'd0);
        mmd    <= ds1 | ds2 ? SI   : f_dec.mode;
        mwe    <= ds1 | ds2 ? R_NA : f_dec.mwe;

        rwd[0] <= ds1 | ds2 ? R_NA : f_dec.rwd;
        alu    <= ds1 | ds2 ? A_NA : f_dec.alu;
  //  end else begin
  //    alu    <= ds1 | ds2 ? A_NA : f_dec.alu; //
      end

    end
  end

  assign mar = marp + immp;
//  assign mdw = mdwen ? mdwp : 'd0;

// synthesis translate_off
  function void debug_print(u32_t pc, u32_t ir, u32_t mar, u32_t mdr, u32_t rrd1, u32_t rrd2, u32_t rwdat);
    if(ir[1:0] == 2'd3)
      $display("%8h %8h  %8h %8h %8h %8h %8h", pc, ir, mar, mdr, rrd1, rrd2, rwdat);
    else
      $display("%8h     %4h  %8h %8h %8h %8h %8h", pc, ir[15:0], mar, mdr, rrd1, rrd2, rwdat);
  endfunction
  logic [1:0] bst;
  u32_t rrd1h, rrd2h;
  always@(posedge clk) begin
    if(rdy) begin
        bst <= {bst[0]|ex_stall,bra_stall};
        rrd1h <= ex_stall ? rrd1h : rrd1;
        rrd2h <= ex_stall ? rrd2h : rrd2;
        if(debug) debug_print(pc1, IR, mar, mdr, ex_stall?rrd1h:rrd1, ex_stall?rrd2h:rrd2, bst[1]?'d0:rwdat[1]);
    end
  end

// synthesis translate_on

endmodule

