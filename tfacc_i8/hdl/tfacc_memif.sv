//-- memif.vhd
//-- DDR3 interface
//--
`timescale 1ns/1ns
//`include "acc/logic_types.svh"

module tfacc_memif
    (
//-- bus
    input  wire         cclk,
    input  wire         xreset,
    input  wire [31:0]  adr,	
    input  wire [3:0]   we,	
    input  wire         re,	
    output wire         rdy,	
    input  wire [31:0]  dw,	
    output wire [31:0]  dr,
    output wire         irq,
    
//-- axi
    input  wire         M00_AXI_ACLK,
    input  wire         M00_AXI_ARESETN,
    output wire [3 : 0] M00_AXI_AWID,
    output wire [39 : 0] M00_AXI_AWADDR,
    output wire [7 : 0] M00_AXI_AWLEN,
    output wire [2 : 0] M00_AXI_AWSIZE,
    output wire [1 : 0] M00_AXI_AWBURST,
    output wire         M00_AXI_AWLOCK,
    output wire [3 : 0] M00_AXI_AWCACHE,
    output wire [2 : 0] M00_AXI_AWPROT,
    output wire [3 : 0] M00_AXI_AWQOS,
    output wire         M00_AXI_AWVALID,
    input  wire         M00_AXI_AWREADY,
    output wire [127 : 0] M00_AXI_WDATA,
    output wire [15 : 0] M00_AXI_WSTRB,
    output wire         M00_AXI_WLAST,
    output wire         M00_AXI_WVALID,
    input  wire         M00_AXI_WREADY,
    input  wire [3 : 0] M00_AXI_BID,
    input  wire [1 : 0] M00_AXI_BRESP,
    input  wire         M00_AXI_BVALID,
    output wire         M00_AXI_BREADY,
    output wire [3 : 0] M00_AXI_ARID,
    output wire [39 : 0] M00_AXI_ARADDR,
    output wire [7 : 0] M00_AXI_ARLEN,
    output wire [2 : 0] M00_AXI_ARSIZE,
    output wire [1 : 0] M00_AXI_ARBURST,
    output wire         M00_AXI_ARLOCK,
    output wire [3 : 0] M00_AXI_ARCACHE,
    output wire [2 : 0] M00_AXI_ARPROT,
    output wire [3 : 0] M00_AXI_ARQOS,
    output wire         M00_AXI_ARVALID,
    input  wire         M00_AXI_ARREADY,
    input  wire [3 : 0] M00_AXI_RID,
    input  wire [127 : 0] M00_AXI_RDATA,
    input  wire [1 : 0] M00_AXI_RRESP,
    input  wire         M00_AXI_RLAST,
    input  wire         M00_AXI_RVALID,
    output wire         M00_AXI_RREADY,

    output wire [4:0]   fp
);

//parameter Np = 16;
//parameter Np = 20;
//parameter Np = 24;
//parameter Np = 26;
parameter Np = 32;
//parameter Np = 38;
//parameter Np = 40;    // not routeable
//parameter Np = 42;    // LUT over 4757/4727

parameter debug = 0;

  // Wire declarations
      
wire  aclk;
wire  arst_n;

// Start of User Design top instance

assign arst_n = M00_AXI_ARESETN;
assign aclk   = M00_AXI_ACLK;

// End of User Design top instance

wire [0 : 0] S00_AXI_AWID,    S01_AXI_AWID,     S02_AXI_AWID,    S03_AXI_AWID,    S04_AXI_AWID, S05_AXI_AWID;
wire [39 : 0] S00_AXI_AWADDR, S01_AXI_AWADDR,   S02_AXI_AWADDR,  S03_AXI_AWADDR,  S04_AXI_AWADDR, S05_AXI_AWADDR;
wire [7 : 0] S00_AXI_AWLEN,   S01_AXI_AWLEN,    S02_AXI_AWLEN,   S03_AXI_AWLEN,   S04_AXI_AWLEN, S05_AXI_AWLEN;
wire [2 : 0] S_AXI_AWSIZE;
wire [1 : 0] S_AXI_AWBURST;
wire         S_AXI_AWLOCK;
wire [3 : 0] S_AXI_AWCACHE;
wire [2 : 0] S_AXI_AWPROT;
wire [3 : 0] S_AXI_AWQOS;
wire         S00_AXI_AWVALID, S01_AXI_AWVALID,  S02_AXI_AWVALID,S03_AXI_AWVALID,  S04_AXI_AWVALID, S05_AXI_AWVALID;
wire         S00_AXI_AWREADY, S01_AXI_AWREADY,  S02_AXI_AWREADY,S03_AXI_AWREADY,  S04_AXI_AWREADY, S05_AXI_AWREADY;
wire [63 : 0] S00_AXI_WDATA;
wire [63 : 0]                 S01_AXI_WDATA,    S02_AXI_WDATA,  S03_AXI_WDATA,    S04_AXI_WDATA;
wire [31 : 0]                 S05_AXI_WDATA;
wire [7 : 0] S00_AXI_WSTRB;
wire [7 : 0]                  S01_AXI_WSTRB,    S02_AXI_WSTRB,  S03_AXI_WSTRB,    S04_AXI_WSTRB;
wire [3 : 0]                  S05_AXI_WSTRB;

wire         S00_AXI_WLAST,   S01_AXI_WLAST,    S02_AXI_WLAST,  S03_AXI_WLAST,    S04_AXI_WLAST,  S05_AXI_WLAST;
wire         S00_AXI_WVALID,  S01_AXI_WVALID,   S02_AXI_WVALID, S03_AXI_WVALID,   S04_AXI_WVALID, S05_AXI_WVALID;
wire         S00_AXI_WREADY,  S01_AXI_WREADY,   S02_AXI_WREADY, S03_AXI_WREADY,   S04_AXI_WREADY, S05_AXI_WREADY;


wire [0 : 0] S00_AXI_BID,     S01_AXI_BID,      S02_AXI_BID,    S03_AXI_BID,      S04_AXI_BID ,   S05_AXI_BID;
wire [1 : 0] S00_AXI_BRESP,   S01_AXI_BRESP,    S02_AXI_BRESP,  S03_AXI_BRESP,    S04_AXI_BRESP,  S05_AXI_BRESP;
wire         S00_AXI_BVALID,  S01_AXI_BVALID,   S02_AXI_BVALID, S03_AXI_BVALID,   S04_AXI_BVALID, S05_AXI_BVALID;
wire         S00_AXI_BREADY,  S01_AXI_BREADY,   S02_AXI_BREADY, S03_AXI_BREADY,   S04_AXI_BREADY, S05_AXI_BREADY;
wire [0 : 0] S00_AXI_ARID,    S01_AXI_ARID,     S02_AXI_ARID,   S03_AXI_ARID,     S04_AXI_ARID,   S05_AXI_ARID;
wire [39 : 0] S00_AXI_ARADDR, S01_AXI_ARADDR,   S02_AXI_ARADDR, S03_AXI_ARADDR,   S04_AXI_ARADDR, S05_AXI_ARADDR;
wire [7 : 0] S00_AXI_ARLEN,   S01_AXI_ARLEN,    S02_AXI_ARLEN,  S03_AXI_ARLEN,    S04_AXI_ARLEN,  S05_AXI_ARLEN;
wire [2 : 0] S_AXI_ARSIZE;
wire [1 : 0] S_AXI_ARBURST;
wire         S_AXI_ARLOCK;
wire [3 : 0] S_AXI_ARCACHE;
wire [2 : 0] S_AXI_ARPROT;
wire [3 : 0] S_AXI_ARQOS;
wire         S00_AXI_ARVALID, S01_AXI_ARVALID,  S02_AXI_ARVALID,S03_AXI_ARVALID,  S04_AXI_ARVALID, S05_AXI_ARVALID;
wire         S00_AXI_ARREADY, S01_AXI_ARREADY,  S02_AXI_ARREADY,S03_AXI_ARREADY,  S04_AXI_ARREADY, S05_AXI_ARREADY;
wire [0 : 0] S00_AXI_RID,     S01_AXI_RID,      S02_AXI_RID,    S03_AXI_RID,      S04_AXI_RID,     S05_AXI_RID;
wire [63 : 0] S00_AXI_RDATA;
wire [63 : 0]                 S01_AXI_RDATA,    S02_AXI_RDATA,  S03_AXI_RDATA,    S04_AXI_RDATA;
wire [31 : 0]                 S05_AXI_RDATA;
wire [1 : 0] S00_AXI_RRESP,   S01_AXI_RRESP,    S02_AXI_RRESP,  S03_AXI_RRESP,    S04_AXI_RRESP,  S05_AXI_RRESP;
wire         S00_AXI_RLAST,   S01_AXI_RLAST,    S02_AXI_RLAST,  S03_AXI_RLAST,    S04_AXI_RLAST,  S05_AXI_RLAST;
wire         S00_AXI_RVALID,  S01_AXI_RVALID,   S02_AXI_RVALID, S03_AXI_RVALID,   S04_AXI_RVALID, S05_AXI_RVALID;
wire         S00_AXI_RREADY,  S01_AXI_RREADY,   S02_AXI_RREADY, S03_AXI_RREADY,   S04_AXI_RREADY, S05_AXI_RREADY ;

wire [2 : 0] S0_AXI_AWSIZE;
wire [1 : 0] S0_AXI_AWBURST;
wire         S0_AXI_AWLOCK;
wire [3 : 0] S0_AXI_AWCACHE;
wire [2 : 0] S0_AXI_AWPROT;
wire [3 : 0] S0_AXI_AWQOS;
wire [2 : 0] S0_AXI_ARSIZE;
wire [1 : 0] S0_AXI_ARBURST;
wire         S0_AXI_ARLOCK;
wire [3 : 0] S0_AXI_ARCACHE;
wire [2 : 0] S0_AXI_ARPROT;
wire [3 : 0] S0_AXI_ARQOS;

assign S0_AXI_AWSIZE  = 3'b011;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^3 = 8 byte
assign S0_AXI_AWBURST = 2'b01;	// Burst type 00:FIXED 01:INCR 
assign S0_AXI_AWLOCK  = 1'b0;	// AXI4 does not support locked transactions. 
assign S0_AXI_AWCACHE = 4'b0011; // Memory types 0:Device Non-bufferable  1:Device Bufferable 
assign S0_AXI_AWPROT  = 3'b000;	// Access permissions pp71
assign S0_AXI_AWQOS   = 4'b0;	// Quarity of service

assign S0_AXI_ARSIZE  = 3'b011;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^3 = 8 byte
assign S0_AXI_ARBURST = 2'b01;	// Burst type 00:FIXED 01:INCR 
assign S0_AXI_ARLOCK  = 1'b0;	// AXI4 does not support locked transactions. 
assign S0_AXI_ARCACHE = 4'b0011; // Memory types 0:Device Non-bufferable  1:Device Bufferable 
assign S0_AXI_ARPROT  = 3'b000;	// Access permissions pp71
assign S0_AXI_ARQOS   = 4'b0;	// Quarity of service

assign S_AXI_AWSIZE  = 3'b010;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^2 = 4 byte
assign S_AXI_AWBURST = 2'b01;	// Burst type 00:FIXED 01:INCR 
assign S_AXI_AWLOCK  = 1'b0;	// AXI4 does not support locked transactions. 
assign S_AXI_AWCACHE = 4'b0011;	// Memory types 0:Device Non-bufferable  1:Device Bufferable 
assign S_AXI_AWPROT  = 3'b000;	// Access permissions pp71
assign S_AXI_AWQOS   = 4'b0;	// Quarity of service

assign S_AXI_ARSIZE  = 3'b011;	// The maximum number of bytes to transfer in each data transfer, or beat, in a burst.  2^3 = 8 byte
assign S_AXI_ARBURST = 2'b01;	// Burst type 00:FIXED 01:INCR 
assign S_AXI_ARLOCK  = 1'b0;	// AXI4 does not support locked transactions. 
assign S_AXI_ARCACHE = 4'b0011;	// Memory types 0:Device Non-bufferable  1:Device Bufferable 
assign S_AXI_ARPROT  = 3'b000;	// Access permissions pp71
assign S_AXI_ARQOS   = 4'b0;	// Quarity of service

// input 

assign S00_AXI_AWID = {1'b1};
assign S01_AXI_AWID = {1'b1};
assign S02_AXI_AWID = {1'b1};
assign S03_AXI_AWID = {1'b1};
assign S04_AXI_AWID = {1'b1};
assign S05_AXI_AWID = {1'b1};

assign S00_AXI_ARID = {1'b1};
assign S01_AXI_ARID = {1'b1};
assign S02_AXI_ARID = {1'b1};
assign S03_AXI_ARID = {1'b1};
assign S04_AXI_ARID = {1'b1};
assign S05_AXI_ARID = {1'b1};

//assign S00_AXI_WSTRB = 8'b11111111;
assign S01_AXI_WSTRB = 8'h00;	// read only
assign S02_AXI_WSTRB = 8'h00;
assign S03_AXI_WSTRB = 8'h00;
assign S04_AXI_WSTRB = 8'h00;
assign S05_AXI_WSTRB = 4'b1111;

assign S00_AXI_BREADY  = 1'b1;
assign S01_AXI_BREADY  = 1'b1;
assign S02_AXI_BREADY  = 1'b1;
assign S03_AXI_BREADY  = 1'b1;
assign S04_AXI_BREADY  = 1'b1;
assign S05_AXI_BREADY  = 1'b1;

//***************************************************************************
axi_ic u_aci_ic (
  .INTERCONNECT_ACLK    (aclk),        		// input wire INTERCONNECT_ACLK
  .INTERCONNECT_ARESETN (arst_n),  		// input wire INTERCONNECT_ARESETN
  .S00_AXI_ARESET_OUT_N (),  			// output wire S00_AXI_ARESET_OUT_N
  .S00_AXI_ACLK         (aclk),                 // input wire S00_AXI_ACLK
  .S00_AXI_AWID         (S00_AXI_AWID),       	// input wire [0 : 0] S00_AXI_AWID
  .S00_AXI_AWADDR       (S00_AXI_AWADDR),       // input wire [39 : 0] S00_AXI_AWADDR
  .S00_AXI_AWLEN        (S00_AXI_AWLEN),        // input wire [7 : 0] S00_AXI_AWLEN
  .S00_AXI_AWSIZE       (S0_AXI_AWSIZE),        // input wire [2 : 0] S00_AXI_AWSIZE
  .S00_AXI_AWBURST      (S0_AXI_AWBURST),       // input wire [1 : 0] S00_AXI_AWBURST
  .S00_AXI_AWLOCK       (S0_AXI_AWLOCK),        // input wire S00_AXI_AWLOCK
  .S00_AXI_AWCACHE      (S0_AXI_AWCACHE),       // input wire [3 : 0] S00_AXI_AWCACHE
  .S00_AXI_AWPROT       (S0_AXI_AWPROT),        // input wire [2 : 0] S00_AXI_AWPROT
  .S00_AXI_AWQOS        (S0_AXI_AWQOS),         // input wire [3 : 0] S00_AXI_AWQOS
  .S00_AXI_AWVALID      (S00_AXI_AWVALID),      // input wire S00_AXI_AWVALID
  .S00_AXI_AWREADY      (S00_AXI_AWREADY),      // output wire S00_AXI_AWREADY
  .S00_AXI_WDATA        (S00_AXI_WDATA),        // input wire [63 : 0] S00_AXI_WDATA
  .S00_AXI_WSTRB        (S00_AXI_WSTRB),        // input wire [7 : 0] S00_AXI_WSTRB
  .S00_AXI_WLAST        (S00_AXI_WLAST),        // input wire S00_AXI_WLAST
  .S00_AXI_WVALID       (S00_AXI_WVALID),       // input wire S00_AXI_WVALID
  .S00_AXI_WREADY       (S00_AXI_WREADY),       // output wire S00_AXI_WREADY
  .S00_AXI_BID          (S00_AXI_BID),          // output wire [0 : 0] S00_AXI_BID
  .S00_AXI_BRESP        (S00_AXI_BRESP),        // output wire [1 : 0] S00_AXI_BRESP
  .S00_AXI_BVALID       (S00_AXI_BVALID),       // output wire S00_AXI_BVALID
  .S00_AXI_BREADY       (S00_AXI_BREADY),       // input wire S00_AXI_BREADY
  .S00_AXI_ARID         (S00_AXI_ARID),         // input wire [0 : 0] S00_AXI_ARID
  .S00_AXI_ARADDR       (S00_AXI_ARADDR),       // input wire [39 : 0] S00_AXI_ARADDR
  .S00_AXI_ARLEN        (S00_AXI_ARLEN),        // input wire [7 : 0] S00_AXI_ARLEN
  .S00_AXI_ARSIZE       (S0_AXI_ARSIZE),        // input wire [2 : 0] S00_AXI_ARSIZE
  .S00_AXI_ARBURST      (S0_AXI_ARBURST),       // input wire [1 : 0] S00_AXI_ARBURST
  .S00_AXI_ARLOCK       (S0_AXI_ARLOCK),        // input wire S00_AXI_ARLOCK
  .S00_AXI_ARCACHE      (S0_AXI_ARCACHE),       // input wire [3 : 0] S00_AXI_ARCACHE
  .S00_AXI_ARPROT       (S0_AXI_ARPROT),        // input wire [2 : 0] S00_AXI_ARPROT
  .S00_AXI_ARQOS        (S0_AXI_ARQOS),         // input wire [3 : 0] S00_AXI_ARQOS
  .S00_AXI_ARVALID      (S00_AXI_ARVALID),      // input wire S00_AXI_ARVALID
  .S00_AXI_ARREADY      (S00_AXI_ARREADY),      // output wire S00_AXI_ARREADY
  .S00_AXI_RID          (S00_AXI_RID),          // output wire [0 : 0] S00_AXI_RID
  .S00_AXI_RDATA        (S00_AXI_RDATA),        // output wire [63 : 0] S00_AXI_RDATA
  .S00_AXI_RRESP        (S00_AXI_RRESP),        // output wire [1 : 0] S00_AXI_RRESP
  .S00_AXI_RLAST        (S00_AXI_RLAST),        // output wire S00_AXI_RLAST
  .S00_AXI_RVALID       (S00_AXI_RVALID),       // output wire S00_AXI_RVALID
  .S00_AXI_RREADY       (S00_AXI_RREADY),       // input wire S00_AXI_RREADY

  .S01_AXI_ARESET_OUT_N (),  			// output wire S01_AXI_ARESET_OUT_N
  .S01_AXI_ACLK         (aclk),                 // input wire S01_AXI_ACLK
  .S01_AXI_AWID         (S01_AXI_AWID),         // input wire [0 : 0] S01_AXI_AWID
  .S01_AXI_AWADDR       (S01_AXI_AWADDR),       // input wire [39 : 0] S01_AXI_AWADDR
  .S01_AXI_AWLEN        (S01_AXI_AWLEN),        // input wire [7 : 0] S01_AXI_AWLEN
  .S01_AXI_AWSIZE       (S_AXI_AWSIZE),         // input wire [2 : 0] S01_AXI_AWSIZE
  .S01_AXI_AWBURST      (S_AXI_AWBURST),        // input wire [1 : 0] S01_AXI_AWBURST
  .S01_AXI_AWLOCK       (S_AXI_AWLOCK),         // input wire S01_AXI_AWLOCK
  .S01_AXI_AWCACHE      (S_AXI_AWCACHE),        // input wire [3 : 0] S01_AXI_AWCACHE
  .S01_AXI_AWPROT       (S_AXI_AWPROT),         // input wire [2 : 0] S01_AXI_AWPROT
  .S01_AXI_AWQOS        (S_AXI_AWQOS),          // input wire [3 : 0] S01_AXI_AWQOS
  .S01_AXI_AWVALID      (S01_AXI_AWVALID),      // input wire S01_AXI_AWVALID
  .S01_AXI_AWREADY      (S01_AXI_AWREADY),      // output wire S01_AXI_AWREADY
  .S01_AXI_WDATA        (S01_AXI_WDATA),        // input wire [63 : 0] S01_AXI_WDATA
  .S01_AXI_WSTRB        (S01_AXI_WSTRB),        // input wire [7 : 0] S01_AXI_WSTRB
  .S01_AXI_WLAST        (S01_AXI_WLAST),        // input wire S01_AXI_WLAST
  .S01_AXI_WVALID       (S01_AXI_WVALID),       // input wire S01_AXI_WVALID
  .S01_AXI_WREADY       (S01_AXI_WREADY),       // output wire S01_AXI_WREADY
  .S01_AXI_BID          (S01_AXI_BID),          // output wire [0 : 0] S01_AXI_BID
  .S01_AXI_BRESP        (S01_AXI_BRESP),        // output wire [1 : 0] S01_AXI_BRESP
  .S01_AXI_BVALID       (S01_AXI_BVALID),       // output wire S01_AXI_BVALID
  .S01_AXI_BREADY       (S01_AXI_BREADY),       // input wire S01_AXI_BREADY
  .S01_AXI_ARID         (S01_AXI_ARID),         // input wire [0 : 0] S01_AXI_ARID
  .S01_AXI_ARADDR       (S01_AXI_ARADDR),       // input wire [39 : 0] S01_AXI_ARADDR
  .S01_AXI_ARLEN        (S01_AXI_ARLEN),        // input wire [7 : 0] S01_AXI_ARLEN
  .S01_AXI_ARSIZE       (S_AXI_ARSIZE),         // input wire [2 : 0] S01_AXI_ARSIZE
  .S01_AXI_ARBURST      (S_AXI_ARBURST),        // input wire [1 : 0] S01_AXI_ARBURST
  .S01_AXI_ARLOCK       (S_AXI_ARLOCK),         // input wire S01_AXI_ARLOCK
  .S01_AXI_ARCACHE      (S_AXI_ARCACHE),        // input wire [3 : 0] S01_AXI_ARCACHE
  .S01_AXI_ARPROT       (S_AXI_ARPROT),         // input wire [2 : 0] S01_AXI_ARPROT
  .S01_AXI_ARQOS        (S_AXI_ARQOS),          // input wire [3 : 0] S01_AXI_ARQOS
  .S01_AXI_ARVALID      (S01_AXI_ARVALID),      // input wire S01_AXI_ARVALID
  .S01_AXI_ARREADY      (S01_AXI_ARREADY),      // output wire S01_AXI_ARREADY
  .S01_AXI_RID          (S01_AXI_RID),          // output wire [0 : 0] S01_AXI_RID
  .S01_AXI_RDATA        (S01_AXI_RDATA),        // output wire [63 : 0] S01_AXI_RDATA
  .S01_AXI_RRESP        (S01_AXI_RRESP),        // output wire [1 : 0] S01_AXI_RRESP
  .S01_AXI_RLAST        (S01_AXI_RLAST),        // output wire S01_AXI_RLAST
  .S01_AXI_RVALID       (S01_AXI_RVALID),       // output wire S01_AXI_RVALID
  .S01_AXI_RREADY       (S01_AXI_RREADY),       // input wire S01_AXI_RREADY

  .S02_AXI_ARESET_OUT_N (),                  // output wire S02_AXI_ARESET_OUT_N
  .S02_AXI_ACLK         (aclk),                 // input wire S02_AXI_ACLK
  .S02_AXI_AWID         (S02_AXI_AWID),         // input wire [0 : 0] S02_AXI_AWID
  .S02_AXI_AWADDR       (S02_AXI_AWADDR),       // input wire [39 : 0] S02_AXI_AWADDR
  .S02_AXI_AWLEN        (S02_AXI_AWLEN),        // input wire [7 : 0] S02_AXI_AWLEN
  .S02_AXI_AWSIZE       (S_AXI_AWSIZE),         // input wire [2 : 0] S02_AXI_AWSIZE
  .S02_AXI_AWBURST      (S_AXI_AWBURST),        // input wire [1 : 0] S02_AXI_AWBURST
  .S02_AXI_AWLOCK       (S_AXI_AWLOCK),         // input wire S02_AXI_AWLOCK
  .S02_AXI_AWCACHE      (S_AXI_AWCACHE),        // input wire [3 : 0] S02_AXI_AWCACHE
  .S02_AXI_AWPROT       (S_AXI_AWPROT),         // input wire [2 : 0] S02_AXI_AWPROT
  .S02_AXI_AWQOS        (S_AXI_AWQOS),          // input wire [3 : 0] S02_AXI_AWQOS
  .S02_AXI_AWVALID      (S02_AXI_AWVALID),      // input wire S02_AXI_AWVALID
  .S02_AXI_AWREADY      (S02_AXI_AWREADY),      // output wire S02_AXI_AWREADY
  .S02_AXI_WDATA        (S02_AXI_WDATA),        // input wire [63 : 0] S02_AXI_WDATA
  .S02_AXI_WSTRB        (S02_AXI_WSTRB),        // input wire [7 : 0] S02_AXI_WSTRB
  .S02_AXI_WLAST        (S02_AXI_WLAST),        // input wire S02_AXI_WLAST
  .S02_AXI_WVALID       (S02_AXI_WVALID),       // input wire S02_AXI_WVALID
  .S02_AXI_WREADY       (S02_AXI_WREADY),       // output wire S02_AXI_WREADY
  .S02_AXI_BID          (S02_AXI_BID),          // output wire [0 : 0] S02_AXI_BID
  .S02_AXI_BRESP        (S02_AXI_BRESP),        // output wire [1 : 0] S02_AXI_BRESP
  .S02_AXI_BVALID       (S02_AXI_BVALID),       // output wire S02_AXI_BVALID
  .S02_AXI_BREADY       (S02_AXI_BREADY),       // input wire S02_AXI_BREADY
  .S02_AXI_ARID         (S02_AXI_ARID),         // input wire [0 : 0] S02_AXI_ARID
  .S02_AXI_ARADDR       (S02_AXI_ARADDR),       // input wire [39 : 0] S02_AXI_ARADDR
  .S02_AXI_ARLEN        (S02_AXI_ARLEN),        // input wire [7 : 0] S02_AXI_ARLEN
  .S02_AXI_ARSIZE       (S_AXI_ARSIZE),         // input wire [2 : 0] S02_AXI_ARSIZE
  .S02_AXI_ARBURST      (S_AXI_ARBURST),        // input wire [1 : 0] S02_AXI_ARBURST
  .S02_AXI_ARLOCK       (S_AXI_ARLOCK),         // input wire S02_AXI_ARLOCK
  .S02_AXI_ARCACHE      (S_AXI_ARCACHE),        // input wire [3 : 0] S02_AXI_ARCACHE
  .S02_AXI_ARPROT       (S_AXI_ARPROT),         // input wire [2 : 0] S02_AXI_ARPROT
  .S02_AXI_ARQOS        (S_AXI_ARQOS),          // input wire [3 : 0] S02_AXI_ARQOS
  .S02_AXI_ARVALID      (S02_AXI_ARVALID),      // input wire S02_AXI_ARVALID
  .S02_AXI_ARREADY      (S02_AXI_ARREADY),      // output wire S02_AXI_ARREADY
  .S02_AXI_RID          (S02_AXI_RID),          // output wire [0 : 0] S02_AXI_RID
  .S02_AXI_RDATA        (S02_AXI_RDATA),        // output wire [63 : 0] S02_AXI_RDATA
  .S02_AXI_RRESP        (S02_AXI_RRESP),        // output wire [1 : 0] S02_AXI_RRESP
  .S02_AXI_RLAST        (S02_AXI_RLAST),        // output wire S02_AXI_RLAST
  .S02_AXI_RVALID       (S02_AXI_RVALID),       // output wire S02_AXI_RVALID
  .S02_AXI_RREADY       (S02_AXI_RREADY),       // input wire S02_AXI_RREADY

  .S03_AXI_ARESET_OUT_N (),                     // output wire S03_AXI_ARESET_OUT_N
  .S03_AXI_ACLK         (aclk),                 // input wire S03_AXI_ACLK
  .S03_AXI_AWID         (S03_AXI_AWID),         // input wire [0 : 0] S03_AXI_AWID
  .S03_AXI_AWADDR       (S03_AXI_AWADDR),       // input wire [39 : 0] S03_AXI_AWADDR
  .S03_AXI_AWLEN        (S03_AXI_AWLEN),        // input wire [7 : 0] S03_AXI_AWLEN
  .S03_AXI_AWSIZE       (S_AXI_AWSIZE),         // input wire [2 : 0] S03_AXI_AWSIZE
  .S03_AXI_AWBURST      (S_AXI_AWBURST),        // input wire [1 : 0] S03_AXI_AWBURST
  .S03_AXI_AWLOCK       (S_AXI_AWLOCK),         // input wire S03_AXI_AWLOCK
  .S03_AXI_AWCACHE      (S_AXI_AWCACHE),        // input wire [3 : 0] S03_AXI_AWCACHE
  .S03_AXI_AWPROT       (S_AXI_AWPROT),         // input wire [2 : 0] S03_AXI_AWPROT
  .S03_AXI_AWQOS        (4'b0),                 // input wire [3 : 0] S03_AXI_AWQOS
  .S03_AXI_AWVALID      (S03_AXI_AWVALID),      // input wire S03_AXI_AWVALID
  .S03_AXI_AWREADY      (S03_AXI_AWREADY),      // output wire S03_AXI_AWREADY
  .S03_AXI_WDATA        (S03_AXI_WDATA),        // input wire [63 : 0] S03_AXI_WDATA
  .S03_AXI_WSTRB        (S03_AXI_WSTRB),        // input wire [7 : 0] S03_AXI_WSTRB
  .S03_AXI_WLAST        (S03_AXI_WLAST),        // input wire S03_AXI_WLAST
  .S03_AXI_WVALID       (S03_AXI_WVALID),       // input wire S03_AXI_WVALID
  .S03_AXI_WREADY       (S03_AXI_WREADY),       // output wire S03_AXI_WREADY
  .S03_AXI_BID          (S03_AXI_BID),          // output wire [0 : 0] S03_AXI_BID
  .S03_AXI_BRESP        (S03_AXI_BRESP),        // output wire [1 : 0] S03_AXI_BRESP
  .S03_AXI_BVALID       (S03_AXI_BVALID),       // output wire S03_AXI_BVALID
  .S03_AXI_BREADY       (S03_AXI_BREADY),       // input wire S03_AXI_BREADY
  .S03_AXI_ARID         (S03_AXI_ARID),         // input wire [0 : 0] S03_AXI_ARID
  .S03_AXI_ARADDR       (S03_AXI_ARADDR),       // input wire [39 : 0] S03_AXI_ARADDR
  .S03_AXI_ARLEN        (S03_AXI_ARLEN),        // input wire [7 : 0] S03_AXI_ARLEN
  .S03_AXI_ARSIZE       (S_AXI_ARSIZE),         // input wire [2 : 0] S03_AXI_ARSIZE
  .S03_AXI_ARBURST      (S_AXI_ARBURST),        // input wire [1 : 0] S03_AXI_ARBURST
  .S03_AXI_ARLOCK       (S_AXI_ARLOCK),         // input wire S03_AXI_ARLOCK
  .S03_AXI_ARCACHE      (S_AXI_ARCACHE),        // input wire [3 : 0] S03_AXI_ARCACHE
  .S03_AXI_ARPROT       (S_AXI_ARPROT),         // input wire [2 : 0] S03_AXI_ARPROT
  .S03_AXI_ARQOS        (4'b0),                 // input wire [3 : 0] S03_AXI_ARQOS
  .S03_AXI_ARVALID      (S03_AXI_ARVALID),      // input wire S03_AXI_ARVALID
  .S03_AXI_ARREADY      (S03_AXI_ARREADY),      // output wire S03_AXI_ARREADY
  .S03_AXI_RID          (S03_AXI_RID),          // output wire [0 : 0] S03_AXI_RID
  .S03_AXI_RDATA        (S03_AXI_RDATA),        // output wire [63 : 0] S03_AXI_RDATA
  .S03_AXI_RRESP        (S03_AXI_RRESP),        // output wire [1 : 0] S03_AXI_RRESP
  .S03_AXI_RLAST        (S03_AXI_RLAST),        // output wire S03_AXI_RLAST
  .S03_AXI_RVALID       (S03_AXI_RVALID),       // output wire S03_AXI_RVALID
  .S03_AXI_RREADY       (S03_AXI_RREADY),       // input wire S03_AXI_RREADY

  .S04_AXI_ARESET_OUT_N (),             // output wire S04_AXI_ARESET_OUT_N
  .S04_AXI_ACLK     (aclk),                 // input wire S04_AXI_ACLK
  .S04_AXI_AWID     (S04_AXI_AWID),         // input wire [0 : 0] S04_AXI_AWID
  .S04_AXI_AWADDR   (S04_AXI_AWADDR),       // input wire [39 : 0] S04_AXI_AWADDR
  .S04_AXI_AWLEN    (S04_AXI_AWLEN),        // input wire [7 : 0] S04_AXI_AWLEN
  .S04_AXI_AWSIZE   (S_AXI_AWSIZE),         // input wire [2 : 0] S04_AXI_AWSIZE
  .S04_AXI_AWBURST  (S_AXI_AWBURST),        // input wire [1 : 0] S04_AXI_AWBURST
  .S04_AXI_AWLOCK   (S_AXI_AWLOCK),         // input wire S04_AXI_AWLOCK
  .S04_AXI_AWCACHE  (S_AXI_AWCACHE),        // input wire [3 : 0] S04_AXI_AWCACHE
  .S04_AXI_AWPROT   (S_AXI_AWPROT),         // input wire [2 : 0] S04_AXI_AWPROT
  .S04_AXI_AWQOS    (4'b0),                 // input wire [3 : 0] S04_AXI_AWQOS
  .S04_AXI_AWVALID  (S04_AXI_AWVALID),      // input wire S04_AXI_AWVALID
  .S04_AXI_AWREADY  (S04_AXI_AWREADY),      // output wire S04_AXI_AWREADY
  .S04_AXI_WDATA    (S04_AXI_WDATA),        // input wire [63 : 0] S04_AXI_WDATA
  .S04_AXI_WSTRB    (S04_AXI_WSTRB),        // input wire [7 : 0] S04_AXI_WSTRB
  .S04_AXI_WLAST    (S04_AXI_WLAST),        // input wire S04_AXI_WLAST
  .S04_AXI_WVALID   (S04_AXI_WVALID),       // input wire S04_AXI_WVALID
  .S04_AXI_WREADY   (S04_AXI_WREADY),       // output wire S04_AXI_WREADY
  .S04_AXI_BID      (S04_AXI_BID),          // output wire [0 : 0] S04_AXI_BID
  .S04_AXI_BRESP    (S04_AXI_BRESP),        // output wire [1 : 0] S04_AXI_BRESP
  .S04_AXI_BVALID   (S04_AXI_BVALID),       // output wire S04_AXI_BVALID
  .S04_AXI_BREADY   (S04_AXI_BREADY),       // input wire S04_AXI_BREADY
  .S04_AXI_ARID     (S04_AXI_ARID),         // input wire [0 : 0] S04_AXI_ARID
  .S04_AXI_ARADDR   (S04_AXI_ARADDR),       // input wire [39 : 0] S04_AXI_ARADDR
  .S04_AXI_ARLEN    (S04_AXI_ARLEN),        // input wire [7 : 0] S04_AXI_ARLEN
  .S04_AXI_ARSIZE   (S_AXI_ARSIZE),         // input wire [2 : 0] S04_AXI_ARSIZE
  .S04_AXI_ARBURST  (S_AXI_ARBURST),        // input wire [1 : 0] S04_AXI_ARBURST
  .S04_AXI_ARLOCK   (S_AXI_ARLOCK),         // input wire S04_AXI_ARLOCK
  .S04_AXI_ARCACHE  (S_AXI_ARCACHE),        // input wire [3 : 0] S04_AXI_ARCACHE
  .S04_AXI_ARPROT   (S_AXI_ARPROT),         // input wire [2 : 0] S04_AXI_ARPROT
  .S04_AXI_ARQOS    (4'b0),                 // input wire [3 : 0] S04_AXI_ARQOS
  .S04_AXI_ARVALID  (S04_AXI_ARVALID),      // input wire S04_AXI_ARVALID
  .S04_AXI_ARREADY  (S04_AXI_ARREADY),      // output wire S04_AXI_ARREADY
  .S04_AXI_RID      (S04_AXI_RID),          // output wire [0 : 0] S04_AXI_RID
  .S04_AXI_RDATA    (S04_AXI_RDATA),        // output wire [63 : 0] S04_AXI_RDATA
  .S04_AXI_RRESP    (S04_AXI_RRESP),        // output wire [1 : 0] S04_AXI_RRESP
  .S04_AXI_RLAST    (S04_AXI_RLAST),        // output wire S04_AXI_RLAST
  .S04_AXI_RVALID   (S04_AXI_RVALID),       // output wire S04_AXI_RVALID
  .S04_AXI_RREADY   (S04_AXI_RREADY),       // input wire S04_AXI_RREADY

  .S05_AXI_ARESET_OUT_N(),  // output wire S05_AXI_ARESET_OUT_N
  .S05_AXI_ACLK     (aclk),                  // input wire S05_AXI_ACLK
  .S05_AXI_AWID     (S05_AXI_AWID),                  // input wire [0 : 0] S05_AXI_AWID
  .S05_AXI_AWADDR   (S05_AXI_AWADDR),              // input wire [39 : 0] S05_AXI_AWADDR
  .S05_AXI_AWLEN    (S05_AXI_AWLEN),                // input wire [7 : 0] S05_AXI_AWLEN
  .S05_AXI_AWSIZE   (S_AXI_AWSIZE),              // input wire [2 : 0] S05_AXI_AWSIZE
  .S05_AXI_AWBURST  (S_AXI_AWBURST),            // input wire [1 : 0] S05_AXI_AWBURST
  .S05_AXI_AWLOCK   (S_AXI_AWLOCK),              // input wire S05_AXI_AWLOCK
  .S05_AXI_AWCACHE  (S_AXI_AWCACHE),            // input wire [3 : 0] S05_AXI_AWCACHE
  .S05_AXI_AWPROT   (S_AXI_AWPROT),              // input wire [2 : 0] S05_AXI_AWPROT
  .S05_AXI_AWQOS    (4'b0),                // input wire [3 : 0] S05_AXI_AWQOS
  .S05_AXI_AWVALID  (S05_AXI_AWVALID),            // input wire S05_AXI_AWVALID
  .S05_AXI_AWREADY  (S05_AXI_AWREADY),            // output wire S05_AXI_AWREADY
  .S05_AXI_WDATA    (S05_AXI_WDATA),                // input wire [31 : 0] S05_AXI_WDATA
  .S05_AXI_WSTRB    (S05_AXI_WSTRB),                // input wire [3 : 0] S05_AXI_WSTRB
  .S05_AXI_WLAST    (S05_AXI_WLAST),                // input wire S05_AXI_WLAST
  .S05_AXI_WVALID   (S05_AXI_WVALID),              // input wire S05_AXI_WVALID
  .S05_AXI_WREADY   (S05_AXI_WREADY),              // output wire S05_AXI_WREADY
  .S05_AXI_BID      (S05_AXI_BID),                    // output wire [0 : 0] S05_AXI_BID
  .S05_AXI_BRESP    (S05_AXI_BRESP),                // output wire [1 : 0] S05_AXI_BRESP
  .S05_AXI_BVALID   (S05_AXI_BVALID),              // output wire S05_AXI_BVALID
  .S05_AXI_BREADY   (S05_AXI_BREADY),              // input wire S05_AXI_BREADY
  .S05_AXI_ARID     (S05_AXI_ARID),                  // input wire [0 : 0] S05_AXI_ARID
  .S05_AXI_ARADDR   (S05_AXI_ARADDR),              // input wire [39 : 0] S05_AXI_ARADDR
  .S05_AXI_ARLEN    (S05_AXI_ARLEN),                // input wire [7 : 0] S05_AXI_ARLEN
  .S05_AXI_ARSIZE   (3'd2),              // input wire [2 : 0] S05_AXI_ARSIZE
  .S05_AXI_ARBURST  (S_AXI_ARBURST),            // input wire [1 : 0] S05_AXI_ARBURST
  .S05_AXI_ARLOCK   (S_AXI_ARLOCK),              // input wire S05_AXI_ARLOCK
  .S05_AXI_ARCACHE  (S_AXI_ARCACHE),            // input wire [3 : 0] S05_AXI_ARCACHE
  .S05_AXI_ARPROT   (S_AXI_ARPROT),              // input wire [2 : 0] S05_AXI_ARPROT
  .S05_AXI_ARQOS    (4'b0),                // input wire [3 : 0] S05_AXI_ARQOS
  .S05_AXI_ARVALID  (S05_AXI_ARVALID),            // input wire S05_AXI_ARVALID
  .S05_AXI_ARREADY  (S05_AXI_ARREADY),            // output wire S05_AXI_ARREADY
  .S05_AXI_RID      (S05_AXI_RID),                    // output wire [0 : 0] S05_AXI_RID
  .S05_AXI_RDATA    (S05_AXI_RDATA),                // output wire [31 : 0] S05_AXI_RDATA
  .S05_AXI_RRESP    (S05_AXI_RRESP),                // output wire [1 : 0] S05_AXI_RRESP
  .S05_AXI_RLAST    (S05_AXI_RLAST),                // output wire S05_AXI_RLAST
  .S05_AXI_RVALID   (S05_AXI_RVALID),              // output wire S05_AXI_RVALID
  .S05_AXI_RREADY   (S05_AXI_RREADY),              // input wire S05_AXI_RREADY
  
  .M00_AXI_ARESET_OUT_N (),                 // output wire M00_AXI_ARESET_OUT_N
  .M00_AXI_ACLK     (aclk),                 // input wire M00_AXI_ACLK
  .M00_AXI_AWID     (M00_AXI_AWID),         // output wire [3 : 0] M00_AXI_AWID
  .M00_AXI_AWADDR   (M00_AXI_AWADDR),       // output wire [39 : 0] M00_AXI_AWADDR
  .M00_AXI_AWLEN    (M00_AXI_AWLEN),        // output wire [7 : 0] M00_AXI_AWLEN
  .M00_AXI_AWSIZE   (M00_AXI_AWSIZE),       // output wire [2 : 0] M00_AXI_AWSIZE
  .M00_AXI_AWBURST  (M00_AXI_AWBURST),      // output wire [1 : 0] M00_AXI_AWBURST
  .M00_AXI_AWLOCK   (M00_AXI_AWLOCK),       // output wire M00_AXI_AWLOCK
  .M00_AXI_AWCACHE  (M00_AXI_AWCACHE),      // output wire [3 : 0] M00_AXI_AWCACHE
  .M00_AXI_AWPROT   (M00_AXI_AWPROT),       // output wire [2 : 0] M00_AXI_AWPROT
  .M00_AXI_AWQOS    (M00_AXI_AWQOS),        // output wire [3 : 0] M00_AXI_AWQOS
  .M00_AXI_AWVALID  (M00_AXI_AWVALID),      // output wire M00_AXI_AWVALID
  .M00_AXI_AWREADY  (M00_AXI_AWREADY),      // input wire M00_AXI_AWREADY
  .M00_AXI_WDATA    (M00_AXI_WDATA),        // output wire [127 : 0] M00_AXI_WDATA
  .M00_AXI_WSTRB    (M00_AXI_WSTRB),        // output wire [15 : 0] M00_AXI_WSTRB
  .M00_AXI_WLAST    (M00_AXI_WLAST),        // output wire M00_AXI_WLAST
  .M00_AXI_WVALID   (M00_AXI_WVALID),       // output wire M00_AXI_WVALID
  .M00_AXI_WREADY   (M00_AXI_WREADY),       // input wire M00_AXI_WREADY
  .M00_AXI_BID      (M00_AXI_BID),          // input wire [3 : 0] M00_AXI_BID
  .M00_AXI_BRESP    (M00_AXI_BRESP),        // input wire [1 : 0] M00_AXI_BRESP
  .M00_AXI_BVALID   (M00_AXI_BVALID),       // input wire M00_AXI_BVALID
  .M00_AXI_BREADY   (M00_AXI_BREADY),       // output wire M00_AXI_BREADY
  .M00_AXI_ARID     (M00_AXI_ARID),         // output wire [3 : 0] M00_AXI_ARID
  .M00_AXI_ARADDR   (M00_AXI_ARADDR),       // output wire [39 : 0] M00_AXI_ARADDR
  .M00_AXI_ARLEN    (M00_AXI_ARLEN),        // output wire [7 : 0] M00_AXI_ARLEN
  .M00_AXI_ARSIZE   (M00_AXI_ARSIZE),       // output wire [2 : 0] M00_AXI_ARSIZE
  .M00_AXI_ARBURST  (M00_AXI_ARBURST),      // output wire [1 : 0] M00_AXI_ARBURST
  .M00_AXI_ARLOCK   (M00_AXI_ARLOCK),       // output wire M00_AXI_ARLOCK
  .M00_AXI_ARCACHE  (M00_AXI_ARCACHE),      // output wire [3 : 0] M00_AXI_ARCACHE
  .M00_AXI_ARPROT   (M00_AXI_ARPROT),       // output wire [2 : 0] M00_AXI_ARPROT
  .M00_AXI_ARQOS    (M00_AXI_ARQOS),        // output wire [3 : 0] M00_AXI_ARQOS
  .M00_AXI_ARVALID  (M00_AXI_ARVALID),      // output wire M00_AXI_ARVALID
  .M00_AXI_ARREADY  (M00_AXI_ARREADY),      // input wire M00_AXI_ARREADY
  .M00_AXI_RID      (M00_AXI_RID),          // input wire [3 : 0] M00_AXI_RID
  .M00_AXI_RDATA    (M00_AXI_RDATA),        // input wire [127 : 0] M00_AXI_RDATA
  .M00_AXI_RRESP    (M00_AXI_RRESP),        // input wire [1 : 0] M00_AXI_RRESP
  .M00_AXI_RLAST    (M00_AXI_RLAST),        // input wire M00_AXI_RLAST
  .M00_AXI_RVALID   (M00_AXI_RVALID),       // input wire M00_AXI_RVALID
  .M00_AXI_RREADY   (M00_AXI_RREADY)        // output wire M00_AXI_RREADY
);

// cache bus
wire [31:0] c_adr, d_adr, e_adr;
wire [31:0]  c_dr;    // ch_para
wire [31:0] d_dr, e_dr;
logic c_re, d_re, e_re;
//logic in_rdy, c_rdy, d_rdy, rdyin;
logic c_rdy, d_rdy, e_rdy;

//assign rdyin = in_rdy & c_rdy;
//assign rdyin = 1'b1;

// cache control regs

wire [31:0] rbase, wbase;

wire [3:0] clreq;
/*-- clreq from tfacc_core
logic cs;
assign cs = (adr & 32'hffffffe0) == 32'hffff0180 ? 1'b1 : 1'b0;	// ffff0180
// flreq3,2,1,0 clreq3,2,1,0
//assign clreq = (cs && we[3] && adr[4:2] == 3'd0) ? dw[27:24] : 4'b0000;    // BE
assign clreq = (cs && we[0] && adr[4:2] == 3'd0) ? dw[3:0] : 4'b0000;    // LE
--*/

//------ output_arb ---------------------------
logic        wreq[Np];
logic        wack[Np];
logic [31:0] wadr[Np];  
logic [63:0] wdata[Np];
logic [7:0]  wstb[Np];
logic [7:0]  wlen[Np];

output_arb 
   #(.Np   (Np),	// Number of parallel
     .debug(debug))	// debug mode
    u_output_arb
    (
     .wreq   (wreq),	// input  logic        wreq[Np],
     .wack   (wack),	// output logic        wack[Np],
     .wadr   (wadr),	// input  logic [31:0] wadr[Np],  
     .wdata  (wdata),	// input  logic [63:0] wdata[Np],
     .wstbi  (wstb),
     .wlen   (wlen),	// input  logic [7:0]  wlen[Np],       // word en

     .baseadr(wbase),	// input  logic [39:0] baseadr,	//

    //-- memc interface
     .aclk   (aclk),	// input  logic        aclk,		//
     .arst_n (arst_n),	// input  logic        arst_n,		//
    
     .awaddr (S00_AXI_AWADDR),	// output logic [39:0] awaddr,		// write port
     .awlen  (S00_AXI_AWLEN),	// output logic [7:0]  awlen,		//
     .awvalid(S00_AXI_AWVALID),	// output logic        awvalid,	//
     .awready(S00_AXI_AWREADY),	// input  logic        awready,	// 
    
     .wr_data(S00_AXI_WDATA),	// output logic [63:0] wr_data,	//
     .wvalid (S00_AXI_WVALID),	// output logic        wvalid,		//
     .wstb   (S00_AXI_WSTRB),	// output logic [7:0]  wstb,           //
     .wlast  (S00_AXI_WLAST),	// output logic        wlast,		//
     .wready (S00_AXI_WREADY),	// input  logic        wready,		//
    
     .araddr (S00_AXI_ARADDR),	// output logic [39:0] araddr,		//
     .arlen  (S00_AXI_ARLEN),	// output logic [7:0]  arlen,		//
     .arvalid(S00_AXI_ARVALID),	// output logic        arvalid,	//
     .arready(S00_AXI_ARREADY),	// input  logic        arready,	//
    
     .rd_data(S00_AXI_RDATA),	// input  logic [63:0] rd_data,	//
     .rvalid (S00_AXI_RVALID),	// input  logic        rvalid,		//
     .rlast  (S00_AXI_RLAST),	// input  logic        rlast,		//
     .rready (S00_AXI_RREADY)	// output logic        rready		//
    );


wire [31:0] rptmon, wptmon;

//------ input_arb ---------------------------

logic rreq[Np];
logic rack[Np];
u24_t radr[Np];  
u64_t rdata[Np];

input_arb 
  #(.Np     (Np),	// Number of parallel
     .debug  (debug))	// debug mode
  u_input_arb (
//    .clk        (aclk),	// input  logic    clk,                //
//    .xrst       (arst_n),	// input  logic    xrst;               //

    .rreq       (rreq),	// input  logic        rreq[Np];
    .rack       (rack),	// output logic        rack[Np];
    .radr       (radr),	// input  logic [23:0] radr[Np];  
    .rdata      (rdata),	// output logic [63:0] rdata[Np];

    .baseadr(rbase),	// input  logic [39:0] baseadr;        //
//-- memc interface
    .aclk       (aclk),		// in  std_logic;
    .arst_n     (arst_n),	// in	std_logic;

    .awaddr     (S01_AXI_AWADDR),	// out	unsigned(39 downto 0);
    .awlen      (S01_AXI_AWLEN),	// out	unsigned(7 downto 0);
    .awvalid    (S01_AXI_AWVALID),	// out	std_logic;
    .awready    (S01_AXI_AWREADY),	// in	std_logic;

    .wr_data    (S01_AXI_WDATA),	// out	unsigned(63 downto 0);
    .wlast      (S01_AXI_WLAST),	// out	std_logic;
    .wvalid     (S01_AXI_WVALID),	// out	std_logic;
    .wready     (S01_AXI_WREADY),	// in	std_logic;

    .araddr     (S01_AXI_ARADDR),	// out	unsigned(39 downto 0);
    .arlen      (S01_AXI_ARLEN),	// out	unsigned(7 downto 0);
    .arvalid    (S01_AXI_ARVALID),	// out	std_logic;
    .arready    (S01_AXI_ARREADY),	// in	std_logic;

    .rd_data    (S01_AXI_RDATA),	// in	unsigned(63 downto 0);
    .rlast      (S01_AXI_RLAST),	// in	std_logic;
    .rvalid     (S01_AXI_RVALID),	// in	std_logic;
    .rready     (S01_AXI_RREADY)	// out	std_logic;
  );

wire [31:0] c_base, d_base, e_base;

//rd_cache_nk  # (.NK(32), .debug(debug) ) u_cache_filt
rd_cache_nk  # (.NK(4), .debug(debug) ) u_cache_filt
    (
    .rptmon(), .wptmon(),
//-- bus
    .baseadr    (c_base),
    .adr        (c_adr),	// in  unsigned(31 downto 0);
    .re         (c_re),		// in  std_logic;
    .rdy        (c_rdy),	// out std_logic;
    .dr         (c_dr),     // out unsigned(31 downto 0);
    .dru8       (), // out u8_t

    .clreq      (clreq[2]),

//-- axi i/f
    .aclk       (aclk),		// in  std_logic;
    .arst_n     (arst_n),	// in	std_logic;

    .awaddr     (S02_AXI_AWADDR),	// out	unsigned(39 downto 0);
    .awlen      (S02_AXI_AWLEN),	// out	unsigned(7 downto 0);
    .awvalid    (S02_AXI_AWVALID),	// out	std_logic;
    .awready    (S02_AXI_AWREADY),	// in	std_logic;

    .wr_data    (S02_AXI_WDATA),	// out	unsigned(63 downto 0);
    .wlast      (S02_AXI_WLAST),	// out	std_logic;
    .wvalid     (S02_AXI_WVALID),	// out	std_logic;
    .wready     (S02_AXI_WREADY),	// in	std_logic;

    .araddr     (S02_AXI_ARADDR),	// out	unsigned(39 downto 0);
    .arlen      (S02_AXI_ARLEN),	// out	unsigned(7 downto 0);
    .arvalid    (S02_AXI_ARVALID),	// out	std_logic;
    .arready    (S02_AXI_ARREADY),	// in	std_logic;

    .rd_data    (S02_AXI_RDATA),	// in	unsigned(63 downto 0);
    .rlast      (S02_AXI_RLAST),	// in	std_logic;
    .rvalid     (S02_AXI_RVALID),	// in	std_logic;
    .rready     (S02_AXI_RREADY)	// out	std_logic;
    );

rd_cache_nk  # (.NK(4), .debug(debug) ) u_cache_bias
    (
    .rptmon(),    .wptmon(),
//-- bus
    .baseadr    (d_base),
    .adr        (d_adr),    // in  u32_t
    .re         (d_re),     // in  std_logic;
    .rdy        (d_rdy),    // out std_logic;
    .dr         (d_dr),     // out s32_t  bias
    .dru8       (),
    
    .clreq      (clreq[3]),

//-- axi i/f
    .aclk       (aclk),        // in  std_logic;
    .arst_n     (arst_n),      // in	std_logic;

    .awaddr     (S03_AXI_AWADDR),	// out	unsigned(39 downto 0);
    .awlen      (S03_AXI_AWLEN),	// out	unsigned(7 downto 0);
    .awvalid    (S03_AXI_AWVALID),	// out	std_logic;
    .awready    (S03_AXI_AWREADY),	// in	std_logic;

    .wr_data    (S03_AXI_WDATA),	// out	unsigned(63 downto 0);
    .wlast      (S03_AXI_WLAST),	// out	std_logic;
    .wvalid     (S03_AXI_WVALID),	// out	std_logic;
    .wready     (S03_AXI_WREADY),	// in	std_logic;

    .araddr     (S03_AXI_ARADDR),	// out	unsigned(39 downto 0);
    .arlen      (S03_AXI_ARLEN),	// out	unsigned(7 downto 0);
    .arvalid    (S03_AXI_ARVALID),	// out	std_logic;
    .arready    (S03_AXI_ARREADY),	// in	std_logic;

    .rd_data    (S03_AXI_RDATA),	// in	unsigned(63 downto 0);
    .rlast      (S03_AXI_RLAST),	// in	std_logic;
    .rvalid     (S03_AXI_RVALID),	// in	std_logic;
    .rready     (S03_AXI_RREADY)	// out	std_logic;
    );

rd_cache_nk  # (.NK(4), .debug(debug) ) u_cache_quant
    (
    .rptmon(),    .wptmon(),
    //-- bus
    .baseadr    (e_base),
    .adr        (e_adr),    // in  u32_t
    .re         (e_re),     // in  std_logic;
    .rdy        (e_rdy),    // out std_logic;
    .dr         (e_dr),     // out s32_t  bias
    .dru8       (),

    .clreq      (clreq[3]),

    //-- axi i/f
    .aclk       (aclk),        // in  std_logic;
    .arst_n     (arst_n),      // in   std_logic;

    .awaddr     (S04_AXI_AWADDR),   // out  unsigned(39 downto 0);
    .awlen      (S04_AXI_AWLEN),    // out  unsigned(7 downto 0);
    .awvalid    (S04_AXI_AWVALID),  // out  std_logic;
    .awready    (S04_AXI_AWREADY),  // in   std_logic;

    .wr_data    (S04_AXI_WDATA),   // out  unsigned(63 downto 0);
    .wlast      (S04_AXI_WLAST),    // out  std_logic;
    .wvalid     (S04_AXI_WVALID),   // out  std_logic;
    .wready     (S04_AXI_WREADY),   // in   std_logic;

    .araddr     (S04_AXI_ARADDR),   // out  unsigned(39 downto 0);
    .arlen      (S04_AXI_ARLEN),    // out  unsigned(7 downto 0);
    .arvalid    (S04_AXI_ARVALID),  // out  std_logic;
    .arready    (S04_AXI_ARREADY),  // in   std_logic;

    .rd_data    (S04_AXI_RDATA),    // in   unsigned(63 downto 0);
    .rlast      (S04_AXI_RLAST),    // in   std_logic;
    .rvalid     (S04_AXI_RVALID),   // in   std_logic;
    .rready     (S04_AXI_RREADY)    // out  std_logic;
    );

wire  r_rdy, t_rdy;
wire [31:0] r_dr, t_dr;

assign rdy = r_rdy & t_rdy;
assign dr  = r_dr | t_dr;

rv_axi_port u_rv_axi_port (
    .xrst     (xreset), //   input logic xrst,
    //-- CPU bus
    .cclk     (cclk),    //   input  logic cclk,    //    : in    std_logic;
    .adr      (adr),    //  input  u32_t adr,    //       adr     : in      unsigned(31 downto 0);
    .we       (we),     // input  u4_t  we,     //      : in   std_logic_vector(3 downto 0);
    .re       (re),     //input  logic re,     //      : in   std_logic;
    .rdyin    (1'b1),        //    input  logic rdyin,    //   : in    std_logic;
    .rdy      (r_rdy),    //  output logic rdy,    // : out   std_logic;
    .dw       (dw),     //input  u32_t dw,    //      : in    unsigned(31 downto 0);
    .dr       (r_dr),    // output u32_t dr,    //      : out   unsigned(31 downto 0);

    //-- axi interface
    .aclk     (aclk),    //  input  logic        aclk,           //
    .arst_n   (arst_n),    //    input  logic        arst_n,         //

    .awaddr     (S05_AXI_AWADDR),   // out  unsigned(39 downto 0);
    .awlen      (S05_AXI_AWLEN),    // out  unsigned(7 downto 0);
    .awvalid    (S05_AXI_AWVALID),  // out  std_logic;
    .awready    (S05_AXI_AWREADY),  // in   std_logic;

    .wr_data    (S05_AXI_WDATA),   // out  unsigned(31 downto 0);
    .wlast      (S05_AXI_WLAST),    // out  std_logic;
    .wvalid     (S05_AXI_WVALID),   // out  std_logic;
    .wready     (S05_AXI_WREADY),   // in   std_logic;

    .araddr     (S05_AXI_ARADDR),   // out  unsigned(39 downto 0);
    .arlen      (S05_AXI_ARLEN),    // out  unsigned(7 downto 0);
    .arvalid    (S05_AXI_ARVALID),  // out  std_logic;
    .arready    (S05_AXI_ARREADY),  // in   std_logic;

    .rd_data    (S05_AXI_RDATA),    // in   unsigned(31 downto 0);
    .rlast      (S05_AXI_RLAST),    // in   std_logic;
    .rvalid     (S05_AXI_RVALID),   // in   std_logic;
    .rready     (S05_AXI_RREADY)    // out  std_logic;
    
    );

tfacc_core #(.Np(Np), .debug(debug)) u_tfacc_core (
    .cclk  (cclk),    // input  logic clk,
    .xrst (xreset),  // input  logic xrst,
    // rv_cpu bus
    .adr  (adr),    // input   logic [31:0]      adr,    
    .we   (we),     // input   logic [3:0]       we,     
    .re   (re),     // input   logic             re,     
    .rdy  (t_rdy),    // output  logic             rdy,    
    .dw   (dw),     // input   logic [31:0]      dw,     
    .dr   (t_dr),     // output  logic [31:0]      dr,
    .irq  (irq),    // output  logic             irq,

    .aclk (aclk),
    .arst_n(arst_n),

    // cache bus a : output
    .wreq     (wreq), // input  logic        wreq[Np],
    .wack     (wack), // output logic        wack[Np],
    .wadr     (wadr), // input  logic [31:0] wadr[Np],  
    .wdata    (wdata),// input  logic [63:0] wdata[Np],
    .wlen     (wlen), // input  logic [7:0]  wlen[Np],       // word en
    .wstb     (wstb),
    .wbase    (wbase),
    
    // cache bus b : input
    .rreq     (rreq),   // logic        rreq[Np];
    .rack     (rack),   // logic        rack[Np];
    .radr     (radr),   // logic [23:0] radr[Np];  
    .rdata    (rdata),  // logic [63:0] rdata[Np];
    .rbase    (rbase),
//    .in_rdy(in_rdy),

    // cache bus c : filter
    .c_base   (c_base),
    .c_adr    (c_adr),   // output  logic [31:0]      c_adr,    
    .c_re     (c_re),    // output  logic             c_re,     
    .c_rdy    (c_rdy),   // input   logic             c_rdy,    
    .c_dr     (c_dr),    // input   logic [31:0]       c_dr,

    // cache bus d : bias
    .d_base   (d_base),
    .d_adr    (d_adr),   // output  logic [31:0]      d_adr,    
    .d_re     (d_re),    // output  logic             d_re,     
    .d_rdy    (d_rdy),   // input   logic             d_rdy,    
    .d_dr     (d_dr),    // input   logic [31:0]      d_dr,
    
    // cache bus e : quant
    .e_base   (e_base),
    .e_adr    (e_adr),   // output  logic [31:0]      e_adr,    
    .e_re     (e_re),    // output  logic             e_re,     
    .e_rdy    (e_rdy),   // input   logic             e_rdy,    
    .e_dr     (e_dr),    // input   logic [31:0]      e_dr,

    .clreq    (clreq),   // output u4_t             clreq,
    .fp       (fp)       // output  logic [4:0]     fp
 );

/*---
ila_0 u_ila (
  .clk(aclk), // input wire clk
  .probe0(S00_AXI_AWADDR[31:0]), // input wire [31:0]  probe0  
  .probe1(S01_AXI_ARADDR[31:0]), // input wire [31:0]  probe1 
  .probe2(radr[0]), // input wire [31:0]  probe2 
  .probe3(wadr[37]), // input wire [31:0]  probe3
  .probe4(radr[37]), // input wire [31:0]  probe4
  .probe5({rreq[0],rack[0],rreq[37],rack[37],wreq[0],wack[0],wreq[37],wack[37],fp}), // input wire [31:0]  probe5
         // 7 6    5 4   3 2     1 0 (Np=2)
  .probe6({S00_AXI_AWREADY, S01_AXI_RREADY, S00_AXI_WREADY, rdyin,
           wreq[0],         wack[0],        wreq[37],       wack[37]})	// input wire [7:0]  probe6
);
---*/

endmodule

