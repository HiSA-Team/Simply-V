/******************************************************************************
* Copyright (C) 2014 - 2021 Xilinx, Inc.  All rights reserved.
* Copyright (C) 2022 - 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/

/*****************************************************************************/
/**
*
* @file xil_io.h
*
* @addtogroup common_io_interfacing_apis Register IO interfacing APIs
*
* The xil_io.h file contains the interface for the general I/O component, which
* encapsulates the Input/Output functions for the processors that do not
* require any special I/O handling.
*
* @{
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who      Date     Changes
* ----- -------- -------- -----------------------------------------------
* 5.00 	pkp  	 05/29/14 First release
* 6.00  mus      08/19/16 Remove checking of __LITTLE_ENDIAN__ flag for
*                         ARM processors
* 7.20  har      01/03/20 Added Xil_SecureOut32 for avoiding blindwrite for
*                         CR-1049218
* 7.30  kpt      09/21/20 Moved Xil_EndianSwap16 and Xil_EndianSwap32 to
*                         xil_io.h and made them as static inline
*       am       10/13/20 Changed the return type of Xil_SecureOut32 function
*                         from u32 to int
* 7.50  dp       02/12/21 Fix compilation error in Xil_EndianSwap32() that occur
*                         when -Werror=conversion compiler flag is enabled
* 7.5   mus      05/17/21 Update the functions with comments. It fixes CR#1067739.
* 9.0   ml       03/03/23 Add description and remove comments to fix doxygen warnings.
* </pre>
******************************************************************************/

#ifndef XIL_IO_H           /**< prevent circular inclusions */
#define XIL_IO_H           /**< by using protection macros */


/***************************** Include Files *********************************/

// #include "xil_types.h"

#define INLINE inline /**< static inline keyword */

/*****************************************************************************/
/**
*
* @brief    Performs an input operation for a memory location by reading
*           from the specified address and returning the 8 bit Value read from
*            that address.
*
* @param	Addr contains the address to perform the input operation
*
* @return	The 8 bit Value read from the specified input address.

*
******************************************************************************/
static INLINE u8 Xil_In8(uintptr_t Addr)
{
	return *(volatile u8 *) Addr;
}

/*****************************************************************************/
/**
*
* @brief    Performs an input operation for a memory location by reading from
*           the specified address and returning the 16 bit Value read from that
*           address.
*
* @param	Addr contains the address to perform the input operation
*
* @return	The 16 bit Value read from the specified input address.
*
******************************************************************************/
static INLINE u16 Xil_In16(uintptr_t Addr)
{
	return *(volatile u16 *) Addr;
}

/*****************************************************************************/
/**
*
* @brief    Performs an input operation for a memory location by
*           reading from the specified address and returning the 32 bit Value
*           read  from that address.
*
* @param	Addr contains the address to perform the input operation
*
* @return	The 32 bit Value read from the specified input address.
*
******************************************************************************/
static INLINE u32 Xil_In32(uintptr_t Addr)
{
	return *(volatile u32 *) Addr;
}

// /*****************************************************************************/
// /**
// *
// * @brief     Performs an input operation for a memory location by reading the
// *            64 bit Value read  from that address.
// *
// *
// * @param	Addr contains the address to perform the input operation
// *
// * @return	The 64 bit Value read from the specified input address.
// *
// ******************************************************************************/
// static INLINE u64 Xil_In64(uintptr_t Addr)
// {
// 	return *(volatile u64 *) Addr;
// }

/*****************************************************************************/
/**
*
* @brief    Performs an output operation for an memory location by
*           writing the 8 bit Value to the the specified address.
*
* @param	Addr contains the address to perform the output operation
* @param	Value contains the 8 bit Value to be written at the specified
*           address.
*
* @return	None.
*
******************************************************************************/
static INLINE void Xil_Out8(uintptr_t Addr, u8 Value)
{
	/* write 8 bit value to specified address */
	volatile u8 *LocalAddr = (volatile u8 *)Addr;
	*LocalAddr = Value;
}

/*****************************************************************************/
/**
*
* @brief    Performs an output operation for a memory location by writing the
*            16 bit Value to the the specified address.
*
* @param	Addr contains the address to perform the output operation
* @param	Value contains the Value to be written at the specified address.
*
* @return	None.
*
******************************************************************************/
static INLINE void Xil_Out16(uintptr_t Addr, u16 Value)
{
	/* write 16 bit value to specified address */
	volatile u16 *LocalAddr = (volatile u16 *)Addr;
	*LocalAddr = Value;
}

/*****************************************************************************/
/**
*
* @brief    Performs an output operation for a memory location by writing the
*           32 bit Value to the the specified address.
*
* @param	Addr contains the address to perform the output operation
* @param	Value contains the 32 bit Value to be written at the specified
*           address.
*
* @return	None.
*
******************************************************************************/
static INLINE void Xil_Out32(uintptr_t Addr, u32 Value)
{
	/* write 32 bit value to specified address */
	volatile u32 *LocalAddr = (volatile u32 *)Addr;
	*LocalAddr = Value;
}

// /*****************************************************************************/
// /**
// *
// * @brief    Performs an output operation for a memory location by writing the
// *           64 bit Value to the the specified address.
// *
// * @param	Addr contains the address to perform the output operation
// * @param	Value contains 64 bit Value to be written at the specified address.
// *
// * @return	None.
// *
// ******************************************************************************/
// static INLINE void Xil_Out64(uintptr_t Addr, u64 Value)
// {
// 	/* write 64 bit value to specified address */
// 	volatile u64 *LocalAddr = (volatile u64 *)Addr;
// 	*LocalAddr = Value;
// }


#endif
