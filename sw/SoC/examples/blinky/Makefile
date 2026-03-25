# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
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

#############
# Libraries #
#############

LIB_OBJ_LIST     =
LIB_INC_LIST     =

#############
# Toolchain #
#############

include $(SW_ROOT)/SoC/common/config.mk

###########
# Targets #
###########

include $(SW_ROOT)/SoC/common/Makefile
