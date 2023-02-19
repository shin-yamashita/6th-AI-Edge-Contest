
`timescale 1ns/1ns

// u8adrgen.sv
// Conv2d dwConv2d input/filter/bias/output address generator
//
// quantized op version
//
// 2022/09/10 ch_para
// 2022/10/30 Fixed malfunction under condition (outC < 4)

`include "logic_types.svh"

module u8adrgen #(parameter Np = 1)
  (
  input  logic cclk,
  input  logic xrst,
//
  input  logic kick,	// start 1 frame sequence

// Convolution parameter
  input  logic pwe,	// param register write
  input  logic pre,	//                read
  input  u8_t  padr,	// param addr 0 to 22 , 23 to 23+Np-1
  input  u32_t pdata,	// param write data
  output u32_t prdata,	//       read data

  input  logic aclk,
  input  logic arst_n,
// address
  output u24_t in_adr[Np], // input addr (byte)
  output logic valid[Np],  // in_adr valid
  input  logic in_rdy,
  output u24_t fil_adr,	// filter addr (byte)
  input  logic fil_rdy,
  output u24_t out_adr[Np],// output addr (byte)
  output u3_t  out_res, // ch_para
  input  logic out_rdy,
  output u18_t bias_adr,	// bias addr (byte)
  input  logic bias_rdy,
  output logic oen[Np],	// output enable
  output logic chen[Np],	// para channel enable

// running flag
  output logic run,	// cclk 1 : running 

  output logic run_s,	// aclk 1 : running 

// u8mac control
  output logic aen,	// acc en
  output logic acl,	// acc clear
  input  logic acvalid,	// acc data valid
  output logic dwen,  // depthwise enable  // ch_para

// quantize parameters
  output s9_t  in_offs , // quantize params
  output s9_t  out_offs
 );


 u24_t in_adr_i[Np], in_adr_h[Np];
 u24_t fil_adr_i, fil_adr_h;
 logic valid_i[Np], valid_h[Np];
 logic rdy, rdy1;
 logic aen_i, aen_h;

 always_comb begin
  for(int i = 0; i < Np; i++) begin
    //in_adr[i] = rdy ? in_adr_i[i] : in_adr_h[i];
    //valid[i]  = rdy ? valid_i[i]  : valid_h[i];
    in_adr[i] = rdy1 ? in_adr_i[i] : in_adr_h[i]; // 230104
    valid[i]  = rdy1 ? valid_i[i]  : valid_h[i];
  end
 end
 //assign fil_adr = rdy ? fil_adr_i : fil_adr_h;
 //assign aen = rdy ? aen_i : aen_h;
 assign fil_adr = rdy1 ? fil_adr_i : fil_adr_h;
 assign aen = rdy1 ? aen_i : aen_h;

 always@(posedge aclk) begin
  rdy1 <= rdy;  // 230104
  if(!xrst) begin
    aen_h <= 1'b0;
  end else begin
    for(int i = 0; i < Np; i++) begin
      in_adr_h[i] <= (rdy ? in_adr_i[i] : in_adr_h[i]);
      valid_h[i]  <= (rdy ? valid_i[i] : valid_h[i]);
    end
    fil_adr_h <= rdy ? fil_adr_i : fil_adr_h;
    aen_h <= rdy ? aen_i : aen_h;
  end
 end

 u11_t inH, inW, inC;
 u3_t  filH, filW;
 u11_t filC;
 u11_t outH, outW, outC;
 u20_t outWH, pH;
 s16_t dim123;

 u3_t strH, strW, dilH, dilW, padH, padW;
 u8_t n_chen;
 bit  depthmul;
 bit  calc, outtc;
 u12_t ch1C, ch2C, ch3C, finc, dw_c;
 s24_t inCW;

 u24_t cntrun, cntxrdy;

 assign ch1C = depthmul ? inC : outC;
 assign ch2C = depthmul ? 'd1 : inC;
 assign ch3C = depthmul ? outC : inC;
 //assign finc = depthmul ? filC: 'd1;
 assign finc = 'd4; // ch_para
 assign dwen = depthmul;  // ch_para

/*----- param read disable ----
 // parameter register read
 always@(posedge clk) begin
  if(pre)
    case(padr)
     0: prdata <= inH;
     1: prdata <= inW;
     2: prdata <= inC;
     3: prdata <= filH;
     4: prdata <= filW;
     5: prdata <= filC;
     6: prdata <= outH;
     7: prdata <= outW;
     8: prdata <= outC;
     9: prdata <= pH;
    10: prdata <= {strH,dilH,padH};
    11: prdata <= {strW,dilW,padW};
    12: prdata <= depthmul;
    13: prdata <= actmin;
    14: prdata <= actmax;
    15: prdata <= in_offs;
    16: prdata <= fil_offs;
    17: prdata <= out_offs;
    18: prdata <= out_mult;
    19: prdata <= out_shift;
    default: prdata <= 'd0;
    endcase
  else
    prdata <= 'd0;
 end
---------*/
 logic kick_s, run_ss, rdy_s;
 always@(posedge cclk) begin
  run_ss <= run_s;
  rdy_s <= rdy;
  if(!xrst) begin
    kick_s <= 1'b0;
  end else if(kick) begin
    kick_s <= 1'b1;
    cntrun <= 'd0;
    cntxrdy <= 'd0;
  end else begin
    if(run_ss) begin
      cntrun <= cntrun + 1;
      kick_s <= 1'b0;
    end
    if(run_ss && !rdy_s) cntxrdy <= cntxrdy + 1;
  end
  run <= kick_s | run_ss;
  if(pre)
    case(padr)
     0: prdata <= cntrun;
     1: prdata <= cntxrdy;
    default: prdata <= 'd0;
    endcase
  else
    prdata <= 'd0;
 end

 enum {Idle, AccClear, Acc, AccFlush, AccTerm} state;

 // address counter
 s12_t in_x[Np],  in_y[Np];
 s12_t in_xo[Np], in_yo[Np];
 u11_t  out_x[Np], out_y[Np];
 u11_t  out_xh[Np], out_yh[Np];
 u11_t out_c, in_c;
 u3_t  res_c;
 u3_t  fil_x,  fil_y;
 s28_t in_a[Np];
 u20_t out_a;

 assign dw_c = depthmul ? out_c : in_c;
// assign out_res = res_c;

 always@(posedge aclk) begin
   for(int i = 0; i < Np; i++) begin
     in_xo[i] <= signed'((out_x[i] * strW) - padW);
     in_yo[i] <= signed'((out_y[i] * strH) - padH);
     in_a[i]  <= inCW * in_yo[i] + signed'(ch3C) * in_xo[i];
   end
 end

 always_comb begin
  for(int i = 0; i < Np; i++) begin
   in_x[i] <= in_xo[i] + fil_x;
   in_y[i] <= in_yo[i] + fil_y;
  end
 end


// logic rdy;
 assign rdy = in_rdy && fil_rdy && bias_rdy;
 logic [2:0] ncalc;

// params
 always@(posedge cclk) begin
    if(pwe) begin
    case(padr)
     0: inH <= pdata;
     1: inW <= pdata;
     2: inC <= pdata;
     3: filH <= pdata;
     4: filW <= pdata;
     5: filC <= pdata;
     6: outH <= pdata;
     7: outW <= pdata;
     8: outC <= pdata;
     9: pH <= pdata;	// (outWH + (Np-1)) / Np  srmon.c
    10: {strH,dilH,padH} <= pdata;
    11: {strW,dilW,padW} <= pdata;
    12: depthmul <= pdata;
//    13: actmin <= pdata;
//    14: actmax <= pdata;
    15: in_offs <= pdata;
//    16: fil_offs <= pdata;
    17: out_offs <= pdata;
//    18: out_mult <= pdata;
//    19: out_shift <= pdata;
    20: outWH <= pdata;		// outW * outH
    21: dim123 <= pdata;	// filH * filW * filC 
    22: n_chen <= pdata;	// (outWH+pH-1)/pH
    default: ;
    endcase

    for(int i = 0; i < Np; i++) begin
      if(padr == i + 24) begin
        out_yh[i] <= pdata[26:16];
        out_xh[i] <= pdata[10:0];
      end
    end
  end
 end
/*---- Conv3quant ---*/
 logic kick_as;
 always@(posedge aclk) begin
  kick_as <= kick_s;
  if(!arst_n) begin
    state <= Idle;
    chen   <= '{Np{'b0}};
  end

// output address counter
  if(state == AccFlush && calc) begin
    if(out_c == 0) begin
      for(int i = 0; i < Np; i++) begin
        if(oen[i]) begin
          if(out_x[i] == outW-1) begin
            out_x[i] <= 'd0;
            out_y[i] <= out_y[i] + 1;
          end else begin
            out_x[i] <= out_x[i] + 1;
          end
        end
      end
    end
  end else begin
    if(kick_as) begin
      for(int i = 0; i < Np; i++) begin
          out_y[i] <= out_yh[i];
          out_x[i] <= out_xh[i];
      end
//1030      out_res <= 3;
      out_res <= ch1C >= 4 ? 3 : ch1C - 1;	// 1030
    end
  end

  if(ncalc > 0 && rdy) begin // Prepare filter address
    //if(depthmul) fil_adr_i <= out_c;
    //else         fil_adr_i <= dim123 * out_c;
    fil_adr_i <= dim123 * out_c;  // ch_para  dim123 = (dwen ? 1 : filC) * filH*filW;
    inCW <= ch3C * inW;
  end

  if(state == Idle) begin
    if(kick_as) begin
      state  <= AccClear;
      calc   <= 1'b1;
    end else begin
      calc   <= 1'b0;
    end
    run_s    <= 1'b0;
    out_a  <= 0;
    out_c  <= 0;
    fil_y  <= 0;
    fil_x  <= 0;
    in_c   <= 0;
    valid_i  <= '{Np{'b0}};
    oen    <= '{Np{'b0}};
//    chen   <= '{Np{'b0}};
    aen_i    <= 1'b0;
    acl    <= 1'b0;
    outtc  <= 0;
//1030    res_c  <= 3;
    res_c <= ch1C >= 4 ? 3 : ch1C - 1;	// 1030  
    ncalc  <= 'd0;
    in_adr_i  <= '{Np{'d0}};
    fil_adr_i <= 'd0;
    bias_adr <= 'd0;
  end else if(state == AccClear) begin
    valid_i  <= '{Np{'b0}};
//    oen    <= '{Np{'b1}};
    aen_i    <= 1'b0;
    acl    <= 1'b1;
    calc   <= 1'b0;
    ncalc  <= ncalc + 1;
    if(ncalc > 1) state  <= Acc;
    for(int i = 0; i < Np; i++) begin
      chen[i] <= i < n_chen;
      oen[i] <= i < n_chen;
      case(ncalc)
      0: out_adr[i] <= out_y[i] * outW + out_x[i];
      1: out_adr[i] <= out_adr[i] * outC;
      endcase
    end
  end else if(state == Acc) begin
    aen_i    <= 1'b1;
   	acl    <= 1'b0;
    outtc  <= 1'b0;
    ncalc  <= 'd0;
    run_s    <= 1'b1;

    if(rdy & rdy1) begin  // 230104
      if(in_c < ch2C-1) begin
        in_c <= in_c + 1;
      end else begin
        in_c <= 0;
        if(fil_x < filW-1) begin
          fil_x <= fil_x + 1;
        end else begin
          fil_x <= 0;
          if(fil_y < filH-1) begin
            fil_y <= fil_y + 1;
          end else begin
            fil_y <= 0;
            state <= AccFlush;
            calc <= 1'b1;
            //if(out_c < ch1C-4) begin  // ch_para
            if(out_c + 4 < ch1C) begin  // 1030
              out_c <= out_c + 4; // ch_para
              //out_c <= out_c + 1;
            end else begin
              out_c <= 0;
              if(out_a < pH-1) begin
                out_a <= out_a + 1;
              end else begin
                out_a <= 0;
                state <= AccTerm;
              end
            end // out_c
          end // fil_y
        end // fil_x
      end // in_c

      if(aen_i) fil_adr_i <= fil_adr_i + finc;

      bias_adr <= out_c;
      for(int i = 0; i < Np; i++) begin
//        in_adr_i[i]  <= inCW * signed'(in_yo[i] + fil_y) + ch3C * signed'(in_xo[i] + fil_x) + dw_c;
        in_adr_i[i]  <= in_a[i] + signed'((inCW * fil_y) + (ch3C * fil_x) + dw_c);

        if(outtc) begin
          out_adr[i] <= out_adr[i] + (oen[i]?out_res+1 : 0);
          oen[i]     <= out_y[i] < outH;
        end
        valid_i[i]   <= ((in_x[i] >= 0) && (in_x[i] < inW) && (in_y[i] >= 0) && (in_y[i] < inH));
      end // for
    end

  end else if(rdy&rdy1 && state == AccFlush) begin
    ncalc  <= ncalc < 7 ? ncalc + 1 : 'd7;
    if(rdy) begin
      aen_i <= 1'b0;
      calc <= 1'b0;
    end
    if(acvalid && out_rdy) begin // output write
      acl <= 1'b1;
      state <= Acc;
      res_c <= ch1C - out_c > 3 ? 3 : ch1C - out_c - 1; 
      out_res <= res_c;
      outtc <= 1'b1;
    end
  end else if(rdy&rdy1 && state == AccTerm) begin
  	if(rdy) begin
      aen_i <= 1'b0;
      calc <= 1'b0;
  	end
    if(acvalid && out_rdy) begin // output write last 1 data
      acl <= 1'b1;
      run_s <= 1'b0;
      out_res <= res_c;
      outtc <= 1'b1;  // ch_para
      state <= Idle;
    end
  end
 end

endmodule

