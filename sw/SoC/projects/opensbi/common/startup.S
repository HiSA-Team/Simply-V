/*
 * Entrypoint of a basic kernel running in S-mode.
 * - zero all registers
 * - hang on interrupt (stvec)
 * - initialize stack
 * - call main
 *
 * Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */
    .section .text._start, "ax"
    .globl _start
_start:
    /* Reset registers */
    mv ra, zero
    mv gp, zero
    mv tp, zero
    mv t0, zero
    mv t1, zero
    mv t2, zero
    mv s0, zero
    mv s1, zero
    mv a0, zero
    mv a1, zero
    mv a2, zero
    mv a3, zero
    mv a4, zero
    mv a5, zero
    mv a6, zero
    mv a7, zero
    mv s2, zero
    mv s3, zero
    mv s4, zero
    mv s5, zero
    mv s6, zero
    mv s7, zero
    mv s8, zero
    mv s9, zero
    mv s10, zero
    mv s11, zero
    mv t3, zero
    mv t4, zero
    mv t5, zero
    mv t6, zero

    /* Dummy trap handler */
    la a0, __hang
    csrw stvec, a0

    /* Load stack pointer */
    la sp, __stack_top

    /* Zero out a0 register*/
    add a0, zero, zero

    call main

    /* Hang */
__hang:  
    j __hang

