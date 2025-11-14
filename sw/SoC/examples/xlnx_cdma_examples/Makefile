# Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
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
INC_DIR        = inc \
                 $(SOC_SW_ROOT_DIR)/lib/uninasoc/inc \
                 $(SOC_SW_ROOT_DIR)/lib/tinyio/inc
                 
INCLUDES       = $(addprefix -I, $(INC_DIR))

STARTUP_DIR = $(SOC_SW_ROOT_DIR)/common

LD_SCRIPT     = ld/user.ld

#############
# Libraries #
#############

LIB_OBJ_LIST = \
    $(SOC_SW_ROOT_DIR)/lib/uninasoc/lib/libuninasoc.a \
    $(SOC_SW_ROOT_DIR)/lib/tinyio/lib/tinyio.a

LIB_INC_LIST = \
    $(SOC_SW_ROOT_DIR)/lib/uninasoc/inc \
    $(SOC_SW_ROOT_DIR)/lib/tinyio/inc

#############
# Toolchain #
#############

RISCV_GCC_PATH := $(HOME)/riscv-gnu-toolchain32/bin
PATH := $(RISCV_GCC_PATH):$(PATH)

RV_PREFIX     = riscv32-unknown-elf-
CC            = $(RV_PREFIX)gcc
LD            = $(RV_PREFIX)ld
OBJDUMP       = $(RV_PREFIX)objdump
OBJCOPY       = $(RV_PREFIX)objcopy

CFLAGS        = -march=rv32imad_zicsr_zifencei -O0 -c $(INCLUDES)

LDFLAGS       = $(LIB_OBJ_LIST) -nostdlib -T$(LD_SCRIPT)

include $(SW_ROOT)/SoC/common/Makefile

