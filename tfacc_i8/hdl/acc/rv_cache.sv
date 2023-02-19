//
// rv_cache
//  SDRAM cache
// 2022/06/12 copy from mm10 sr_cache.vhd

`timescale 1ns/1ns
//`include "rv_types.svh"
`include "logic_types.svh"

module rv_cache #(parameter BASE = 16'h0010, LAST = 16'h7FFF)(	// 0x0010_0000 ~ 0x7fff_ffff
    input  logic xrst, //	: in	std_logic;

// chahe clear / flush request / busy status
    input  logic clreq,   //	: in	std_logic;
    output logic clbsy,   //	: out	std_logic;
    input  logic flreq,   //	: in	std_logic;
    output logic flbsy,   //	: out	std_logic;

// CPU bus
    input  logic cclk,   //	: in  	std_logic;
    input  u32_t adr,    //     : in  	unsigned(31 downto 0);
    input  u4_t  we,     //      : in  	std_logic_vector(3 downto 0);
    input  logic re,     //      : in  	std_logic;
    input  logic rdyin,  //	: in	std_logic;
    output logic rdy,    //	: out	std_logic;
    input  u32_t dw,     //      : in  	unsigned(31 downto 0);
    output u32_t dr,     //      : out 	unsigned(31 downto 0);

// memc interface
    input  logic aclk,      //		: in	std_logic;	// clock 120MHz in
    input  logic arst_n,    //		: in	std_logic;	// reset_n
    output u40_t awaddr,    // 		: out	std_logic_vector(39 downto 0);
    output u8_t  awlen,     //		: out	std_logic_vector(7 downto 0);
    output logic awvalid,   //		: out 	std_logic;
    input  logic awready,   //		: in	std_logic;

    output u32_t wr_data,   //		: out	std_logic_vector(31 downto 0);
    output logic wvalid,    //		: out	std_logic;	// wr_en
    output logic wlast,     //		: out	std_logic;
    input  logic wready,    //		: in	std_logic;	// wr_full

    output u40_t araddr,    //		: out	std_logic_vector(39 downto 0);
    output u8_t  arlen,     //		: out	std_logic_vector(7 downto 0);
    output logic arvalid,   //		: out	std_logic;
    input  logic arready,   //		: in	std_logic;

    input  u32_t rd_data,   //		: in	std_logic_vector(31 downto 0);
    input  logic rvalid,    //		: in	std_logic;	// rd_en
    input  logic rlast,     //		: in	std_logic;	// rd_en
    output logic rready     //		: out	std_logic	//
    );


/*
COMPONENT dpram10m
  PORT (
    clka 	: IN STD_LOGIC;
    wea 	: IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    addra 	: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    dina 	: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    douta 	: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    clkb 	: IN STD_LOGIC;
    web 	: IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    addrb 	: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    dinb 	: IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    doutb 	: OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

*/
u4_t    wea;    //	: std_logic_vector(3 downto 0);
u4_t    web;    //	: std_logic_vector(3 downto 0);
u32_t   douta;  //	: std_logic_vector(31 downto 0);

typedef enum u5_t {Idle, Ack, WrdyWait, Writecyc, Writecmd, Readcyc, Readcmd, Post} migstate_t;
migstate_t mst;
logic xrst30;   //	: std_logic;
logic wen2, wen2e;  //	: std_logic;
logic ren2, ren2e;  //, ren2e1;  //	: std_logic;
logic req2, wrq2, ack2; //	: std_logic;
u25_t adr2; //

//
typedef enum u2_t {cidle, write_back, read} state_t;

// Registers
u8_t dirty;     //  		: unsigned(7 downto 0);
state_t state;  //		: state_t;
u3_t mblk;  //		: std_logic_vector(2 downto 0);
logic re1;  //		: std_logic;
u3_t dwen, dren;    //	: unsigned(2 downto 0);
u32_t dr_h; //		: unsigned(31 downto 0);
logic drdy; //		: std_logic;
logic dack2;    //		: std_logic;
logic arst_n_s;

// wire
logic cs_d; //		: std_logic;
u3_t blk;   //		: unsigned(2 downto 0);
logic hit;  //		: std_logic;
//logic rdy_i		: std_logic;

u7_t addra; //		: std_logic_vector(6 downto 0);
u7_t addrb, addrb_f;    //	: std_logic_vector(6 downto 0);
//logic wea0, wea1, wea2, wea3	: std_logic;
u32_t dwl, drl; //		: std_logic_vector(31 downto 0);

// adr2      21 ...       0
// adr 31:28 27 ... 9 8 . 6 5 ... 0
//     0010  18 ... 0 2 1 0	mm6a
//           //Atag// -blk-

// adr2   24 ...       0
// adr 31 30 ... 9 8 . 6 5 ... 0
//     0  21 ... 0 2 1 0	mm6a
//        //Atag// -blk-

u4_t blkadr;    //
logic awe;  //	: std_logic;
u23_t atagwd;   //
u23_t atagrd;   //

typedef enum u2_t {cfIdle, Clean, Flush, Flwrite} cfstate_t;
cfstate_t cfstate;

// adrtag dist-ram instance
 assign blkadr = ((cfstate == Clean) | (cfstate == Flush) | !xrst30) ? {1'b0, mblk} : {1'b0, blk};
 assign atagwd = ((cfstate == Clean) | !xrst30) ? {1'b1, 22'h0} : {1'b0, adr[30:9]};

 adrtag u_adrtag (
    .a      (blkadr),	// u4  write adr
    .d      (atagwd),	// u23 write data
    .dpra   (blkadr),	// u4  read adr
    .clk    (cclk),
    .we     (awe),
    .xrst   (xrst30),
    .dpo    (atagrd)    // u23 read data
  );

// chip select
 assign cs_d = arst_n_s ? (adr[31:16] >= BASE && adr[31:16] <= LAST) : '0;
 assign blk = adr[8:6];

 assign hit = (atagrd == {1'b0, adr[30:9]}) ? cs_d : 1'b0;

 assign rdy = (we != '0 || re) ? !(cs_d && !hit) : '1;

 always_ff@(posedge cclk) begin
    if(rdyin) begin
        re1 <= re & cs_d;
    end
    drdy <= rdyin;
    if(drdy && !rdyin) begin
        dr_h <= drl;
    end
    arst_n_s <= arst_n; // async
 end
 assign drl = douta;

 always_ff@(posedge cclk) begin
    xrst30 <= xrst;
    dack2 <= ack2;	// sync clk96
    dwen <= {dwen[1:0], wen2};
    dren <= {dren[1:0], ren2};

    if(!xrst30) begin
        dirty <= '0;
        req2 <= '0;
        wrq2 <= '0;
        adr2 <= '0;
        awe <= '1;
    //    mblk <= mblk + 1;   // ?
        mblk <= '0;
        state <= cidle;
        cfstate <= cfIdle;
        clbsy <= '0;
        flbsy <= '0;
    end else if(cs_d && (we != '0 || re)) begin
        mblk <= adr[8:6];   //std_logic_vector(adr(8:6));
        if(!hit) begin  //then
            case (state)
            cidle : begin
                req2 <= '1;
                awe <= '0;
                if(dirty[blk]) begin   //then
                    state <= write_back;
                    wrq2 <= '1;
                    adr2 <= {(atagrd[21:0]), blk};
                end else begin
                    state <= read;
                    wrq2 <= '0;
                    adr2 <= adr[30:6];
                end
            end
            write_back :begin
                if(dack2) begin //then
                    req2 <= '0;
                end
                if(dwen[2:1] == 2'd2) begin //then
                    req2 <= '1;
                    state <= read;
                    wrq2 <= '0;
                    adr2 <= adr[30:6];
                end
            end
            read : begin
                if(dack2) begin //then
                    req2 <= '0;
                end
                if(dren[1:0] == 2'd2) begin //then
                    awe <= '1;
                end else begin
                    awe <= '0;
                end
                if(dren[2:1] == 2'd2) begin //then
                    dirty[blk] <= '0;
                    state <= cidle;
                    wrq2 <= '0;
                end
            end
            default :   //when others => null;
                ;
            endcase
        end else begin
            if(we != '0) begin  //then
                dirty[blk] <= '1;
            end
            awe <= '0;
        end
    end else begin
        case (cfstate)	// cache clean / flush sequence
        cfIdle : begin 
            if(clreq) begin
                clbsy <= '1;
            end
            if(flreq) begin
                flbsy <= '1;
            end
            mblk <= '0;
            req2 <= '0;
            if(flbsy) begin
                cfstate <= Flush;
                awe <= '0;
            end else if(clbsy) begin
                cfstate <= Clean;
                awe <= '1;
            end else begin
                awe <= '0;
            end
        end
        Clean : begin
            mblk <= mblk + 'd1;
            if(mblk == 'd7) begin
                cfstate <= cfIdle;
                awe <= '0;
                clbsy <= '0;
            end
        end
        Flush : begin
            if(dirty[mblk]) begin
                req2 <= '1;
                wrq2 <= '1;
                adr2 <= {atagrd[21:0], mblk};
                cfstate <= Flwrite;
            end else if(mblk == 'd7) begin
                cfstate <= cfIdle;
                flbsy <= '0;
            end else begin
                mblk <= mblk + 'd1;
            end
        end
        Flwrite : begin
            if(dack2) begin
                req2 <= '0;
            end
            if(dwen[2:1] == 2'd2) begin
                dirty[mblk] <= '0;
                cfstate <= Flush;
                wrq2 <= '0;
                mblk <= mblk + 'd1;
            end
        end
        endcase
    end
 end
 
 assign addra = adr[8:2];
 assign dr = (re1 && !drdy) ? dr_h : (re1 ? drl : 'd0);

 assign dwl  = dw;

 // cache ram   port a : cpu bus  port b : sdram

assign wea = (cs_d && hit) ? we : 4'd0;

 dpram10m u_dpram10m (
        .clka  (cclk),
        .wea   (wea),   // u4
        .addra (addra), // u7
        .dina  (dwl),   // u32
        .douta (douta), // u32
        .clkb  (aclk),
        .web   (web),   // u4
        .addrb (addrb_f),   // u7
        .dinb  (rd_data),   // u32
        .doutb (wr_data)    // u32
 );

 assign addrb_f = !wen2e ? addrb : {addrb[6:4],(addrb[3:0] + 4'd1)};

// mig side sequencer

 assign web = {ren2e,ren2e,ren2e,ren2e};
 logic req2_s, wrq2_s;

 always_ff@(posedge aclk) begin
    if(!arst_n) begin
        mst <= Idle;
        ack2 <= '0;
        ren2 <= '0;
        wen2 <= '0;
        req2_s <= '0; 
        wrq2_s <= '0;
    end else begin
        req2_s <= req2; // async
        wrq2_s <= wrq2;
        case(mst)
        Idle : begin
            ack2 <= '0;
            ren2 <= '0;
            wen2 <= '0;
            awvalid <= '0;
        //    wlast <= '0;
            arvalid <= '0;
            rready <= '0;
            if(req2_s) begin
                mst <= Ack;
            end
        end
        Ack : begin
            ack2 <= '1;
            addrb[3:0] <= '0;
            if(wrq2_s) begin
                mst <= Writecmd;
                awvalid <= '1;
            end else begin
                mst <= Readcmd;
                arvalid <= '1;
            end
        end
        Writecmd : begin
        //    wlast <= '0;
            if(awready) begin
                mst <= WrdyWait;
                awvalid <= '0;
            end else begin
                awvalid <= '1;
            end
        end
        WrdyWait : begin
            awvalid <= '0;
        //	if(wready = '1') begin
                wen2 <= '1;
                mst <= Writecyc;
        //	end if;
        end
        Writecyc : begin
            if(wen2e) begin
                addrb[3:0] <= addrb[3:0] + 'd1;
            end
            if(wen2e && (addrb[3:0] == 'd14)) begin
                ack2 <= '0;
            //    wlast <= '1;
                mst <= Post;
            end
        end
        Readcmd : begin
            if(arready) begin
                mst <= Readcyc;
                arvalid <= '0;
                rready <= '1;
            end else begin
                arvalid <= '1;
            end
        end
        Readcyc : begin
            arvalid <= '0;
            if(ren2e) begin
                addrb[3:0] <= addrb[3:0] + 'd1;
            end
            //if(ren2e && (addrb[3:0] == 'd14)) begin
            if(ren2e && rlast) begin
                ack2 <= '0;
                ren2 <= '0;
                mst <= Post;
            end else begin
                ren2 <= '1;
            end
        end
        Post : begin
            //if(wen2e||ren2e) begin
            //    wlast <= '0;
                wen2 <= '0;
                mst <= Idle;
                rready <= '0;
            //end
        end
        endcase
    end
    addrb[6:4] <= mblk;
 end

 assign wlast = wen2e && addrb[3:0] == awlen;

 assign wvalid = wen2;
 assign wen2e = wen2 & wready;
 assign ren2e = rvalid;

 assign awlen = 8'b00001111;	// 16x32=64byte burst
 assign arlen = 8'b00001111;	// 16x32=64byte burst
 assign awaddr = {9'h0, adr2, 6'b000000};
 assign araddr = {9'h0, adr2, 6'b000000};

endmodule
