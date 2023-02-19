//
// i8mac.sv
// tflite int8 per channel quantized MAC
//
`timescale 1ns/1ns

`include "logic_types.svh"

module i8mac (
  input  logic clk     , //
  input  logic xreset  , //
  input  logic aen     , // acc enable
  input  logic acl     , // acc clear
  input  logic rdy     , // memory read data ready (in & fil)
  input  logic ivalid  , // input data valid
  input  s8_t  in_d    , // s8 input
  input  s8_t  fil_d   , // s8 filter
  input  s32_t bias    , // s32 bias
  input  s9_t  in_offs , // quantize params
  input  s9_t  out_offs,
  input  u32_t quant,   // output quantize param  // ch_para

  output s8_t  accd    , // s8 out
  output logic acvalid   // accd data valid
);

  // s8*s8 acc
  // (in_d + in_offs) * fil_d  (s8+s9)*s8
  s32_t acc;
  s32_t accm;
  s32_t xx;
  u32_t mask, th, rem;
  logic [3:0] aen_d;
  logic cl, en, ben, en1, ben1;
  s8_t  fil_d1;
  s9_t  in_d1;
  s18_t accn;

  s18_t out_mult;
  u8_t  out_shift;
  assign out_mult = quant[31:15]; // ch_para
  assign out_shift = quant[7:0];

  assign cl = rdy && acl;
  assign en = rdy && aen && ivalid;
  assign ben = rdy && !aen && aen_d[0];

  always@(posedge clk) begin
    in_d1 <= 9'(s9_t'(in_d) + in_offs);
    fil_d1 <= fil_d;
    en1 <= en;
    ben1 <= ben;
  end
  //assign accn = 9'(s9_t'(in_d1) + in_offs) * s9_t'(fil_d1);
  assign accn = in_d1 * s9_t'(fil_d1);


  always@(posedge clk) begin
    if(cl) begin
      acc <= 'd0;
    end else if(en1) begin
      acc <= acc + s32_t'(accn);
    end else if(ben1) begin
      acc <= acc + bias;
    //  acc <= acc + (en1 ? s32_t'(accn) : 32'sd0) + (ben ? bias : 32'sd0);
    //  acc <= acc + ((en1 ? s32_t'(accn) : 32'sd0) | (ben1 ? bias : 32'sd0));
    end
  end

  always@(posedge clk) begin
    if(!xreset) begin
      aen_d <= 'd0;
    end else if(rdy) begin
      aen_d <= {aen_d[2:0], aen};
    end

    mask <= (1 << out_shift) - 1;
    th <= (mask >> 1) + (acc < 0);

    if(!xreset) begin
        acvalid <= '0;
    end else if(!aen_d[1] && aen_d[2]) begin		// scale 1
        xx <= s48_t'(acc * out_mult) >>> 16;
    end else if(!aen_d[2] && aen_d[3]) begin	// scale 2
//        accd <= accm < signed'(actmin) ? actmin : accm > actmax ? actmax : accm[7:0];
        accd <= accm < -128 ? -128 : accm > 127 ? 127 : accm[7:0];
        acvalid <= '1;
//    end else if(acl) begin
    end else begin
        acvalid <= '0;
    end

  end

////  assign xx = signed'(acc * out_mult) >>> 16;
//  assign mask = (1 << out_shift) - 1;
//  assign th = (mask >> 1) + (acc < 0);
  assign rem = xx & mask;
  assign accm = signed'(((xx >>> out_shift) + out_offs) + ((rem > th)?1:0));

endmodule

/*--- tflite acc output rounding ------
inline int32 _MultiplyByQuantizedMultiplier(int32 x, int32 quantized_multiplier, int shift) {    // right shift only
    int32 xx = ((int64_t)x * (quantized_multiplier>>15)) >> 16;
    int32 mask = (1 << (shift)) - 1;
    int32 th = (mask >> 1) + (x < 0);
    int32 rem = xx & mask;
    return (xx >> shift) + (rem > th);
}
*/

