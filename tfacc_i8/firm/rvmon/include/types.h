//
//

#ifndef _TYPES_H
#define _TYPES_H

#include <stdint.h>

typedef unsigned size_t;
typedef int      ssize_t;

typedef int8_t   s8;
typedef uint8_t  u8;
typedef int16_t  s16;
typedef uint16_t u16;
typedef int32_t  s32;
typedef uint32_t u32;
typedef uint64_t u64;

typedef union {float f; unsigned u;} fu_t;
#define fu(x)	((fu_t)(x)).u
#define uf(x)	((fu_t)(x)).f

#endif	// _TYPES_H
