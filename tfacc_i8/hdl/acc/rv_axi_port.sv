//--
//-- rv_axi_port
//    axi access port for rv32_core bus
//-- 2022/01/30 

`timescale 1ns/1ns
`include "logic_types.svh"

module rv_axi_port #(parameter BASE = 16'h0010, LAST = 16'h7FFF) ( // 0x0010_0000 ~ 0x7fff_ffff

    input logic xrst,
//-- CPU bus
    input  logic cclk,    //	: in  	std_logic;
    input  u32_t adr,    //       adr     : in  	unsigned(31 downto 0);
    input  u4_t  we,     //      : in  	std_logic_vector(3 downto 0);
    input  logic re,     //      : in  	std_logic;
    input  logic rdyin,    //	: in	std_logic;
    output logic rdy,    //	: out	std_logic;
    input  u32_t dw,    //      : in  	unsigned(31 downto 0);
    output u32_t dr,    //      : out 	unsigned(31 downto 0);

//-- axi interface
    input  logic        aclk,           //
    input  logic        arst_n,         //

    output logic [39:0] awaddr,         // write port
    output logic [7:0]  awlen,          //
    output logic        awvalid,        //
    input  logic        awready,        // 

    output logic [31:0] wr_data,        //
    output logic        wvalid,         //
    output logic        wlast,          //
    input  logic        wready,         //

    output logic [39:0] araddr,         //
    output logic [7:0]  arlen,          //
    output logic        arvalid,        //
    input  logic        arready,        //

    input  logic [31:0] rd_data,        //
    input  logic        rvalid,         //
    input  logic        rlast,          //
    output logic        rready          //
    );

u32_t dr_d, dr_f;
assign dr = dr_d | dr_f;

logic clreq, clbsy, flreq, flbsy;
logic cs_cache;
assign cs_cache = adr == 32'hffff0188 ? 1'b1 : 1'b0; // ffff0188

always_ff@(posedge cclk) begin
    if(!xrst) begin
        flreq <= '0;
        clreq <= '0;
    end else begin
        if(cs_cache && we[3]) begin
            flreq <= flreq | dw[4];
            clreq <= clreq | dw[0];
        end else begin
            if(clbsy) clreq <= '0;
            if(flbsy) flreq <= '0;
        end
        if(cs_cache && re) begin
            dr_f <= {flbsy, 3'b0, clbsy};
        end else begin
            dr_f <= '0;
        end
    end
end

rv_cache #(.BASE(BASE), .LAST(LAST)) u_rv_cache_d (
    .xrst    (xrst),

// chahe clear / flush request / busy status
    .clreq   (clreq),
    .clbsy   (clbsy),
    .flreq   (flreq),
    .flbsy   (flbsy),

// CPU bus
    .cclk    (cclk),
    .adr     (adr),
    .we      (we),
    .re      (re),
    .rdyin   (rdyin),
    .rdy     (rdy),
    .dw      (dw),
    .dr      (dr_d),

// memc interface
    .aclk	    (aclk),
    .arst_n	    (arst_n),
    .awaddr	    (awaddr),	//          : out   std_logic_vector(27:0);
    .awlen 	    (awlen),	//          : out   std_logic_vector(7:0);
    .awvalid	(awvalid),	//         : out   std_logic;
    .awready	(awready),	//         : in    std_logic;

    .wr_data	(wr_data),	//         : out   std_logic_vector(31:0);
    .wvalid 	(wvalid),	//         : out   std_logic;      // wr_en
    .wlast  	(wlast),	//         : out   std_logic;
    .wready 	(wready),	//         : in    std_logic;      // wr_full

    .araddr 	(araddr),	//         : out   std_logic_vector(27:0);
    .arlen  	(arlen),	//         : out   std_logic_vector(7:0);
    .arvalid	(arvalid),	//         : out   std_logic;
    .arready	(arready),	//         : in    std_logic;

    .rd_data	(rd_data),	//         : in    std_logic_vector(31:0);
    .rvalid 	(rvalid),	//         : in    std_logic;      // rd_en
    .rlast  	(rlast),	//         : in    std_logic;      // rd_en
    .rready 	(rready)	//         : out   std_logic       //
    );

endmodule


