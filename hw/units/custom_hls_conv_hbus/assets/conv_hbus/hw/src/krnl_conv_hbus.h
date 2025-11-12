#ifndef __CONV2D_HBUS_H
#define __CONV2D_HBUS_H

#include <stdint.h> // uint32_t
#include "ap_int.h"

///////////////////////////
// Notation from MAESTRO //
///////////////////////////

// Tensor Dimension Notation
// Input Batch      N
#define  N 1
// Output Channel   K
#define  K 3
// Input Channel    C
#define  C 6
// Input Row        Y
#define  Y 8
// Input Column     X
#define  X 8
// Filter Row       R
#define  R 3
// Filter Column    S
#define  S 3
// Output Row       Y’
#define Y1 6
// Output Column    X’
#define X1 6

// Tensor               Tensor Index
// Input Activation     I [n][c][y][x]
// Filter Weight        W [k][c][r][s]
// Partial Sum          P [n][k][c][y’][x’][r][s]
// Output Activation    O [n][k][y’][x’]

// Tensor sizes
#define SIZE_I ( N  *  C  *  Y  *  X )
#define SIZE_W ( K  *  C  *  R  *  S )
#define SIZE_O ( N  *  K  * Y1  * X1 )

// AXI bundle name
// Usa same bundle for all pointers
#define M_AXI_NAME_I master
#define M_AXI_NAME_W master
#define M_AXI_NAME_O master
// Usa a different bundle for each pointer
// #define M_AXI_NAME_I master_I
// #define M_AXI_NAME_W master_W
// #define M_AXI_NAME_O master_O

// AXI bundle width
#define M_AXI_DWIDTH 32
// #define M_AXI_DWIDTH 512

typedef uint8_t target_type_t;
#ifdef MOCK_AP_INT
    typedef uint8_t m_axi_port_type_t;
#else
    typedef ap_uint<M_AXI_DWIDTH> m_axi_port_type_t;
#endif


void krnl_conv_hbus (
                    m_axi_port_type_t * I,
                    m_axi_port_type_t * W,
                    m_axi_port_type_t * O,
                    uint8_t N_input,
                    uint8_t C_input,
                    uint8_t K_input
                );


void init_data (
                    target_type_t I[N][C][ Y][ X],
                    target_type_t W[K][C][ R][ S],
                    target_type_t O[N][K][Y1][X1]
                );

void compute_expected (
                    target_type_t I[N][C][ Y][ X],
                    target_type_t W[K][C][ R][ S],
                    target_type_t expected[N][K][Y1][X1]
                );

int check_values (
                    target_type_t out     [N][K][Y1][X1],
                    target_type_t expected[N][K][Y1][X1]
                );


#endif // __CONV_OPT1_H__