#ifndef __XLNX_H__
#define __XLNX_H__

// Define types for xil_io.h
#include <stdint.h>
typedef char char8;
typedef int8_t s8;
typedef uint8_t u8;
typedef int16_t s16;
typedef uint16_t u16;
typedef int32_t s32;
typedef uint32_t u32;
typedef int sint32;

// Inlcude I/O macros
#include "xil_io.h"

// Include IP-specific symbols
#include "driver.h"

#endif // __XLNX_H__
