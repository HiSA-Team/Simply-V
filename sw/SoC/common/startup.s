# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: Startup code and vector table definition for uninasoc

################
# Vector table #
################
.section .vector_table, "ax"
.option norvc;
.weak _sw_handler
.weak _timer_handler
.weak _ext_handler
.extern _sw_handler;
.extern _timer_handler;
.extern _ext_handler;

  # According to RISC-V Specification, all entries are jumps to the specific handler.
  # Only the reset handler is defined in this file, while all other handlers points to
  # the default_handler (a loop)

  # Reset handler
  jal x0, _reset_handler      # Entry 0

  jal x0, _default_handler    # Entry 1
  jal x0, _default_handler    # Entry 2

  # SIE handler
  jal x0, _sw_handler         # Entry 3

  jal x0, _default_handler    # Entry 4
  jal x0, _default_handler    # Entry 5
  jal x0, _default_handler    # Entry 6

  # TIE handler
  jal x0, _timer_handler      # Entry 7

  jal x0, _default_handler    # Entry 8
  jal x0, _default_handler    # Entry 9
  jal x0, _default_handler    # Entry 10

  # EIE handler
  jal x0, _ext_handler        # Entry 11

  jal x0, _default_handler    # Entry 12
  jal x0, _default_handler    # Entry 13
  jal x0, _default_handler    # Entry 14
  jal x0, _default_handler    # Entry 15
  jal x0, _default_handler    # Entry 16
  jal x0, _default_handler    # Entry 17
  jal x0, _default_handler    # Entry 18
  jal x0, _default_handler    # Entry 19
  jal x0, _default_handler    # Entry 20
  jal x0, _default_handler    # Entry 21
  jal x0, _default_handler    # Entry 22
  jal x0, _default_handler    # Entry 23
  jal x0, _default_handler    # Entry 24
  jal x0, _default_handler    # Entry 25
  jal x0, _default_handler    # Entry 26
  jal x0, _default_handler    # Entry 27
  jal x0, _default_handler    # Entry 28
  jal x0, _default_handler    # Entry 29
  jal x0, _default_handler    # Entry 30
  jal x0, _default_handler    # Entry 31

# Keep a dedicated sections for handlers
.section .text.handlers

_reset_handler:
  .global _reset_handler

  #####################
  # Registers Cleanup #
  #####################

  mv ra, zero
  mv sp, zero
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

  #####################
  # Enable Interrupts #
  #####################

  # Set mtvec to vectored mode
  la a0, _vector_table_start  # Load vector table base address
  li a1, 1                    # Set vectored mode bit
  or a1, a1, a0
  csrw mtvec, a1              # Commit on mtvec register

  # Enable global interrupts
  csrs mstatus, 0x8           # Enable MIE in mstatus

  # Enable local interrupt lines
  # MEI (External Interrupt), MSI (Software Interrupt) e MTI (Timer Interrupt) in mie register
  li a1, 0x0888
  csrs mie, a1

  ########
  # Tail #
  ########

  # Initialize the stack pointer
  la   sp, _stack_start

  # Jump to start function
  j _start

_default_handler:
  j _default_handler

.section .text.start

_start:
  .global _start

  # jump to main program entry point (argc = argv = 0)
  mv a0, zero
  mv a1, zero

  jal ra, main

# Hold program execution
_exit_wfi:
  wfi

# Spin in place
_exit_spin:
  j _exit_spin





