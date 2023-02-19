//
// input_cache.sv
// 
// 2022/09/10 ch_para

`timescale 1ns/1ns
`include "logic_types.svh"

module input_cache (
  input  logic        clk,
  input  logic        xrst,

  input  logic        civ,	// cache invalidate

// fpmac
  input  logic        dwen, // depthwise enable  // ch_para
  input  logic        re,	// input data read enable
  input  logic [23:0] adr,	//   address (byte, 0 offset)
  output logic [31:0] dr,	// input data (uint8 x 4) // ch_para
  output logic        rdy,	//   1:ready
//  input  logic        rdyin,

// memory
  output logic        rreq,	// read request (1024B burst)
  input  logic        rack,	// read ack/enable
  output logic [23:0] radr,	// burst start address (byte, 0 offset)  
  input  logic [63:0] rdata	// int8 x8
);
//  localparam Nbk = 32;
  localparam Nbk = 16;
  localparam Nbkb = $clog2(Nbk);    // Nbk=32 -> Nbkb = 5
//  localparam Ntfr = 16;
//  localparam Ntfr = 32;
  localparam Ntfr = 64;
  localparam Nb = $clog2(Ntfr*8);
    
  // 24 23   d c|b a 9 8 7|6 5 4 3|2 1 0|  Ntfr = 16, Nb = 7
  // cl atag[23:7]        |
  //            |9  --addrb---     0|0 0|
  //            |8  --addra--    0|0 0 0|
  //            | -bk-    |  -burstadr- |

  // 24 23   d|c b a 9 8|7 6 5 4 3|2 1 0|  Ntfr = 32, Nb = 8
  // cl atag[23:8]      |
  //          |a  --addrb---       0|0 0|
  //          |9  --addra--      0|0 0 0|
  //          | -bk-    |    -burstadr- |

  // 24 23  |d c b a 9|8 7 6 5 4 3|2 1 0|  Ntfr = 64, Nb = 9
  // cl atag[23:9]    |
  //        |b  --addrb---         0|0 0|
  //        |a  --addra--        0|0 0 0|
  //        | -bk-    |    -burstadr-   |
  
  logic [24:Nb] atag[Nbk];	// address tag for cache control

  logic [Nb:0] wpt;
  logic [23:0] rpt;	// rdbuf write/read pointer (byte address)

  logic [Nb+Nbkb-4:0] addra; // Nbk=32 -> [Nb+1:0]
  logic [Nb+Nbkb-3:0] addrb; // Nbk=32 -> [Nb+2:0]
  logic [31:0] doutb;
  logic [1:0]  adr1;
//  logic re1;

//  rdbuf4k u_rdbuf (	// Ntfr = 16 Nbk = 32
//  rdbuf8k u_rdbuf (	// Ntfr = 32 Nbk = 32 // Ntfr = 64 Nbk = 16
  generate
    case(Ntfr*Nbk)
      2048: rdbuf16k u_rdbuf (	// Ntfr = 64 Nbk = 32
              .clka (clk),    // input wire clka   // write (read from axi)
              .wea  ({8{rack}}),   // input wire [7 : 0] wea
              .addra(addra),  // input wire [Nb+1 : 0] addra
              .dina (rdata),  // input wire [63 : 0] dina
              .douta(),       // output wire [63 : 0] douta
              .clkb (clk),    // input wire clkb   // read (to fpmac)
              .web  (4'b0),   // input wire [3 : 0] web
              .addrb(addrb),  // input wire [Nb+2 : 0] addrb
              .dinb (32'h0),  // input wire [31 : 0] dinb
              .doutb(doutb)   // output wire [31 : 0] doutb
                 );
      1024: rdbuf8k u_rdbuf (    // Ntfr = 64 Nbk = 32
              .clka (clk),    // input wire clka   // write (read from axi)
              .wea  ({8{rack}}),   // input wire [7 : 0] wea
              .addra(addra),  // input wire [Nb+1 : 0] addra
              .dina (rdata),  // input wire [63 : 0] dina
              .douta(),       // output wire [63 : 0] douta
              .clkb (clk),    // input wire clkb   // read (to fpmac)
              .web  (4'b0),   // input wire [3 : 0] web
              .addrb(addrb),  // input wire [Nb+2 : 0] addrb
              .dinb (32'h0),  // input wire [31 : 0] dinb
              .doutb(doutb)   // output wire [31 : 0] doutb
                );
    endcase
  endgenerate
  
  logic [Nbk-1:0] hit, miss, hits;
  logic [Nbkb-1:0] rbk, wbk, abk;	// bank 0,1,2,3...,31

  function u8_t byte_sel(logic [1:0] adr, u32_t data);
      case(adr)
      2'd3: return data[31:24];
      2'd2: return data[23:16];
      2'd1: return data[15:8];
      default: return data[7:0];
      endcase
  endfunction

  function u32_t in_data(logic dwen, logic [1:0] adr, u32_t data); // ch_para
    u8_t bdat = byte_sel(adr, data);
    if(dwen) return data;     // Fix Me!!  
    else     return {bdat, bdat, bdat, bdat};
  endfunction


  assign rpt = adr;
// hit
  for(genvar i = 0; i < Nbk; i++) begin
    assign hits[i] = atag[i] == {1'b0,rpt[23:Nb]};
    assign hit[i]  = re && hits[i];
    assign miss[i] = re && !hits[i];
  end

  assign addrb = {rbk,rpt[Nb-1:2]};
  assign addra = {wbk,wpt[Nb-1:3]};

//  assign dr = re1 ? byte_sel(adr1,doutb) : 8'h00;
//  assign dr = byte_sel(adr1,doutb); // ch_para
  assign dr = in_data(dwen, adr1, doutb); // ch_para
  logic rdyi;
  assign rdyi = !re || ((hit != 'd0) && wpt>rpt[Nb-1:0]);

  always_comb begin	// encode hit tag number
    rbk = 'd0;
    for(int i = 0; i < Nbk; i++) begin
      if(hit[i]) begin	// hit
        rbk = i;
        break;
      end
    end
  end
  

  enum {Idle, WaitAck, Readcyc} mst;

  always@(posedge clk) begin
    rdy <= rdyi;
    adr1 <= #1 adr[1:0];
    if(!xrst || civ) begin
      for(int i = 0; i < Nbk; i++) atag[i] <= {1'b1,(24-Nb)'(0)};
      rreq <= 1'b0;
      mst <= Idle;
      abk <= 0;
      wbk <= 0;
      wpt <= 'd0;
    end else begin

      case(mst)
      Idle: begin
          if(miss == ~Nbk'(0)) begin	// all miss
            abk <= abk + 1;	// 0,..,15
            atag[abk] <= {1'b0,rpt[23:Nb]};
            wpt <= 'd0;
            wbk <= abk;
            radr <= {rpt[23:Nb],(Nb)'(0)};
            rreq <= 1'b1;
            mst <= WaitAck;
          end else if(re) begin	// hit
            if(wpt <= rpt[Nb-1:0]) begin
              radr <= {atag[rbk][23:Nb],(Nb)'(0)};
              wpt <= 'd0;
              wbk <= rbk;
              rreq <= 1'b1;
              mst <= WaitAck;
            end
          end
        end
      WaitAck: begin
          if(rack) begin
            wpt <= wpt + 8;
            rreq <= 1'b0;
            mst <= Readcyc;
          end
        end
      Readcyc: begin
          if(rack) begin
            wpt <= wpt + 8;
            rreq <= 1'b0;
          end
          if(wpt[Nb-1:3] == (Ntfr-1)) mst <= Idle;
        end
      default: mst <= Idle;
      endcase
    end
  end

endmodule

