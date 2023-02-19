//
// memcpy.c
// copy memory to memory
// 2012/12/17
//

#include "stdio.h"
#include "ulib.h"

//static u32 cpbuf[64];

void memcpy32(u32 *d32, u32 *s32, size_t len)	// len : # of bytes
{
	int mlen = len & 0x3;
	len /= 4;

	while(len--){
		*d32++ = *s32++;
	}
	u8 *d8 = (u8*)d32; 
	u8 *s8 = (u8*)s32; 
	while(mlen--){
		*d8++ = *s8++;
	}
}

#if 0
void memcpydma(u8 *dst, u8 *src, size_t len)	// sr_dmac control
{
	if(len < 16){
	  while(len--){
	    *dst++ = *src++;
	  }
	}else{
      	  while(*DMACMD & 0x1);   // dmac busy?
      	  *DMASRCPT = (u32)src;
      	  *DMADSTPT = (u32)dst;
      	  *DMALEN = len;
      	  *DMACMD = 1;
	}
}

#endif
