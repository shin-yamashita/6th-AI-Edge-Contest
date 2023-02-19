//
// rv_muldiv.sv
//
// alu muliply / divide unit
//
// 2021/4
//

`include "logic_types.svh"
import  pkg_rv_decode::*;

module rv_muldiv (
  input  logic clk,
  input  logic xreset,
  input  logic rdy,
  input  alu_t alu,
  input  u32_t rrd1,
  input  u32_t rrd2,
  output u32_t rwdat,   // div/mod 17 cycle
  output u32_t rwdatx,  // mul 2 cycle
  output logic cmpl,
  output logic mulop  // 2 cycle op
  );

  typedef struct {
    u32_t A, B;
    u64_t R;
  } div_t;

  logic sgn, msgn;
  div_t Q;

  alu_t alu1;
  u64_t umul;
  s32_t smul, sumul;
  //s32_t sdiv, srem;

  /*
  s17_t al, ah, bl, bh;	// rrd1:a rrd2:b
  s16_t sah, sbh;
  assign al = {1'b0,rrd1[15:0]};
  assign ah = {1'b0,rrd1[31:16]};
  assign bl = {1'b0,rrd2[15:0]};
  assign bh = {1'b0,rrd2[31:16]};
  assign sah = rrd1[31:16];
  assign sbh = rrd2[31:16];
  s33_t xl, xm, sxm, xh, sxh, suxh;
  s34_t suxm;
  */
  always_ff@(posedge clk) begin
    alu1 <= alu;
    /*
    xl   <= al * bl;
    xm   <= bh * al + ah * bl;
    sxm  <= sbh * al + sah * bl;
    suxm <= bh * al + sah * bl;
    xh   <= ah * bh;
    sxh  <= sah * sbh;
    suxh <= sah * bh;
    */
    umul[31:0]  <= 32'(rrd1 * rrd2);
    umul[63:32] <= 64'(rrd1 * rrd2) >>> 32;
    smul        <= 64'(signed'(rrd1) * signed'(rrd2)) >>> 32;        // s32*s32-> s64 >> 32
    sumul       <= 64'(signed'(rrd1) * signed'({1'b0,rrd2})) >>> 32; // s32*u32-> s64 >> 32
  end

//  assign umul  = u64_t'(xl) + (xm << 16) + (xh << 32);
//  assign smul  = xl + (sxm <<< 16)  + (sxh <<< 32);
//  assign sumul = xl + (suxm <<< 16) + (suxh <<< 32);

  always_comb begin
    case(alu)	// rrd1 op rrd2
    MUL,MULH,MULHSU,MULHU: mulop = 1'b1;
    default: mulop = 1'b0;
    endcase
    case(alu1)	// pipe'd mulop out
    MUL:    rwdatx = umul[31:0];  // u32*u32 & 0xffffffff
    MULH:   rwdatx = smul;        // s32*s32 >> 32
    MULHSU: rwdatx = sumul;       // s32*u32 >> 32
    MULHU:  rwdatx = umul[63:32]; // u32*u32 >> 32
    default: rwdatx = 'd0;
    endcase
  /*
    case(alu)	// rrd1 op rrd2
//    DIV:    rwdat = sgn ? 32'd0 - Q.A : Q.A;	// rrd1 / rrd2
    DIV:    rwdat = sdiv;
    DIVU:   rwdat = Q.A;
//    REM:    rwdat = msgn ? 2'd0 - Q.B : Q.B;	// rrd1 % rrd2
    REM:    rwdat = srem;
    REMU:   rwdat = Q.B;
    default: rwdat = 'd0;
    //    printf("ill ALU operation %d.\n", alu);	
    endcase
    */
  end


  // 2bit divide
  function div_t div_sub(div_t Q);
    div_t q;
    q = Q;
    for(int i = 0; i < 2; i++) begin
      q.R = {1'b0, q.R[63:1]};
      if((q.R[63:32] == 'd0) && (q.B >= q.R[31:0])) begin
        q.B = q.B - q.R[31:0];
        q.A = {q.A[30:0], 1'b1};
      end else begin
        q.A = {q.A[30:0], 1'b0};
      end
    end
    return q;
  endfunction

  typedef enum logic {Idle, Calc} state_t;
  state_t st;
  u5_t exc;
  div_t vQ;
  assign vQ = div_sub(Q);

  always_ff@(posedge clk) begin
    if(!xreset) begin
      st <= Idle;
      exc <= 'd0;
      cmpl <= 1'b0;
    end else begin
      if(rdy && st == Idle) begin
        exc <= 'd16;
        cmpl <= 1'b0;
        case (alu)
        DIV,REM : begin
            sgn <= rrd1[31] ^ rrd2[31];
            msgn <= rrd1[31];
            Q.R <= {32'((rrd2[31] ? (32'd0 - rrd2) : rrd2)), 32'd0};
            Q.B <= rrd1[31] ? (32'd0 - rrd1) : rrd1;
            Q.A <= 'd0;
            st <= Calc;
          end
        DIVU,REMU : begin
            sgn <= 1'b0;
            msgn <= 1'b0;
            Q.R <= {rrd2, 32'd0};
            Q.B <= rrd1;
            Q.A <= 'd0;
            st <= Calc;
          end
        default: begin
            st <= Idle;
          end
        endcase
      end else if(st == Calc) begin
        Q <= vQ;

        case(alu)	// rrd1 op rrd2
        DIV:    rwdat <= sgn ? 32'd0 - vQ.A : vQ.A;	// rrd1 / rrd2
        DIVU:   rwdat <= vQ.A;
        REM:    rwdat <= msgn ? 2'd0 - vQ.B : vQ.B;	// rrd1 % rrd2
        REMU:   rwdat <= vQ.B;
        default: rwdat <= 'd0;
        endcase

        //sdiv <= sgn ? 32'd0 - vQ.A : vQ.A;	// rrd1 / rrd2
        //srem <= msgn ? 2'd0 - vQ.B : vQ.B;	// rrd1 % rrd2

        exc <= exc - 'd1;
        if(exc == 0) begin
          st <= Idle;
        end
        cmpl <= exc == 2 ? 1'b1 : 1'b0;
      end
    end
  end

endmodule


