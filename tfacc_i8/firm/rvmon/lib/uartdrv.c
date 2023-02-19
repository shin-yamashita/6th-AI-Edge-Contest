//
// uartdrv.c
//  mm6 uart control
//

#include "stdio.h"
#include "ulib.h"

//	sr_sio interface

#define brate(br)       ((int)(f_clk / (br) + 0.5f))

void uart_set_baud(int brreg)
{
        *SIOBR = brreg;
}


#ifdef TXIRQ
//#define RXIRQ

#define TXINTE  0x8 //
#define TXINT   0x4 // not txfull
#define TXFULL  0x2 // tx full
#define RXINTE  0x20
#define RXINT   0x10    // not rx empty
#define RXEMP   0x1 // rx empty

// SIOFLG  rxinte rxirq txinte txirq txf rxe

static char txbuf[256];
static u8 txwpt = 0, txrpt = 0;
static u8 txinte = 0;

static char rxbuf[256];
static u8 rxinte = 0;
static volatile u8 rxwpt = 0, rxrpt = 0;
//static u8 xoff = 0;

void txirq_handl()
{
    u8 flg = *SIOFLG;
    set_port(1);
    if(flg & TXINT){	// txirq
        *SIOTRX = txbuf[++txrpt];	// pop txbuf
        if(txwpt == txrpt){		// tx empty
            txinte = 0;
            *SIOFLG = txinte | rxinte;	// tx int disable
        }
    }
#ifdef RXIRQ
    if(flg & RXINT){
        rxbuf[rxwpt++] = *SIOTRX;
        if(rxwpt == rxrpt) rxwpt--; // rx full
        *SIOFLG = txinte | rxinte | RXEMP;  // increment rxfifo
    }
#endif
    reset_port(1);
}
#else
void txirq_handl(){}
#endif

unsigned char uart_rx(void)
{
    char c;
#ifdef RXIRQ
    rxinte = RXINTE;
    *SIOFLG = txinte | rxinte;
    enable_irq();
    set_port(2);
    while(rxwpt == rxrpt);  // while rxbuf empty
    c = rxbuf[rxrpt++];
    reset_port(2);
#else
    while(*SIOFLG & 1);     // while rx fifo empty
    c = *SIOTRX;
    while(!(*SIOFLG & 1)){	// while not empty
        *SIOFLG = 1;    // inc fifo pointer
    }
#endif
    return c;
}
int uart_rx_ready(void)
{
#ifdef RXIRQ
    return !(rxwpt == rxrpt);
#else
    return !(*SIOFLG & 1);
#endif
}

void uart_tx(unsigned char data)
{
    while(*SIOFLG & TXFULL);     // while tx fifo full
    *SIOTRX = data;
}

//--------- mini stdio --------------------------------------------

void uart_putc(char c)
{
#ifdef TXIRQ
    unsigned char res = txrpt - txwpt;

    if(res > 7){	// txbuf full
        while(*SIOFLG & TXFULL);	// while tx fifo full
    }
    txbuf[++txwpt] = c;	// push txbuf
    txinte = TXINTE;
    *SIOFLG = txinte | rxinte;
    enable_irq();   // set mie[11]

#else
    uart_tx(c);
#endif
}

ssize_t uart_read(int fd, char *buf, size_t count)
{
    int n = count;
    while(n--){
        *buf++ = uart_rx();
    }
    return count;
}

ssize_t uart_write(int fd, const char *buf, size_t count)
{
    int n = count;
    while(n--){
        uart_putc(*buf++);
    }
    return count;
}

