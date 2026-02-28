# This Makefile orchestrates the build of OpenSBI and S-mode payloads.
#
# Usage:
#  make              # builds payloads and OpenSBI
#  make payloads     # builds all payloads in payloads/
#  make install      # install the platform configuration in the OpenSBI tree
#  make opensbi      # build opensbi firmware for simply-v refer to `README.md` for further details
#  make pull-opensbi # make sure OpenSBI submodule is synchronized and checked out to the correct version
#  make run          # run a debug session loading the M-mode firmware and S-mode payload using GDB
#  make clean        # clean build artifact
#
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>

ifndef SIMPLY_ROOT_DIR
$(error Setup script settings.sh has not been sourced, aborting)
endif

PYTHON ?= python3.10 # Requires >= 3.10

# SoC system configuration
include $(SW_ROOT)/SoC/common/config.mk

# Overwrite: we need linux-gnu toolchain for OpenSBI
RV_PREFIX   := riscv$(XLEN)-unknown-linux-gnu-

# Payload directory
PAYLOAD_DIR := payloads
PAYLOADS    := $(notdir $(wildcard $(PAYLOAD_DIR)/*))

# OpenSBI params
OPENSBI_FW_PAYLOAD_BIN_PATH ?= $(SW_SOC_ROOT)/projects/opensbi/payloads/hello_world/build/hello_world.bin
OPENSBI_DIR                 := $(SW_SOC_ROOT)/projects/opensbi/opensbi
OPENSBI_FLAGS               := PLATFORM=fpga/simply-v \
                               CROSS_COMPILE=$(RV_PREFIX) \
                               FW_PAYLOAD_PATH=$(OPENSBI_FW_PAYLOAD_BIN_PATH) \
                               PLATFORM_RISCV_XLEN=$(XLEN)
# Run script params
OPENSBI_GDB_SERVER_ADDRESS  := localhost:3004
OPENSBI_FW_PAYLOAD_ELF_PATH ?= $(OPENSBI_FW_PAYLOAD_BIN_PATH:.bin=.elf)
LOAD_JUMP_PAYLOAD           ?= y
OPENSBI_FW_JUMP             ?= n
OPENSBI_RUN_FLAGS           := GDB_SERVER=$(OPENSBI_GDB_SERVER_ADDRESS) \
                               FW_JUMP=$(OPENSBI_FW_JUMP) \
                               LOAD_JUMP_PAYLOAD=$(LOAD_JUMP_PAYLOAD) \
                               FW_PAYLOAD_ELF_PATH=$(OPENSBI_FW_PAYLOAD_ELF_PATH)

# retrieve OpenSBI code, install platform porting and build all payloads
all: payloads opensbi

# build opensbi firmware
opensbi:
	$(MAKE) -C $(OPENSBI_DIR) $(OPENSBI_FLAGS)

# install: installs the platform configuration in the OpenSBI tree
install: pull-opensbi
	$(PYTHON) $(SW_SOC_ROOT)/projects/opensbi/scripts/create_config.py \
		$(CONFIG_ROOT)/configs/$(SIMPLYV_PROFILE)/config_main_bus.csv \
		$(SW_SOC_ROOT)/projects/opensbi/simply-v/config.mk
	cp -vr simply-v $(OPENSBI_DIR)/platform/fpga

# pull-opensbi: retrieve opensbi code
pull-opensbi:
	@git submodule update --init --recursive $(OPENSBI_DIR)

# payloads: build S-mode payloads in payloads/
payloads: $(PAYLOADS)

menuconfig: install
	$(MAKE) -C $(OPENSBI_DIR) $(OPENSBI_FLAGS) menuconfig

# call make inside payloads/<name>
$(PAYLOADS):
	@$(MAKE) -C $(PAYLOAD_DIR)/$@ all

# run: program the firmware using gdb
run:
	$(MAKE) -C $(OPENSBI_DIR) $(OPENSBI_FLAGS) $(OPENSBI_RUN_FLAGS) run

# clean everything
clean:
	$(MAKE) -C $(OPENSBI_DIR) clean distclean
	@for a in $(PAYLOADS); do \
		$(MAKE) -C $(PAYLOAD_DIR)/$$a clean; \
	done

.PHONY: all clean opensbi payloads
