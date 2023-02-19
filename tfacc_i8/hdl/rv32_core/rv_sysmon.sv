//
// rv_sysmon
// sysmon (ADC) interface
// 2023/01/18
// https://docs.xilinx.com/v/u/en-US/ug580-ultrascale-sysmon
//

`timescale 1ns/1ns
`include "logic_types.svh"

module rv_sysmon (
    input  logic clk,
    input  logic xreset,
// bus
    input  u5_t  adr,
    input  logic cs,
    input  logic rdy,
    input  u4_t  we,
    input  logic re,
    input  u32_t dw,
    output u32_t dr,
// port
    output logic fan_out
);

u5_t adr1;
logic re1;
u16_t adcreg[8];  // 0:temp,1:vccint,2:vccaux,6:vccbram
u6_t channel_out;
u16_t ad_data;
logic eoc_out,alarm_out,eos_out,busy_out;
u8_t pwm;

assign dr = re1 ? {adcreg[adr1[4:2]], 8'h0, pwm} : 32'd0;

always_ff @(posedge clk) begin
    if(rdy) begin
        re1 <= cs && re;
        adr1 <= adr;
    end
    if(!xreset) begin
        pwm  <= 'd0;
    end else begin
        if(cs && (adr == 'd0) && rdy) begin
            if(we[0]) begin
                pwm <= dw[7:0];
            end
        end
    end
    if(eoc_out) begin
        adcreg[channel_out] <= ad_data;
    end
end

sysmon_0 u_sysmon_0 (
    .dclk_in   (clk),                  // input wire dclk_in
    .reset_in  (~xreset),                // input wire reset_in
    .channel_out(channel_out),          // output wire [5 : 0] channel_out
    .eoc_out   (eoc_out),                  // output wire eoc_out
    .alarm_out (alarm_out),              // output wire alarm_out
    .eos_out   (eos_out),                  // output wire eos_out
    .busy_out  (busy_out),                // output wire busy_out
    .adc_data_master(ad_data)  // output wire [15 : 0] adc_data_master
  );

u8_t count;
u16_t prescale; // 5.9
//u11_t prescale; // 190
//u12_t prescale; // 95
//logic [13:0] prescale; // 24

always_ff @(posedge clk) begin
    if(!xreset) begin
        count <= '0;
        prescale <= '0;
    end else begin
        if(prescale == '0)
            count <= count + 1;
        prescale <= prescale + 1;
    end
    fan_out <= count > pwm; 
end

endmodule

