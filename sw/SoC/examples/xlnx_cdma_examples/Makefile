# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Author: Michele Giugliano <michele.giuglian2@studenti.unina.it>
# Description:
#   Makefile for AXI CDMA examples on Simply-V SoC.
# Usage:
#       make CDMA_EXAMPLE=simple
#       make CDMA_EXAMPLE=irq

################
# Program Name #
################

# Example selection
CDMA_EXAMPLE ?= simple
# Bind program name to example
PROGRAM_NAME = $(shell basename $$PWD)_$(CDMA_EXAMPLE)

#############
# Toolchain #
#############

#####################
# Paths and Folders #
#####################

SOC_SW_ROOT_DIR = $(SW_ROOT)/SoC

SRC_DIR        = src
OBJ_DIR        = obj
INC_DIR     = inc
STARTUP_DIR = $(SOC_SW_ROOT_DIR)/common

LD_SCRIPT     = ld/user.ld

#############
# Libraries #
#############

LIB_OBJ_TINYIO    = $(LIB_DIR)/tinyio/lib/tinyio.a
LIB_INC_TINYIO    = -I$(LIB_DIR)/tinyio/inc

LIB_OBJ_UNINASOC  = $(LIB_DIR)/uninasoc/lib/libuninasoc.a
LIB_INC_UNINASOC   = -I$(LIB_DIR)/uninasoc/inc

LIB_OBJ_LIST     = $(LIB_OBJ_TINYIO) $(LIB_OBJ_UNINASOC)
LIB_INC_LIST     = $(LIB_INC_TINYIO) $(LIB_INC_UNINASOC)

#############
# Toolchain #
#############

include $(SW_ROOT)/SoC/common/config.mk

###########
# Targets #
###########

# Override object file
OBJS := $(OBJ_DIR)/$(CDMA_EXAMPLE)_main.o

# Use common targets
include $(SW_ROOT)/SoC/common/Makefile
