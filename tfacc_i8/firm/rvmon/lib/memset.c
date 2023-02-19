
#include <stddef.h>

void *memset(void *s, int c, size_t n)
{
    char *d = s;
    while(n--) *d++ = c;
    return s;
}

