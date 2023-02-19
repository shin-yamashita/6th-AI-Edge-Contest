//
// expsf.c
// exp(x) single float
//
//

//#include <stdio.h>
#include <math.h>
#include "mathsf.h"

typedef union {float f; unsigned u;} fu_t;

#define LN2	((float)M_LN2)
#define INVLN2	((float)(1.0/M_LN2))

float expsf(float x)
{
 // 変数変換
 // e^x = 2^a
 // a = x/ln2
 // n = (int)a                      a を整数化
 // b = (a - n)ln2 = x - n*ln2      b はレンジが ln2 の範囲に絞られる
 // e^b = e^(x-n*ln2) = e^x 2^-n    
 // e^x = e^b 2^n                   b と n で exp(x) を再構成
 // calc exp(b) by Maclaurin expansion
 // re constract exp(x) = 2^n exp(b)　再構成
 // Maclaurin
 // exp(x) = 1 + x/1! + x^2/2! + ... + x^n/n! + ...

    float a, b, expb;
    int n;
    //                         1            1/2!                1/3!              1/4!           1/5!            1/6!
    // range reduction   -0.5ln2 < b < 0.5ln2
    a = x * INVLN2 + (x < 0.0f ? -0.5f : 0.5f);
    n = (int)a;
    b = x - n * LN2;

// calc exp(b) by Maclaurin (+ coeff adjust)

#ifdef DEGREE5
    const float cf5[] = {9.9999985252e-01,4.9999200435e-01,1.6667133594e-01,4.1890954711e-02,8.3186421629e-03,};
    expb = 1.0f+b*(cf5[0]+b*(cf5[1]+b*(cf5[2]+b*(cf5[3]+b*(cf5[4])))));
#else
    const float cf6[] = {1.0000000000e+00,4.9999996902e-01,1.6666648685e-01,4.1669474588e-02,8.3571913396e-03,1.3624404424e-03,};
    expb = 1.0f+b*(cf6[0]+b*(cf6[1]+b*(cf6[2]+b*(cf6[3]+b*(cf6[4]+b*(cf6[5]))))));
#endif

    // exp(x) = 2^n * exp(b)   再構成、 ieee754 形式の指数部を直接操作
    unsigned iy = (((fu_t)expb).u + (n << 23)) & 0x7fffffff;	// multiply 2^n 

    return ((fu_t)iy).f;
}


//  次数と誤差の関係 (-1.0 < x < 1.0) 　誤差は double の exp() との差の絶対値
// ncf   err max -1<x<1   expf()       乗算　加減算
// 3 er1:0.000151195 er2:7.04666e-08	5	6
// 4 er1:3.7567e-06  er2:7.04666e-08	6	7
// 5 er1:1.70737e-07 er2:7.04666e-08	7	8
// 6 er1:7.06131e-08 er2:7.04666e-08	8	9  *
// 7 er1:7.06131e-08 er2:7.04666e-08	9	10



