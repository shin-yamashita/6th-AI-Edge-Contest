//
// output_cache.sv
// 
`timescale 1ns/1ns
`include "logic_types.svh"

module output_cache 
   (
    input  logic clk,
    input  logic xrst,	//

    input  logic civ,	// cache invalidate request
    input  logic flreq,	// flush request
    output logic flbsy,	//       busy

// u8mac
    input  u32_t adr,	// output addr (byte, 0 offset)
    input  logic we,	//
    input  u3_t  out_res, // ch_para
    //input  u8_t  dw,	// uint8 output data
    input  u32_t  dw, // ch_para
    output logic rdy,	//
    output logic cmpl,	//

// memory
    output logic wreq,    // burst write request
    input  logic wack,    // write ack, enable
    output u32_t wadr,    // burst addr (byte, 0 offset)
    output u64_t wdata,   // u8 x8
    output u8_t  wstb,    // write strobe
    output u8_t  wlen     // write burst length - 1
  );

  logic cv;       // cache valid

  logic [3:0] web;
  logic [7:0] addra;
  logic [8:0] addrb;

  logic [31:0] wpt, rpt;	// buffer RAM write pointer, read pointer (byte addr)
  logic wen;
  //u32_t dinb;
  u8_t db;
  u2_t oc;

  function u4_t we_sel(logic [1:0] adr, logic wen);
      u4_t web;
      if(wen)
          case(adr[1:0])
              2'd0:   web = 4'b0001;
              2'd1:   web = 4'b0010;
              2'd2:   web = 4'b0100;
              default:web = 4'b1000;
          endcase
      else
          web = 4'b0000;
      return web;
  endfunction
  
  function u8_t wstrobe(logic [2:0] wlenb);
    u8_t stb;
    case(wlenb)
      3'd0: stb = 'b00000001;
      3'd1: stb = 'b00000011;
      3'd2: stb = 'b00000111;
      3'd3: stb = 'b00001111;
      3'd4: stb = 'b00011111;
      3'd5: stb = 'b00111111;
      3'd6: stb = 'b01111111;
      default:stb = 'b11111111;
    endcase
    return stb;
  endfunction

  assign db = dw[oc*8+7 -:8];
  rdbuf2k u_rdbuf (
          .clka(clk),   // input wire clka      AXI side
          .wea(8'b0),   // input wire [7 : 0] wea
          .addra(addra),// input wire [7 : 0] addra
          .dina(64'h0), // input wire [63 : 0] dina
          .douta(wdata),// output wire [63 : 0] douta
          .clkb(clk),   // input wire clkb
          .web(web),    // input wire [3 : 0] web
          .addrb(addrb),// input wire [8 : 0] addrb
          .dinb({db,db,db,db}),    // input wire [31 : 0] dinb
          //.dinb(dw),  // ch_para
          .doutb()      // output wire [31 : 0] doutb
      );

  enum {Wait, Write} wst;

  // out_data write sequencer
  always@(posedge clk) begin
    if(!xrst) begin
      wst <= Wait;
      oc <= '0;
      wen <= 1'b0;
      wpt <= adr[31:0];
    end else begin
      case (wst)
      Wait: begin
      //  wpt <= adr[31:0] + out_res;
      //  wpt <= adr[31:0];
        oc <= '0;
        if(we) begin
          wpt <= adr[31:0];
          wst <= Write;
          wen <= 1'b1;
        end else begin
          wpt <= adr[31:0] + out_res;
        end
      end
      Write: begin
        oc <= oc + 1;
        wpt <= wpt + 1;
        if(oc == out_res) begin
          wst <= Wait;
          wen <= 1'b0;
        end else begin
          wen <= 1'b1;
        end 
      end
      endcase
    end
  end

// assign wen    = cv && we;	//
//  assign wen    = we; //
  assign web    = we_sel(wpt[1:0], wen);
//  assign web    = {wen, wen, wen, wen}; // ch_para

//  assign wpt    = adr[31:0] + out_res;  // ch_para
  assign addra  = wack ? rpt[10:3] + 1 : rpt[10:3];	// 64bit @ memory
  assign addrb  = wpt[10:2];	// 32bit @ memory

// axi bus sequencer
//  assign wreq   = wen && (wpt > (rpt + 256));

  logic lt, eq;
  assign lt = rpt[31:3] < wpt[31:3];
  assign eq = rpt[31:3] == wpt[31:3];

  int wlen_wd, wlen_b;
  assign wlen_b = (wpt - rpt);
  assign wlen_wd = wlen_b >> 3;	// cached word(8byte) length
  assign wstb = eq ? wstrobe(wlen_b[2:0]): 'hff;
  
  logic [6:0] wcnt;

  enum {Idle, Flush, WaitAck, Writecyc, Post} mst;

//  assign rdy = mst == Idle;
  assign cmpl = mst == Idle;

  assign rdy = !cv || wpt < (rpt + 1536);

  always@(posedge clk) begin
    if(!xrst || civ) begin
      mst <= Idle;
      rpt <= 'd0;
      cv <= 'b0;
      flbsy <= 'b0;
      wreq <= 'b0;
      //wwen <= 2'b11;
      wlen <= 'd0;
      wcnt <= 'd0;
//      wstb <= 'hff; // 8byte enable
    end else begin
      case(mst)
      Idle: begin
          //wwen <= 'b11;
          if(!cv && we) begin
            cv <= 'b1;
          end
          if(!cv) rpt <= {wpt[31:8],8'd0};
          if(flreq) begin
            wadr <= {rpt[31:8],8'd0};
          //  wadr <= rpt;
            wlen <= wlen_wd;	// 
 //           wstb <= wlen_wd <= 1 ? wstrobe(wlen_b[2:0]): 'hff;
            wcnt <= 'd0;
            mst <= Flush;
            flbsy <= 'b1;
          end else begin
          //  if(wen && (wpt > (rpt + 256))) begin
            if(cv && (wpt > (rpt + 256+4))) begin
              wadr <= {rpt[31:8],8'd0};
          //    wadr <= rpt;
              wreq <= 'b1;
              wlen <= 8'd31;
 //             wstb <= 'hff;
              wcnt <= 'd0;
              mst <= WaitAck;
            end
            flbsy <= 'b0;    // 1015
          end
        end
      Flush: begin
          if(wpt > rpt) begin
            wreq <= 'b1;
            mst <= WaitAck;
          end else begin
            mst <= Idle;
            flbsy <= 'b0;
          end
        end
      WaitAck:  begin
          if(wack) begin
            wreq <= 'b0;
            rpt <= rpt + 8;	// 8byte/tfr
            wcnt <= wcnt + 1;
//            wstb <= wlen_wd <= 1 ? wstrobe(wlen_b[2:0]): 'hff;
       //     wwen <= lt ? 2'b11 : (eq ? {wpt[2],1'b1} : 2'b00);
            if(wcnt == wlen) begin
                mst <= Post;
            end
          end
        end
      Post: begin
          mst <= flbsy ? Flush : Idle;
        end
      default: mst <= Idle;
      endcase
    end
  end

endmodule

