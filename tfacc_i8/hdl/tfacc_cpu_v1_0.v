
`timescale 1 ns / 1 ps

module tfacc_cpu_v1_0
(
    // Users to add ports here
    
    //-- data bus
    output wire [31:0] adr, // out unsigned(31 downto 0);
    output wire [3:0]  we,  // out std_logic_vector(3 downto 0);
    output wire re,         // out std_logic;
    input  wire rdy,        // in  std_logic;
    output wire [31:0] dw,  // out unsigned(31 downto 0);
    input  wire [31:0] dr,  // in  unsigned(31 downto 0);
    input  wire irq,

    //-- debug port
    output wire RXD,        // out   std_logic;      -- to debug terminal 
    input  wire TXD,        // in    std_logic;      -- from debug terminal
    //-- para port out
    output wire xsrrst,
    output wire [3:0] pout, // out   std_logic_vector(7 downto 0)
    output wire fan_out,
    
    // User ports ends
    // Do not modify the ports beyond this line
    
    // Ports of Axi Slave Bus Interface S00_AXI
    input  wire  s00_axi_aclk,
    input  wire  s00_axi_aresetn,
    input  wire [15 : 0] s00_axi_awaddr,
    input  wire [2 : 0] s00_axi_awprot,
    input  wire  s00_axi_awvalid,
    output wire  s00_axi_awready,
    input  wire [31 : 0] s00_axi_wdata,
    input  wire [3 : 0] s00_axi_wstrb,
    input  wire  s00_axi_wvalid,
    output wire  s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire  s00_axi_bvalid,
    input  wire  s00_axi_bready,
    input  wire [15 : 0] s00_axi_araddr,
    input  wire [2 : 0] s00_axi_arprot,
    input  wire  s00_axi_arvalid,
    output wire  s00_axi_arready,
    output wire [31 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire  s00_axi_rvalid,
    input  wire  s00_axi_rready
);

wire [15 : 0] m_apb_paddr;
wire [0 : 0]  m_apb_psel;
wire m_apb_penable;
wire m_apb_pwrite;
wire [31 : 0] m_apb_pwdata;
wire [0 : 0]  m_apb_pready;
wire [31 : 0] m_apb_prdata;
wire [0 : 0]  m_apb_pslverr;

axi_apb_bridge_0 u_axi_apb_bridge (
  .s_axi_aclk(s00_axi_aclk),        // input wire s_axi_aclk
  .s_axi_aresetn(s00_axi_aresetn),  // input wire s_axi_aresetn
  .s_axi_awaddr(s00_axi_awaddr),    // input wire [15 : 0] s_axi_awaddr
  .s_axi_awvalid(s00_axi_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(s00_axi_awready),  // output wire s_axi_awready
  .s_axi_wdata(s00_axi_wdata),      // input wire [31 : 0] s_axi_wdata
  .s_axi_wvalid(s00_axi_wvalid),    // input wire s_axi_wvalid
  .s_axi_wready(s00_axi_wready),    // output wire s_axi_wready
  .s_axi_bresp(s00_axi_bresp),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(s00_axi_bvalid),    // output wire s_axi_bvalid
  .s_axi_bready(s00_axi_bready),    // input wire s_axi_bready
  .s_axi_araddr(s00_axi_araddr),    // input wire [15 : 0] s_axi_araddr
  .s_axi_arvalid(s00_axi_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(s00_axi_arready),  // output wire s_axi_arready
  .s_axi_rdata(s00_axi_rdata),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(s00_axi_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(s00_axi_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(s00_axi_rready),    // input wire s_axi_rready

  .m_apb_paddr(m_apb_paddr),      // output wire [15 : 0] m_apb_paddr
  .m_apb_psel(m_apb_psel),        // output wire [0 : 0] m_apb_psel
  .m_apb_penable(m_apb_penable),  // output wire m_apb_penable
  .m_apb_pwrite(m_apb_pwrite),    // output wire m_apb_pwrite
  .m_apb_pwdata(m_apb_pwdata),    // output wire [31 : 0] m_apb_pwdata
  .m_apb_pready(m_apb_pready),    // input wire [0 : 0] m_apb_pready
  .m_apb_prdata(m_apb_prdata),    // input wire [31 : 0] m_apb_prdata
  .m_apb_pslverr(m_apb_pslverr)  // input wire [0 : 0] m_apb_pslverr
);

wire [31:0] p_adr;
wire [31:0] p_dw, p_dr;
wire p_we, p_re, p_ack;
reg  p_rack;
reg  [31:0] slvreg0, slvreg1;

assign p_we = m_apb_penable & m_apb_pwrite;
assign p_re = m_apb_penable & !m_apb_pwrite & !p_rack;
assign m_apb_prdata = p_dr;
assign p_dw = m_apb_pwdata;
assign p_adr = {16'h0000, m_apb_paddr};
assign m_apb_pready[0] = (p_we & p_ack) | p_rack;

always@(posedge s00_axi_aclk) begin
    p_rack <= p_re & p_ack;

    if(!s00_axi_aresetn) begin
      slvreg0 <= 32'h00000000;
      slvreg1 <= 32'h00000000;
    end else if(we != 0 && adr == 32'h00000084 && rdy) begin
      slvreg1 <= dw;
    end else if(p_we && m_apb_paddr == 16'h0080) begin
      slvreg0 <= m_apb_pwdata;
    end else if(p_we && m_apb_paddr == 16'h0084) begin
      slvreg1 <= m_apb_pwdata;
    end
end

assign xsrrst = slvreg0[0];
assign eirq = (irq || slvreg1[0]) & xsrrst;

// Add user logic here
rv32_core u_rv32_core (
    .cclk    (s00_axi_aclk),  //: in    std_logic;
    
    //-- memory access bus
    .p_adr   (p_adr),       // in  unsigned(31 downto 0);
    .p_we    (p_we),        // in  std_logic;
    .p_re    (p_re),        // in  std_logic;
    .p_dw    (p_dw),        // in  unsigned(31 downto 0);
    .p_dr    (p_dr),        // out unsigned(31 downto 0);
    .p_ack   (p_ack),       // out std_logic;
    
    //-- data bus
    .xreset  (xsrrst),      // in  std_logic;
    .adr     (adr), // out unsigned(31 downto 0);
    .we      (we),  // out std_logic_vector(3 downto 0);
    .re      (re),  // out std_logic;
    .rdy     (rdy), // in  std_logic;
    .dw      (dw),  // out unsigned(31 downto 0);
    .dr      (dr),  // in  unsigned(31 downto 0);
    
    //-- debug port
    .RXD     (RXD), // out std_logic;      -- to debug terminal 
    .TXD     (TXD), // in  std_logic;      -- from debug terminal
    //-- ext irq
    .eirq    (eirq),
    //-- para port out
    .pout    (pout), // out   std_logic_vector(3 downto 0)
    .fan_out (fan_out)
);

// User logic ends
/*---
ila_0 u_ila (
  .clk(s00_axi_aclk), // input wire clk
  .probe0(p_adr), // input wire [31:0]  probe0  
  .probe1(adr), // input wire [31:0]  probe1 
  .probe2(p_dw), // input wire [31:0]  probe2 
  .probe3(p_dr), // input wire [31:0]  probe3
  .probe4({p_we, p_re, p_ack, p_rack, m_apb_penable, m_apb_pwrite, m_apb_pready[0], m_apb_psel}) // input wire [7:0]  probe4
  // 7     6     5      4       3         2       1        0
);
---*/

endmodule

