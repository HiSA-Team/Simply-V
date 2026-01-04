# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
# 	It assigns the correct toolchain size depending on XLEN config parameter.
#	XLEN is overwritten by `config/scripts/config_sw.sh`

#############
# Toolchain #
#############

XLEN ?= 64
RV_PREFIX ?= riscv${XLEN}-unknown-elf-

CC          = $(RV_PREFIX)gcc
LD          = $(RV_PREFIX)ld
OBJDUMP     = $(RV_PREFIX)objdump
OBJCOPY     = $(RV_PREFIX)objcopy
AR          = $(RV_PREFIX)ar

# RISC-V Extensions
C_EXTENSION 	?= Y
F_EXTENSION		?= N
A_EXTENSION 	?= N
V_EXTENSION		?= N

#########
# Flags #
#########

ifeq ($(XLEN), 64)
ABI := lp64
else ifeq ($(XLEN), 32)
ABI := ilp32
else
$(error Unsupported XLEN value: $(XLEN))
endif

# Assume at least estensions IM
ARCH = rv${XLEN}im

# A: Atomic
ifeq ($(A_EXTENSION), Y)
	ARCH := $(addsuffix a,$(ARCH))
endif

# Floating-point also influences the ABI
# F: Single-precision floating-point
ifeq ($(F_EXTENSION), Y)
	ARCH := $(addsuffix f,$(ARCH))
	ABI  := $(addsuffix f,$(ABI))
endif

#	D: Double-precision floating-point
ifeq ($(D_EXTENSION), Y)
	ARCH := $(addsuffix d,$(ARCH))
	ABI  := $(addsuffix d,$(ABI))
endif

# C: Compressed
ifeq ($(C_EXTENSION), Y)
	ARCH := $(addsuffix c,$(ARCH))
endif

# V: Vector
ifeq ($(V_EXTENSION), Y)
	ARCH := $(addsuffix v,$(ARCH))
endif

# Always add Zicsr and Zifence
ARCH := $(addsuffix _zicsr_zifencei,$(ARCH))

DFLAG ?= -g -O0
CFLAGS ?= -march=${ARCH} -mabi=${ABI} $(DFLAG) -c
LDFLAGS ?= $(LIB_OBJ_LIST) -nostdlib -T$(LD_SCRIPT)

