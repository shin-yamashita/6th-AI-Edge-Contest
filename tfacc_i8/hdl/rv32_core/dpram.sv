//
// True-Dual-Port BRAM with Byte-wide Write Enable
//      No-Change mode
//
// portA : Instruction read only, half word (16) addressing.
// portB : Data read and write, word (32) addressing.
//
//                     byte addr
// we[3] : dinB[31:24]  3
// we[2] : dinB[23:16]  2
// we[1] : dinB[15:8]   1
// we[0] : dinB[7:0]    0

module dpram
  #(
    //---------------------------------------------------------------
    parameter   NUM_COL                 =   4,
    parameter   COL_WIDTH               =   8,
    parameter   ADDR_WIDTH              =  13, // Addr  Width in bits : 2**ADDR_WIDTH = RAM Depth
    parameter   DATA_WIDTH              =  NUM_COL*COL_WIDTH,  // Data  Width in bits
    parameter   init_file_u             =  "init_file_u.mem",
    parameter   init_file_l             =  "init_file_l.mem"
    //---------------------------------------------------------------
    ) (
       input  logic clk,

       input  logic                  enaA, 	// read port
       input  logic [ADDR_WIDTH:0]   addrA,	// half woad addr
       output logic [DATA_WIDTH-1:0] doutA,
       
       input  logic                  enaB,	// read write port
       input  logic [NUM_COL-1:0]    weB,
       input  logic [ADDR_WIDTH-1:0] addrB,	// woad addr
       input  logic [DATA_WIDTH-1:0] dinB,
       output logic [DATA_WIDTH-1:0] doutB
       );

  // half word access
  logic [ADDR_WIDTH-1:0]     adr_u, adr_l;
  logic [DATA_WIDTH/2-1:0] doA_u, doA_l;
  assign adr_u = addrA[ADDR_WIDTH:1];
  assign adr_l = addrA[0] ? addrA[ADDR_WIDTH:1]+1 : addrA[ADDR_WIDTH:1];
  logic  adra0;
  assign doutA = adra0 ? {doA_l,doA_u} : {doA_u,doA_l};

  always_ff@(posedge clk) begin
    if(enaA)
      adra0 <= addrA[0];
  end

  dpram_h #(.NUM_COL(NUM_COL/2), .COL_WIDTH(COL_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH/2), .init_file(init_file_u))
  u_dpram_h_u (
    .clk   (clk),
    .enaA  (enaA),
    .addrA (adr_u),
    .doutA (doA_u),
    .enaB  (enaB),
    .weB   (weB[NUM_COL-1:NUM_COL/2]),
    .addrB (addrB),
    .dinB  (dinB[DATA_WIDTH-1:DATA_WIDTH/2]),
    .doutB (doutB[DATA_WIDTH-1:DATA_WIDTH/2])
  );

  dpram_h #(.NUM_COL(NUM_COL/2), .COL_WIDTH(COL_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH/2), .init_file(init_file_l))
  u_dpram_h_l (
    .clk   (clk),
    .enaA  (enaA),
    .addrA (adr_l),
    .doutA (doA_l),
    .enaB  (enaB),
    .weB   (weB[NUM_COL/2-1:0]),
    .addrB (addrB),
    .dinB  (dinB[DATA_WIDTH/2-1:0]),
    .doutB (doutB[DATA_WIDTH/2-1:0])
  );

endmodule // dpram

