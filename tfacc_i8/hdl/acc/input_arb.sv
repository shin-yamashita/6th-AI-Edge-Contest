
`timescale 1ns/1ns
`include "logic_types.svh"

module input_arb 
   #(parameter Np = 1,	// Number of parallel
     parameter debug = 0)	// debug mode
    (
//    input  logic    clk,		//
//    input  logic    xrst,		//

    input  logic        rreq[Np],
    output logic        rack[Np],
    input  logic [23:0] radr[Np],  
    output logic [63:0] rdata[Np],

    input  logic [31:0] baseadr,	//

//-- memc interface
    input  logic        aclk,		//
    input  logic        arst_n,		//

    output logic [39:0] awaddr,		// 0 write port not used
    output logic [7:0]  awlen,		// 0
    output logic        awvalid,	// 0
    input  logic        awready,	// 

    output logic [63:0] wr_data,	// 0
    output logic        wvalid,		// 0
    output logic        wlast,		// 0
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

  function int penc(input logic req[Np]);
    int i;
    for(i = 0; i < Np; i++)
      if(req[i]) break;
    return i;
  endfunction

  assign awaddr  = 40'h0000000000;
  assign awlen   = 8'h00;
  assign awvalid = 1'b0;
  assign wr_data = 32'h00000000;
  assign wvalid  = 1'b0;
  assign wlast   = 1'b0;

  logic [23:0] wpt;
  
//  localparam Ntfr = 16;
//  localparam Ntfr = 32;
  localparam Ntfr = 64;
  localparam Nb = $clog2(Ntfr*8);

  assign araddr = {16'b0, wpt[23:Nb], (Nb)'(0)} + baseadr;
  assign arlen  = 8'(Ntfr-1);	// 16 tfr  64bit/tfr 128B/burst
                                // 32 tfr  64bit/tfr 256B/burst
                                // 64 tfr  64bit/tfr 512B/burst
  int ch;

  always_comb begin
    for(int i = 0; i < Np; i++) begin
      if(i == ch) begin
        rack[i] = rvalid;  
        rdata[i] = rd_data; //[47:32], rd_data[15:0]} :	// for debug
      end else begin
        rack[i] = 1'b0;  
        rdata[i] = 64'd0;
      end
    end
  end

// axi bus sequencer
  logic [6:0] wcnt;

  enum {Idle, Ack, Readcyc, Readcmd, Post} mst;

  wire zeros[Np] = '{default:0};

  always@(posedge aclk) begin
    if(!arst_n) begin
      mst <= Idle;
      arvalid <= 'b0;
      rready <= 'b0;
      wcnt <= 7'd0;
      ch <= 0;
    end else begin
      case(mst)
      Idle: begin
          arvalid <= 'b0;
          rready <= 'b0;
          wcnt <= 7'd0;
          if(rreq != zeros) begin
            ch <= penc(rreq);
            mst <= Ack;
          end
        end
      Ack:  begin
          arvalid <= 'b1;
          wpt <= radr[ch];
          mst <= Readcmd;
        end
      Readcmd: begin
          if(arready) begin
            arvalid <= 'b0;
            mst <= Readcyc;
            rready <= 'b1;
          end
        end
      Readcyc: begin
          if(rvalid) wcnt <= wcnt + 1;
          if(rvalid && wcnt == arlen) begin
            mst <= Idle;
          end
        end
      Post: begin
          mst <= Idle;
          rready <= 'b0;
        end
      default: mst <= Idle;
      endcase
    end
  end

endmodule

