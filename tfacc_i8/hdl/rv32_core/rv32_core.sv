
//
// 2021/4
// 2022/11/23 for kv260
// 2023/01/14 Nk = 64 -> 32

`timescale 1ns/1ns
`include "logic_types.svh"

module rv32_core #( parameter debug = 0, parameter Nk = 32 ) (
    input  logic cclk,    //    : in    std_logic;
    input  logic xreset,  //  : in  std_logic;
    //-- memory access bus
    input  u32_t p_adr,   //   : in  unsigned(31 downto 0);
    input  logic p_we,    //    : in  std_logic;
    input  logic p_re,    //    : in  std_logic;
    input  u32_t p_dw,    //    : in  unsigned(31 downto 0);
    output u32_t p_dr,    //    : out unsigned(31 downto 0);
    output logic p_ack,   //   : out std_logic;
    //-- data bus
    output u32_t adr,     //     : out unsigned(31 downto 0);
    output u4_t  we,      //      : out std_logic_vector(3 downto 0);
    output logic re,      //      : out std_logic;
    input  logic rdy,     //     : in  std_logic;
    output u32_t dw,      //      : out unsigned(31 downto 0);
    input  u32_t dr,      //      : in  unsigned(31 downto 0);
    //-- debug port
    output logic RXD,     // : out std_logic;    -- to debug terminal 
    input  logic TXD,     // : in  std_logic;    -- from debug terminal
    //-- ext irq input
    input  logic eirq,    //    : in  std_logic;
    //-- para port out
    output u4_t  pout,     //    : out unsigned(3 downto 0)
    output logic fan_out
    );

 u32_t i_adr;   // insn addr
 u32_t i_dr;    // insn read data
 logic i_re;    // insn read enable
 logic i_rdy;   // insn data ready

 u32_t d_adr;   // mem addr
 u32_t d_dr;    // mem read data
 u4_t  d_we;    // mem write enable
 u32_t d_dw;    // mem write data
 logic d_re;    // mem read enable
 logic d_rdy;   // mem data ready
 logic d_be;    // mem bus big endian

 logic irq, irq2;

 u32_t d_dr1, d_dr2, d_dr3;
 //logic enaB, re1;
 
 
 //-- external bus connection
 assign adr = d_adr;
 assign we = d_we;
 assign re = d_re;
 assign dw = d_dw;
 
 assign i_rdy = 1'b1;
 assign d_rdy = rdy;
 assign d_be = 1'b0;

 assign d_dr = d_dr3 | d_dr2 | d_dr1 | dr;

 //assign enaB = (d_re || (d_we != 'd0)) && d_adr < 32'h10000;
 
 assign irq = eirq || irq2;
 
// synthesis translate_off
  integer STDERR;
  initial begin
    STDERR = $fopen("stderr.out", "w");
  end
// synthesis translate_on

  always @(posedge cclk) begin
    if(d_we[0] && d_adr == 32'hffff0000)    // para port
      pout <= d_dw[3:0];
// synthesis translate_off
    else if(d_we[0] && d_adr == 32'hffff0004)
      $fwrite(STDERR, "%c", d_dw[7:0]);
//      $write("%c", d_dw[7:0]);
// synthesis translate_on
  end

  rv_core #(.Nregs(16), .debug(debug)) u_rv_core (
      .clk   (cclk),    // input  logic clk,
      .xreset(xreset), // input  logic xreset,
    
      .i_adr (i_adr),  // output u32_t i_adr,   // insn addr
      .i_dr  (i_dr),   // input  u32_t i_dr,    // insn read data
      .i_re  (i_re),   // output logic i_re,    // insn read enable
      .i_rdy (i_rdy),  // input  logic i_rdy,   // insn data ready
    
      .d_adr (d_adr),  // output u32_t d_adr,   // mem addr
      .d_dr  (d_dr),   // input  u32_t d_dr,    // mem read data
      .d_re  (d_re),   // output logic d_re,    // mem read enable
      .d_dw  (d_dw),   // output u32_t d_dw,    // mem write data
      .d_we  (d_we),   // output u4_t  d_we,    // mem write enable
      .d_rdy (d_rdy),  // input  logic d_rdy,   // mem data ready
      .d_be  (d_be),   // input  logic d_be,    // mem bus big endian
    
      .irq   (irq)     // input  logic irq  // interrupt request
  );

  rv_mem #(.Nk(Nk)) u_rv_mem (
      .clk    (cclk),    // input  logic clk,
      .xreset (xreset), // input  logic xreset,
      .rdy    (d_rdy),    // input  logic rdy,
      //-- Insn Bus (read only)
      .i_adr  (i_adr),    // input  u32_t i_adr,
      .i_dr   (i_dr),    // output u32_t i_dr,
      .i_re   (i_re),    // input  logic i_re,
      //-- Data Bus
      .d_adr  (d_adr),    // input  u32_t d_adr,
      .d_dw   (d_dw),    // input  u32_t d_dw,
      .d_dr   (d_dr1),    // output u32_t d_dr,
      .d_we   (d_we),    // input  u4_t  d_we,
      .d_re   (d_re),    // input  logic d_re,
      //-- Peripheral Bus
      .p_adr  (p_adr),    // input  u32_t p_adr,
      .p_dw   (p_dw),    // input  u32_t p_dw,
      .p_dr   (p_dr),    // output u32_t p_dr,
      .p_we   (p_we),    // input  logic p_we,
      .p_re   (p_re),    // input  logic p_re,
      .p_ack  (p_ack)     // output logic p_ack
  );


// peripheral : debug serial terminal
  logic  cs_sio, xtxd, xrxd, cs_sys;
  assign cs_sio = {d_adr[31:5],5'h0} == 32'hffff0020;
  assign cs_sys = {d_adr[31:5],5'h0} == 32'hffff0040;

  rv_sio u_rv_sio (
    .clk  (cclk),
    .xreset(xreset),
    .adr  (d_adr[4:0]),
    .cs   (cs_sio), .rdy (d_rdy),
    .we   (d_we),  .re   (d_re),  .irq (irq2),
    .dw   (d_dw),  .dr   (d_dr2),	
    .txd  (xtxd),  .rxd  (xrxd),
    .dsr  (1'b0),  .dtr  (), .txen ()
  );
  assign RXD = xtxd;    // to CP2103 RXD
  assign xrxd = TXD;    // from CP2103 TXD

  rv_sysmon u_rv_sysmon(
    .clk  (cclk),
    .xreset(xreset),
    .adr  (d_adr[4:0]),
    .cs   (cs_sys), .rdy (d_rdy),
    .we   (d_we),  .re   (d_re),
    .dw   (d_dw),  .dr   (d_dr3),	
    .fan_out  (fan_out)
  );

endmodule



