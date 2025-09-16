# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
#   This Makefile defines the project name and paths for the common Makefile.
#   Optionally, a user can define additional targets here.

################
# Program Name #
################

# Get program name from directory name
PROGRAM_NAME = $(shell basename $$PWD)


#####################
# Paths and Folders #
#####################

SOC_SW_ROOT_DIR = $(SW_ROOT)/SoC

SRC_DIR        = src
OBJ_DIR        = obj
INC_FLAGS     = -Iinc -I$(SOC_SW_ROOT_DIR)/common
STARTUP_DIR = $(SOC_SW_ROOT_DIR)/common

LD_SCRIPT     = ld/user.ld

#############
# Libraries #
#############

LIB_OBJ_LIST =
LIB_INC_LIST =

#############
# Toolchain #
#############

RV_PREFIX     = riscv32-unknown-elf-
CC             = $(RV_PREFIX)gcc
LD             = $(RV_PREFIX)ld
OBJDUMP     = $(RV_PREFIX)objdump
OBJCOPY     = $(RV_PREFIX)objcopy

CFLAGS         = -march=rv32imad_zicsr_zifencei -O0 -c
LDFLAGS     = $(LIB_OBJ_LIST) -nostdlib -T$(LD_SCRIPT)

include $(SW_ROOT)/SoC/common/Makefile

