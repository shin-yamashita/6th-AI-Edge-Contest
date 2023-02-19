
//
// 2019/11/08 200MHz MET

`timescale 1ns/1ns
`include "logic_types.svh"

parameter SYS_exit = 93;

module tb_rv32_core #(parameter debug = 1) ();

 logic rxd, txd, CTS, RTS;

logic cclk = 1;    //    : in    std_logic;
logic xreset;  //  : in  std_logic;
//-- memory access bus
u32_t p_adr;   //   : in  unsigned(31 downto 0);
logic p_we = 0;    //    : in  std_logic;
logic p_re = 0;    //    : in  std_logic;
u32_t p_dw;    //    : in  unsigned(31 downto 0);
u32_t p_dr;    //    : out unsigned(31 downto 0);
logic p_ack;   //   : out std_logic;
//-- data bus
u32_t adr;     //     : out unsigned(31 downto 0);
u4_t  we;      //      : out std_logic_vector(3 downto 0);
logic re;      //      : out std_logic;
logic rdy = 1;     //     : in  std_logic;
u32_t dw;      //      : out unsigned(31 downto 0);
u32_t dr;      //      : in  unsigned(31 downto 0);
//-- debug port
logic RXD;     // : out std_logic;    -- to debug terminal 
logic TXD;     // : in  std_logic;    -- from debug terminal
//-- ext irq input
logic eirq;    //    : in  std_logic;
//-- para port out
u4_t  pout;     //    : out unsigned(7 downto 0)
logic fan_out;

 always #5       // 100MHz
        cclk <= !cclk;

 initial begin
   xreset = 1'b0;
   #50
   @(posedge cclk)
   xreset = 1'b1;

 end

 u32_t ir, rwdat;

 rv32_core #(.debug(debug)) u_rv32_core (.*);

// bit i_dr_match, d_dr_match;
// assign i_dr_match = u_rvc.i_dr == u_rvc.i_dr_b;
// assign d_dr_match = u_rvc.d_dr1 == u_rvc.d_dr1_b;

 assign ir = u_rv32_core.u_rv_core.IR;
 assign rwdat = u_rv32_core.u_rv_core.rwdat[0];

 always@(posedge cclk) begin
   if(ir == 32'h00000073 && rwdat == SYS_exit) begin
     $display("*** ecall %d", rwdat);
     # 50 $finish;
   end
 end

endmodule



