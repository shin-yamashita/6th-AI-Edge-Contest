
`timescale 1ns/1ns
`include "logic_types.svh"

module rd_cache_nk 
  #(
    parameter NK = 32,			// NK memory size kB
    parameter debug = 0)
   (
//    input  logic    xrst,		//

//-- chahe clear / flush request / busy status
    input  logic    clreq,		//

//-- read dta bus
    input  logic        aclk,		//
    input  logic [31:0] adr,		//
    input  logic        re,		//
//    input  logic        rdyin,		//
    output logic        rdy,		//
    output logic [31:0] dr,     // u32_t
    output logic [7:0]  dru8,   // u8_t
    
    input  logic [31:0] baseadr,	//

//-- memc interface
//    input  logic        aclk,		//
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
    output logic        rready,		//

output logic [31:0] rptmon,
output logic [31:0] wptmon
    );

// NK = 2,  8,16,32
// Nb = 11,13,14,15
  parameter Nb = $clog2(NK) + 10;

  logic [7:0] wea;
//  logic [13:0] addra;  32k:14 2k:10
//  logic [14:0] addrb;      15    11
  logic [Nb-4:0] addra;
  logic [Nb-3:0] addrb;
  logic [63:0] dina;
  logic [31:0] doutb;
  logic [1:0] adr1;
//  logic ren1;

//  assign dina = {fp32_16(rd_data[31:0]),fp32_16(rd_data[63:32])};
  assign dina = rd_data;    //debug ? {rd_data[47:32], rd_data[15:0]} : {fp32_16(rd_data[63:32]),fp32_16(rd_data[31:0])};
  
  assign dr = doutb;    //ren1 ? (debug ? 32'(doutb) : fp16_32(doutb)) : 32'h00000000;

  generate 
    case(NK)
    2:  rdbuf2k  u_rdbuf (.*, .clka(aclk), .douta(), .clkb(aclk), .web(4'b0), .dinb(32'h0));
    4:  rdbuf4k  u_rdbuf (.*, .clka(aclk), .douta(), .clkb(aclk), .web(4'b0), .dinb(32'h0));
    8:  rdbuf8k  u_rdbuf (.*, .clka(aclk), .douta(), .clkb(aclk), .web(4'b0), .dinb(32'h0));
    16: rdbuf16k u_rdbuf (.*, .clka(aclk), .douta(), .clkb(aclk), .web(4'b0), .dinb(32'h0));
    32: rdbuf32k u_rdbuf (.*, .clka(aclk), .douta(), .clkb(aclk), .web(4'b0), .dinb(32'h0));
    endcase
  endgenerate

  assign awaddr  = 40'h0000000000;
  assign awlen   = 8'h00;
  assign awvalid = 1'b0;
  assign wr_data = 32'h00000000;
  assign wvalid  = 1'b0;
  assign wlast   = 1'b0;

  logic [31:0] wpt, rpt;	// buffer RAM write pointer, read pointer (byte addr)
//  logic [31:0] minadr;
  logic ren, inrange;

assign rptmon = {inrange,rpt[30:0]};
assign wptmon = {ren,wpt[30:0]};
//  assign minadr = 32'h000000;	// minadr[8:0] must 0
//  assign ren    = {adr[31:28],4'h0} == base ? re : 1'b0;
  assign ren    = re;	//{adr[31:28],4'h0} == base ? re : 1'b0;
//  assign inrange = (wpt - rpt) < 32768*4;	// cached
//  assign inrange = (wpt - rpt) < NK*1024*4;	// cached
  assign inrange = wpt < (rpt + NK*1024);	// cached
  assign rdy    = ren ? (wpt > rpt) && inrange: 1'b1;

  assign rpt   = adr[31:0];
//  assign addra = wpt[16:3];	// 64bit
//  assign addrb = rpt[16:2];	// 32bit
  assign addra = wpt[Nb-1:3];	// 64bit
  assign addrb = rpt[Nb-1:2];	// 32bit

  assign araddr = baseadr + {wpt[31:9], 9'b0};
//  assign araddr = {wpt[31:9], 9'b0};
  assign arlen  = 8'(8'd64-1);	// 64 tfr  64bit/tfr 512B/burst 128W/burst

  function u8_t byte_select(u32_t d32, logic [1:0] adr);
    u8_t rv;
    case(adr)
    2'd0:    rv = d32[7:0];
    2'd1:    rv = d32[15:8];
    2'd2:    rv = d32[23:16];
    default: rv = d32[31:24];
    endcase
    return rv;
  endfunction
  
  assign dru8 = byte_select(dr, adr1);

  // axi bus sequencer
  logic arreq;
//  assign arreq = (wpt - rpt) < 256;
  assign arreq = ren && (wpt < (rpt + 264));
//  assign arreq = ren && (wpt < (rpt + 512)); 
  assign wea = {8{rvalid}};

  enum {Idle, Ack, Readcyc, Readcmd, Post} mst;

  always@(posedge aclk) begin
    adr1 <= adr[1:0];
//    ren1 <= ren & rdyin;
    if(!arst_n) begin
      mst <= Idle;
      wpt <= 'h0;
      arvalid <= 'b0;
      rready <= 'b0;
    end else begin
      case(mst)
      Idle: begin
          arvalid <= 'b0;
          rready <= 'b0;
          if(clreq) begin
            wpt <= 'h0;
          end else if(!inrange) begin
            wpt <= {rpt[31:9],9'h0};
          end
          if(arreq) mst <= Ack;
        end
      Ack:  begin
          arvalid <= 'b1;
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
          if(rvalid) wpt <= wpt + 8;	// 8byte/tfr
          if(rvalid && wpt[8:3] == 63) begin
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

