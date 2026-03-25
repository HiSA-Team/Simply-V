// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//  HLS implementation of a CONV2D engine.
//  Version HBUS: Wide M_AXI port for HBUS.

// Headers
#include <stdio.h>  // For printf()
#include <assert.h> // For assert()
#include "krnl_conv_hbus.h"

void krnl_conv_hbus (
                    m_axi_port_type_t * I,
                    m_axi_port_type_t * W,
                    m_axi_port_type_t * O,
                    uint8_t N_input,
                    uint8_t C_input,
                    uint8_t K_input
                ) {

    #pragma HLS INTERFACE mode=m_axi depth=((SIZE_I/sizeof(m_axi_port_type_t))) bundle=gmem0 port=I \
        max_read_burst_length=16 \
        max_widen_bitwidth=512 \
        max_write_burst_length=16

    #pragma HLS INTERFACE mode=m_axi depth=((SIZE_W/sizeof(m_axi_port_type_t))+1) bundle=gmem0 port=W \
        max_read_burst_length=16 \
        max_widen_bitwidth=512 \
        max_write_burst_length=16

    #pragma HLS INTERFACE mode=m_axi depth=((SIZE_O/sizeof(m_axi_port_type_t))+1) bundle=gmem0 port=O \
        max_read_burst_length=16 \
        max_widen_bitwidth=512 \
        max_write_burst_length=16 \
        num_read_outstanding=16

    // Help the compiler infer minimum loop iterations
    assert ( N_input > 0 );
    assert ( K_input > 0 );
    assert ( C_input > 0 );

    // Pre-load Input feature map
    #define FETCH_LEN_I ((SIZE_I/sizeof(m_axi_port_type_t))) // No need for +1, since it is already m_axi_port_type_t-aligned
    m_axi_port_type_t I_fetch_line [FETCH_LEN_I] = {0};
    // printf("FETCH_LEN_I %lu\n\r", FETCH_LEN_I);
    // printf("sizeof(m_axi_port_type_t) %u\n\r", sizeof(m_axi_port_type_t));
    // printf("I [ 0 ] = %s\n\r", I [ 0 ].to_string(16).c_str());
    // printf("I [ 1 ] = %s\n\r", I [ 1 ].to_string(16).c_str());
    // printf("I [ 2 ] = %s\n\r", I [ 2 ].to_string(16).c_str());
    // printf("I [ 3 ] = %s\n\r", I [ 3 ].to_string(16).c_str());
    // printf("I [ 4 ] = %s\n\r", I [ 4 ].to_string(16).c_str());
    // printf("I [ 5 ] = %s\n\r", I [ 5 ].to_string(16).c_str());
    // printf("I [ 6 ] = %s\n\r", I [ 6 ].to_string(16).c_str());
    // Fetch line-wise
    for ( uint64_t fetch_index = 0; fetch_index < FETCH_LEN_I; fetch_index++ ) {
        I_fetch_line [ fetch_index ] = I [ fetch_index ];
    }
    // Fetch byte-wise
    // NOTE: no need, since it is already m_axi_port_type_t-aligned

    // Pre-fetch all filter weights
    #define FETCH_LEN_W ((SIZE_W/sizeof(m_axi_port_type_t))+1)
    m_axi_port_type_t W_fetch_line [FETCH_LEN_W] = {0};
    // printf("FETCH_LEN_W %lu\n\r", FETCH_LEN_W);
    // printf("W [ 0 ] = %s\n\r", W [ 0 ].to_string(16).c_str());
    // printf("W [ 1 ] = %s\n\r", W [ 1 ].to_string(16).c_str());
    // printf("W [ 2 ] = %s\n\r", W [ 2 ].to_string(16).c_str());
    // Fetch line-wise
    for ( uint64_t fetch_index = 0; fetch_index < (FETCH_LEN_W-1); fetch_index++ ) {
        W_fetch_line [ fetch_index ] = W [ fetch_index ];
    }
    // Fetch byte-wise
    #define FETCH_LEN_W_LAST (SIZE_W)
    for ( uint64_t fetch_index = (SIZE_W/sizeof(m_axi_port_type_t)); fetch_index < FETCH_LEN_W_LAST; fetch_index++ ) {
        ((uint8_t*)W_fetch_line) [ fetch_index ] = ((uint8_t*)W) [ fetch_index ];
    }

    // For input batch size
    for ( uint8_t n = 0; n < N_input; n++ ) {

        // Local buffer for I [N][C][ Y][ X]
        target_type_t I_local [C * Y * X];
        for ( uint64_t cyx = 0; cyx < (C * X * Y); cyx++ ) {
            ((target_type_t*)I_fetch_line) [ cyx ] = ((target_type_t*)I) [(n * C * X * Y) + cyx];
        }

        // For output batch size
        for ( uint8_t k = 0; k < K_input; k++ ) {

            // Reset accumulator
            target_type_t accumulator[Y1 * X1] = {0};

            // For each input channel
            for ( uint8_t c = 0; c < C_input; c++ ) {
                // Local buffers for W [K][C][R][S]
                target_type_t W_local [R * S];
                // Preload buffer
                for ( uint8_t rs = 0; rs < R * S; rs++ ) {
                    #define INDEX_W ( ( ( k * C_input ) + c ) * R * S + rs )
                    #define INDEX_W_LOCAL ( rs )
                    W_local [INDEX_W_LOCAL] = ((target_type_t*)W_fetch_line) [INDEX_W];
                    #undef INDEX_W_LOCAL
                } // rs < R * S

                // For I dimensions Y1 and X1
                for ( uint8_t y1 = 0; y1 < Y1; y1++ ) {
                    for ( uint8_t x1 = 0; x1 < X1; x1++ ) {
                        // Compute
                        for ( uint8_t r = 0; r < R; r++ ) {
                            for ( uint8_t s = 0; s < S; s++ ) {
                                #define INDEX_W_LOCAL ( r * S + s )
                                #define INDEX_I ( ( ( c * Y ) + (y1+r) ) * X + (x1+s) )
                                #define INDEX_ACC ( y1 * X1 + x1 )
                                accumulator[INDEX_ACC] += W_local [INDEX_W_LOCAL] * ((target_type_t*)I_fetch_line) [INDEX_I];
                                #undef INDEX_W_LOCAL
                            } // s < S
                        } // r < R
                    } // x1 < x1
                } // y1 < Y1
            } // c < C

            // Store result
            for ( uint8_t y1x1 = 0; y1x1 < Y1 * X1; y1x1++ ) {
                #define INDEX_O ( ( ( n * K_input ) + k ) * Y1 * X1 + y1x1 )
                ((target_type_t*)O) [ INDEX_O ] = accumulator [y1x1];
            } // y1x1 < Y1 * X1
        } // k < K
    } // n < N
} // krnl_conv_hbus()