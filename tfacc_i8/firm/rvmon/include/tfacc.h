//
// 2020/03/23 tfacc.h
// tfacc_core driver
//

#include "types.h"

//      tfacc_core 

#define CACHECTRL       ((volatile u8*)0xffff0180)
#define RVCACHECTRL       ((volatile u8*)0xffff0188)

#define TFACCCACHE      ((volatile u32 *)0xffff0180)

#define TFACCFLG        ((volatile u32 *)0xffff0300)	// b0:(w)kick (r)run b8:(wr)cmpl b9:(wr)inten

#define BASEADR_OUT     ((volatile u32 *)0xffff0304)
#define BASEADR_IN      ((volatile u32 *)0xffff0308)
#define BASEADR_FILT    ((volatile u32 *)0xffff030c)
#define BASEADR_BIAS    ((volatile u32 *)0xffff0310)
#define BASEADR_QUANT   ((volatile u32 *)0xffff0314)

#define TFACC_NP        ((volatile u32 *)0xffff031c)
#define TFACCMON        ((volatile u32 *)0xffff0320)    // monisel
#define TFACCFPR        ((volatile u32 *)0xffff0324)    // fpr 

#define TFACCPARAM      ((volatile u32 *)0xffff0400)    // accparams[64]

#define RESET_REG       ((volatile u32 *)0x00000080)
#define RUN_REG         ((volatile u32 *)0x00000084)
#define RUN_REG_P       ((volatile u32 *)0x000001f0)

#define PREP_BUF        ((volatile u32 *)0x000000c0)    // Preproc data buffer addr
#define PREP_ST         ((volatile u32 *)0x000000c4)    // Preproc process status 1:progress
#define PREP_LEN        ((volatile u32 *)0x000000c8)    // lider data length (float word)
#define PREP_W          ((volatile u32 *)0x000000cc)    // BEV H,W size
#define PREP_BANK       ((volatile u32 *)0x000000d0)    // BEV bank 0/1
#define PREP_BNDRY      ((volatile float *)0x000000d4)    // BNDRY
#define PREP_AREA       ((volatile float *)0x000000d8)    // area
#define PREP_R45        ((volatile u32 *)0x000000dc)    // R45

#define FREQ_REG        ((volatile u32 *)0x000000f0)
#define ACCPARAMS       ((volatile u32 *)0x00000100)

//u32 *accparams = (u32*)0x100;

#define set_param(n, p)     (ACCPARAMS[n] = (p))
#define get_param(n)        (ACCPARAMS[n])
#define set_accparam(n, p)  set_param(8+(n), (p))
#define get_accparam(n)     get_param(8+(n))

typedef enum {
    kTfaccNstage = 5,
    kTfaccDWen,
    kTfaccRun,
} TfaccCtrl;

_BEGIN_STD_C
void run_preproc();
int rv_cache_flush();
int rv_cache_clean();
_END_STD_C
