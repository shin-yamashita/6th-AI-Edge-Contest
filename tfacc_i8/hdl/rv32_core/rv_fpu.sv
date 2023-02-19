//
// sr_fpu.vhd
// 2011/04
// 2014/08/14 add divf
//
// rv_fpu.sv
// 2022/07/09 for rv_core vhdl-> systemverilog
//  riscv zfinx
//  no fma 

`timescale 1ns/1ns
`include "logic_types.svh"
import  pkg_rv_decode::*;

module rv_fpu #(parameter divfen = 1) (
    input logic clk,  // in  std_logic;
    input logic xreset,  // in  std_logic;
    input logic rdy,  // in  std_logic;
    input alu_t alu,  // in  alu_code;
    input u32_t rrd1,  // in  unsigned(31:0);
    input u32_t rrd2,  // in  unsigned(31:0);
    output u32_t rwdat,  // out unsigned(31:0)
    output u32_t rwdatx,  // mul 2 cycle
    output logic cmpl,
    output logic mulop  // 2 cycle op
    );


  // Registers
  logic sgns; // std_logic;
  u9_t  exps; // unsigned(8:0);
  u26_t sigs; // unsigned(25:0);
  logic nan, inf, rfz; // boolean;

  u26_t R, A, B; // unsigned(25:0);	// divf

  // 

  function logic is_nan(u32_t flt);
      return (flt[30:23] == 'd255) && (flt[22:0] != 'd0);
  endfunction
  function logic is_fzero(u32_t flt);
      return (flt[30:23] == 'd0) && (flt[22:0] == 0);
  endfunction
  function logic is_inf(u32_t flt);
      return (flt[30:23] == 'd255) && (flt[22:0] == 'd0);
  endfunction

  function u8_t leadingzero(u32_t ud, int nb);
      u8_t zr;
      zr = 'd0;
      for(int i = nb-1;  i >= 0; i--) begin
          if(ud[i]) begin
              break;
          end else begin
              zr = zr + 'd1;
          end
      end
      return zr;
  endfunction

  function u33_t sgned(u32_t rd);
  u33_t rv;
      rv = {rd[31], rd};
      if(rd[30:0] == 'd0) begin
          rv = 'd0;
      end else if(rd[31]) begin
          rv[30:0] = ~rv[30:0];
      end
      return rv;
  endfunction

  function u3_t grsg(u26_t sig, int d);
    u3_t rv;
    rv = '0;
    if(d-1 >= 0) rv[2] = sig[d-1];//g
    if(d-2 >= 0) rv[1] = sig[d-2];//r
    if(d-3 >= 0) rv[0] = (sig & ((1'b1 << d-2) - 'd1)) != 'd0;
    return rv;
  endfunction

  function u4_t rndup(u4_t d);
    logic ulp, g, r, s;
    {ulp,g,r,s} = d;
    return g & (ulp|r|s) ? 4'b1000 : 4'b0000;
  endfunction

  typedef enum logic {Idle, Calc} state_t;
  state_t st;
  u5_t exc;

  logic nan1r, nan2r, inf1r, inf2r, fz1r, fz2r;   // : boolean;

  bit nan1, nan2, inf1, inf2, fz1, fz2;
  logic sgn1, sgn2, vsgns;
  u3_t grs1, grs2;
  u8_t exp1, exp2; // unsigned(7:0);
  u8_t d	; // unsigned(7:0);
  u9_t vexps ; // unsigned(8:0);
  u26_t sig1, sig2 ; // unsigned(25:0);
  u26_t vsigs; // unsigned(25:0);
  u29_t sums, vsums;
  u32_t fsigs; // unsigned(31:0);
  u48_t msigs; // unsigned(47:0);
  u33_t rd	; // unsigned(32:0);
  u32_t cc	; // 
  u26_t vR, vA, vB; // unsigned(25:0);	// divf

  always_comb begin
    case (alu)
    FLOAT,FMUL,FIX,FEQ,FLT,FLE,FMIN,FMAX,FSGNJ,FSGNJN,FSGNJX: mulop <= 1'b1;
    default:  mulop <= 1'b0;
    endcase
  end

  always_ff@(posedge clk) begin
    sgn1 = rrd1[31];
    sgn2 = rrd2[31];
    exp1 = rrd1[30:23];
    exp2 = rrd2[30:23];
    sig1 = {3'b001, rrd1[22:0]};
    sig2 = {3'b001, rrd2[22:0]};
    nan1 = is_nan(rrd1);
    fz1  = is_fzero(rrd1);
    inf1 = is_inf(rrd1);
    nan2 = is_nan(rrd2);
    fz2  = is_fzero(rrd2);
    inf2 = is_inf(rrd2);
    cc  = '0;
    if(!xreset) begin
      //st <= Idle;
      //exc <= 'd0;
      //cmpl <= 1'b0;
    end else begin
      if(rdy) begin
        case (alu)
        FADD,FSUB : begin // 2 cycle
                nan <= nan1 | nan2 | inf1 | inf2;
                inf <= inf1 | inf2;
                if(alu == FSUB) begin // rs1 - rs2
                    sgn2 = ~sgn2;
                end
                grs1 = '0;
                grs2 = '0;
                if(exp1 > exp2) begin
                    d = exp1 - exp2;
                    vexps = {1'b0, exp1};
                    if(fz2 || d > 'd24) begin
                        sig2 = 'd0;
                    end else begin
                        grs2 = grsg(sig2, d);
                        sig2 = sig2 >> d;
                    end
                end else begin
                    d = exp2 - exp1;
                    vexps = {1'b0, exp2};
                    if(fz1 || d > 'd24) begin
                        sig1 = '0;
                    end else begin
                        if(d > 0) begin
                            grs1 = grsg(sig1, d);
                        end
                        sig1 = sig1 >> d;
                    end
                end
                if(sgn1 != sgn2) begin  // diff
                    vsums = {sig1,grs1} - {sig2,grs2};
                end else begin  // sum
                    vsums = {sig1,grs1} + {sig2,grs2};
                end
                if(vsums[28]) begin // vsums < 0
                    vsums = 'd0 - vsums;
                    vsgns = ~sgn1;
                end else begin
                    vsgns = sgn1;
                end
                sgns <= vsgns;
                exps <= vexps;
                sums <= vsums;
            //// pipe
                vsgns = sgns;
                vexps = exps;
                vsums = sums;
                if(!vsums) begin
                    vexps = '0;
                end else if(vsums[27]) begin	// normalize
                    vsums = {1'b0, vsums[28:1]};  // + vsigs[0];
                    vexps = vexps + 'd1;
                end else begin
                    d = leadingzero(vsums, 29) - 'd2;
                    vexps = vexps - d;
                    vsums = vsums << d;
                    if(vexps[8]) begin	// underflow
                        vexps = '0;
                        vsums = '0;
                    end
                end
                vsigs = (vsums + rndup(vsums[3:0])) >> 3;   // round
                if(nan) begin
                    vexps = 8'hff;
                end
                if(inf) begin
                    vsigs[22:0] = '0;
                end
                rwdat[31] <= vsgns;
                rwdat[30:23] <= vexps[7:0];
                rwdat[22:0] <= vsigs[22:0];
        end
        FDIV : begin	// 17 cycle rrd2 / rrd1 => rrd1 / rrd2
            if(divfen) begin
                vB = B;
                vA = A;
                vR = R;
                if(st == Idle) begin
              //    exc <= 'd16;
              //    st <= Calc;
                  vR = sig2;
                  vB = sig1;
                  vA = '0;
                  exps <= 'd254 + exp1 - exp2;
                  sgns <= sgn1 ^ sgn2;
                  nan1r <= nan1;
                  nan2r <= nan2;
                  inf1r <= inf1;
                  inf2r <= inf2;
                  fz1r <= fz1;
                  fz2r <= fz2; 
                end else if(exc > 'd3) begin
                    for(int i = 0; i < 2; i++) begin
                        if(vB >= vR) begin
                                vB = vB - vR;
                                vA = {vA[24:0], 1'b1};
                        end else begin
                                vA = {vA[24:0], 1'b0};
                        end
                        vB = {vB[24:0], 1'b0};
                    end
                end
                B <= vB;
                A <= vA;	// q
                R <= vR;
                if(exc == 'd1) begin
                    if(A[25]) begin	//// 2.0 > q >= 1.0
                        vsigs = A[25:2] + A[1];
                        vexps = exps;
                    end else begin			//// 1.0 > q >= 0.5
                        vsigs = A[25:1] + A[0];
                        vexps = exps - 'd1;
                    end
                    if(vexps < 'd128) begin	// underflow
                        vexps = '0;
                        vsigs[22:0] = 'd0;
                    end else if(vexps > 'd254+'d127) begin	// overflow
                        vexps = 8'hff;
                        vsigs[22:0] = 'd0;
                    end else begin
                        vexps = vexps - 'd127;
                    end

                    // exceptions
                    if((fz2r && fz1r) || (inf1r && inf2r)) begin
                        vexps = 8'hff;	// 0/0, inf/inf => nan
                        vsigs[22:0] = {1'b1, 22'd0};
                    end else if(fz1r || inf2r) begin
                        vexps = '0;	// 0/x, x/inf => 0
                        vsigs[22:0] = '0;
                    end else if(fz2r || inf1r) begin
                        vexps = 8'hff;	// x/0, inf/x => inf
                        vsigs[22:0] = '0;
                    end
                    if(nan1r || nan2r) begin
                        vexps = 8'hff;
                        vsigs[22:0] = {1'b1, 22'd0};
                    end
                    rwdat[31] <= sgns;
                    rwdat[30:23] <= vexps[7:0];
                    rwdat[22:0] <= vsigs[22:0];
                //    st <= Idle;
                end
            end
        end

        FLOAT : begin // 1 cycle
            fsigs = rrd1;
            vsgns = '0;
            if(rrd2 == '0) begin    // signed
                if(rrd1[31]) begin
                    fsigs = 'd0 - rrd1;
                    vsgns = 1'b1;
                end
            end
            d = leadingzero(fsigs, 32);
            vexps = 9'('d127+'d31) - d;
            if(d < 9) begin
                d = 'd8 - d;	
                fsigs = (fsigs >> d);
            end else begin
                d = d - 'd8;
                fsigs = (fsigs << d);
            end
            if(fz1) begin
                vexps = '0;
            end
            rwdatx[31] <= vsgns;
            rwdatx[30:23] <= vexps[7:0];
            rwdatx[22:0] <= fsigs[22:0];
        end

        FMUL : begin  // 1 cycle
            msigs = sig1[23:0] * sig2[23:0];
            if(msigs[47]) begin
                vsigs[22:0] = msigs[46:24] + msigs[23];
                vexps = {1'b0, exp1} + exp2 + 1;
            end else if(msigs[45:22] == 24'hffffff) begin	// bugfix 121018
                vsigs[22:0] = '0;
                vexps = {1'b0, exp1} + exp2 + 'd1;
            end else begin
                vsigs[22:0] = msigs[45:23] + msigs[22];
                vexps = {1'b0, exp1} + exp2;
            end
            if(vexps < 128) begin	// underflow
                vexps = '0;
            end else if(vexps > 'd254+'d127) begin	// overflow
                vexps = 8'hff;
            end else begin
                vexps = vexps - 'd127;
            end
            vsgns = sgn1 ^ sgn2;

            if(fz1 || fz2) begin
                vexps = '0;
                vsigs[22:0] ='0;
            end
            if(inf1 || inf2) begin
                vsigs[22:0] = '0;
            end
            if(nan1 || nan2 || inf1 || inf2) begin
                vexps = 8'hff;
            end 
            rwdatx[31] <= vsgns;
            rwdatx[30:23] <= vexps[7:0];
            rwdatx[22:0] <= vsigs[22:0];
        end
        FIX : begin // 1 cycle
            fsigs = sig1;
            d = ('d23 + 'd127) - exp1;
            if(!d[7]) begin	// d >= 0
                fsigs = (fsigs >> d);
            end else begin
                fsigs = fsigs << (0-d);
            end
            if(sgn1) begin
            //    if(rrd2 == '0) begin    // signed int
                    fsigs = 'd0 - fsigs;
            //    end else begin  // unsigned int
            //        fsigs = '0;
            //    end
            end
            rwdatx <= fsigs;
        end
        FEQ,FLT,FLE,FMIN,FMAX : begin // 1 cycle  // return (rs1 == rs2) , (rs1 < rs2) , (rs1 <= rs2)  
            rd = sgned(rrd1) - sgned(rrd2);
            case(alu) 
            FEQ : cc = rd[31:0] == '0;  // z
            FLT : cc = rd[32];  // v
            FLE : cc = rd[32] || (rd[31:0] == '0);  // v || z
            FMIN: cc = rd[32] ? rrd1 : rrd2;
            FMAX: cc = rd[32] ? rrd2 : rrd1;
            default : cc = '0;
            endcase
            rwdatx <= cc;
        end
        FSGNJ,FSGNJN,FSGNJX: begin   // 1 cycle // sign injection
            cc = rrd1;
            case(alu)
            FSGNJ:  cc[31] = rrd2[31];
            FSGNJN: cc[31] = ~rrd2[31];
            FSGNJX: cc[31] = rrd1[31] ^ rrd2[31];
            default: ;
            endcase
            rwdatx <= cc;
        end
        default : begin
            rwdatx <= '0;
            rwdat <= '0;
        end
        endcase
      end
    end

  // multi cycle op sequencer
    if(!xreset) begin
      st <= Idle;
      cmpl <= 1'b0;
      exc <= 'd0;
    end else if(rdy) begin
        if(st == Idle) begin
          case(alu)
          FADD,FSUB: begin
            st <= Calc;
            exc <= 'd1;
            cmpl <= 1'b1;
          end
          FDIV: begin
            st <= Calc;
            exc <= 'd16;
          end
          default: begin
            exc <= 'd0;
          end
          endcase
        end else begin  // Calc
          case(alu)
          FADD,FSUB: begin
            cmpl <= 1'b0;
          end
          FDIV: begin
            if(exc == 'd2) begin
              cmpl <= 1'b1;
            end else begin
              cmpl <= 1'b0;
            end
          end
          default: begin
            cmpl <= 1'b0;
          end
          endcase
          if(exc > 'd0) begin
            exc <= exc - 'd1;
          end else if(exc == '0) begin
            st <= Idle;
          end
        end
    end
  end

endmodule


