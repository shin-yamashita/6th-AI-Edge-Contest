
`timescale 1ns/1ns
`include "../hdl/acc/logic_types.svh"

module tb_tfacc_rv();

//    parameter Np = 48;
//    parameter Np = 38;
//    parameter Np = 32;
//    parameter Np = 24;
    parameter Np = 16;
    
//----------------------------------------------------------
  import "DPI-C"  context task c_main(int b, int e);

  import "DPI-C"  pure function int mem_rd(int s, int adr);
  import "DPI-C"  pure function int mem_wr(int adr, int data);
  import "DPI-C"  context task compare_mem();
  export "DPI-C"  task reg_wr;
  export "DPI-C"  task reg_rd;
  export "DPI-C"  task nop;
  //----- debug -----
  import "DPI-C"  pure function int input_acces_check(int adr, int data);

  logic        clk = 1;
  
  // tfacc_memif  sr_cpu bus
  logic [31:0]      adr;    
  logic [3:0]       we = 4'b0000;     
  logic             re = 1'b0;     
  logic             rdy;    
  logic [31:0]      dw;     
  logic [31:0]      dr;
  logic             irq;


  always #5  clk <= !clk;	// 100MHz clock

  task reg_wr(input int a, input int data);
//    @(posedge clk);
    #1
    we  = 4'b1111;
    re  = 0;
    adr = a;
    dw  = data;
//    $display("w a: %h d:%d", adr, data);
    do
    @(posedge clk);
    while(!rdy);
  endtask

  task nop();
//    @(posedge clk);
    #1
    we  = 0;
    re  = 0;
    @(posedge clk);
  endtask

  task reg_rd(input int a, output int data);
 //   @(posedge clk);
    #1
    we  = 0;
    re  = 1;
    adr = a;
    do
    @(posedge clk);
    while(!rdy);
    #1
    re  = 0;
    data = dr;
//    $display("r a: %h d:%d", adr, data);
    @(posedge clk);
  endtask

//----------------------------------------------------------

/*---
logic [31:0] input_data[100000], filter_data[100000], output_data[100000], bias_data[100000], outref_data[100000];

initial begin
  $readmemh("../firm/acc/tinput_data.mem", input_data);
  $readmemh("../firm/acc/tfilter_data.mem", filter_data);
  $readmemh("../firm/acc/toutput_data.mem", outref_data);
  $readmemh("../firm/acc/tbias_data.mem", bias_data);
end
--*/

//-- tfacc_memif  axi bus
wire             M00_AXI_ACLK;		//	in
wire             M00_AXI_ARESETN;	//	in
wire [3 : 0]     M00_AXI_AWID;		//
wire [39 : 0]    M00_AXI_AWADDR;	//
wire [7 : 0]     M00_AXI_AWLEN;		//
wire [2 : 0]     M00_AXI_AWSIZE;	//
wire [1 : 0]     M00_AXI_AWBURST;	//
wire             M00_AXI_AWLOCK;	//
wire [3 : 0]     M00_AXI_AWCACHE;	//
wire [2 : 0]     M00_AXI_AWPROT;	//
wire [3 : 0]     M00_AXI_AWQOS;		//
wire             M00_AXI_AWVALID;	//
wire             M00_AXI_AWREADY;	//	in
wire [127 : 0]   M00_AXI_WDATA;		//
wire [15 : 0]    M00_AXI_WSTRB;		//
wire             M00_AXI_WLAST;		//
wire             M00_AXI_WVALID;	//
wire             M00_AXI_WREADY;	//	in
wire [3 : 0]     M00_AXI_BID;		//	in
wire [1 : 0]     M00_AXI_BRESP;		//	in	
wire             M00_AXI_BVALID;	//	in
wire             M00_AXI_BREADY;	//
wire [3 : 0]     M00_AXI_ARID ;		//
wire [39 : 0]    M00_AXI_ARADDR;	//
wire [7 : 0]     M00_AXI_ARLEN;		//
wire [2 : 0]     M00_AXI_ARSIZE;	//
wire [1 : 0]     M00_AXI_ARBURST;	//
wire             M00_AXI_ARLOCK;	//
wire [3 : 0]     M00_AXI_ARCACHE;	//
wire [2 : 0]     M00_AXI_ARPROT;	//
wire [3 : 0]     M00_AXI_ARQOS;		//
wire             M00_AXI_ARVALID;	//
wire             M00_AXI_ARREADY;	//	in
wire [3 : 0]     M00_AXI_RID;		//	in	
wire [127 : 0]   M00_AXI_RDATA;		//	in
wire [1 : 0]     M00_AXI_RRESP;		//	in
wire             M00_AXI_RLAST;		//	in
wire             M00_AXI_RVALID;	//	in
wire             M00_AXI_RREADY;	//

//-- bus
  logic xrst;
  logic [4:0]     fp;

axi_slave_bfm #(
    .C_S_AXI_ID_WIDTH      (4),
    .C_S_AXI_ADDR_WIDTH    (40),
    .C_S_AXI_DATA_WIDTH    (128),
    .C_S_AXI_AWUSER_WIDTH  (1),
    .C_S_AXI_ARUSER_WIDTH  (1),
    .C_S_AXI_WUSER_WIDTH   (1),
    .C_S_AXI_RUSER_WIDTH   (1),
    .C_S_AXI_BUSER_WIDTH   (1),

    .C_S_AXI_TARGET        (0),
    .C_OFFSET_WIDTH        (20), // 割り当てるRAMのアドレスのビット幅
    .C_S_AXI_BURST_LEN     (256),

    .WRITE_RANDOM_WAIT     (1), // Write Transactionデータ転送時にランダムなWaitを発生させる=1、Waitしない=0
    .READ_RANDOM_WAIT      (1), // Read Transactionデータ転送時にランダムなWaitを発生させる=1、Waitしない=0
    .READ_DATA_IS_INCREMENT(0), // Read TransactionでRAMのデータを読み出す=0、0はじまりの+1データを使う=1
    .RANDOM_BVALID_WAIT    (1)  // Write Transaction後、BVALIDをランダムにWaitする=1、ランダムにWaitしない=0
) u_axi_slave_bfm
(
    	// System Signals
  .ACLK         (clk),       //  input ACLK,
  .ARESETN      (xrst),      //  input ARESETN,

    	// Slave Interface Write Address Ports
  .S_AXI_AWID       (M00_AXI_AWID),      //  input   [C_S_AXI_ID_WIDTH-1 : 0]    S_AXI_AWID,
  .S_AXI_AWADDR     (M00_AXI_AWADDR),    //  input   [C_S_AXI_ADDR_WIDTH-1 : 0]  S_AXI_AWADDR,
  .S_AXI_AWLEN      (M00_AXI_AWLEN),     //  input   [8-1 : 0]                   S_AXI_AWLEN,
  .S_AXI_AWSIZE     (M00_AXI_AWSIZE),    //  input   [3-1 : 0]                   S_AXI_AWSIZE,
  .S_AXI_AWBURST    (M00_AXI_AWBURST),   //  input   [2-1 : 0]                   S_AXI_AWBURST,
  .S_AXI_AWLOCK     (M00_AXI_AWLOCK),    //  input   [1 : 0]                     S_AXI_AWLOCK,
  .S_AXI_AWCACHE    (M00_AXI_AWCACHE),   //  input   [4-1 : 0]                   S_AXI_AWCACHE,
  .S_AXI_AWPROT     (M00_AXI_AWPROT),    //  input   [3-1 : 0]                   S_AXI_AWPROT,
  .S_AXI_AWQOS      (M00_AXI_AWQOS),     //  input   [4-1 : 0]                   S_AXI_AWQOS,
  .S_AXI_AWUSER     (M00_AXI_AWUSER),    //  input   [C_S_AXI_AWUSER_WIDTH-1 :0] S_AXI_AWUSER,
  .S_AXI_AWVALID    (M00_AXI_AWVALID),   //  input                               S_AXI_AWVALID,
  .S_AXI_AWREADY    (M00_AXI_AWREADY),   //  output                              S_AXI_AWREADY,

    	// Slave Interface Write Data Ports
  .S_AXI_WDATA      (M00_AXI_WDATA),      //  input   [C_S_AXI_DATA_WIDTH-1 : 0]  S_AXI_WDATA,
  .S_AXI_WSTRB      (M00_AXI_WSTRB),      //  input   [C_S_AXI_DATA_WIDTH/8-1 : 0]S_AXI_WSTRB,
  .S_AXI_WLAST      (M00_AXI_WLAST),      //  input                               S_AXI_WLAST,
  .S_AXI_WUSER      (M00_AXI_WUSER),      //  input   [C_S_AXI_WUSER_WIDTH-1 : 0] S_AXI_WUSER,
  .S_AXI_WVALID     (M00_AXI_WVALID),     //  input                               S_AXI_WVALID,
  .S_AXI_WREADY     (M00_AXI_WREADY),     //  output                              S_AXI_WREADY,

    	// Slave Interface Write Response Ports
  .S_AXI_BID        (M00_AXI_BID),      //  output  [C_S_AXI_ID_WIDTH-1 : 0]    S_AXI_BID,
  .S_AXI_BRESP      (M00_AXI_BRESP),    //  output  [2-1 : 0]                   S_AXI_BRESP,
  .S_AXI_BUSER      (M00_AXI_BUSER),    //  output  [C_S_AXI_BUSER_WIDTH-1 : 0] S_AXI_BUSER,
  .S_AXI_BVALID     (M00_AXI_BVALID),   //  output                              S_AXI_BVALID,
  .S_AXI_BREADY     (M00_AXI_BREADY),   //  input                               S_AXI_BREADY,

    	// Slave Interface Read Address Ports
  .S_AXI_ARID       (M00_AXI_ARID),     //  input   [C_S_AXI_ID_WIDTH-1 : 0]    S_AXI_ARID,
  .S_AXI_ARADDR     (M00_AXI_ARADDR),   //  input   [C_S_AXI_ADDR_WIDTH-1 : 0]  S_AXI_ARADDR,
  .S_AXI_ARLEN      (M00_AXI_ARLEN),    //  input   [8-1 : 0]                   S_AXI_ARLEN,
  .S_AXI_ARSIZE     (M00_AXI_ARSIZE),   //  input   [3-1 : 0]                   S_AXI_ARSIZE,
  .S_AXI_ARBURST    (M00_AXI_ARBURST),  //  input   [2-1 : 0]                   S_AXI_ARBURST,
  .S_AXI_ARLOCK     (M00_AXI_ARLOCK),   //  input   [2-1 : 0]                   S_AXI_ARLOCK,
  .S_AXI_ARCACHE    (M00_AXI_ARCACHE),  //  input   [4-1 : 0]                   S_AXI_ARCACHE,
  .S_AXI_ARPROT     (M00_AXI_ARPROT),   //  input   [3-1 : 0]                   S_AXI_ARPROT,
  .S_AXI_ARQOS      (M00_AXI_ARQOS),    //  input   [4-1 : 0]                   S_AXI_ARQOS,
  .S_AXI_ARUSER     (M00_AXI_ARUSER),   //  input   [C_S_AXI_ARUSER_WIDTH-1 : 0]S_AXI_ARUSER,
  .S_AXI_ARVALID    (M00_AXI_ARVALID),  //  input                               S_AXI_ARVALID,
  .S_AXI_ARREADY    (M00_AXI_ARREADY),  //  output                              S_AXI_ARREADY,

    	// Slave Interface Read Data Ports
  .S_AXI_RID        (M00_AXI_RID),      //  output  reg [C_S_AXI_ID_WIDTH-1: 0] S_AXI_RID,
  .S_AXI_RDATA      (M00_AXI_RDATA),    //  output  [C_S_AXI_DATA_WIDTH-1 : 0]  S_AXI_RDATA,
  .S_AXI_RRESP      (M00_AXI_RRESP),    //  output  reg [2-1 : 0]               S_AXI_RRESP,
  .S_AXI_RLAST      (M00_AXI_RLAST),    //  output                              S_AXI_RLAST,
  .S_AXI_RUSER      (M00_AXI_RUSER),    //  output  [C_S_AXI_RUSER_WIDTH-1 : 0] S_AXI_RUSER,
  .S_AXI_RVALID     (M00_AXI_RVALID),   //  output                              S_AXI_RVALID,
  .S_AXI_RREADY     (M00_AXI_RREADY)    //  input                               S_AXI_RREADY
);

//tfacc_core u_tfacc_core( .*, .fp() );
    
tfacc_memif #(.Np(Np),.debug(1))
    u_tfacc_memif(.*, .cclk(clk), .xreset(xrst), .M00_AXI_ACLK(clk), .M00_AXI_ARESETN(xrst), .rdy(rdy), .dr(dr));

bit i_re[Np], i_rdy[Np];
u32_t i_adr[Np];
u8_t in_d[Np];
bit iachk[Np];
generate
    for(genvar i = 0; i < Np; i++) begin
//        assign i_re[i]  = tb_tfacc_rv.u_tfacc_memif.u_tfacc_core.i_re[i];
//        assign i_adr[i] = tb_tfacc_rv.u_tfacc_memif.u_tfacc_core.i_adr[i];
        assign in_d[i] = tb_tfacc_rv.u_tfacc_memif.u_tfacc_core.in_d[i];
//        assign i_rdy[i]  = tb_tfacc_rv.u_tfacc_memif.u_tfacc_core.i_rdy[i];
        always@(posedge clk) begin
            i_re[i]  <= tb_tfacc_rv.u_tfacc_memif.u_tfacc_core.i_re[i];
            i_rdy[i] <= tb_tfacc_rv.u_tfacc_memif.u_tfacc_core.i_rdy[i];
            i_adr[i] <= tb_tfacc_rv.u_tfacc_memif.u_tfacc_core.i_adr[i];
            if(i_re[i] && i_rdy[i]) begin
                iachk[i] <= input_acces_check(i_adr[i], in_d[i]);
            end
        end
   end
endgenerate

int stage_b, stage_e;

initial begin
    stage_b = 0;
    stage_e = 0;
    if($value$plusargs("b=%d", stage_b)) $display("b=%d", stage_b);
    if($value$plusargs("e=%d", stage_e)) $display("e=%d", stage_e);
    $display("stage begin:%d end:%d", stage_b, stage_e);
    c_main(stage_b, stage_e);
end

real simtime;

initial begin
    simtime = $realtime;
    xrst = 1'b0;
    #(100)
    xrst = 1'b1;
end

int st, runcnt, nrun, outH;

int runcount = 500;
//int matchcount = 0;
//int misscount = 0;
logic run, term = 0, eval = 0;
assign run = u_tfacc_memif.u_tfacc_core.run;

always@(posedge clk) begin
    if(we && adr == 'hffff0800) begin
        term <= dw[0];
        eval <= dw[1];
    end
    
    if(run) runcount <= runcount > 20000 ? 20000 : (runcount + 1);
    else runcount <= runcount - 1;
/*    if(acl && acvalid) begin
        for(int i = 0; i < Np; i++) begin
            if(oen[i]) begin
                if(match[i]) matchcount = matchcount + 1;
                else misscount = misscount + 1;
            end
        end
    end
*/
    if(eval) begin
        compare_mem();
        eval <= 0;
        $timeformat(-3, 3, " ms", 12);
        $display("Current time:%t, elapsed:%t", $realtime, $realtime - simtime);
        simtime = $realtime;
    end
//    if(runcount <= 0 || term) begin
    if(term) begin
 //       $display("match : %d", matchcount);
 //       $display("miss  : %d", misscount);
//        compare_mem();
        $finish;
    end
end


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
//u32_t adr;     //     : out unsigned(31 downto 0);
//u4_t  we;      //      : out std_logic_vector(3 downto 0);
//logic re;      //      : out std_logic;
//logic rdy = 1;     //     : in  std_logic;
//u32_t dw;      //      : out unsigned(31 downto 0);
//u32_t dr;      //      : in  unsigned(31 downto 0);
//-- debug port
logic RXD;     // : out std_logic;    -- to debug terminal 
logic TXD;     // : in  std_logic;    -- from debug terminal
//-- ext irq input
logic eirq = '0;    //    : in  std_logic;
//-- para port out
u4_t  pout;     //    : out unsigned(7 downto 0)
logic fan_out;

rv32_core #(.debug(0)) u_rv32_core (.*,  .cclk(clk), .xreset(xrst));


endmodule


