/*
   mm7 memory test
   2012/08/11
   2022/06/26 for rv_memif Arty-A7 DDR3 access test
*/

#include "stdio.h"
#include "ulib.h"
int rv_cache_flush();

#define A       16807           /* 乗数     */
#define M       2147483647      /* 周期 (2^31 - 1)  */

#define Q       127773
#define R       2836

static int seed = 1;

int i_rand()
{
        int i;

        i = A * (seed % Q) - R * (seed / Q);
        seed = (i > 0 ? i : i + M);

        return seed;
}

static u32 reg;

int prsg()
{
        reg <<= 1;
//        if(reg & (1 << 26)) reg ^= 0x4000047;	// 2^26-1
        if(reg & (1 << 24)) reg ^= 0x1000087;	// 2^24-1
        return reg & 0x3ffffff;
}

void reset_prsg(u32 d)
{
        reg = d;
}

//int main(int argc, char *argv[])
void memory_test()
{
    int i, cnt, err;
    u32 *buf   = (u32*)0x40000000;
    u16 *buf16 = (u16*)0x40000000;
    u8 *buf8   = (u8*)0x40000000;
    u32 d;
    int len = 1000000;	// 1M 32bitword
//    int len = 67585;	// 1000 32bitword
//    int len = 10000000;	// 10M 32bitword

    set_port(1);
    printf("memtst start\n write 32bit words.  mem[i] = &mem[i];");

    for(i = 0; i < len; i++){
        buf[i] = (u32)(&buf[i]);
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf[i]);
            printf(".");
        }
    }
    rv_cache_flush();
    reset_port(1);
    set_port(2);
    printf("\n %d words wrote\n read 32bit words and check", i);
    cnt = err = 0;

    for(i = 0; i < len; i++){
        if(buf[i] != (u32)(&buf[i])) cnt++;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf[i]);
            printf(cnt ? "x":".");
            err += cnt;
            cnt = 0;
        }
    }
    printf("\n %d words read\n%d errors\n", i, err);
    reset_port(2);

    set_port(1);
    printf("\n\n write 32bit words.  mem[i] = rand();");
    seed = 1;

    for(i = 0; i < len; i++){
        d = i_rand();
        buf[i] = d;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf[i]);
            printf(".");
        }
    }
    rv_cache_flush();
    reset_port(1);
    set_port(2);
    printf("\n %d words wrote\n read 32bit words and check", i);
    cnt = err = 0;

    seed = 1;
    for(i = 0; i < len; i++){
        d = i_rand();
        if(buf[i] != d) cnt++;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf[i]);
            printf(cnt ? "x":".");
            err += cnt;
            cnt = 0;
        }
    }
    printf("\n %d words read\n%d errors\n", i, err);
    reset_port(2);
//=============================================================

    printf("memtst start\n write 8bit words.  mem[i] = &mem[i];");

    for(i = 0; i < len; i++){
        buf8[i] = i&0xff;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf8[i]);
            printf(".");
        }
    }
    rv_cache_flush();
    printf("\n %d words wrote\n read 8bit words and check", i);
    cnt = err = 0;


    for(i = 0; i < len; i++){
        if(buf8[i] != (i&0xff)) cnt++;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf8[i]);
            printf(cnt ? "x":".");
            err += cnt;
            cnt = 0;
        }
    }
    printf("\n %d words read\n%d errors\n", i, err);

//=============================================================

    printf("\n\n write 8bit words.  mem[i] = rand();");
    seed = 1;

    for(i = 0; i < len; i++){
        d = i_rand()&0xff;
        buf8[i] = d;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf8[i]);
            printf(".");
        }
    }
    rv_cache_flush();
    printf("\n %d words wrote\n read 8bit words and check", i);
    cnt = err = 0;

    seed = 1;
    for(i = 0; i < len; i++){
        d = i_rand() & 0xff;
        if(buf8[i] != d) cnt++;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf8[i]);
            printf(cnt ? "x":".");
            err += cnt;
            cnt = 0;
        }
    }
    printf("\n %d words read\n%d errors\n", i, err);
//=============================================================

    printf("\n\n write 16bit words.  mem[i] = rand();");
    seed = 1;

    for(i = 0; i < len; i++){
        d = i_rand()&0xffff;
        buf16[i] = d;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf16[i]);
            printf(".");
        }
    }
    rv_cache_flush();
    printf("\n %d words wrote\n read 16bit words and check", i);
    cnt = err = 0;

    seed = 1;
    for(i = 0; i < len; i++){
        d = i_rand() & 0xffff;
        if(buf16[i] != d) cnt++;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf16[i]);
            printf(cnt ? "x":".");
            err += cnt;
            cnt = 0;
        }
    }
    printf("\n %d words read\n%d errors\n", i, err);
//=============================================================
#ifndef SIM
    printf("\n\n random write 32bit words.  mem[prs] = prs*4;");
#endif

    reset_prsg(1);

    for(i = 0; i < len/2; i++){
        d = prsg();
        d |= 0x01000000;
        buf[d] = d*4;
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf[i]);
            printf(".");
        }
    }
    rv_cache_flush();
#ifndef SIM
    printf("\n %d words wrote\n read 32bit words and check", i);
#endif
    cnt = err = 0;

    reset_prsg(1);

    for(i = 0; i < len/2; i++){
        d = prsg();
        d |= 0x01000000;
        if(buf[d] != d*4){
            set_port(2);
            cnt++;
        }else{
            reset_port(2);
        }
        if(!(i & 0xffff)){
            if(!(i & 0x3f0000)) printf("\n%x:", &buf[i]);
            printf(cnt ? "x":".");
            err += cnt;
            cnt = 0;
        }
    }
    printf("\n %d words read\n%d errors\n", i, err);
    
    return ;
}

