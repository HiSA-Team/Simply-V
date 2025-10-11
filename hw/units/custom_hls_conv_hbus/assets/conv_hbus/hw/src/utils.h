#ifndef __UTILS_C_
#define __UTILS_C_

#include <stddef.h>
#include <stdint.h>

// Init I and W tensors with pseudo-random values
// Init O tensor with constant 0x55555555
void init_data (
                    target_type_t I[N][C][ Y][ X],
                    target_type_t W[K][C][ R][ S],
                    target_type_t O[N][K][Y1][X1]
                ) {

    // Init I
    for ( uint32_t n = 0; n < N; n++ )
            for ( uint32_t c = 0; c < C; c++ )
                for ( uint32_t y = 0; y < Y; y++ )
                    for ( uint32_t x = 0; x < X; x++ )
                            I[n][c][y][x] = (x << 4) + y;

    // Init W
    for ( uint32_t k = 0; k < K; k++ )
            for ( uint32_t c = 0; c < C; c++ )
                for ( uint32_t r = 0; r < R; r++ )
                    for ( uint32_t s = 0; s < S; s++ )
                            W[k][c][s][r] = (s << 4) + r;

    // Init O
    for ( uint32_t n = 0; n < N; n++ )
            for ( uint32_t k = 0; k < K; k++ )
                for ( uint32_t y1 = 0; y1 < Y1; y1++ )
                    for ( uint32_t x1 = 0; x1 < X1; x1++ )
                            O[n][k][y1][x1] = (target_type_t)0x55555555;

}

// Print num_batch x num_chan x num_rows x num_cols tensor
void print_tensor (
                    target_type_t * data,
                    uint32_t        num_batch,
                    uint32_t        num_chan,
                    uint32_t        num_rows,
                    uint32_t        num_cols
                ) {
    for ( uint32_t n = 0; n < num_batch; n++ ) {
        printf("Batch %u \n\r", n);
        for ( uint32_t ch = 0; ch < num_chan; ch++ ) {
            printf("\tChannel %u \n\r\t\t", ch);
            for ( uint32_t r = 0; r < num_rows; r++ ) {
                for ( uint32_t c = 0; c < num_cols; c++ ) {
                    printf("0x%02x ", ((target_type_t(*)[num_chan][num_rows][num_cols])data)[n][ch][r][c]);
                    // #define INDEX ( ( n * num_chan + ch ) * num_rows + r ) * num_cols + c
                    // printf("0x%02x ", data[INDEX]);
                }
                printf("\n\r\t\t");
            }
            printf("\n\r");
        }
        printf("\n\r");
    }
}

// Compute expected result with software
void compute_expected (
                    target_type_t        I[N][C][ Y][ X],
                    target_type_t        W[K][C][ R][ S],
                    target_type_t expected[N][K][Y1][X1]
                ) {

    for ( uint32_t n = 0; n < N; n++ ) {
        for ( uint32_t k = 0; k < K; k++ ) {
            for ( uint32_t c = 0; c < C; c++ ) {
                for ( uint32_t y1 = 0; y1 < Y1; y1++ ) {
                    for ( uint32_t x1 = 0; x1 < X1; x1++ ) {
                        for ( uint32_t r = 0; r < R; r++ ) {
                            for ( uint32_t s = 0; s < S; s++ ) {
                                // O[n][k][y’][x’] += W[n][k][c][r][s] * I[n][c][y’+r][x’+s];
                                expected[n][k][y1][x1] += W[k][c][r][s] * I[n][c][y1+r][x1+s];
                            } // s < S
                        } // r < R
                    } // x1 < X1
                } // y1 < Y1
            } // c < C
        } // k < K
    } // n < N
}

// Compare two output tensors
int check_values (
                    target_type_t out     [N][K][Y1][X1],
                    target_type_t expected[N][K][Y1][X1]
                ) {

    // Compare
    for ( uint32_t n = 0; n < N; n++ ) {
        for ( uint32_t k = 0; k < K; k++ ) {
            for ( uint32_t y1 = 0; y1 < Y1; y1++ ) {
                for ( uint32_t x1 = 0; x1 < X1; x1++ ) {
                    if ( out[n][k][y1][x1] != expected[n][k][y1][x1] ) {
                        printf("[ERROR] Failing [%u,%u,%u,%u]: expected 0x%04x != 0x%04x\n\r",
                            n, k, y1, x1,
                            expected[n][k][y1][x1],
                            out     [n][k][y1][x1]
                        );
                        // Return immediately
                        return false;
                    }
                    // DEBUG
                    // printf("[INFO] Check [%u,%u,%u,%u]: expected 0x%04x == 0x%04x\n",
                    //         n, k, y1, x1,
                    //         expected[n][k][y1][x1],
                    //         out     [n][k][y1][x1]
                    // );

                }
            }
        }
    }

    // No error occurred
    return true;
}

#endif // __UTILS_C_
