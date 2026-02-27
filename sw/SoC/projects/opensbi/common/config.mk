# This file should be modified by configuration script to provide the correct FW_TEXT_START variable.
# This is needed since OpenSBI firmware linkerscript places the firmware starting from this variable.
#
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>

OPENSBI_FW_TEXT_START ?= 0x1000000
