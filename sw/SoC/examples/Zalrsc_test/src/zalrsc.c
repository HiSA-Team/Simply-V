// Author: Valerio Di Domenico <valerio.didomenico@unina.it>
// Description:  Zalrsc tests' functions implementation file

#include "zalrsc.h"

    // LR.W / SC.W function
    int lr_w_sc_sequence(volatile unsigned int* addr, unsigned int new_val) {
        int success;
        asm volatile (
            "lr.w t0, (%1)\n"
            "sc.w %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr), "r"(new_val)
            : "t0", "memory"
        );
        return success;
    }

    // LR.W.aq / SC.W.rl function
    int lr_w_aq_sc_rl_sequence(volatile unsigned int* addr, unsigned int new_val) {
        int success;
        asm volatile (
            "lr.w.aq t0, (%1)\n"
            "sc.w.rl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr), "r"(new_val)
            : "t0", "memory"
        );
        return success;
    }

    // LR.W.aqrl / SC.W.aqrl function
    int lr_w_aqrl_sc_aqrl_sequence(volatile unsigned int* addr, unsigned int new_val) {
        int success;
        asm volatile (
            "lr.w.aqrl t0, (%1)\n"     // Full fence acquire+release at LR
            "sc.w.aqrl %0, %2, (%1)\n" // Full fence acquire+release at SC
            : "=r"(success)
            : "r"(addr), "r"(new_val)
            : "t0", "memory"
        );
        return success;
    }

#ifdef __LP64__

    // LR.D / SC.D function
    int lr_d_sc_sequence(volatile unsigned long long* addr, unsigned long long new_val) {
        int success;
        asm volatile (
            "lr.d t0, (%1)\n"
            "sc.d %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr), "r"(new_val)
            : "t0", "memory"
        );
        return success;
    }

    // LR.D.aq / SC.D.rl function
    int lr_d_aq_sc_rl_sequence(volatile unsigned long long* addr, unsigned long long new_val) {
        int success;
        asm volatile (
            "lr.d.aq t0, (%1)\n"
            "sc.d.rl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr), "r"(new_val)
            : "t0", "memory"
        );
        return success;
    }

    // LR.D.aqrl / SC.D.aqrl function
    int lr_d_aqrl_sc_aqrl_sequence(volatile unsigned long long* addr, unsigned long long new_val) {
        int success;
        asm volatile (
            "lr.d.aqrl t0, (%1)\n"
            "sc.d.aqrl %0, %2, (%1)\n"
            : "=r"(success)
            : "r"(addr), "r"(new_val)
            : "t0", "memory"
        );
        return success;
    }

#endif


