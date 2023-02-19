/* AXI Master用 Slave Bus Function Mode (BFM)
   axi_slave_BFM.v

   2012/02/25 : S_AXI_AWBURST＝1 (INCR) にのみ対応、AWSIZE, ARSIZE = 000 (1byte), 001 (2bytes), 010 (4bytes) のみ対応。
   2012/07/04 : READ_ONLY_TRANSACTION を追加。Read機能のみでも+1したデータを出力することが出来るように変更した。
   2014/01/05 : ポート名をM_AXI〜からS_AXI〜に修正、Verilogに移植（By Koba）
*/
// 2014/07/18 : Write Respose Channel に sync_fifo を使用した by marsee
// 2014/08/31 : READ_RANDOM_WAIT=1 の時に、S_AXI_RREADY が S_AXI_RVALID に依存するバグをフィック。 by marsee
//              WRITE_RANDOM_WAIT=1 の時に、S_AXI_WVALID が S_AXI_WREADY に依存するバグをフィック。 by marsee
//
// ライセンスは二条項BSDライセンス (2-clause BSD license)とします。
//


module axi_slave_bfm #(
    parameter integer C_S_AXI_ID_WIDTH       = 1,
    parameter integer C_S_AXI_ADDR_WIDTH     = 32,
    parameter integer C_S_AXI_DATA_WIDTH     = 32,
    parameter integer C_S_AXI_AWUSER_WIDTH   = 1,
    parameter integer C_S_AXI_ARUSER_WIDTH   = 1,
    parameter integer C_S_AXI_WUSER_WIDTH    = 1,
    parameter integer C_S_AXI_RUSER_WIDTH    = 1,
    parameter integer C_S_AXI_BUSER_WIDTH    = 1,

    parameter integer C_S_AXI_TARGET         = 0,
    parameter integer C_OFFSET_WIDTH         = 10, // 割り当てるRAMのアドレスのビット幅
    parameter integer C_S_AXI_BURST_LEN      = 256,

    parameter integer WRITE_RANDOM_WAIT      = 1, // Write Transactionデータ転送時にランダムなWaitを発生させる=1、Waitしない=0
    parameter integer READ_RANDOM_WAIT       = 1, // Read Transactionデータ転送時にランダムなWaitを発生させる=1、Waitしない=0
    parameter integer READ_DATA_IS_INCREMENT = 0, // Read TransactionでRAMのデータを読み出す=0、0はじまりの+1データを使う=1
    parameter integer RANDOM_BVALID_WAIT     = 1  // Write Transaction後、BVALIDをランダムにWaitする=1、ランダムにWaitしない=0
)
(
    // System Signals
    input ACLK,
    input ARESETN,

    // Slave Interface Write Address Ports
    input   [C_S_AXI_ID_WIDTH-1 : 0]    S_AXI_AWID,
    input   [C_S_AXI_ADDR_WIDTH-1 : 0]  S_AXI_AWADDR,
    input   [8-1 : 0]                   S_AXI_AWLEN,
    input   [3-1 : 0]                   S_AXI_AWSIZE,
    input   [2-1 : 0]                   S_AXI_AWBURST,
    // input S_AXI_AWLOCK [2-1 : 0],
    input   [1 : 0]                     S_AXI_AWLOCK,
    input   [4-1 : 0]                   S_AXI_AWCACHE,
    input   [3-1 : 0]                   S_AXI_AWPROT,
    input   [4-1 : 0]                   S_AXI_AWQOS,
    input   [C_S_AXI_AWUSER_WIDTH-1 :0] S_AXI_AWUSER,
    input                               S_AXI_AWVALID,
    output                              S_AXI_AWREADY,

    // Slave Interface Write Data Ports
    input   [C_S_AXI_DATA_WIDTH-1 : 0]  S_AXI_WDATA,
    input   [C_S_AXI_DATA_WIDTH/8-1 : 0]S_AXI_WSTRB,
    input                               S_AXI_WLAST,
    input   [C_S_AXI_WUSER_WIDTH-1 : 0] S_AXI_WUSER,
    input                               S_AXI_WVALID,
    output                              S_AXI_WREADY,

    // Slave Interface Write Response Ports
    output  [C_S_AXI_ID_WIDTH-1 : 0]    S_AXI_BID,
    output  [2-1 : 0]                   S_AXI_BRESP,
    output  [C_S_AXI_BUSER_WIDTH-1 : 0] S_AXI_BUSER,
    output                              S_AXI_BVALID,
    input                               S_AXI_BREADY,

    // Slave Interface Read Address Ports
    input   [C_S_AXI_ID_WIDTH-1 : 0]    S_AXI_ARID,
    input   [C_S_AXI_ADDR_WIDTH-1 : 0]  S_AXI_ARADDR,
    input   [8-1 : 0]                   S_AXI_ARLEN,
    input   [3-1 : 0]                   S_AXI_ARSIZE,
    input   [2-1 : 0]                   S_AXI_ARBURST,
    input   [2-1 : 0]                   S_AXI_ARLOCK,
    input   [4-1 : 0]                   S_AXI_ARCACHE,
    input   [3-1 : 0]                   S_AXI_ARPROT,
    input   [4-1 : 0]                   S_AXI_ARQOS,
    input   [C_S_AXI_ARUSER_WIDTH-1 : 0]S_AXI_ARUSER,
    input                               S_AXI_ARVALID,
    output                              S_AXI_ARREADY,

    // Slave Interface Read Data Ports
    output  reg [C_S_AXI_ID_WIDTH-1: 0] S_AXI_RID,
    output  [C_S_AXI_DATA_WIDTH-1 : 0]  S_AXI_RDATA,
    output  reg [2-1 : 0]               S_AXI_RRESP,
    output                              S_AXI_RLAST,
    output  [C_S_AXI_RUSER_WIDTH-1 : 0] S_AXI_RUSER,
    output                              S_AXI_RVALID,
    input                               S_AXI_RREADY
);
    
    import "DPI-C"  pure function int ram_access_rd(int adr);
    import "DPI-C"  pure function int ram_access_wr(int adr, int data);
    
localparam AXBURST_FIXED = 2'b00;
localparam AXBURST_INCR = 2'b01;
localparam AXBURST_WRAP = 2'b10;
localparam RESP_OKAY = 2'b00;
localparam RESP_EXOKAY = 2'b01;
localparam RESP_SLVERR = 2'b10;
localparam RESP_DECERR = 2'b11;
localparam DATA_BUS_BYTES = (C_S_AXI_DATA_WIDTH / 8);
//localparam ADD_INC_OFFSET = log2(DATA_BUS_BYTES);
localparam ADD_INC_OFFSET = (DATA_BUS_BYTES==1) ? 0:
                            (DATA_BUS_BYTES==2) ? 1:
                            (DATA_BUS_BYTES==4) ? 2:
                            (DATA_BUS_BYTES==8) ? 3:
                            (DATA_BUS_BYTES==16) ? 4:
                            (DATA_BUS_BYTES==32) ? 5:
                            (DATA_BUS_BYTES==64) ? 6:
                            (DATA_BUS_BYTES==128) ? 7: 32'hxxxxxxxx;

// fifo depth for address
localparam AD_FIFO_DEPTH         = 16;

// wad_fifo field
localparam WAD_FIFO_WIDTH        = C_S_AXI_ADDR_WIDTH+5+C_S_AXI_ID_WIDTH-1+1;
localparam WAD_FIFO_AWID_HIGH    = C_S_AXI_ADDR_WIDTH+5+C_S_AXI_ID_WIDTH-1;
localparam WAD_FIFO_AWID_LOW     = C_S_AXI_ADDR_WIDTH+5;
localparam WAD_FIFO_AWBURST_HIGH = C_S_AXI_ADDR_WIDTH+4;
localparam WAD_FIFO_AWBURST_LOW  = C_S_AXI_ADDR_WIDTH+3;
localparam WAD_FIFO_AWSIZE_HIGH  = C_S_AXI_ADDR_WIDTH+2;
localparam WAD_FIFO_AWSIZE_LOW   = C_S_AXI_ADDR_WIDTH;
localparam WAD_FIFO_ADDR_HIGH    = C_S_AXI_ADDR_WIDTH-1;
localparam WAD_FIFO_ADDR_LOW     = 0;

// wres_fifo field
localparam WRES_FIFO_WIDTH          = 2+C_S_AXI_ID_WIDTH-1+1;
localparam WRES_FIFO_AWID_HIGH      = 2+C_S_AXI_ID_WIDTH-1;
localparam WRES_FIFO_AWID_LOW       = 2;
localparam WRES_FIFO_AWBURST_HIGH   = 1;
localparam WRES_FIFO_AWBURST_LOW    = 0;

// rad_fifo field
localparam RAD_FIFO_WIDTH        = C_S_AXI_ADDR_WIDTH+13+C_S_AXI_ID_WIDTH-1+1;
localparam RAD_FIFO_ARID_HIGH    = C_S_AXI_ADDR_WIDTH+13+C_S_AXI_ID_WIDTH-1;
localparam RAD_FIFO_ARID_LOW     = C_S_AXI_ADDR_WIDTH+13;
localparam RAD_FIFO_ARBURST_HIGH = C_S_AXI_ADDR_WIDTH+12;
localparam RAD_FIFO_ARBURST_LOW  = C_S_AXI_ADDR_WIDTH+11;
localparam RAD_FIFO_ARSIZE_HIGH  = C_S_AXI_ADDR_WIDTH+10;
localparam RAD_FIFO_ARSIZE_LOW   = C_S_AXI_ADDR_WIDTH+8;
localparam RAD_FIFO_ARLEN_HIGH   = C_S_AXI_ADDR_WIDTH+7;
localparam RAD_FIFO_ARLEN_LOW    = C_S_AXI_ADDR_WIDTH;
localparam RAD_FIFO_ADDR_HIGH    = C_S_AXI_ADDR_WIDTH-1;
localparam RAD_FIFO_ADDR_LOW     = 0;

// RAMの生成
//localparam SLAVE_ADDR_NUMBER = 2 ** (C_OFFSET_WIDTH - ADD_INC_OFFSET);
//reg [(C_S_AXI_DATA_WIDTH - 1):0] ram_array [(SLAVE_ADDR_NUMBER - 1):0];
logic [(C_S_AXI_DATA_WIDTH - 1):0] ram_rddata;

// for write transaction
// write_address_state
//localparam IDLE_WRAD  = 1'd0;
//localparam AWR_ACCEPT = 1'd1;
//reg wradr_cs;
enum {IDLE_WRAD, AWR_WAIT, AWR_ACCEPT} wradr_cs;

// write_data_state
localparam IDLE_WRDT = 1'd0;
localparam WR_BURST  = 1'd1;
reg wrdat_cs;

// write_response_state
localparam IDLE_WRES     = 2'd0;
localparam WAIT_BVALID   = 2'd1;
localparam BVALID_ASSERT = 2'd2;
reg [1:0] wrres_cs;

integer addr_inc_step_wr = 1;
reg awready;
reg [(C_S_AXI_ADDR_WIDTH - 1):0]   wr_addr;
reg [(C_S_AXI_ID_WIDTH - 1):0] wr_bid;
reg [1:0] wr_bresp;
reg wr_bvalid;
reg [15:0] m_seq16_wr;
reg wready;

// wready_state
localparam IDLE_WREADY     = 2'd0;
localparam ASSERT_WREADY   = 2'd1;
localparam DEASSERT_WREADY = 2'd2;
reg [1:0] cs_wready;

wire cdc_we;
wire wad_fifo_full;
wire wad_fifo_empty;
wire wad_fifo_almost_full;
wire wad_fifo_almost_empty;
wire wad_fifo_rd_en;
wire [WAD_FIFO_WIDTH-1:0] wad_fifo_din;
wire [WAD_FIFO_WIDTH-1:0] wad_fifo_dout;
reg  [15:0] m_seq16_wr_res;
reg  [4:0]  wr_resp_cnt;

// wres_fifo
wire wres_fifo_wr_en;
wire wres_fifo_full;
wire wres_fifo_empty;
wire wres_fifo_almost_full;
wire wres_fifo_almost_empty;
wire wres_fifo_rd_en;
wire [WRES_FIFO_WIDTH-1:0] wres_fifo_din;
wire [WRES_FIFO_WIDTH-1:0] wres_fifo_dout;

// for read transaction
// read_address_state
//localparam IDLE_RDA   = 1'd0;
//localparam ARR_ACCEPT = 1'd1;
//reg rdadr_cs;
enum {IDLE_RDA, ARR_WAIT, ARR_ACCEPT} rdadr_cs;

// read_data_state
localparam IDLE_RDD = 1'd0;
localparam RD_BURST = 1'd1;
reg rddat_cs;

// read_last_state
localparam IDLE_RLAST   = 1'd0;
localparam RLAST_ASSERT = 1'd1;
reg rdlast;

integer addr_inc_step_rd = 1;
reg arready;
reg [(C_S_AXI_ADDR_WIDTH - 1):0] rd_addr;
reg [7:0] rd_axi_count;
reg rvalid;
reg rlast;
reg [15:0] m_seq16_rd;

// rvalid_state
localparam IDLE_RVALID     = 2'd0;
localparam ASSERT_RVALID   = 2'd1;
localparam DEASSERT_RVALID = 2'd2;
reg [1:0] cs_rvalid;

logic [(C_S_AXI_DATA_WIDTH - 1):0] read_data_count;
reg reset_1d;
reg reset_2d;
wire reset;
wire rad_fifo_full;
wire rad_fifo_empty;
wire rad_fifo_almost_full;
wire rad_fifo_almost_empty;
wire rad_fifo_rd_en;
wire [RAD_FIFO_WIDTH-1:0] rad_fifo_din;
wire [RAD_FIFO_WIDTH-1:0] rad_fifo_dout;

// ARESETN をACLK で同期化
always @ ( posedge ACLK ) begin
    reset_1d <= ~ARESETN;
    reset_2d <= reset_1d;
end

assign reset = reset_2d;

localparam WRADR_DLY = 30;
int wradr_delay;

// AXI4バス Write Address State Machine
always @ ( posedge ACLK ) begin
    if ( reset ) begin
        wradr_cs <= IDLE_WRAD;
        awready  <= 1'b0;
        wradr_delay <= 0;
    end
    else
        case (wradr_cs)
            IDLE_WRAD:  if ((S_AXI_AWVALID == 1'b1) && (wad_fifo_full == 1'b0) && (wres_fifo_full == 1'b0))    // S_AXI_AWVALIDが1にアサートされた
                        begin
                            wradr_cs <= AWR_WAIT;
                            wradr_delay <= 0;
                        end
            AWR_WAIT:   begin
                            wradr_delay <= wradr_delay + 1;
                            if(wradr_delay > WRADR_DLY) begin
                                awready <= 1'b1;
                                wradr_cs <= AWR_ACCEPT;
                            end
                        end
            AWR_ACCEPT: begin
                            wradr_cs <= IDLE_WRAD;
                            awready <= 1'b0;
                        end
        endcase
end

assign S_AXI_AWREADY = awready;


// {S_AXI_AWID, S_AXI_AWBURST, S_AXI_AWSIZE, S_AXI_AWADDR}を保存しておく同期FIFO
assign wad_fifo_din = {S_AXI_AWID, S_AXI_AWBURST, S_AXI_AWSIZE, S_AXI_AWADDR};

sync_fifo  #(
    .C_MEMORY_SIZE  (AD_FIFO_DEPTH),
    .DATA_BUS_WIDTH (WAD_FIFO_WIDTH)
  ) wad_fifo (
    .clk            (ACLK),
    .rst            (reset),
    .wr_en          (awready),
    .din            (wad_fifo_din),
    .full           (wad_fifo_full),
    .almost_full    (wad_fifo_almost_full),
    .rd_en          (wad_fifo_rd_en),
    .dout           (wad_fifo_dout),
    .empty          (wad_fifo_empty),
    .almost_empty   (wad_fifo_almost_empty)
);

assign wad_fifo_rd_en = (wready & S_AXI_WVALID & S_AXI_WLAST);


// AXI4バス Write Data State Machine
always @( posedge ACLK ) begin
    if ( reset )
        wrdat_cs <= IDLE_WRDT;
    else
        case (wrdat_cs)
            IDLE_WRDT:  if ( wad_fifo_empty == 1'b0 )   // AXI Writeアドレス転送の残りが1個以上ある
                            wrdat_cs <= WR_BURST;
            WR_BURST :  if ( S_AXI_WLAST & S_AXI_WVALID & wready )  // Write Transaction終了
                            wrdat_cs <= IDLE_WRDT;
        endcase
end

// M系列による16ビット乱数生成関数
function [15:0] M_SEQ16_BFM_F;
input [15:0] mseq16in;
reg   xor_result;
begin
    xor_result = mseq16in[15] ^ mseq16in[12] ^ mseq16in[10] ^ mseq16in[8] ^
                 mseq16in[7]  ^ mseq16in[6]  ^ mseq16in[3]  ^ mseq16in[2];
    M_SEQ16_BFM_F = {mseq16in[14:0], xor_result};
end
endfunction


// m_seq_wr、16ビットのM系列を計算する
always @( posedge ACLK ) begin
    if ( reset )
        m_seq16_wr <= 16'b1;
    else begin
        if ( WRITE_RANDOM_WAIT ) begin // Write Transaction時にランダムなWaitを挿入する
            if ( wrdat_cs == WR_BURST )
                m_seq16_wr <= M_SEQ16_BFM_F(m_seq16_wr);
        end
        else    // Wait無し
            m_seq16_wr <= 16'b0;
    end
end


// wready の処理、M系列を計算して128以上だったらWaitする。
always @( posedge ACLK ) begin
    if ( reset ) begin
        cs_wready <= IDLE_WREADY;
        wready    <= 1'b0;
    end
    else
        case (cs_wready)
            IDLE_WREADY:    if ( (wrdat_cs == IDLE_WRDT) && (wad_fifo_empty == 1'b0) ) begin
                                if ( (m_seq16_wr[7] == 1'b0) && (wres_fifo_full==1'b0) ) begin
                                    cs_wready <= ASSERT_WREADY;
                                    wready    <= 1'b1;
                                end
                                else begin
                                    cs_wready <= DEASSERT_WREADY;
                                    wready    <= 1'b0;
                                end
                            end
            ASSERT_WREADY:  if ( (wrdat_cs == WR_BURST) && S_AXI_WLAST && S_AXI_WVALID ) begin
                                cs_wready <= IDLE_WREADY;
                                wready <= 1'b0;
                            end
                            else if ( (wrdat_cs == WR_BURST) && S_AXI_WVALID ) begin
                                if ((m_seq16_wr[7] == 1'b1) || (wres_fifo_full==1'b1)) begin
                                    cs_wready <= DEASSERT_WREADY;
                                    wready <= 1'b0;
                                end
                            end
            DEASSERT_WREADY:if ( (m_seq16_wr[7] == 1'b0) && (wres_fifo_full==1'b0) ) begin
                                cs_wready <= ASSERT_WREADY;
                                wready <= 1'b1;
                            end
        endcase
end

assign S_AXI_WREADY = wready;
assign cdc_we = ( (wrdat_cs == WR_BURST) && wready && S_AXI_WVALID );


// addr_inc_step_wrの処理
always @ ( posedge ACLK ) begin
    if ( reset )
        addr_inc_step_wr <= 1;
    else begin
        if ( (wrdat_cs == IDLE_WRDT) & (wad_fifo_empty == 1'b0) )
            case (wad_fifo_dout[WAD_FIFO_AWSIZE_HIGH:WAD_FIFO_AWSIZE_LOW])
                3'b000 : addr_inc_step_wr <=   1;   //    8ビット転送
                3'b001 : addr_inc_step_wr <=   2;   //   16ビット転送
                3'b010 : addr_inc_step_wr <=   4;   //   32ビット転送
                3'b011 : addr_inc_step_wr <=   8;   //   64ビット転送
                3'b100 : addr_inc_step_wr <=  16;   //  128ビット転送
                3'b101 : addr_inc_step_wr <=  32;   //  256ビット転送
                3'b110 : addr_inc_step_wr <=  64;   //  512ビット転送
                default: addr_inc_step_wr <= 128;   // 1024ビット転送
            endcase
    end
end

// wr_addr の処理
always @ (posedge ACLK ) begin
    if ( reset )
        wr_addr <= 'b0;
    else begin
        if ( (wrdat_cs == IDLE_WRDT) && (wad_fifo_empty == 1'b0) )
            wr_addr <= wad_fifo_dout[(C_S_AXI_ADDR_WIDTH - 1):0];
        else if ( (wrdat_cs == WR_BURST) && S_AXI_WVALID && wready )    // アドレスを進める
            wr_addr <= (wr_addr + addr_inc_step_wr);
    end
end

// Wirte Response FIFO (wres_fifo)
sync_fifo #(
    .C_MEMORY_SIZE(AD_FIFO_DEPTH),
    .DATA_BUS_WIDTH(WRES_FIFO_WIDTH)
) wres_fifo (
    .clk(ACLK),
    .rst(reset),
    .wr_en(wres_fifo_wr_en),
    .din(wres_fifo_din),
    .full(wres_fifo_full),
    .almost_full(wres_fifo_almost_full),
    .rd_en(wres_fifo_rd_en),
    .dout(wres_fifo_dout),
    .empty(wres_fifo_empty),
    .almost_empty(wres_fifo_almost_empty)
);
assign wres_fifo_wr_en = (S_AXI_WLAST & S_AXI_WVALID & wready) ? 1'b1 : 1'b0;   // Write Transaction 終了
assign wres_fifo_din = {wad_fifo_dout[WAD_FIFO_AWID_HIGH:WAD_FIFO_AWID_LOW], wad_fifo_dout[WAD_FIFO_AWBURST_HIGH:WAD_FIFO_AWBURST_LOW]};
assign wres_fifo_rd_en = (wr_bvalid & S_AXI_BREADY) ? 1'b1 : 1'b0;

// S_AXI_BID の処理
assign S_AXI_BID = wres_fifo_dout[WRES_FIFO_AWID_HIGH:WRES_FIFO_AWID_LOW];

// S_AXI_BRESP の処理
// S_AXI_AWBURSTがINCRの時はOKAYを返す。それ以外はSLVERRを返す。
assign S_AXI_BRESP = (wres_fifo_dout[WRES_FIFO_AWBURST_HIGH:WRES_FIFO_AWBURST_LOW]==AXBURST_INCR) ? RESP_OKAY : RESP_SLVERR;

// wr_bvalid の処理
// wr_bvalid のアサートは、Write Data Channelの完了より必ず1クロックは遅延する
always @ ( posedge ACLK ) begin
    if ( reset ) begin
        wrres_cs <= IDLE_WRES;
        wr_bvalid <= 1'b0;
    end
    else
        case (wrres_cs)
            IDLE_WRES:  if ( wres_fifo_empty == 1'b0 ) begin    // Write Transaction 終了
                            if ( (m_seq16_wr_res == 0) || (RANDOM_BVALID_WAIT == 0) ) begin
                                wrres_cs <= BVALID_ASSERT;
                                wr_bvalid <= 1'b1;
                            end
                            else
                                wrres_cs <= WAIT_BVALID;
                        end
            WAIT_BVALID:if ( wr_resp_cnt == 0 ) begin
                            wrres_cs <= BVALID_ASSERT;
                            wr_bvalid <= 1'b1;
                        end
            BVALID_ASSERT: if ( S_AXI_BREADY ) begin
                            wrres_cs <= IDLE_WRES;
                            wr_bvalid <= 1'b0;
                          end
        endcase
end

assign S_AXI_BVALID = wr_bvalid;
assign S_AXI_BUSER  = 'b0;

// wr_resp_cnt
always @ ( posedge ACLK ) begin
    if ( reset )
        wr_resp_cnt <= 'b0;
    else begin
        if ( (wrres_cs == IDLE_WRES) && (wres_fifo_empty==1'b0) )
            wr_resp_cnt <= m_seq16_wr_res[4:0];
        else if ( wr_resp_cnt!=0 )
            wr_resp_cnt <= wr_resp_cnt - 1;
    end
end

// m_seq_wr_res、16ビットのM系列を計算する
always @ ( posedge ACLK ) begin
    if ( reset )
        m_seq16_wr_res <= 16'b1;
    else
        m_seq16_wr_res <= M_SEQ16_BFM_F(m_seq16_wr_res);
end

localparam ARR_DLY = 20;
int arr_delay;
// AXI4バス Read Address Transaction State Machine
always @ ( posedge ACLK ) begin
    if ( reset ) begin
        rdadr_cs <= IDLE_RDA;
        arready <= 1'b0;
        arr_delay <= 0;
    end
    else
        case (rdadr_cs)
            IDLE_RDA:   if ( (S_AXI_ARVALID == 1'b1) && (rad_fifo_full == 1'b0) ) begin // Read Transaction要求
                            rdadr_cs <= ARR_WAIT;
                            arready  <= 1'b0;
                            arr_delay <= 0;
                        end
            ARR_WAIT:   begin
                            arr_delay <= arr_delay + 1;
                            if(arr_delay > ARR_DLY) begin
                                rdadr_cs <= ARR_ACCEPT;
                                arready  <= 1'b1;
                            end
                        end
            ARR_ACCEPT: begin   // S_AXI_ARREADYをアサート
                            rdadr_cs <= IDLE_RDA;
                            arready  <= 1'b0;
                        end
        endcase
end

assign S_AXI_ARREADY = arready;


// S_AXI_ARID & S_AXI_ARBURST & S_AXI_ARSIZE & S_AXI_ARLEN & S_AXI_ARADDR を保存しておく同期FIFO
assign rad_fifo_din ={S_AXI_ARID, S_AXI_ARBURST, S_AXI_ARSIZE, S_AXI_ARLEN, S_AXI_ARADDR};

sync_fifo #(
    .C_MEMORY_SIZE  (AD_FIFO_DEPTH),
    .DATA_BUS_WIDTH (RAD_FIFO_WIDTH)
  ) rad_fifo
 (
    .clk            (ACLK),
    .rst            (reset),
    .wr_en          (arready),
    .din            (rad_fifo_din),
    .full           (rad_fifo_full),
    .almost_full    (rad_fifo_almost_full),
    .rd_en          (rad_fifo_rd_en),
    .dout           (rad_fifo_dout),
    .empty          (rad_fifo_empty),
    .almost_empty   (rad_fifo_almost_empty)
);

assign rad_fifo_rd_en = (rvalid & S_AXI_RREADY & rlast);


// AXI4バス Read Data Transaction State Machine
always @( posedge ACLK ) begin
    if ( reset ) begin
        rddat_cs <= IDLE_RDD;
    end else begin
        case (rddat_cs)
            IDLE_RDD:   if ( rad_fifo_empty == 1'b0 )   // AXI Read アドレス転送の残りが1個以上ある
                            rddat_cs <= RD_BURST;
            RD_BURST:   if ( (rd_axi_count == 0) && rvalid && S_AXI_RREADY )  // Read Transaction終了
                            rddat_cs <= IDLE_RDD;
        endcase
    end
end

// m_seq_rd、16ビットのM系列を計算する
always @ ( posedge ACLK ) begin
    if ( reset )
        m_seq16_rd <= 16'hffff;
    else begin
        if ( READ_RANDOM_WAIT) begin
            if ( rddat_cs == RD_BURST )
                m_seq16_rd <= M_SEQ16_BFM_F(m_seq16_rd);
        end else
            m_seq16_rd <= 16'b0;
    end
end


// rvalidの処理、M系列を計算して128以上だったらWaitする
always @( posedge ACLK ) begin
    if ( reset ) begin
        cs_rvalid <= IDLE_RVALID;
        rvalid    <= 1'b0;
    end
    else
        case (cs_rvalid)
            IDLE_RVALID:    if ( (rddat_cs == IDLE_RDD) && (rad_fifo_empty == 1'b0) ) begin // 次はrd_burst
                                if ( m_seq16_rd[7] == 1'b0 ) begin
                                    cs_rvalid <= ASSERT_RVALID;
                                    rvalid    <= 1'b1;
                                end
                                else begin
                                    cs_rvalid <= DEASSERT_RVALID;
                                    rvalid <= 1'b0;
                                end
                            end
            ASSERT_RVALID:  if ( (rddat_cs == RD_BURST) && rlast && S_AXI_RREADY ) begin    // 終了
                                cs_rvalid <= IDLE_RVALID;
                                rvalid    <= 1'b0;
                            end
                            else if ( (rddat_cs == RD_BURST) & S_AXI_RREADY ) begin // 1つのトランザクション終了
                                if ( m_seq16_rd[7] ) begin
                                    cs_rvalid <= DEASSERT_RVALID;
                                    rvalid    <= 1'b0;
                                end
                            end
            DEASSERT_RVALID:if ( m_seq16_rd[7] == 1'b0 ) begin
                                cs_rvalid <= ASSERT_RVALID;
                                rvalid    <= 1'b1;
                            end
        endcase
end

assign S_AXI_RVALID = rvalid;

// addr_inc_step_rdの処理
always @( posedge ACLK ) begin
    if ( reset )
        addr_inc_step_rd <= 1;
    else begin
        if ( (rddat_cs == IDLE_RDD) && (rad_fifo_empty == 1'b0) )
            case (rad_fifo_dout[RAD_FIFO_ARSIZE_HIGH:RAD_FIFO_ARSIZE_LOW])
                3'b000: addr_inc_step_rd <=   1;    //    8ビット転送
                3'b001: addr_inc_step_rd <=   2;    //   16ビット転送
                3'b010: addr_inc_step_rd <=   4;    //   32ビット転送
                3'b011: addr_inc_step_rd <=   8;    //   64ビット転送
                3'b100: addr_inc_step_rd <=  16;    //  128ビット転送
                3'b101: addr_inc_step_rd <=  32;    //  256ビット転送
                3'b110: addr_inc_step_rd <=  64;    //  512ビット転送
                default:addr_inc_step_rd <= 128;    // 1024ビット転送
            endcase
        end
end


// rd_addr の処理
always @ ( posedge ACLK ) begin
    if ( reset )
        rd_addr <= 'b0;
    else begin
        if ( (rddat_cs == IDLE_RDD) && (rad_fifo_empty == 1'b0) )
            rd_addr <= rad_fifo_dout[(C_S_AXI_ADDR_WIDTH - 1):0];
        else if ( (rddat_cs == RD_BURST) && S_AXI_RREADY && rvalid )
            rd_addr <= (rd_addr + addr_inc_step_rd);
    end
end
always @ ( negedge ACLK ) begin
    if(rvalid) begin
      for(int i = 0; i < (C_S_AXI_DATA_WIDTH / 8); i = i + 1) begin
          ram_rddata[(i * 8) +: 8] <= ram_access_rd(rd_addr+i);
      end
    end
end

assign S_AXI_RDATA = ram_rddata;

// rd_axi_countの処理（AXIバス側のデータカウント）
always @ ( posedge ACLK ) begin
    if ( reset )
        rd_axi_count <= 'b0;
    else begin
        if ( (rddat_cs == IDLE_RDD) && (rad_fifo_empty == 1'b0) ) // rd_axi_countのロード
            rd_axi_count <= rad_fifo_dout[RAD_FIFO_ARLEN_HIGH:RAD_FIFO_ARLEN_LOW];
        else if ( (rddat_cs == RD_BURST) && rvalid && S_AXI_RREADY )    // Read Transactionが1つ終了
            rd_axi_count <= rd_axi_count - 1;
    end
end


// rdlast State Machine
always @ ( posedge ACLK ) begin
    if ( reset ) begin
        rdlast <= IDLE_RLAST;
        rlast  <= 1'b0;
    end
    else
        case (rdlast)
            IDLE_RLAST: if ( (rd_axi_count == 1) && rvalid && S_AXI_RREADY ) begin  // バーストする場合
                            rdlast <= RLAST_ASSERT;
                            rlast  <= 1'b1;
                        end
                        else if ( (rddat_cs == IDLE_RDD) && (rad_fifo_empty == 1'b0) &&
                                  (rad_fifo_dout[RAD_FIFO_ARLEN_HIGH:RAD_FIFO_ARLEN_LOW] == 0) ) begin // 転送数が1の場合
                            rdlast <= RLAST_ASSERT;
                            rlast  <= 1'b1;
                        end
            RLAST_ASSERT:if ( rvalid && S_AXI_RREADY ) begin    // Read Transaction終了（rd_axi_count=0は決定）
                            rdlast <= IDLE_RLAST;
                            rlast  <= 1'b0;
                         end
        endcase
end

assign S_AXI_RLAST = rlast;


// S_AXI_RID, S_AXI_RUSER の処理
always @ ( posedge ACLK ) begin
    if ( reset )
        S_AXI_RID <= 'b0;
    else begin
        if ( (rddat_cs == IDLE_RDD) && (rad_fifo_empty == 1'b0) )
            S_AXI_RID <= rad_fifo_dout[RAD_FIFO_ARID_HIGH:RAD_FIFO_ARID_LOW];
    end
end

assign S_AXI_RUSER = 'b0;


// S_AXI_RRESP は、S_AXI_ARBURST がINCR の場合はOKAYを返す。それ以外はSLVERRを返す。
always @( posedge ACLK ) begin
    if ( reset )
        S_AXI_RRESP <= 'b0;
    else begin
        if ( (rddat_cs == IDLE_RDD) && (rad_fifo_empty == 1'b0) ) begin
            if ((rad_fifo_dout[RAD_FIFO_ARBURST_HIGH:RAD_FIFO_ARBURST_LOW] == AXBURST_INCR))
                S_AXI_RRESP <= RESP_OKAY;
            else
                S_AXI_RRESP <= RESP_SLVERR;
        end
    end
end

// RAM
//integer i, ram_waddr;
//assign ram_waddr = wr_addr[(C_OFFSET_WIDTH - 1):ADD_INC_OFFSET];
//    int ram_access(int wr, int adr, int wdata)
logic [1:0] ill_write;

always @( posedge ACLK ) begin
    if ( cdc_we ) begin :Block_Name_2
        for (int i=0; i<(C_S_AXI_DATA_WIDTH / 8); i=i+1) begin
            if ( S_AXI_WSTRB[i] )begin
            //    ram_array[wr_addr[(C_OFFSET_WIDTH - 1):ADD_INC_OFFSET]][(i * 8) +: 8] <= S_AXI_WDATA[(i * 8) +: 8];
            //    ram_access(1, S_AXI_AWADDR+ram_waddr*(C_S_AXI_DATA_WIDTH / 8)+i, S_AXI_WDATA[(i * 8) +: 8]);
                ill_write = ram_access_wr(wr_addr+i, S_AXI_WDATA[(i * 8) +: 8]);
           end
        end
    end
end

// Read Transaciton の時に +1 されたReadデータを使用する（Read 毎に+1）
/*--
always @( posedge ACLK ) begin
    if ( reset )
        read_data_count <= 'b0;
    else begin
        if ( (rddat_cs == RD_BURST) && rvalid && S_AXI_RREADY )
            read_data_count <= read_data_count + 1;
    end
end
--*/
//assign read_data_count = {32'(rd_addr[19:2]+3),32'(rd_addr[19:2]+2),32'(rd_addr[19:2]+1),32'(rd_addr[19:2]+0)};
//assign S_AXI_RDATA = (READ_DATA_IS_INCREMENT == 0) ? ram_array[rd_addr[(C_OFFSET_WIDTH - 1):ADD_INC_OFFSET]] : read_data_count;

endmodule

