//
// logsf.c
// log(x) single float
//

//#include <stdio.h>
#include <math.h>

#include "mathsf.h"

typedef union {float f; unsigned u;} fu_t;

#define LN2	((float)M_LN2)

float logsf(float a)
{
 // 入力 a を２のべき乗表現で考え、指数部 2^n と仮数部 (1+x) にする
 // a --> 2^n * (1+x)
 // log(a) = log2(2^n)*LN2 + log(1+x) 
 //        = n * LN2 + log(1+x)
 // (1+x) の範囲は 1.0 <= (1+x) < 2.0 
 // log(1+x) をby Maclaurin 展開などで計算。ただし、Maclaurin の収束は非常に遅い。
 //
 // Maclaurin より収束のはやい形式を用いた。さらに係数を非線形最適化し、誤差を小さくした。
 // y = (x-1)/(x+1)　変数変換
 // log(x)/2 = y + (1/3)*y^3 + ... + (1/(2n-1))*y(2n-1) + ...
 // http://na-inet.jp/nasoft/chap06.pdf

 // 直接 ieee754 形式から整数演算で指数部と仮数部を取り出す
    int n = (int)( (((fu_t)a).u << 1) - 0x7f000000 ) >> 24;	// get ieee754 8bit exponent (2^n)
    unsigned ix = (((fu_t)a).u & 0x7fffff) | 0x3f800000;	// get 23bit fraction (1+frac)
    float x = ((fu_t)ix).f;
    float y = (x - 1.0f) / (x + 1.0f);	// 変数変換、除算1回
    float f, yy = y * y;

#ifdef DEGREE6
    const float cf6[] = {2.0000000000e+00,6.6666561224e-01,4.0004315684e-01,2.8480352473e-01,2.3043217603e-01,1.7447693180e-01,};
    f = y *(cf6[0] + yy*(cf6[1] + yy*(cf6[2] + yy*(cf6[3] + yy*(cf6[4] + yy*cf6[5])))));// 6次でfloat 限界
#else
    const float cf5[] = {2.0000000764e+00,6.6665553119e-01,4.0044387116e-01,2.7786767296e-01,2.8657712787e-01,};
    f = y *(cf5[0] + yy*(cf5[1] + yy*(cf5[2] + yy*(cf5[3] + yy*cf5[4]))));	// 5次でほぼfloat 限界
#endif

    return n * LN2 + f;
}

//  次数と誤差の関係 (0.1 < x < 10.0) 　誤差は double の log() との差の絶対値
//ncf   logsf() err     logf() err     除算　乗算　加減算
// 3 er1:3.8885e-06  er2:1.62852e-07	1     4     4
// 4 er1:2.2401e-07  er2:1.62852e-07	1     5     5
// 5 er1:1.71833e-07 er2:1.62852e-07	1     6     6	*
// 6 er1:1.62852e-07 er2:1.62852e-07	1     7     7


