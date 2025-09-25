// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
// control
// 0x00 : Control signals
//        bit 0  - ap_start (Read/Write/COH)
//        bit 1  - ap_done (Read)
//        bit 2  - ap_idle (Read)
//        bit 3  - ap_ready (Read/COR)
//        bit 4  - ap_continue (Read/Write/SC)
//        bit 7  - auto_restart (Read/Write)
//        bit 9  - interrupt (Read)
//        others - reserved
// 0x04 : Global Interrupt Enable Register
//        bit 0  - Global Interrupt Enable (Read/Write)
//        others - reserved
// 0x08 : IP Interrupt Enable Register (Read/Write)
//        bit 0 - enable ap_done interrupt (Read/Write)
//        bit 1 - enable ap_ready interrupt (Read/Write)
//        others - reserved
// 0x0c : IP Interrupt Status Register (Read/TOW)
//        bit 0 - ap_done (Read/TOW)
//        bit 1 - ap_ready (Read/TOW)
//        others - reserved
// 0x10 : Data signal of I
//        bit 31~0 - I[31:0] (Read/Write)
// 0x14 : Data signal of I
//        bit 31~0 - I[63:32] (Read/Write)
// 0x18 : reserved
// 0x1c : Data signal of W
//        bit 31~0 - W[31:0] (Read/Write)
// 0x20 : Data signal of W
//        bit 31~0 - W[63:32] (Read/Write)
// 0x24 : reserved
// 0x28 : Data signal of O
//        bit 31~0 - O[31:0] (Read/Write)
// 0x2c : Data signal of O
//        bit 31~0 - O[63:32] (Read/Write)
// 0x30 : reserved
// 0x34 : Data signal of N_input
//        bit 7~0 - N_input[7:0] (Read/Write)
//        others  - reserved
// 0x38 : reserved
// 0x3c : Data signal of C_input
//        bit 7~0 - C_input[7:0] (Read/Write)
//        others  - reserved
// 0x40 : reserved
// 0x44 : Data signal of K_input
//        bit 7~0 - K_input[7:0] (Read/Write)
//        others  - reserved
// 0x48 : reserved
// (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

#define XKRNL_CONV_HBUS_CONTROL_ADDR_AP_CTRL      0x00
#define XKRNL_CONV_HBUS_CONTROL_ADDR_GIE          0x04
#define XKRNL_CONV_HBUS_CONTROL_ADDR_IER          0x08
#define XKRNL_CONV_HBUS_CONTROL_ADDR_ISR          0x0c
#define XKRNL_CONV_HBUS_CONTROL_ADDR_I_DATA       0x10
#define XKRNL_CONV_HBUS_CONTROL_BITS_I_DATA       64
#define XKRNL_CONV_HBUS_CONTROL_ADDR_W_DATA       0x1c
#define XKRNL_CONV_HBUS_CONTROL_BITS_W_DATA       64
#define XKRNL_CONV_HBUS_CONTROL_ADDR_O_DATA       0x28
#define XKRNL_CONV_HBUS_CONTROL_BITS_O_DATA       64
#define XKRNL_CONV_HBUS_CONTROL_ADDR_N_INPUT_DATA 0x34
#define XKRNL_CONV_HBUS_CONTROL_BITS_N_INPUT_DATA 8
#define XKRNL_CONV_HBUS_CONTROL_ADDR_C_INPUT_DATA 0x3c
#define XKRNL_CONV_HBUS_CONTROL_BITS_C_INPUT_DATA 8
#define XKRNL_CONV_HBUS_CONTROL_ADDR_K_INPUT_DATA 0x44
#define XKRNL_CONV_HBUS_CONTROL_BITS_K_INPUT_DATA 8

