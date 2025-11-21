# ================================================================
#  Author: Michele Giugliano <michele.giuglian2@studenti.unina.it>
#  Description:
#    Standalone Makefile for AXI CDMA examples on Simply-V SoC.
#    Directory layout:
#       src/simple/main.c
#       src/irq/main.c
#       src/multisize/main.c
#
#    Usage:
#       make EXAMPLE=simple
#       make EXAMPLE=irq
#       make EXAMPLE=multisize
# ================================================================

################
# Program Name #
################

PROGRAM_NAME := xlnx_cdma_examples

#####################
# Paths and Folders #
#####################

SOC_SW_ROOT_DIR := $(abspath $(CURDIR)/../..)

SRC_DIR   := src
OBJ_DIR   := obj
BIN_DIR   := bin

INC_DIR   := inc \
             $(SOC_SW_ROOT_DIR)/lib/uninasoc/inc \
             $(SOC_SW_ROOT_DIR)/lib/tinyio/inc

INCLUDES  := $(addprefix -I, $(INC_DIR))

STARTUP_SRC := $(SOC_SW_ROOT_DIR)/common/startup.s
LD_SCRIPT   := ld/user.ld

#############
# Libraries #
#############

LIBUNINASOC := $(SOC_SW_ROOT_DIR)/lib/uninasoc/lib/libuninasoc.a
LIBTINYIO   := $(SOC_SW_ROOT_DIR)/lib/tinyio/lib/tinyio.a
LIBS        := $(LIBUNINASOC) $(LIBTINYIO)

#############
# Toolchain #
#############

RISCV_GCC_PATH ?= $(HOME)/riscv-gnu-toolchain32/bin
PATH := $(RISCV_GCC_PATH):$(PATH)

RV_PREFIX := riscv32-unknown-elf-
CC        := $(RV_PREFIX)gcc
LD        := $(RV_PREFIX)ld
OBJDUMP   := $(RV_PREFIX)objdump
OBJCOPY   := $(RV_PREFIX)objcopy

CFLAGS  := -march=rv32imad_zicsr_zifencei -O0 -c $(INCLUDES) -DIS_EMBEDDED
LDFLAGS := $(LIBS) -nostdlib -T$(LD_SCRIPT)

#############################
# Example Selection Logic   #
#############################

EXAMPLE ?= simple

MAIN_SRC := $(SRC_DIR)/$(EXAMPLE)/main.c

MAIN_OBJ    := $(OBJ_DIR)/main.o
STARTUP_OBJ := $(OBJ_DIR)/startup.o

ELF  := $(BIN_DIR)/$(PROGRAM_NAME).elf
BIN  := $(BIN_DIR)/$(PROGRAM_NAME).bin
DUMP := $(BIN_DIR)/$(PROGRAM_NAME).dump

################
#   Targets    #
################

.PHONY: all clean

all: $(ELF) $(BIN) $(DUMP)

# ------------------------
# Linking ELF
# ------------------------
$(ELF): $(MAIN_OBJ) $(STARTUP_OBJ) $(LIBS) | $(BIN_DIR)
	@echo "[ELF] Linking $@"
	$(LD) -o $@ $(MAIN_OBJ) $(STARTUP_OBJ) $(LDFLAGS)

# ------------------------
# Binary output (.bin)
# ------------------------
$(BIN): $(ELF)
	@echo "[BIN] Generating $@"
	$(OBJCOPY) -O binary $(ELF) $(BIN)

# ------------------------
# Dump output (.dump)
# ------------------------
$(DUMP): $(ELF)
	@echo "[DUMP] Generating $@"
	$(OBJDUMP) -D $(ELF) > $(DUMP)

# ------------------------
# Object compilation
# ------------------------
$(MAIN_OBJ): $(MAIN_SRC) | $(OBJ_DIR)
	@echo "[OBJ] Compiling main from $(MAIN_SRC)"
	$(CC) -o $@ $(MAIN_SRC) $(CFLAGS)

$(STARTUP_OBJ): $(STARTUP_SRC) | $(OBJ_DIR)
	@echo "[OBJ] Compiling startup.s"
	$(CC) -o $@ $(STARTUP_SRC) $(CFLAGS)

# ------------------------
# Directory creation
# ------------------------
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# ------------------------
# Cleanup
# ------------------------
clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)

