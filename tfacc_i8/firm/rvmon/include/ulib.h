//======================================================
// ulib.h
//  library for mm6 hardware control
//

#ifndef _ULIB_H
#define _ULIB_H

#include <_ansi.h>
#include <stdint.h>
#include "time.h"

_BEGIN_STD_C

#include "types.h"

//---- CSR access ----

#define csrw(csr, val) ({asm volatile ("csrw "#csr" , %0" :: "rK"(val));})
#define csrr(csr)      ({uint32_t __tmp;asm volatile ("csrr %0, "#csr : "=r"(__tmp)); __tmp;})
#define csrs(csr, val) ({asm volatile ("csrs "#csr" , %0" :: "rK"(val));})  // set
#define csrc(csr, val) ({asm volatile ("csrc "#csr" , %0" :: "rK"(val));})  // clear

#define csrwi(csr, imm) ({asm volatile ("csrw "#csr" , %0" :: "i"(imm));})
#define csrsi(csr, imm) ({asm volatile ("csrs "#csr" , %0" :: "i"(imm));})
#define csrci(csr, imm) ({asm volatile ("csrc "#csr" , %0" :: "i"(imm));})

#define MSIE    0x8
#define MTIE    0x80
#define MEIE    0x800
//----

#define __START	__attribute__ ((__section__ (".start"))) 
#define __SRAM	__attribute__ ((__section__ (".sram"))) 
#define __DRAM	__attribute__ ((__section__ (".dram"))) 

#define mtime	 ((volatile u64*)0xffff8000)
#define mtimecmp ((volatile u64*)0xffff8008)

//	para port
#define POUT    ((volatile u8*)0xffff0000)
#define GPIO    ((volatile u8*)0xffff0004)

//      rv_sio interface
#define SIOTRX  ((volatile char *)0xffff0020)
#define SIOFLG  ((volatile char *)0xffff0021)
#define SIOBR   ((volatile short *)0xffff0022)

//      rv_sysmon
#define SYSMON  ((volatile u32 *)0xffff0040)

//      ulib.c function prototypes


int get_pout();
void set_pout(int d);           // direct set 8bit
void set_port(int bit);         // bit set
void reset_port(int bit);       // bit reset
int get_port();

void init_timer(int br);
void disable_timer();
void enable_timer();
clock_t clock();

void set_expose(int exp);
//void timer_ctrl(void);
void wait(void);	// wait 1 ms
void n_wait(int n);	// wait n ms
void set_timer(int t);	// set 1ms counter val
int get_timer();	// 
void enable_irq();   //
void disable_irq();

void irq_handler(void);
void add_timer_irqh_sys(void (*irqh)(void));
void add_timer_irqh(void (*irqh)(void));
void add_user_irqh(void (*irqh)(void));
void add_user_irqh_1(void (*irqh)(void));
void add_user_irqh_2(void (*irqh)(void));
void remove_timer_irqh_sys(void);
void remove_timer_irqh(void);
void remove_user_irqh(void);
void remove_user_irqh_1(void);
void remove_user_irqh_2(void);

// memcpy32		len : # of bytes
void memcpy32(u32 *dst, u32 *src, size_t len);	// dst, src : u32 aligned
void memcpydma(u8 *dst, u8 *src, size_t len);	// sr_dmac

// memclr.c
void *memclr(void *s, size_t n);

// rcp.c
float rcp(float x);	// reciprocal  return 1/x

// sincos.c
float fsin(float x);
float fcos(float x);
void fsincos(float x, float *s, float *c);

// fsqrt.c
float invsqrt(float a);
float fsqrt(float x);

// from srmon.c
void getstr(char *str);
unsigned char asc2hex(int c);
unsigned int str2u32(char *s);

#include "uartdrv.h"

// clear bss section
extern u32 _bss_start, _end;
#define	zero_bss()	{u32 *p;for(p=&_bss_start;p<&_end;*p++=0);}
// get stack pointer
//static inline u32 get_sp(){u32 sp;__asm__("mv %0,sp" : "=r" (sp));return sp;}

_END_STD_C

#endif  // _ULIB_H
