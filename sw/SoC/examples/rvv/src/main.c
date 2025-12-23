// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description: Perform some RISC-V vector operations and check for expected result:
//                  - On 64-bit elements (SEW=EEW=64)
//                  - At maximum length (LMUL=8)
//                  - Vector loads  (vle64.v)
//                  - Vector stores (vse64.v)
//                  - Vector permutations (vmv.v.i)
//                  - Vector integer arithmetic (vadd.vv)

#include "uninasoc.h"
#include <stdint.h>

// Application Vector Length
// NOTE: Maxium vector length for VLEN = 2048 and 64-bit elements
//       MAXVL = VLEN * LMUL / SEW = 2048 * 8 / 64 = 256
#define AVL (256)

// CSR utility macros
#define MSTATUS_FS (0x000006000U)
#define MSTATUS_XS (0x000018000U)
#define MSTATUS_VS (0x000000600U)
#define MISA_V     (0x000200000U)

// Number of RVV CSRs
#define NUM_VCSRS 5
// Dump RVV CSRs
void vcsr_dump () {
    // Local buffer
    uint64_t vcsr_values [NUM_VCSRS] = {0};
    // CSR names
    char*    vcsr_names  [NUM_VCSRS] = {
		"vstart",
		"vtype ",
		"vl    ",
		"vcsr  ",
		"vlenb ",
    };

    // Read by asm
	asm volatile (
		"csrr  %0, vstart \n\t"
		"csrr  %1, vtype  \n\t"
		"csrr  %2, vl     \n\t"
		"csrr  %3, vcsr   \n\t"
		"csrr  %4, vlenb  \n\t"
		: "=r" (vcsr_values[0]),
		  "=r" (vcsr_values[1]),
		  "=r" (vcsr_values[2]),
		  "=r" (vcsr_values[3]),
		  "=r" (vcsr_values[4])
    );

    // Print
    for ( unsigned int i = 0; i < NUM_VCSRS; i++ ) {
        printf("[RVV] %s: 0x%008x\n\r", vcsr_names[i], vcsr_values[i]);
    }
}

// Print 1D array
void print_array( uint64_t* array, size_t size ) {
    for ( int i = 0; i < size; i++)
        printf("0x%008x ", array[i]);
    printf("\n\r");
}

int main() {

    // Local variables
    uint64_t csr_value = 0;

    // Initialize HAL
    uninasoc_init();

    // Print
    printf("[RVV] Hi, let's play with some vectors :)\n\r");

    // Read MISA.V
    csr_value = 0;
    asm volatile("csrr %[csr_value], misa" : [csr_value] "=r"(csr_value));
    printf("[RVV] MISA  : 0x%016x\n\r", csr_value);
    printf("[RVV] MISA.V: 0x%016x\n\r", csr_value & MISA_V);
    if ( !(csr_value & MISA_V) ) {
        printf("[RVV][ERROR] RVV not available in MISA!\n\r");
        return 1;
    }

    // Read MSTATUS.VS
    csr_value = 0;
    asm volatile("csrr %[csr_value], mstatus" : [csr_value] "=r"(csr_value));
    printf("[RVV] MSTATUS   : 0x%016x\n\r", csr_value);
    printf("[RVV] MSTATUS.VS: 0x%016x\n\r", csr_value & MSTATUS_VS);

    // First set MSTATUS.VS
    asm volatile (" li      t0, %0     " :: "i"(MSTATUS_FS | MSTATUS_XS | MSTATUS_VS));
    asm volatile (" csrs    mstatus, t0" );
    // Read-back
    csr_value = 0;
    asm volatile("csrr %[csr_value], mstatus" : [csr_value] "=r"(csr_value));
    printf("[RVV] MSTATUS   : 0x%016x\n\r", csr_value);
    printf("[RVV] MSTATUS.VS: 0x%016x\n\r", csr_value & MSTATUS_VS);
    if ( !(csr_value & MSTATUS_VS) ) {
        printf("[RVV][ERROR] RVV not available in MSTATUS!\n\r");
        return 1;
    }

    // Dump before vector configuration
    vcsr_dump();

    // Check MAXVL at LMUL=8 and SEW=8, also VLEN
    csr_value = 0;
    asm volatile("vsetvli   %0, zero, e8, m8, ta, ma" : "=r"(csr_value));
    printf("[RVV] MAXVL: %lu\n\r", csr_value);

    // Vector configuration
    csr_value = 0;
    asm volatile("li        t0 ,  %0" :: "i"(AVL));
    asm volatile("vsetvli   %0, t0, e64, m8, ta, ma" : "=r"(csr_value));
    printf("[RVV] AVL        : %lu\n\r", AVL);
    printf("[RVV] Returned VL: %lu\n\r", csr_value);

    // Dump after vector configuration
    vcsr_dump();

    // Allocate array in memory
    uint64_t array_load [AVL];
    uint64_t array_store [AVL];
    uint64_t* address_load = array_load;
    uint64_t* address_store = array_store;
    // Initialize buffers
    for ( unsigned int i = 0; i < AVL; i++ ) {
        array_load[i] = i;
        array_store[i] = 0xdeadbeefdeadbeefu;
    }

    // Compute expected
    uint64_t expected [AVL];
    for ( unsigned int i = 0; i < AVL; i++ ) {
        expected[i] = array_load[i] +1;
    }

    // Dump before vector operations
    printf("[RVV] array_load: \n\r\t");
    print_array( array_load, AVL );
    printf("[RVV] array_store: \n\r\t");
    print_array( array_store, AVL );

    // Vector load
    // v24 = *address_load
    asm volatile("vle64.v	v24, (%0)": "+&r"(address_load));

    // Vector permutation
    // v0 = {1,1,...,1}
    asm volatile("vmv.v.i   v0 ,  1");
    // Vector arithmetic
    // v16 = v24 + v0
    asm volatile("vadd.vv   v16, v24, v0");

    // Vector store
    // *address_store = v16
    asm volatile("vse64.v	v16, (%0)": "+&r"(address_store));

    // Dump after operations
    printf("[RVV] array_store: \n\r\t");
    print_array( array_store, AVL );

    // Check for mismatches
    uint64_t errors = 0;
    for ( unsigned int i = 0; i < AVL; i++) {
        // Check values
        if ( expected[i] != address_store[i] ) {
            // Print
            printf("[RVV][ERROR] Mismatching value at index %u:  0x%08x != 0x%08x\n\r",
                    i, address_load[i], address_store[i]);
            // Count up
            errors++;
        }
    }

    // Print result
    if ( errors == 0 )
        printf("[RVV][INFO] Vector playtime successful!\n\r");
    else
        printf("[RVV][ERROR] Vector playtime failed...\n\r");

    // Return to caller
    return errors;

}


