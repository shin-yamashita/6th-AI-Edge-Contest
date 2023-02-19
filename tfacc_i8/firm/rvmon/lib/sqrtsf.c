
//#include "stdio.h"
#include "mathsf.h"
#include "types.h"

float invsqrt(float a)
{
    unsigned ix = (0xbe800000 - ((fu_t)a).u) >> 1;
    float x = ((fu_t)ix).f;

    // Xn+1 = Xn * (3 - A * Xn^2) / 2
    x = x * (3.0f - a * x * x) / 2;
    x = x * (3.0f - a * x * x) / 2;
    x = x * (3.0f - a * x * x) / 2;
    return x;
}

float sqrtsf(float x)
{
    return x * invsqrt(x);
}

