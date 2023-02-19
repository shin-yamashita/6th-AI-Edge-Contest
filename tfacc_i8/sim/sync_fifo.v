// Synchronous FIFO for Simulation
//
// 2013/11/08 by marsee
//
// ライセンスは二条項BSDライセンス (2-clause BSD license)とします。

`default_nettype none

module sync_fifo #(
    parameter integer C_MEMORY_SIZE =        512,    // Word (not byte), 2のn乗
    parameter integer DATA_BUS_WIDTH =        32        // RAM Data Width
)
(
    input    wire    clk,
    input    wire    rst,
    input    wire    wr_en,
    input    wire    [DATA_BUS_WIDTH-1:0]    din,
    output    wire    full,
    output    wire    almost_full,
    input    wire    rd_en,
    output    wire     [DATA_BUS_WIDTH-1:0]    dout,
    output    wire    empty,
    output    wire    almost_empty
);

    // Beyond Circuts, Constant Function in Verilog 2001を参照しました
    // http://www.beyond-circuits.com/wordpress/2008/11/constant-functions/
    function integer log2;
        input integer addr;
        begin
            addr = addr - 1;
            for (log2=0; addr>0; log2=log2+1)
                addr = addr >> 1;
        end
    endfunction
    
    reg        [DATA_BUS_WIDTH-1:0]    mem    [0:C_MEMORY_SIZE-1];
    reg        [log2(C_MEMORY_SIZE)-1:0]   mem_waddr = 0;
    reg        [log2(C_MEMORY_SIZE)-1:0]   mem_raddr = 0;
    reg        [log2(C_MEMORY_SIZE)-1:0]    rp = 0;
    reg        [log2(C_MEMORY_SIZE)-1:0]    wp = 0;

    wire    [log2(C_MEMORY_SIZE)-1:0]   plus_1 = 1;
    wire    [log2(C_MEMORY_SIZE)-1:0]   plus_2 = 2;

    wire    almost_full_node;
    wire    almost_empty_node;

    integer i;
    // initialize RAM Data
    initial begin
        for (i=0; i<C_MEMORY_SIZE; i=i+1)
            mem[i] = 0;
    end

    // Write
    always @(posedge clk) begin
        if (rst) begin
            mem_waddr <= 0;
            wp <= 0;
        end else begin
            if (wr_en) begin
                mem_waddr <= mem_waddr + 1;
                wp <= wp + 1;
            end
        end
    end

    always @(posedge clk) begin
         if (wr_en) begin
            mem[mem_waddr] <= din;
        end
    end

    assign full = (wp+plus_1 == rp) ? 1'b1 : 1'b0;
    assign almost_full_node = (wp+plus_2 == rp) ? 1'b1 : 1'b0;
    assign almost_full = full | almost_full_node;

    // Read
    always @(posedge clk) begin
        if (rst) begin
            mem_raddr <= 0;
            rp <= 0;
        end else begin
            if (rd_en) begin
                mem_raddr <= mem_raddr + 1;
                rp <= rp + 1;
            end
        end
    end

    assign dout = mem[mem_raddr];

    assign empty = (wp == rp) ? 1'b1 : 1'b0;
    assign almost_empty_node = (wp == rp+plus_1) ? 1'b1 : 1'b0;
    assign almost_empty = empty | almost_empty_node;
endmodule

`default_nettype wire

