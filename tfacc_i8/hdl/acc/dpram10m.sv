

`timescale 1ns/1ps

module dpram10m (
  input         clka,
  input  [3:0]  wea,
  input  [6:0]  addra,
  input  [31:0] dina,
  output reg [31:0] douta,
  input         clkb,
  input  [3:0]  web,
  input  [6:0]  addrb,
  input  [31:0] dinb,
  output reg [31:0] doutb
  );

// disable conflict avoidance logic
  reg [8:0] mem3 [127:0] /* synthesis syn_ramstyle=no_rw_check*/;
  reg [8:0] mem2 [127:0] /* synthesis syn_ramstyle=no_rw_check*/;
  reg [8:0] mem1 [127:0] /* synthesis syn_ramstyle=no_rw_check*/;
  reg [8:0] mem0 [127:0] /* synthesis syn_ramstyle=no_rw_check*/;

// 'write first' or transparent mode
  always @(posedge clka) begin
    if(wea[3])
      mem3[addra] <= dina[31:24];
    douta[31:24] <= mem3[addra];
    if(wea[2])
      mem2[addra] <= dina[23:16];
    douta[23:16] <= mem2[addra];
    if(wea[1])
      mem1[addra] <= dina[15:8];
    douta[15:8] <= mem1[addra];
    if(wea[0])
      mem0[addra] <= dina[7:0];
    douta[7:0] <= mem0[addra];
  end
  always @(posedge clkb) begin
    if(web[3])
      mem3[addrb] <= dinb[31:24];
    doutb[31:24] <= mem3[addrb];
    if(web[2])
      mem2[addrb] <= dinb[23:16];
    doutb[23:16] <= mem2[addrb];
    if(web[1])
      mem1[addrb] <= dinb[15:8];
    doutb[15:8] <= mem1[addrb];
    if(web[0])
      mem0[addrb] <= dinb[7:0];
    doutb[7:0] <= mem0[addrb];
  end

endmodule

