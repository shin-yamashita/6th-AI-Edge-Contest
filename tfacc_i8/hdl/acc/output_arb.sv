//
// output_arb.sv
// multi output_chache to axi arbiter
//
`timescale 1ns/1ns
`include "logic_types.svh"

module output_arb 
   #(parameter Np = 1,	// Number of parallel
     parameter debug = 0)	// debug mode
    (
//    input  logic    clk,		//
//    input  logic    xrst,		//

    input  logic        wreq[Np],
    output logic        wack[Np],
    input  logic [31:0] wadr[Np],  
    input  logic [63:0] wdata[Np],	// uint8  x8
    input  logic [7:0]  wstbi[Np],
    input  logic [7:0]  wlen[Np],	// write burst length -1

    input  logic [31:0] baseadr,	//

//-- memc interface
    input  logic        aclk,		//
    input  logic        arst_n,		//

    output logic [39:0] awaddr,		// write port
    output logic [7:0]  awlen,		//
    output logic        awvalid,	//
    input  logic        awready,	// 

    output logic [63:0] wr_data,	//
    output logic [7:0]  wstb,		//
    output logic        wvalid,		//
    output logic        wlast,		//
    input  logic        wready,		//

    output logic [39:0] araddr,		//
    output logic [7:0]  arlen,		//
    output logic        arvalid,	//
    input  logic        arready,	//

    input  logic [63:0] rd_data,	//
    input  logic        rvalid,		//
    input  logic        rlast,		//
    output logic        rready		//

    );
/*----
  function logic [15:0] fp32_16(input logic [31:0] fp32);
//    int iexp = fp32[30:23] < 112 ? 112 : (fp32[30:23] > 143 ? 143 : fp32[30:23]);
    automatic int iexp = fp32[30:23] < 112 ? 112 : fp32[30:23];
    automatic logic [4:0] exp = iexp - 112;
    return {fp32[31],exp,fp32[22:13]};	// convert fp32 to fp16
  endfunction

  function logic [31:0] fp16_32(input logic [15:0] fp16);
    return {fp16[15],8'(fp16[14:10]+112),fp16[9:0],13'hcc0};	// convert fp16 to fp32
  endfunction
----*/
    
  function int penc(input logic req[Np]);
    int i;
//    for(i = 0; i < Np; i++)
    for(i = Np-1; i >= 0; i--)
            if(req[i]) break;
    return i;
  endfunction

  assign araddr  = 40'h0000000000;
  assign arlen   = 8'h00;
  assign arvalid = 1'b0;
  assign rready  = 1'b0;

  int ch;

  assign awaddr = baseadr + {wadr[ch][31:8], 8'b0};
//  assign awaddr = wadr[ch]; // 32->40
//  assign awlen  = 8'(8'd32-1);	// 32 tfr  64bit/tfr 256B/burst 64W/burst
  assign awlen  = wlen[ch];
  assign wr_data = wdata[ch];
  //debug ? {16'h0,wdata[ch][31:16], 16'h0,wdata[ch][15:0]} :
  //                         {fp16_32(wdata[ch][31:16]), fp16_32(wdata[ch][15:0])};
  assign wstb   = wstbi[ch];

  always_comb begin
    for(int i = 0; i < Np; i++) begin
      if(i == ch) begin
        wack[i] = wready;  
      end else begin
        wack[i] = 1'b0;  
      end
    end
  end

// axi bus sequencer

  logic [6:0] wcnt;

  enum {Idle, Ack, Writecyc, Writecmd, Post} mst;
  wire zeros[Np] = '{default:0};
  assign wlast = wready && wcnt == awlen;
      
  always@(posedge aclk) begin
    if(!arst_n) begin
      mst <= Idle;
      awvalid <= 'b0;
      wvalid <= 'b0;
//      wlast <= 'b0;
//      wcnt <= 7'd1;
      wcnt <= 7'd0;
      ch <= 0;
    end else begin
      case(mst)
      Idle: begin
          awvalid <= 'b0;
          wvalid  <= 'b0;
//          wlast  <= 'b0;
//          wcnt <= 7'd1;
          wcnt <= 7'd0;
          if(wreq != zeros) begin
            ch <= penc(wreq);
            mst <= Ack;
          end
        end
      Ack:  begin
          awvalid <= 'b1;
          mst <= Writecmd;
        end
      Writecmd: begin
          if(awready) begin
            awvalid <= 'b0;
            mst <= Writecyc;
            wvalid <= 'b1;
          end
        end
      Writecyc: begin
          if(wready) wcnt <= wcnt + 1;
          if(wready && wcnt == awlen) begin
//            wlast <= 'b1;
            mst <= Idle;
          end
        end
      Post: begin
          mst <= Idle;
        end
      default: mst <= Idle;
      endcase
    end
  end

endmodule

