#include "stdlib.h"

// Local memcpy (byte-wise unoptimized)
void* memcpy(void* dest, const void* src, size_t n)
{
    for (size_t i = 0; i < n; i++) {
        ((char*)dest)[i] = ((char*)src)[i];
    }
}

// Local memset (from https://github.com/gcc-mirror/gcc/blob/master/libiberty/memset.c)
void* memset(void* dest, register int val, register size_t len)
{
    register unsigned char* ptr = (unsigned char*)dest;
    while (len-- > 0)
        *ptr++ = val;
    return dest;
}
