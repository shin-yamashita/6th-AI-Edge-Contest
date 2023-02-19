
#include <stddef.h>

size_t strlen(const char *s)
{
    int c = 0;
    while(*s++) c++;
    return c;
}


