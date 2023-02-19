
`timescale 1ns/1ns
`include "logic_types.svh"

module tb_sysmon();

logic cclk;
logic clk = 0;
logic xreset;
// bus
u5_t adr;
logic cs;
logic rdy = 1;
u4_t  we;
logic re;
u32_t dw;
u32_t dr;
// port
logic fan_out;
u32_t data;

  task reg_rd(input int a, output int data);
 //   @(posedge cclk);
    #1
    we  = 0;
    re  = 1;
    adr = a;
    do
    @(posedge cclk);
    while(!rdy);
    #1
    re  = 0;
    data = dr;
//    $display("r a: %h d:%d", adr, data);
    @(posedge cclk);
  endtask

  task reg_wr(input int a, input int data);
//    @(posedge cclk);
    #1
    we  = 4'b1111;
    re  = 0;
    adr = a;
    dw  = data;
//    $display("w a: %h d:%d", adr, data);
    do
    @(posedge cclk);
    while(!rdy);
  endtask

  task nop();
//    @(posedge cclk);
    #1
    we  = 0;
    re  = 0;
    @(posedge cclk);
  endtask

assign cclk = clk;

 always #5       // 100MHz
        clk <= !clk;

initial begin
    xreset = '0;
    re = 0;
    we = 0;
    #20
    xreset = '1;
  #10000000

  @(posedge cclk);
  reg_wr(32'h0, 32'h0);
  reg_wr(32'h0, 32'h1);
  reg_wr(32'h0, 32'h2);
  reg_wr(32'h0, 32'h4);
  reg_wr(32'h0, 32'h80);
  nop();
  reg_rd(32'h0, data);
  reg_rd(32'h4, data);
  reg_rd(32'h8, data);
  reg_rd(32'h18, data);
  #1000000
  reg_wr(32'h0, 32'h0);
  #1000000
  reg_wr(32'h0, 32'hff);
end

assign cs = re || (we != 0);


rv_sysmon u_rv_sysmon( .* );

/*
u16_t adc[8]; // 0:temp,1:vccint,2:vccaux,6:vccbram

always@(posedge cclk)
begin
  if(eoc_out) begin
    adc[channel_out] <= ad_data;
  end
end

sysmon_0 u_sysmon_0 (
  .dclk_in (cclk),                  // input wire dclk_in
  .reset_in(reset_in),                // input wire reset_in
  .channel_out(channel_out),          // output wire [5 : 0] channel_out
  .eoc_out (eoc_out),                  // output wire eoc_out
  .alarm_out(alarm_out),              // output wire alarm_out
  .eos_out (eos_out),                  // output wire eos_out
  .busy_out(busy_out),                // output wire busy_out
  .adc_data_master(ad_data)  // output wire [15 : 0] adc_data_master
);
*/
endmodule
