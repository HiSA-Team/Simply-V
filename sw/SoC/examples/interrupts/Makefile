# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description:
#   This Makefile defines the project name and paths for the common Makefile.
#   Optionally, a user can define additional targets here.

################
# Program Name #
################

# Get program name from directory name
PROGRAM_NAME = $(shell basename $$PWD)

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
LIB_DIR     = $(SW_SOC_ROOT)/lib

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

###########
# Targets #
###########

include $(SW_ROOT)/SoC/common/Makefile
