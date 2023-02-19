//
// True-Dual-Port BRAM with Byte-wide Write Enable
//      No-Change mode
//
// bytewrite_tdp_ram_nc.v
//
// ByteWide Write Enable, - NO_CHANGE mode template - Vivado recomended

module dpram_h
  #(
    //---------------------------------------------------------------
    parameter   NUM_COL                 =   2,
    parameter   COL_WIDTH               =   8,
    parameter   ADDR_WIDTH              =  13, // Addr  Width in bits : 2**ADDR_WIDTH = RAM Depth
    parameter   DATA_WIDTH              =  NUM_COL*COL_WIDTH,  // Data  Width in bits
    parameter   init_file               =  "prog-e.mem"
    //---------------------------------------------------------------
    ) (
       input clk,

       input enaA, 	// read port
       input [ADDR_WIDTH-1:0] addrA,	// half woad addr
       output reg [DATA_WIDTH-1:0] doutA,
       
       input enaB,	// read write port
       input [NUM_COL-1:0] weB,
       input [ADDR_WIDTH-1:0] addrB,	// woad addr
       input [DATA_WIDTH-1:0] dinB,
       output reg [DATA_WIDTH-1:0] doutB
       );

   // Core Memory  
   reg [DATA_WIDTH-1:0]            ram_block [(2**ADDR_WIDTH)-1:0];
   
   initial begin
      $readmemh(init_file, ram_block);
   end
   
   // Port-A Operation
   always @ (posedge clk) begin
      if(enaA) begin
         doutA <= ram_block[addrA];
      end
   end

   // Port-B Operation:
   genvar i;
   generate
      for(i=0;i<NUM_COL;i=i+1) begin
         always @ (posedge clk) begin
            if(enaB) begin
               if(weB[i]) begin
                  ram_block[addrB][i*COL_WIDTH +: COL_WIDTH] <= dinB[i*COL_WIDTH +: COL_WIDTH];
               end
            end
         end
      end
   endgenerate
   
   always @ (posedge clk) begin
      if(enaB) begin
         if (~|weB)
           doutB <= ram_block[addrB];
      end else begin
         doutB <= 'd0;
      end
   end
   
endmodule // bytewrite_tdp_ram_nc
