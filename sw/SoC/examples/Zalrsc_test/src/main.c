// Author: Valerio Di Domenico <valerio.didomenico@unina.it>
// Description:
//   This program performs a memory access test over a defined DDR address range, validating both normal read/write accesses
//   and atomic LR/SC (Load-Reserved / Store-Conditional) accesses.

#include "uninasoc.h"
#include <stdint.h>
#include "zalrsc.h"

extern unsigned int _DDR4CH1_start;
extern unsigned int _DDR4CH1_end;

int main(int argc, char* argv[]) {

    // Initialize HAL
    uninasoc_init();

    uintptr_t ddr_base = (uintptr_t)&_DDR4CH1_start;
    uintptr_t ddr_end  = (uintptr_t)&_DDR4CH1_end;

    printf("=== LR/SC TESTS WORD ===\n\r");
    printf("DDR range: 0x%08lx - 0x%08lx\n\n\r", ddr_base, ddr_end);

    unsigned int init_val_w = 0xAAAA5555;
    unsigned int new_val_w  = 0x12345678;
    unsigned long long init_val_d = 0xAAAA5555AAAA5555ULL;
    unsigned long long new_val_d  = 0x1234567812345678ULL;

    printf("Expected write value (W): 0x%08x\n", new_val_w);
    printf("Expected write value (D): 0x%016llx\n", new_val_d);


    // Iterate over DDR addresses with step
    for (uintptr_t base = ddr_base; base + 8 < ddr_end; base += STEP) {

        printf("==== Iteration base address: 0x%08lx ====\n\n\r", base);

        // Word-mode pointers
        volatile unsigned int*  addr_aligned_w    = (volatile unsigned int*) base;
        volatile unsigned int*  addr_other_w      = (volatile unsigned int*) (base + STEP/2);
        volatile unsigned char* addr_misaligned_w = (volatile unsigned char*) (base + 3); // non word-aligned

        // D-mode pointers (must be 8-byte aligned)
        volatile unsigned long long*  addr_aligned_d    = (volatile unsigned long long*) (base & ~0x7ULL);
        volatile unsigned long long*  addr_other_d      = (volatile unsigned long long*) ((base + STEP/4) & ~0x7ULL);
        volatile unsigned char*       addr_misaligned_d = (volatile unsigned char*) (base + 1);

        unsigned long long read_back;
        int success;

        // --- init memory for both modes ---
        *addr_aligned_w = init_val_w;
        *addr_other_w   = init_val_w;
        *addr_aligned_d = init_val_d;
        *addr_other_d   = init_val_d;

        /*
        * NOTE:
        * The test5 (misaligned access) is commented out because it causes a processor exception.
        * On the MicroBlaze processor, this exception stops the processor execution.
        * On the CVA6 processor, however, the core is not interrupted: the store operation
        * is partially performed, and only the first byte of the intended value is actually written.
        */

        /*
        * NOTE:
        * On the MicroBlaze V processor, TEST3_W and TEST6_W return "FAILED"
        * even though the memory content remains unchanged — which means the behavior
        * is actually correct.
        * The tests are marked as FAILED because, in these specific cases,
        * MicroBlaze V does not write a non-zero value to the destination register
        * to indicate the failure of the SC instruction.
        */


        // -------------------------------------------------------------------
        // 1. LR.W followed by SC.W with same aligned address --> SUCCESS
        // -------------------------------------------------------------------
        printf("********************** [TEST1_W] ********************** \n");
        printf("Description: LR.W + SC.W same address (aligned)\n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        read_back = 0;

        printf("Expected write value: 0x%08x\n", new_val_w);
        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        success = lr_w_sc_sequence(addr_aligned_w, new_val_w);
        read_back = *addr_aligned_w;

        // SC returns 0 if the store was successful.
        // Therefore, PASS requires:
        //   1. success == 0  --> SC succeeded
        //   2. read_back == new_val_w --> memory updated correctly
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success == 0 && read_back == new_val_w) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;


        // -------------------------------------------------------------------
        // 2. SC.W without LR.W --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST2_W] ********************** \n");
        printf("Description: SC.W without LR.W \n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.w %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_aligned_w), "r"(new_val_w)
            : "memory"
        );
        read_back = *addr_aligned_w;

        // A SC.W must be preceded by a valid LR.W on the same address.
        // If no LR.W is executed, SC.W must fail. This means:
        //   1. SC.W failure returns a non-zero value in 'success'
        //   2. Memory remains unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success != 0 && read_back == init_val_w) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;


        // -------------------------------------------------------------------
        // 3. LR.W and SC.W with different addresses --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST3_W] ********************** \n");
        printf("Description: LR.W and SC.W with different addresses\n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        *addr_other_w   = init_val_w;
        success = -1;

        printf("Memory value before SC : 0x%08x\n\r", *addr_other_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w t0, (%1)\n"
            "sc.w %0, %2, (%3)\n"
            : "=r"(success)
            : "r"(addr_aligned_w), "r"(new_val_w), "r"(addr_other_w)
            : "t0", "memory"
        );

        // A SC on addr_other must fail (reservation is tied to addr_aligned_w)
        // Memory values must remain unchanged
        printf("TEST RESULT: %s (SC=%d, memA=0x%08x, memB=0x%08x)\n\r",
               (success != 0 && *addr_aligned_w == init_val_w && *addr_other_w == init_val_w) ? "PASSED" : "FAILED",
               success, *addr_aligned_w, *addr_other_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_other_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;
        *addr_other_w   = init_val_w;


        // -------------------------------------------------------------------
        // 4. SC.W next to valid SC.W --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST4_W] ********************** \n");
        printf("Description: SC after valid SC\n");
        int success2;
        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        success2 = -1;

        success = lr_w_sc_sequence(addr_aligned_w, new_val_w); // first valid SC
        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.w %0, %2, (%1)\n"
            : "=r"(success2)
            : "r"(addr_aligned_w), "r"(init_val_w)
            : "memory"
        );

        // Second SC.W executed immediately after must fail (not valid LR.W anymore) --> success2 != 0
        // Memory must contain the value from the first SC.W
        printf("TEST RESULT: %s (SC1=%d, SC2=%d, mem=0x%08x)\n\r",
               (success == 0 && success2 != 0) ? "PASSED" : "FAILED",
               success, success2, *addr_aligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;

/*
        // -------------------------------------------------------------------
        // 5. Misaligned access --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST5_W] ********************** \n");
        printf("Description: Misaligned LR.W/SC.W \n");
        unsigned long long value_before_sc;

        // === Preconditions ===
        success = -1;
        *addr_misaligned_w = init_val_w;
        value_before_sc = *addr_misaligned_w;

        printf("Memory value before SC : 0x%08x\n\r", *addr_misaligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w t0, (%1)\n"
            "sc.w %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_misaligned_w), "r"(new_val_w)
            : "t0", "memory"
        );
*/
        // LR.W/SC.W sequence must fail due to misalignment
        // SC.W should not modify memory
        printf("TEST RESULT: %s (SC=%d), mem=0x%08x\n\r",
               (*addr_misaligned_w != new_val_w) ? "PASSED" : "FAILED",
               success, *addr_misaligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_misaligned_w);


        // -------------------------------------------------------------------
        // 6. Reservation overwrite --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST6_W] ********************** \n");
        printf("Description: Reservation overwrite \n");
        int success_first = -1;

        // === Preconditions ===
        *addr_aligned_w = init_val_w;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w t0, (%1)\n"          // first reservation
            "lr.w t1, (%2)\n"          // next reservation invalidates first one
            "sc.w %0, %3, (%1)\n"      // SC must fail
            : "=r"(success_first)
            : "r"(addr_aligned_w),"r"(addr_other_w), "r"(new_val_w)
            : "t0", "t1", "memory"
        );

        // SC.W tied to the first LR.W (addr_aligned_w) must fail (reservation lost)
        // Memory must remain unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success_first != 0) ? "PASSED" : "FAILED",
               success_first, *addr_aligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;

        // -------------------------------------------------------------------
        // 1. LR.W.aq followed by SC.W.rl with same aligned address --> SUCCESS
        // -------------------------------------------------------------------
        printf("********************** [TEST1_W_aq_rl] ********************** \n");
        printf("Description: LR.W.aq + SC.W.rl same address (aligned)\n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        success = lr_w_aq_sc_rl_sequence(addr_aligned_w, new_val_w);
        read_back = *addr_aligned_w;

        // SC returns 0 if the store was successful.
        // Therefore, PASS requires:
        //   1. success == 0  --> SC succeeded
        //   2. read_back == new_val_w --> memory updated correctly
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success == 0 && read_back == new_val_w) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;


        // -------------------------------------------------------------------
        // 2. SC.W.rl without LR.W.aq --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST2_W_aq_rl] ********************** \n");
        printf("Description: SC.W.rl without LR.W.aq \n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.w.rl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_aligned_w), "r"(new_val_w)
            : "memory"
        );
        read_back = *addr_aligned_w;

        // A SC.W must be preceded by a valid LR.W on the same address.
        // If no LR.W is executed, SC.W must fail. This means:
        //   1. SC.W failure returns a non-zero value in 'success'
        //   2. Memory remains unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success != 0 && read_back == init_val_w) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;


        // -------------------------------------------------------------------
        // 3. LR.W.aq and SC.W.rl with different addresses --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST3_W_aq_rl] ********************** \n");
        printf("Description: LR.W.aq and SC.W.rl with different addresses\n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        *addr_other_w   = init_val_w;
        success = -1;

        printf("Memory value before SC : 0x%08x\n\r", *addr_other_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w.aq t0, (%1)\n"
            "sc.w.rl %0, %2, (%3)\n"
            : "=r"(success)
            : "r"(addr_aligned_w), "r"(new_val_w), "r"(addr_other_w)
            : "t0", "memory"
        );

        // A SC on addr_other must fail (reservation is tied to addr_aligned_w)
        // Memory values must remain unchanged
        printf("TEST RESULT: %s (SC=%d, memA=0x%08x, memB=0x%08x)\n\r",
               (success != 0 && *addr_aligned_w == init_val_w && *addr_other_w == init_val_w) ? "PASSED" : "FAILED",
               success, *addr_aligned_w, *addr_other_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_other_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;
        *addr_other_w   = init_val_w;


        // -------------------------------------------------------------------
        // 4. SC.W.aq next to valid SC.W.rl --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST4_W_aq_rl] ********************** \n");
        printf("Description: SC after valid SC\n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        success2 = -1;

        success = lr_w_aq_sc_rl_sequence(addr_aligned_w, new_val_w); // first valid SC
        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.w.rl %0, %2, (%1)\n"
            : "=r"(success2)
            : "r"(addr_aligned_w), "r"(init_val_w)
            : "memory"
        );

        // Second SC.W.rl executed immediately after must fail (not valid LR.W.aq anymore) --> success2 != 0
        // Memory must contain the value from the first SC.W.rl
        printf("TEST RESULT: %s (SC1=%d, SC2=%d, mem=0x%08x)\n\r",
               (success == 0 && success2 != 0) ? "PASSED" : "FAILED",
               success, success2, *addr_aligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;
/*

        // -------------------------------------------------------------------
        // 5. Misaligned access --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST5_W_aq_rl] ********************** \n");
        printf("Description: Misaligned LR.W.aq/SC.W.rl \n");

        // === Preconditions ===
        success = -1;
        *addr_misaligned_w = init_val_w;
        value_before_sc = *addr_misaligned_w;

        printf("Memory value before SC : 0x%08x\n\r", *addr_misaligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w.aq t0, (%1)\n"
            "sc.w.rl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_misaligned_w), "r"(new_val_w)
            : "t0", "memory"
        );

        // LR.W.aq/SC.W.rl sequence must fail due to misalignment
        // SC.W should not modify memory
        printf("TEST RESULT: %s (SC=%d), mem=0x%08x\n\r",
               (*addr_misaligned_w != new_val_w) ? "PASSED" : "FAILED",
               success, *addr_misaligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_misaligned_w);
*/

        // -------------------------------------------------------------------
        // 6. Reservation overwrite --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST6_W_aq_rl] ********************** \n");
        printf("Description: Reservation overwrite \n");
        success_first = -1;

        // === Preconditions ===
        *addr_aligned_w = init_val_w;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w.aq t0, (%1)\n"          // first reservation
            "lr.w.aq t1, (%2)\n"          // next reservation invalidates first one
            "sc.w.rl %0, %3, (%1)\n"      // SC must fail
            : "=r"(success_first)
            : "r"(addr_aligned_w),"r"(addr_other_w), "r"(new_val_w)
            : "t0", "t1", "memory"
        );

        // SC.W.rl tied to the first LR.W.aq (addr_aligned_w) must fail (reservation lost)
        // Memory must remain unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success_first != 0) ? "PASSED" : "FAILED",
               success_first, *addr_aligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;


        // -------------------------------------------------------------------
        // LR.W.aqrl followed by SC.W.aqrl with same aligned address --> SUCCESS
        // -------------------------------------------------------------------
        printf("********************** [TEST1_W_aqrl] ********************** \n");
        printf("Description: LR.W.aqrl + SC.W.aqrl same address (aligned)\n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success   = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        success = lr_w_aqrl_sc_aqrl_sequence(addr_aligned_w, new_val_w);
        read_back = *addr_aligned_w;

        // SC returns 0 if the store was successful.
        // Therefore, PASS requires:
        //   1. success == 0  --> SC succeeded
        //   2. read_back == new_val_w --> memory updated correctly
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
            (success == 0 && read_back == new_val_w) ? "PASSED" : "FAILED",
            success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;


        // -------------------------------------------------------------------
        // 2. SC.W.aqrl without LR.W.aqrl --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST2_W_aqrl] ********************** \n");
        printf("Description: SC.W.aqrl without LR.W.aqrl \n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.w.aqrl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_aligned_w), "r"(new_val_w)
            : "memory"
        );
        read_back = *addr_aligned_w;

        // A SC.W.aqrl must be preceded by a valid LR.W.aqrl on the same address.
        // If no LR.W.aqrl is executed, SC.W must fail. This means:
        //   1. SC.W.aqrl failure returns a non-zero value in 'success'
        //   2. Memory remains unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success != 0 && read_back == init_val_w) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;


        // -------------------------------------------------------------------
        // 3. LR.W.aqrl and SC.W.aqrl with different addresses --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST3_W_aqrl] ********************** \n");
        printf("Description: LR.W.aqrl and SC.W.aqrl with different addresses\n");

        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        *addr_other_w   = init_val_w;
        success = -1;

        printf("Memory value before SC : 0x%08x\n\r", *addr_other_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w.aqrl t0, (%1)\n"
            "sc.w.aqrl %0, %2, (%3)\n"
            : "=r"(success)
            : "r"(addr_aligned_w), "r"(new_val_w), "r"(addr_other_w)
            : "t0", "memory"
        );

        // A SC on addr_other must fail (reservation is tied to addr_aligned_w)
        // Memory values must remain unchanged
        printf("TEST RESULT: %s (SC=%d, memA=0x%08x, memB=0x%08x)\n\r",
               (success != 0 && *addr_aligned_w == init_val_w && *addr_other_w == init_val_w) ? "PASSED" : "FAILED",
               success, *addr_aligned_w, *addr_other_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_other_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;
        *addr_other_w   = init_val_w;

        // -------------------------------------------------------------------
        // 4. SC.W.aqrl next to valid SC.W.aqrl --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST4_W_aqrl] ********************** \n");
        printf("Description: SC after valid SC\n");
        // === Preconditions ===
        *addr_aligned_w = init_val_w;
        success = -1;
        success2 = -1;

        success = lr_w_aqrl_sc_aqrl_sequence(addr_aligned_w, new_val_w); // first valid SC
        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.w.aqrl %0, %2, (%1)\n"
            : "=r"(success2)
            : "r"(addr_aligned_w), "r"(init_val_w)
            : "memory"
        );

        // Second SC.W.rl executed immediately after must fail (not valid LR.W.aq anymore) --> success2 != 0
        // Memory must contain the value from the first SC.W.rl
        printf("TEST RESULT: %s (SC1=%d, SC2=%d, mem=0x%08x)\n\r",
               (success == 0 && success2 != 0) ? "PASSED" : "FAILED",
               success, success2, *addr_aligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;

/*
        // -------------------------------------------------------------------
        // 5. Misaligned access --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST5_W_aqrl] ********************** \n");
        printf("Description: Misaligned LR.W.aqrl/SC.W.aqrl \n");

        // === Preconditions ===
        success = -1;
        *addr_misaligned_w = init_val_w;
        value_before_sc = *addr_misaligned_w;

        printf("Memory value before SC : 0x%08x\n\r", *addr_misaligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w.aqrl t0, (%1)\n"
            "sc.w.aqrl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_misaligned_w), "r"(new_val_w)
            : "t0", "memory"
        );

        // LR.W.aqrl/SC.W.aqrl sequence must fail due to misalignment
        // SC.W should not modify memory
        printf("TEST RESULT: %s (SC=%d), mem=0x%08x\n\r",
               (*addr_misaligned_w != new_val_w) ? "PASSED" : "FAILED",
               success, *addr_misaligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_misaligned_w);
*/

        // -------------------------------------------------------------------
        // 6. Reservation overwrite --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST6_W_aqrl] ********************** \n");
        printf("Description: Reservation overwrite \n");
        success_first = -1;

        // === Preconditions ===
        *addr_aligned_w = init_val_w;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_w);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.w.aqrl t0, (%1)\n"          // first reservation
            "lr.w.aqrl t1, (%2)\n"          // next reservation invalidates first one
            "sc.w.aqrl %0, %3, (%1)\n"      // SC must fail
            : "=r"(success_first)
            : "r"(addr_aligned_w),"r"(addr_other_w), "r"(new_val_w)
            : "t0", "t1", "memory"
        );

        // SC.W.aqrl tied to the first LR.W.aqrl (addr_aligned_w) must fail (reservation lost)
        // Memory must remain unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%08x)\n\r",
               (success_first != 0) ? "PASSED" : "FAILED",
               success_first, *addr_aligned_w);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_w);

        // === Postconditions ===
        *addr_aligned_w = init_val_w;

    #ifdef __LP64__

        printf("\n\n=== LR/SC TESTS DOUBLEWORD ===\n\n\r");
        // -------------------------------------------------------------------
        // 1. LR.D followed by SC.D with same aligned address --> SUCCESS
        // -------------------------------------------------------------------
        printf("********************** [TEST1_D] ********************** \n");
        printf("Description: LR.D + SC.D same address (aligned)\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        success = lr_d_sc_sequence(addr_aligned_d, new_val_d);
        read_back = *addr_aligned_d;

        // SC returns 0 if the store was successful.
        // Therefore, PASS requires:
        //   1. success == 0  --> SC succeeded
        //   2. read_back == new_val_d --> memory updated correctly
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success == 0 && read_back == new_val_d) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;


        // -------------------------------------------------------------------
        // 2. SC.D without LR.D --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST2_D] ********************** \n");
        printf("Description: SC.D without LR.D \n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.d %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_aligned_d), "r"(new_val_d)
            : "memory"
        );
        read_back = *addr_aligned_d;

        // A SC.D must be preceded by a valid LR.D on the same address.
        // If no LR.D is executed, SC.D must fail. This means:
        //   1. SC.D failure returns a non-zero value in 'success'
        //   2. Memory remains unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success != 0 && read_back == init_val_d) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;


        // -------------------------------------------------------------------
        // 3. LR.D and SC.D with different addresses --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST3_D] ********************** \n");
        printf("Description: LR.D and SC.D with different addresses\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        *addr_other_d   = init_val_d;
        success = -1;

        printf("Memory value before SC : 0x%08x\n\r", *addr_other_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d t0, (%1)\n"
            "sc.d %0, %2, (%3)\n"
            : "=r"(success)
            : "r"(addr_aligned_d), "r"(new_val_d), "r"(addr_other_d)
            : "t0", "memory"
        );

        // A SC on addr_other must fail (reservation is tied to addr_aligned_d)
        // Memory values must remain unchanged
        printf("TEST RESULT: %s (SC=%d, memA=0x%08x, memB=0x%08x)\n\r",
               (success != 0 && *addr_aligned_d == init_val_d && *addr_other_d == init_val_d) ? "PASSED" : "FAILED",
               success, *addr_aligned_d, *addr_other_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_other_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;
        *addr_other_d   = init_val_d;


        // -------------------------------------------------------------------
        // 4. SC.D next to valid SC.D --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST4_D] ********************** \n");
        printf("Description: SC after valid SC\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        success2 = -1;

        success = lr_d_sc_sequence(addr_aligned_d, new_val_d); // first valid SC
        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.d %0, %2, (%1)\n"
            : "=r"(success2)
            : "r"(addr_aligned_d), "r"(init_val_d)
            : "memory"
        );

        // Second SC.D executed immediately after must fail (not valid LR.D anymore) --> success2 != 0
        // Memory must contain the value from the first SC.D
        printf("TEST RESULT: %s (SC1=%d, SC2=%d, mem=0x%016llx))\n\r",
               (success == 0 && success2 != 0) ? "PASSED" : "FAILED",
               success, success2, *addr_aligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;

/*
        // -------------------------------------------------------------------
        // 5. Misaligned access --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST5_D] ********************** \n");
        printf("Description: Misaligned LR.D/SC.D \n");

        // === Preconditions ===
        success = -1;
        *addr_misaligned_d = init_val_d;
        value_before_sc = *addr_misaligned_d;

        printf("Memory value before SC : 0x%08x\n\r", *addr_misaligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d t0, (%1)\n"
            "sc.d %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_misaligned_d), "r"(new_val_d)
            : "t0", "memory"
        );

        // LR.D/SC.D sequence must fail due to misalignment
        // SC.D should not modify memory
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx)\n\r",
               (*addr_misaligned_d != new_val_d) ? "PASSED" : "FAILED",
               success, *addr_misaligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_misaligned_d);

*/
        // -------------------------------------------------------------------
        // 6. Reservation overwrite --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST6_D] ********************** \n");
        printf("Description: Reservation overwrite \n");
        success_first = -1;

        // === Preconditions ===
        *addr_aligned_d = init_val_d;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d t0, (%1)\n"          // first reservation
            "lr.d t1, (%2)\n"          // next reservation invalidates first one
            "sc.d %0, %3, (%1)\n"      // SC must fail
            : "=r"(success_first)
            : "r"(addr_aligned_d),"r"(addr_other_d), "r"(new_val_d)
            : "t0", "t1", "memory"
        );

        // SC.D tied to the first LR.D (addr_aligned_d) must fail (reservation lost)
        // Memory must remain unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success_first != 0) ? "PASSED" : "FAILED",
               success_first, *addr_aligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;


        // -------------------------------------------------------------------
        // 1. LR.D.AQ followed by SC.D.RL with same aligned address --> SUCCESS
        // -------------------------------------------------------------------
        printf("********************** [TEST1_D_aq_rl] ********************** \n");
        printf("Description: LR.D.AQ + SC.D.RL same address (aligned)\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        success = lr_d_aq_sc_rl_sequence(addr_aligned_d, new_val_d);
        read_back = *addr_aligned_d;

        // SC returns 0 if the store was successful.
        // Therefore, PASS requires:
        //   1. success == 0  --> SC succeeded
        //   2. read_back == new_val_d --> memory updated correctly
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success == 0 && read_back == new_val_d) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;


        // -------------------------------------------------------------------
        // 2. SC.D.aq without LR.D.rl --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST2_D_aq_rl] ********************** \n");
        printf("Description: SC.D.rl without LR.D.aq \n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.d.rl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_aligned_d), "r"(new_val_d)
            : "memory"
        );
        read_back = *addr_aligned_d;

        // A SC.D.rl must be preceded by a valid LR.D.aq on the same address.
        // If no LR.D.aq is executed, SC.D.rl must fail. This means:
        //   1. SC.D failure returns a non-zero value in 'success'
        //   2. Memory remains unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success != 0 && read_back == init_val_d) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;


        // -------------------------------------------------------------------
        // 3. LR.D.aq and SC.D.rl with different addresses --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST3_D] ********************** \n");
        printf("Description: LR.D.aq and SC.D.rl with different addresses\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        *addr_other_d   = init_val_d;
        success = -1;

        printf("Memory value before SC : 0x%08x\n\r", *addr_other_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d.aq t0, (%1)\n"
            "sc.d.rl %0, %2, (%3)\n"
            : "=r"(success)
            : "r"(addr_aligned_d), "r"(new_val_d), "r"(addr_other_d)
            : "t0", "memory"
        );

        // A SC on addr_other must fail (reservation is tied to addr_aligned_d)
        // Memory values must remain unchanged
        printf("TEST RESULT: %s (SC=%d, memA=0x%08x, memB=0x%08x)\n\r",
               (success != 0 && *addr_aligned_d == init_val_d && *addr_other_d == init_val_d) ? "PASSED" : "FAILED",
               success, *addr_aligned_d, *addr_other_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_other_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;
        *addr_other_d   = init_val_d;


        // -------------------------------------------------------------------
        // 4. SC.D next to valid SC.D --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST4_D_aq_rl] ********************** \n");
        printf("Description: SC after valid SC\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        success2 = -1;

        success = lr_d_aq_sc_rl_sequence(addr_aligned_d, new_val_d); // first valid SC
        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.d.rl %0, %2, (%1)\n"
            : "=r"(success2)
            : "r"(addr_aligned_d), "r"(init_val_d)
            : "memory"
        );

        // Second SC.D executed immediately after must fail (not valid LR.D anymore) --> success2 != 0
        // Memory must contain the value from the first SC.D
        printf("TEST RESULT: %s (SC1=%d, SC2=%d, mem=0x%016llx))\n\r",
               (success == 0 && success2 != 0) ? "PASSED" : "FAILED",
               success, success2, *addr_aligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;

/*
        // -------------------------------------------------------------------
        // 5. Misaligned access --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST5_D] ********************** \n");
        printf("Description: Misaligned LR.D.aq/SC.D.rl \n");

        // === Preconditions ===
        success = -1;
        *addr_misaligned_d = init_val_d;
        value_before_sc = *addr_misaligned_d;

        printf("Memory value before SC : 0x%08x\n\r", *addr_misaligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d.aq t0, (%1)\n"
            "sc.d.rl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_misaligned_d), "r"(new_val_d)
            : "t0", "memory"
        );

        // LR.D.aq/SC.D.rl sequence must fail due to misalignment
        // SC.D.rl should not modify memory
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx)\n\r",
               (*addr_misaligned_d != new_val_d) ? "PASSED" : "FAILED",
               success, *addr_misaligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_misaligned_d);
*/

        // -------------------------------------------------------------------
        // 6. Reservation overwrite --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST6_D_aq_rl] ********************** \n");
        printf("Description: Reservation overwrite \n");
        success_first = -1;

        // === Preconditions ===
        *addr_aligned_d = init_val_d;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d.aq t0, (%1)\n"          // first reservation
            "lr.d.aq t1, (%2)\n"          // next reservation invalidates first one
            "sc.d.rl %0, %3, (%1)\n"      // SC must fail
            : "=r"(success_first)
            : "r"(addr_aligned_d),"r"(addr_other_d), "r"(new_val_d)
            : "t0", "t1", "memory"
        );

        // SC.D.rl tied to the first LR.D.aq (addr_aligned_d) must fail (reservation lost)
        // Memory must remain unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success_first != 0) ? "PASSED" : "FAILED",
               success_first, *addr_aligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;

        // -------------------------------------------------------------------
        // 1. LR.D.AQRL followed by SC.D.AQRL with same aligned address --> SUCCESS
        // -------------------------------------------------------------------
        printf("********************** [TEST1_D_aqrl] ********************** \n");
        printf("Description: LR.D.AQRL + SC.D.AQRL same address (aligned)\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        success = lr_d_aqrl_sc_aqrl_sequence(addr_aligned_d, new_val_d);
        read_back = *addr_aligned_d;

        // SC returns 0 if the store was successful.
        // Therefore, PASS requires:
        //   1. success == 0  --> SC succeeded
        //   2. read_back == new_val_d --> memory updated correctly
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success == 0 && read_back == new_val_d) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;


        // -------------------------------------------------------------------
        // 2. SC.D.aq without LR.D.rl --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST2_D_aqrl] ********************** \n");
        printf("Description: SC.D.aqrl without LR.D.aqrl \n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        read_back = 0;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.d.aqrl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_aligned_d), "r"(new_val_d)
            : "memory"
        );
        read_back = *addr_aligned_d;

        // A SC.D.aqrl must be preceded by a valid LR.D.aqrl on the same address.
        // If no LR.D.aqrl is executed, SC.D.aqrl must fail. This means:
        //   1. SC.D.aqrl failure returns a non-zero value in 'success'
        //   2. Memory remains unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success != 0 && read_back == init_val_d) ? "PASSED" : "FAILED",
               success, read_back);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;


        // -------------------------------------------------------------------
        // 3. LR.D.aqrl and SC.D.aqrl with different addresses --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST3_D_aqrl] ********************** \n");
        printf("Description: LR.D.aqrl and SC.D.aqrl with different addresses\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        *addr_other_d   = init_val_d;
        success = -1;

        printf("Memory value before SC : 0x%08x\n\r", *addr_other_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d.aqrl t0, (%1)\n"
            "sc.d.aqrl %0, %2, (%3)\n"
            : "=r"(success)
            : "r"(addr_aligned_d), "r"(new_val_d), "r"(addr_other_d)
            : "t0", "memory"
        );

        // A SC on addr_other must fail (reservation is tied to addr_aligned_d)
        // Memory values must remain unchanged
        printf("TEST RESULT: %s (SC=%d, memA=0x%08x, memB=0x%08x)\n\r",
               (success != 0 && *addr_aligned_d == init_val_d && *addr_other_d == init_val_d) ? "PASSED" : "FAILED",
               success, *addr_aligned_d, *addr_other_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_other_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;
        *addr_other_d   = init_val_d;


        // -------------------------------------------------------------------
        // 4. SC.D.aqrl next to valid SC.D.aqrl --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST4_D_aqrl] ********************** \n");
        printf("Description: SC after valid SC\n");

        // === Preconditions ===
        *addr_aligned_d = init_val_d;
        success = -1;
        success2 = -1;

        success = lr_d_aqrl_sc_aqrl_sequence(addr_aligned_d, new_val_d); // first valid SC
        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "sc.d.rl %0, %2, (%1)\n"
            : "=r"(success2)
            : "r"(addr_aligned_d), "r"(init_val_d)
            : "memory"
        );

        // Second SC.D.aqrl executed immediately after must fail (not valid LR.D.aqrl anymore) --> success2 != 0
        // Memory must contain the value from the first SC.D
        printf("TEST RESULT: %s (SC1=%d, SC2=%d, mem=0x%016llx))\n\r",
               (success == 0 && success2 != 0) ? "PASSED" : "FAILED",
               success, success2, *addr_aligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;

/*
        // -------------------------------------------------------------------
        // 5. Misaligned access --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST5_D_aqrl] ********************** \n");
        printf("Description: Misaligned LR.D.aqrl/SC.D.aqrl \n");

        // === Preconditions ===
        success = -1;
        *addr_misaligned_d = init_val_d;
        value_before_sc = *addr_misaligned_d;

        printf("Memory value before SC : 0x%08x\n\r", *addr_misaligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d.aqrl t0, (%1)\n"
            "sc.d.aqrl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr_misaligned_d), "r"(new_val_d)
            : "t0", "memory"
        );

        // LR.D.aqrl/SC.D.aqrl sequence must fail due to misalignment
        // SC.D.aqrl should not modify memory
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx)\n\r",
               (*addr_misaligned_d != new_val_d) ? "PASSED" : "FAILED",
               success, *addr_misaligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_misaligned_d);
*/

        // -------------------------------------------------------------------
        // 6. Reservation overwrite --> FAILURE
        // -------------------------------------------------------------------
        printf("********************** [TEST6_D_aqrl] ********************** \n");
        printf("Description: Reservation overwrite \n");
        success_first = -1;

        // === Preconditions ===
        *addr_aligned_d = init_val_d;

        printf("Memory value before SC : 0x%08x\n\r", *addr_aligned_d);
        printf("Executing SC...\n\r");
        asm volatile (
            "lr.d.aqrl t0, (%1)\n"          // first reservation
            "lr.d.aqrl t1, (%2)\n"          // next reservation invalidates first one
            "sc.d.aqrl %0, %3, (%1)\n"      // SC must fail
            : "=r"(success_first)
            : "r"(addr_aligned_d),"r"(addr_other_d), "r"(new_val_d)
            : "t0", "t1", "memory"
        );

        // SC.D.aqrl tied to the first LR.D.aqrl (addr_aligned_d) must fail (reservation lost)
        // Memory must remain unchanged
        printf("TEST RESULT: %s (SC=%d, mem=0x%016llx))\n\r",
               (success_first != 0) ? "PASSED" : "FAILED",
               success_first, *addr_aligned_d);
        printf("Memory value after SC : 0x%08x\n\n\r", *addr_aligned_d);

        // === Postconditions ===
        *addr_aligned_d = init_val_d;
    #endif

    } // end loop

    printf("=== ALL TESTS DONE ===\n\r");
    return 0;
}