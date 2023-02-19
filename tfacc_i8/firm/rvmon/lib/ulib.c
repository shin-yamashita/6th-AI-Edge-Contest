//======================================================
//  2010/04  ulib.c   mm6 hardware driver library
//

#include "stdio.h"
#include <stdlib.h>
#include <string.h>
#include "ulib.h"
#include "time.h"

// POUT  parallel output port

static unsigned char _pout = 0;

int get_pout()
{
    return _pout;
}
void set_pout(int d)		// direct set 8bit
{
    *POUT = _pout = d;
}
void set_port(int bit)		// bit set
{
    _pout |= (1<<bit);
    *POUT = _pout;
}
void reset_port(int bit)	// bit reset
{
    _pout &= ~(1<<bit);
    *POUT = _pout;
}
int get_port()
{
    return *POUT;
}

//	mtime interface

static volatile int timer;
static volatile int tick;
static volatile int tmexp, expose;
static volatile int _br;

void init_timer(int br)
{
//    _br = (int)(f_clk / br + 0.5f);
    _br = br;
    *mtime = 0l;
    *mtimecmp = (u64)_br;
    timer = 0;
    csrs(mie, MTIE);
    //	csrc(mip, MTIE);
}
void disable_timer()
{
    csrc(mie, MTIE);
}
void enable_timer()
{
    *mtime = 0l;
    *mtimecmp = (u64)_br;
    csrs(mie, MTIE);
}
clock_t clock()
{
    return *mtime;
}

void at_exit()
{
    printf("** exit() timer: %d\n", timer);
}
void enable_irq()
{
    csrs(mie, MEIE);
}
void disable_irq()
{
    csrc(mie, MEIE);
}
void set_expose(int exp)
{
    expose = exp;
}
/*
void timer_ctrl(void)
{
	if(csrr(mip) & MTIE){
 *mtimecmp += _br;
	}
	tmexp++;
}
 */

void wait(void)
{
    while(!tick) ;  // wait for 1 ms interrupt
    tick = 0;
}
void n_wait(int n)
{
    int i;
    for(i = 0; i < n; i++) wait();
}
void set_timer(int t)
{
    timer = t;
}
int get_timer()
{
    return timer;
}
//----- interrupt handler -----------------------------
//  irq (sr_core irq pin - vector #1)

static void (*timer_irqh_s)(void) = 0;
static void (*timer_irqh)(void) = 0;
static void (*user_irqh)(void) = 0;
static void (*user_irqh1)(void) = 0;
static void (*user_irqh2)(void) = 0;

static void timer_handl(void)
{
    if(csrr(mip) & MTIE){
        set_port(7);
        *mtimecmp += _br;
        if(timer_irqh_s)
            (*timer_irqh_s)(); // 1ms system handler call
        if(timer_irqh)
            (*timer_irqh)(); // 1ms user handler call
        timer++;
        tick = 1;
        csrs(mie, MTIE);
        //	csrc(mip, MTIE);
        reset_port(7);
    }
}

void irq_handler(void)
{
    timer_handl();
    if(csrr(mip) & MEIE){
        txirq_handl();
        if(user_irqh)  (*user_irqh)();
        if(user_irqh1) (*user_irqh1)();
        if(user_irqh2) (*user_irqh2)();
        csrs(mie, MEIE);
    }
}

void add_timer_irqh_sys(void (*irqh)(void))
{
    timer_irqh_s = irqh;
}
void add_timer_irqh(void (*irqh)(void))
{
    timer_irqh = irqh;
}
void add_user_irqh(void (*irqh)(void))
{
    user_irqh = irqh;
}
void add_user_irqh_1(void (*irqh)(void))
{
    user_irqh1 = irqh;
}
void add_user_irqh_2(void (*irqh)(void))
{
    user_irqh2 = irqh;
}
void remove_timer_irqh(void)
{
    timer_irqh = 0;
}
void remove_timer_irqh_sys(void)
{
    timer_irqh_s = 0;
}
void remove_user_irqh(void)
{
    user_irqh = 0;
}
void remove_user_irqh_1(void)
{
    user_irqh1 = 0;
}
void remove_user_irqh_2(void)
{
    user_irqh2 = 0;
}
