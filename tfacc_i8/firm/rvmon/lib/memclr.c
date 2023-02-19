
#include <stddef.h>

void *memclr(void *s, size_t n)
{
    char *d = s;
    while(((unsigned)d & 0x3) && n--) *d++ = 0;
    while(n > 3){
        *((int*)d) = 0;
        n -= 4;
        d += 4;
    }
    while(n--) *d++ = 0;
    return s;
}

