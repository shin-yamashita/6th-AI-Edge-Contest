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

endmodule

