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

// Calculates the len of a '\0' terminated string similar to C stdlib
size_t strlen(const char *s) {
    if (!s) return 0;
    const char *p = s;

    while (*p != '\0') p++;

    return (size_t) (p - s);
}
