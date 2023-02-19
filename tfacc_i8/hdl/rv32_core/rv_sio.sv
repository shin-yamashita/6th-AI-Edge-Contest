
// rv_sio.sv
//  mini uart
//
// 2021/05/15 copy from mm/mm10 vhdl

`timescale 1ns/1ns
`include "logic_types.svh"

//import  pkg_rv_decode::*;

module rv_sio (
    input  logic clk,
    input  logic xreset,
// bus
    input  u5_t  adr,
    input  logic cs,
    input  logic rdy,
    input  u4_t  we,
    input  logic re,
    output logic irq,
    input  u32_t dw,
    output u32_t dr,
// port
    output logic txd,
    input  logic rxd,
    input  logic dsr,
    output logic dtr,
    output logic txen
    );

    // Registers
    u8_t  rfifo[4], tfifo[4];

    logic [1:0] rrp, rwp;
    logic [1:0] trp, twp;

    u8_t  tx, rx;
    u3_t  tbc, rbc;
    logic [1:0] rxlp;
    logic [1:0] inte, irq0;

    logic idsr;
    logic sndbrk;

    logic [13:0] br, tbrc, rbrc;
    // wire
    logic txf, rxe, rxf;
    logic cs0, re1;

    typedef enum logic [1:0] {Idle, StartBit, Trans, StopBit} state_t;
    state_t rst, tst;

    assign cs0 = cs && adr[4:2] == 3'd0;

    assign dr = re1 ? {16'(br), {sndbrk, 1'b0, inte[1], irq0[1], inte[0], irq0[0], txf, rxe}, rfifo[rrp]} : 'd0;

    assign txf = 2'(twp + 'd1) == trp;
    assign rxe = (rwp == rrp);
    assign rxf = 2'(rwp - rrp) > 'd1;

    assign irq0[1] = (inte[1] && !rxe);
    assign irq0[0] = (inte[0] && !txf);
    assign irq     = irq0[0] | irq0[1];

    always_ff @(posedge clk) begin
        if(rdy) begin
            re1 <= cs0 && re;
        end

        if(!xreset) begin
            br   <= 'd10;
            rrp  <= 'd0;
            twp  <= 'd0;
            inte <= 2'b00;
            sndbrk <= 1'b0;
        end else begin
            if(cs0 && rdy) begin
                if(we[0]) begin
                    tfifo[twp] <= dw[7:0];
            ////	putchar(dw(31 downto 24));	// for debug print
                    twp <= twp + 'd1;
                end
                if(we[1] && dw[8]) begin
                    rrp <= rrp + 'd1;
                end
                if(we[1]) begin
                    sndbrk  <= dw[15];	// 1: send break (txd //> 0)
                    inte[1] <= dw[13];	// 1: !RX-empty interrupt enable
                    inte[0] <= dw[11];	// 1: !TX-full interrupt enable
                end
                if(we[3]) begin
                    br[13:8] <= dw[29:24];
                end
                if(we[2]) begin
                    br[7:0] <= dw[23:16];
                end
            end
        end
    end

    always_ff @(posedge clk) begin // tx
        if(!xreset) begin
            tbrc <= 'd2;
            txd  <= 1'b1;
            txen <= 1'b0;
            trp  <= 'd0;
            tst  <= Idle;
            idsr <= 1'b0;
        end else begin
            if(tbrc == 'd1) begin
                idsr <= dsr;
                tbrc <= br;
                case (tst)
                Idle: begin
                    if(!((twp == trp) || idsr)) begin
                        tx  <= tfifo[trp];
                        trp <= trp + 'd1;
                        tst <= StartBit;
                    end
            //	    txd <= '1';
                    txd  <= !sndbrk;
                    txen <= 1'b0;
                    tbc  <= 3'd0;
                    end
                StartBit: begin
                    tst  <= Trans;
                    txd  <= 1'b0;
                    txen <= 1'b1;
                    end
                Trans: begin
                    tx  <= {1'b0, tx[7:1]};
                    txd <= tx[0];
                    tbc <= tbc + 'd1;
                    if(tbc == 'd7) begin
                        tst <= StopBit;
                    end
                end
                StopBit: begin
                    txd <= 1'b1;
                //	txen <= 1'b0;
                    tst <= Idle;
                    end
                default:
                    tst <= Idle;
                endcase
            end else begin
                tbrc <= tbrc - 'd1;
            end
        end
    end

    always_ff @(posedge clk) begin // rx
        rxlp <= {rxlp[0], rxd};
        dtr <= rxf;
        if(!xreset) begin
            rbrc <= 'd2;
            rst  <= Idle;
            rwp  <= 'd0;
        end else begin
            if(rst == Idle) begin
                if(rxlp == 2'b10) begin  // wait for start bit                    
                    rbrc <= {1'b0,br[13:1]};
                    rst  <= StartBit;
                end
            end else if(rbrc == 'd1) begin
                rbrc <= br;
                case (rst)
                StartBit: begin
                    rst <= Trans;
                    rbc <= 3'd0;
                end
                Trans: begin
                    rx  <= {rxlp[1], rx[7:1]};	// sampling
                    rbc <= rbc + 'd1;
                    if(rbc == 'd7) begin
                        rfifo[rwp] <= {rxlp[1], rx[7:1]};
                        rwp <= rwp + 'd1;
                        rst <= Idle;
                    end
                end
                default:
                    rst <= Idle;
                endcase
            end else begin
               rbrc <= rbrc - 'd1;
            end
        end
    end

endmodule
