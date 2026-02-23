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

SRC_DIR     = src
OBJ_DIR     = obj
INC_DIR     = inc
STARTUP_DIR = $(SW_SOC_ROOT)/common

#############
# Libraries #
#############

LIB_OBJ_TINYIO    = $(LIB_DIR)/tinyio/lib/tinyio.a
LIB_INC_TINYIO    = -I$(LIB_DIR)/tinyio/inc

LIB_OBJ_SIMPLYV  = $(LIB_DIR)/simplyv/lib/libsimplyv.a
LIB_INC_SIMPLYV   = -I$(LIB_DIR)/simplyv/inc

LIB_OBJ_LIST     = $(LIB_OBJ_TINYIO) $(LIB_OBJ_SIMPLYV)
LIB_INC_LIST     = $(LIB_INC_TINYIO) $(LIB_INC_SIMPLYV)

#############
# Toolchain #
#############

include $(SW_ROOT)/SoC/common/config.mk

# This example only works at 32 bits for now
ifeq (${XLEN},64)
$(error "Trying to build ${PROGRAM_NAME} with RV64, but it only supportx RV32 for now)
endif

###########
# Targets #
###########

# Override object file
OBJS := $(OBJ_DIR)/$(CDMA_EXAMPLE)_main.o

# Use common targets
include $(SW_ROOT)/SoC/common/Makefile
