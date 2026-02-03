#ifndef __STDLIB_H_
#define __STDLIB_H_

// System libraries
#include <stddef.h>
#include <stdint.h>

void* memcpy(void* dest, const void* src, size_t n);

void* memset(void* dest, register int val, register size_t len);

#endif // __STDLIB_H_
