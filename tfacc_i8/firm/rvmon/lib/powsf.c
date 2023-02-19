//
// powsf.c
// pow(x,y) single float
// x^y

//#include <stdio.h>
#include <math.h>

#include "mathsf.h"

typedef union {float f; unsigned u;} fu_t;

#define LN2	((float)M_LN2)

float powsf(float x, float y)
{
     // x^y = exp(log(x^y)) = exp(y * log(x))
    return expsf(y * logsf(x));
}

