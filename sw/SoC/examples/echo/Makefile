# Author: Stefano Mercogliano     <stefano.mercogliano@unina.it>
# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description:
#   This Makefile defines the project name and paths for the common Makefile.
#    Optionally, a user can define additional targets here.

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

include $(SW_ROOT)/SoC/common/Makefile
