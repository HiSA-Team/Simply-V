# Example Makefile for simple S-mode payload. Each `payloads/` directory contains a kernel example.
# Simple kernels can use this Makefile to produce an ELF. They will be linked with common/linker.ld
# linkerscript and use startup.S as minimal entrypoint.
#
# This Makefile is supposed to be linked into the target project to build
#
# Usage:
#  make         # build the project
#  make clean   # clean build artifact
#
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>

ifndef SIMPLY_ROOT_DIR
$(error Setup script settings.sh has not been sourced, aborting)
endif

RV_PREFIX   ?= 	riscv${XLEN}-unknown-elf-
XLEN        ?= 64

# Toolchain
CC      := $(RV_PREFIX)gcc
LD      := $(RV_PREFIX)ld
OBJCOPY := $(RV_PREFIX)objcopy

# Project name = current directory
PROJECT    := $(notdir $(CURDIR))
COMMON_DIR := $(SW_SOC_ROOT)/projects/opensbi/common

# Architecture
ARCH       := rv$(XLEN)imc_zalrsc_zicsr_zifencei

# Output directories (relative to project dir)
BUILD_DIR        := build
APP_BUILD_DIR    := $(BUILD_DIR)/app
COMMON_BUILD_DIR := $(BUILD_DIR)/common

# Hardcoded common sources (from COMMON_DIR) COMMON_SRCS := startup.S sbi.c split common sources by extension
COMMON_C_SRCS := $(wildcard $(COMMON_DIR)/*.c)
COMMON_S_SRCS := $(wildcard $(COMMON_DIR)/*.S)

# common object names (strip extensions, put under common build dir)
COMMON_OBJS := \
	$(patsubst %.c,$(COMMON_BUILD_DIR)/%.o,$(notdir $(COMMON_C_SRCS))) \
	$(patsubst %.S,$(COMMON_BUILD_DIR)/%.o,$(notdir $(COMMON_S_SRCS)))

# App sources (local directory only)
APP_SRCS := $(wildcard *.c)
APP_OBJS := $(patsubst %.c,$(APP_BUILD_DIR)/%.o,$(APP_SRCS))

OBJS := $(COMMON_OBJS) $(APP_OBJS)

# Flags
CFLAGS := -Wall -Wextra -march=$(ARCH) -I$(COMMON_DIR) -I. -mcmodel=medany

ifeq ($(DEBUG),1)
CFLAGS  += -g -O0
else
CFLAGS  += -O2
endif

LDFLAGS := -T$(COMMON_DIR)/linker.ld -nostdlib

# Outputs
ELF := $(BUILD_DIR)/$(PROJECT).elf
BIN := $(BUILD_DIR)/$(PROJECT).bin

# Default target
all: $(BIN)

# Link
$(ELF): $(OBJS)
	@mkdir -p $(dir $@)
	$(LD) $(OBJS) $(LDFLAGS) -o $@

# Binary
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

# -------------------------
# Build rules (single % per pattern - no %.c.o or %.S.o)
# -------------------------

# App C files (project-local .c -> build/app/%.o)
$(APP_BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Common C files (common dir .c -> build/common/%.o)
$(COMMON_BUILD_DIR)/%.o: $(COMMON_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Common assembly files (common dir .S -> build/common/%.o)
$(COMMON_BUILD_DIR)/%.o: $(COMMON_DIR)/%.S
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Cleanup
clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
