// Author: Valerio Di Domenico <valerio.didomenico@unina.it>
// Description:
//   This program performs a memory access test over a defined DDR address range, validating both normal read/write accesses 
//   and atomic LR/SC (Load-Reserved / Store-Conditional) accesses.

#include "uninasoc.h"
#include <stdint.h>

extern unsigned int _DDR_start;
extern unsigned int _DDR_end;
#define STEP       0x1000   // It is the step between one address and the next for the test


int main(int argc, char* argv[]) {

    // Initialize HAL
    uninasoc_init();

    uintptr_t ddr_base = (uintptr_t)&_DDR_start;
    uintptr_t ddr_end  = (uintptr_t)&_DDR_end;

    printf("=== LR/SC ACCESS TEST ===\n\r");
    printf("Range: 0x%x - 0x%x\n\r", ddr_base, ddr_base);

    for (uintptr_t addr = ddr_base; addr < ddr_end; addr += STEP) {
        volatile unsigned int* ddr_ptr = (volatile unsigned int*) addr;
        unsigned int test_val = (addr & 0xFFFF);  // address-dependent pseudo-random value 
        unsigned int read_back;

        // --- Normal access ---
        *ddr_ptr = test_val;
        read_back = *ddr_ptr;

        if (read_back == test_val) {
            printf("[NORMAL] Addr 0x%08lx: SUCCESS (val=%u)\n\r", addr, read_back);
        } else {
            printf("[NORMAL] Addr 0x%08lx: FAILED (read %u, expected %u)\n\r", addr, read_back, test_val);
        }

        // --- Atomic access (LR/SC) ---
        int success;
        unsigned int new_val = test_val + 1234;

        asm volatile (
            "1: lr.w t0, (%1)\n"      // load-reserved
            "   sc.w %0, %2, (%1)\n"  // store-conditional
            : "=r"(success)
            : "r"(ddr_ptr), "r"(new_val)
            : "t0", "memory"
        );

        if (success == 0) {
            unsigned int verify = *ddr_ptr;
            printf("[ATOMIC] Addr 0x%08lx: SUCCESS (val=%u)\n\r", addr, verify);
        } else {
            printf("[ATOMIC] Addr 0x%08lx: FAILED (sc.w result=%d)\n\r", addr, success);
        }
    }

    printf("=== LR/SC ACCESS TEST DONE ===\n\r");

    return 0;
}
