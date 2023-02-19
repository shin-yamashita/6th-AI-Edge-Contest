//
// rv32_core
//   Instruction / Data dual port RAM
//

`timescale 1ns/1ns
`include "logic_types.svh"

module rv_mem #(parameter Nk = 32)(
    input  logic clk,
    input  logic xreset,
    input  logic rdy,
    //-- Insn Bus (read only)
    input  u32_t i_adr,
    output u32_t i_dr,
    input  logic i_re,
    //-- Data Bus
    input  u32_t d_adr,
    input  u32_t d_dw,
    output u32_t d_dr,
    input  u4_t  d_we,
    input  logic d_re,
    //-- Peripheral Bus
    input  u32_t p_adr,
    input  u32_t p_dw,
    output u32_t p_dr,
    input  logic p_we,
    input  logic p_re,
    output logic p_ack
    );

parameter Nb = $clog2(Nk) + 10; // Nk:32(kB) -> Nb:15(bit)

//-- Registers
//-- wire
u32_t addra, addrb; // : std_logic_vector(13 downto 0);
u32_t doa, dob;
u32_t dob2;
u32_t dib;
logic csa, csb;
logic csb2, cs_p;
logic ena, enb;
u4_t  web;
logic d_re1, d_re2, p_re1;
logic i_re1;
logic den;
u32_t d_dr_s, p_dr_s;

assign den = (d_we != 4'b0000) || d_re ? (csb & xreset) : 1'b0;    // when d_we /= 0 or d_re = '1'	else '0';	-- d-bus enable

assign addra = i_adr;
assign addrb = den ? d_adr : p_adr;

assign csa  = i_adr[31:Nb] == '0;
assign csb  = d_adr[31:Nb] == '0;
assign csb2 = p_adr[31:Nb] == '0;
assign cs_p = (p_adr & 32'hffffff00) == 'h100;  // 
assign cs_d = (d_adr & 32'hffffff00) == 'h100; 

assign ena = csa ? i_re & rdy : '0;
assign enb = (csb | csb2);    // & rdy;
assign web = !rdy ? 4'b0000 : 
             (den ? d_we : (p_we && csb2 ? 4'b1111 : 4'b0000));

assign dib = den ? d_dw : p_dw;

assign i_dr = i_re1 ? doa : '0;
assign d_dr = d_re2 ? d_dr_s : (d_re1 ? dob : '0);
assign p_dr = p_re1 ? p_dr_s : dob;
assign p_ack = (p_we || p_re) & !den;

  always_ff@(posedge clk) begin
    p_re1 <= cs_p & p_re;
    if(rdy) begin
      d_re1 <= csb & d_re;
      d_re2 <= cs_d & d_re;
      i_re1 <= csa & i_re;
    end
  end

  dpram #(.ADDR_WIDTH(Nb-2), .init_file_u("prog_u.mem"), .init_file_l("prog_l.mem")) u_dpram (
      .clk  (clk),
      .enaA (1'b1),      // read port
      .addrA(addra[Nb-1:1]), // half word address
      .doutA(doa),
      .enaB (enb),     // read write port
      .weB  (web),
      .addrB(addrb[Nb-1:2]),
      .dinB (dib),
      .doutB(dob)
      );

  rv_shm u_rv_shm (
      .clkA (clk),  // d port
      .enaA (cs_d),
      .weA  (d_we), // [3:0]
      .addrA(d_adr[7:2]), // [5:0] word adr
      .dinA (d_dw),
      .doutA(d_dr_s),
      .clkB (clk),  // p port
      .enaB (cs_p),
      .weB  ({p_we,p_we,p_we,p_we}),
      .addrB(p_adr[7:2]),
      .dinB (p_dw),
      .doutB(p_dr_s)
  );

endmodule

