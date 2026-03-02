/*
 *  Author: Valerio Di Domenico <valerio.didomenico@unina.it>
 *
 * ==============================================================
 *  RISC-V Atomic Memory Operations (AMO) Functional Test
 * ==============================================================

 *  Description:
 *  This program tests the behavior of all standard RISC-V AMO
 *  (Atomic Memory Operation) instructions, verifying that each
 *  operation updates the target memory location correctly.
 *
 *  The tests are divided into two parts:
 *   - Word-level tests (32-bit): always compiled
 *   - Doubleword-level tests (64-bit): compiled only when
 *     building for RV64 targets
 *
 *  Tested instructions:
 *    1. amoswap.w / amoswap.d
 *    2. amoadd.w  / amoadd.d
 *    3. amoand.w  / amoand.d
 *    4. amoor.w   / amoor.d
 *    5. amoxor.w  / amoxor.d
 *    6. amomax.w  / amomax.d
 *    7. amomaxu.w / amomaxu.d
 *    8. amomin.w  / amomin.d
 *    9. amominu.w / amominu.d
 *
 *  Each test:
 *    - Initializes a memory location in DDR
 *    - Executes the AMO instruction using inline assembly
 *    - Compares the result in memory with the expected value
 *    - Prints “SUCCESS” or “FAILED” for each operation
 *
 * ==============================================================
 */

#include "simplyv.h"
#include <stdint.h>

int main(int argc, char* argv[]) {

    // Initialize HAL
    simplyv_init();

    uintptr_t ddr_base = (uintptr_t)_peripheral_DDR4CH1_start;
    uintptr_t ddr_end  = (uintptr_t)_peripheral_DDR4CH1_end;

    printf("=== RISC-V AMO FUNCTIONAL TEST START ===\n\r");

    // ==========================================================
    //                    WORD (32-bit) TESTS
    // ==========================================================
    volatile int *a_ptr_w = (int *)ddr_base;
    int old_val_w;

    *a_ptr_w = 0x10;

    // ---------- 1. AMOSWAP.W ----------
    int swap_val_w = 0x33;
    __asm__ volatile ("amoswap.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(swap_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if (*a_ptr_w == swap_val_w)
        printf("AMOSWAP.W SUCCESS\n\r");
    else
        printf("AMOSWAP.W FAILED\n\r");

    // ---------- 2. AMOADD.W ----------
    int add_val_w = 0x5;
    __asm__ volatile ("amoadd.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(add_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if (*a_ptr_w == old_val_w + add_val_w)
        printf("AMOADD.W SUCCESS\n\r");
    else
        printf("AMOADD.W FAILED\n\r");

    // ---------- 3. AMOAND.W ----------
    int and_val_w = 0xF;
    __asm__ volatile ("amoand.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(and_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if (*a_ptr_w == (old_val_w & and_val_w))
        printf("AMOAND.W SUCCESS\n\r");
    else
        printf("AMOAND.W FAILED\n\r");

    // ---------- 4. AMOOR.W ----------
    int or_val_w = 0x80;
    __asm__ volatile ("amoor.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(or_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if (*a_ptr_w == (old_val_w | or_val_w))
        printf("AMOOR.W SUCCESS\n\r");
    else
        printf("AMOOR.W FAILED\n\r");

    // ---------- 5. AMOXOR.W ----------
    int xor_val_w = 0xA;
    __asm__ volatile ("amoxor.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(xor_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if (*a_ptr_w == (old_val_w ^ xor_val_w))
        printf("AMOXOR.W SUCCESS\n\r");
    else
        printf("AMOXOR.W FAILED\n\r");

    // ---------- 6. AMOMAX.W ----------
    *a_ptr_w = 0x5;
    int max_val_w = -3;
    __asm__ volatile ("amomax.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(max_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if (*a_ptr_w == ((old_val_w > max_val_w) ? old_val_w : max_val_w))
        printf("AMOMAX.W SUCCESS\n\r");
    else
        printf("AMOMAX.W FAILED\n\r");

    // ---------- 7. AMOMAXU.W ----------
    unsigned int maxu_val_w = 0xFFFFFFF0;
    __asm__ volatile ("amomaxu.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(maxu_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if ((unsigned int)*a_ptr_w == ((unsigned int)old_val_w > maxu_val_w ?
                                   (unsigned int)old_val_w : maxu_val_w))
        printf("AMOMAXU.W SUCCESS\n\r");
    else
        printf("AMOMAXU.W FAILED\n\r");

    // ---------- 8. AMOMIN.W ----------
    *a_ptr_w = 0x5;
    int min_val_w = -3;
    __asm__ volatile ("amomin.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(min_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if (*a_ptr_w == ((old_val_w < min_val_w) ? old_val_w : min_val_w))
        printf("AMOMIN.W SUCCESS\n\r");
    else
        printf("AMOMIN.W FAILED\n\r");

    // ---------- 9. AMOMINU.W ----------
    unsigned int minu_val_w = 0xFFFFFFF0;
    __asm__ volatile ("amominu.w %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_w)
                      : [val] "r"(minu_val_w), [addr] "r"(a_ptr_w)
                      : "memory");
    if ((unsigned int)*a_ptr_w == ((unsigned int)old_val_w < minu_val_w ?
                                   (unsigned int)old_val_w : minu_val_w))
        printf("AMOMINU.W SUCCESS\n\r");
    else
        printf("AMOMINU.W FAILED\n\r");


    // ==========================================================
    //                 DOUBLEWORD (64-bit) TESTS
    // ==========================================================
#ifdef __LP64__
    volatile long *a_ptr_d = (long *)(ddr_base + 0x100);
    long old_val_d;

    *a_ptr_d = 0x10;

    // ---------- 1. AMOSWAP.D ----------
    long swap_val_d = 0x12345678ABCDEF00;
    __asm__ volatile ("amoswap.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(swap_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if (*a_ptr_d == swap_val_d)
        printf("AMOSWAP.D SUCCESS\n\r");
    else
        printf("AMOSWAP.D FAILED\n\r");

    // ---------- 2. AMOADD.D ----------
    long add_val_d = 0x10;
    __asm__ volatile ("amoadd.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(add_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if (*a_ptr_d == old_val_d + add_val_d)
        printf("AMOADD.D SUCCESS\n\r");
    else
        printf("AMOADD.D FAILED\n\r");

    // ---------- 3. AMOAND.D ----------
    long and_val_d = 0xFFFFFFFFFFFFFF0F;
    __asm__ volatile ("amoand.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(and_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if (*a_ptr_d == (old_val_d & and_val_d))
        printf("AMOAND.D SUCCESS\n\r");
    else
        printf("AMOAND.D FAILED\n\r");

    // ---------- 4. AMOOR.D ----------
    long or_val_d = 0x100;
    __asm__ volatile ("amoor.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(or_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if (*a_ptr_d == (old_val_d | or_val_d))
        printf("AMOOR.D SUCCESS\n\r");
    else
        printf("AMOOR.D FAILED\n\r");

    // ---------- 5. AMOXOR.D ----------
    long xor_val_d = 0x55AA;
    __asm__ volatile ("amoxor.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(xor_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if (*a_ptr_d == (old_val_d ^ xor_val_d))
        printf("AMOXOR.D SUCCESS\n\r");
    else
        printf("AMOXOR.D FAILED\n\r");

    // ---------- 6. AMOMAX.D ----------
    *a_ptr_d = 0x5;
    long max_val_d = -3;
    __asm__ volatile ("amomax.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(max_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if (*a_ptr_d == ((old_val_d > max_val_d) ? old_val_d : max_val_d))
        printf("AMOMAX.D SUCCESS\n\r");
    else
        printf("AMOMAX.D FAILED\n\r");

    // ---------- 7. AMOMAXU.D ----------
    unsigned long maxu_val_d = 0xFFFFFFFFFFFFFF00;
    __asm__ volatile ("amomaxu.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(maxu_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if ((unsigned long)*a_ptr_d == ((unsigned long)old_val_d > maxu_val_d ?
                                    (unsigned long)old_val_d : maxu_val_d))
        printf("AMOMAXU.D SUCCESS\n\r");
    else
        printf("AMOMAXU.D FAILED\n\r");

    // ---------- 8. AMOMIN.D ----------
    *a_ptr_d = 0x5;
    long min_val_d = -3;
    __asm__ volatile ("amomin.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(min_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if (*a_ptr_d == ((old_val_d < min_val_d) ? old_val_d : min_val_d))
        printf("AMOMIN.D SUCCESS\n\r");
    else
        printf("AMOMIN.D FAILED\n\r");

    // ---------- 9. AMOMINU.D ----------
    unsigned long minu_val_d = 0xFFFFFFFFFFFFFF00;
    __asm__ volatile ("amominu.d %[old], %[val], (%[addr])"
                      : [old] "=r"(old_val_d)
                      : [val] "r"(minu_val_d), [addr] "r"(a_ptr_d)
                      : "memory");
    if ((unsigned long)*a_ptr_d == ((unsigned long)old_val_d < minu_val_d ?
                                    (unsigned long)old_val_d : minu_val_d))
        printf("AMOMINU.D SUCCESS\n\r");
    else
        printf("AMOMINU.D FAILED\n\r");
#endif

    printf("=== RISC-V AMO FUNCTIONAL TEST END ===\n\r");

    return SIMPLYV_OK;
}