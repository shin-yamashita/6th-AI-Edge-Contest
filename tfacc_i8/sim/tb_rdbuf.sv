
`timescale 1ns/1ns
`include "rv_types.svh"

module tb_rdbuf();


logic clk = 0;
u8_t addra;
u9_t addrb;
u64_t wdata;
u4_t web;
u32_t dw;

initial begin
    
end

  rdbuf2k u_rdbuf (
          .clka(clk),   // input wire clka      AXI side
          .wea(8'b0),   // input wire [7 : 0] wea
          .addra(addra),// input wire [7 : 0] addra
          .dina(64'h0), // input wire [63 : 0] dina
          .douta(wdata),// output wire [63 : 0] douta
          .clkb(clk),   // input wire clkb
          .web(web),    // input wire [3 : 0] web
          .addrb(addrb),// input wire [8 : 0] addrb
          //.dinb({dw,dw,dw,dw}),    // input wire [31 : 0] dinb
          .dinb(dw),  // ch_para
          .doutb()      // output wire [31 : 0] doutb
      );


endmodule
