# Copyright 2022 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Paul Scheffler <paulsc@iis.ee.ethz.ch>

# Import this GNU Make fragment in your project's makefile to regenerate and
# reconfigure these IPs. You can modify the original RTL, configuration, and
# templates from your project without entering this dependency repo by adding
# build targets for them. To build the IPs, `make otp`.

# You may need to adapt these environment variables to your configuration.
BENDER   ?= bender
REGTOOL  ?= $(shell $(BENDER) path register_interface)/vendor/lowrisc_opentitan/util/regtool.py
PLICOPT  ?= -s 32 -t 1 -p 7

OTPROOT  ?= $(shell $(BENDER) path opentitan_peripherals)
IPGEN    ?= $(OTPROOT)/util/ipgen.py
DIFGEN   ?= $(OTPROOT)/util/make_new_dif.py

_otp: otp_rv_plic

# PLIC generation inputs and outputs
OTP_PLIC_TPLD = $(OTPROOT)/src/rv_plic/tpl/rv_plic
OTP_PLIC_IN   = $(addprefix $(OTP_PLIC_TPLD)/rtl/, rv_plic.sv.tpl rv_plic_gateway.sv.tpl rv_plic_target.sv.tpl)
OTP_PLIC_IN  += $(addprefix $(OTP_PLIC_TPLD)/data/, rv_plic.hjson.tpl rv_plic.tpldesc.hjson)
OTP_PLIC_OUTD = $(OTPROOT)/src/rv_plic
OTP_PLIC_OUT  = $(addprefix $(OTP_PLIC_OUTD)/rtl/, rv_plic.sv rv_plic_gateway.sv rv_plic_target.sv)
OTP_PLIC_OUT += $(addprefix $(OTP_PLIC_OUTD)/data/, rv_plic.hjson rv_plic.ipconfig.hjson)

# Only one target must be built to build them all
otp_rv_plic: $(OTP_PLIC_OUTD)/rtl/rv_plic.sv

$(OTP_PLIC_OUT): $(OTP_PLIC_IN)
	rm -rf $(OTP_PLIC_OUTD)/gen
	PYTHONPATH=$(dir $(REGTOOL)) python3.10 $(IPGEN) generate -C $(OTP_PLIC_TPLD) -o $(OTP_PLIC_OUTD)/gen -c $(OTPROOT)/src/rv_plic/rv_plic.cfg.hjson
	cp -a --no-preserve=mode $(OTP_PLIC_OUTD)/gen/* $(OTP_PLIC_OUTD)/
	rm -rf $(OTP_PLIC_OUTD)/gen

# Generate software for peripherals
OTP_REG_DIR  = $(OTPROOT)/sw/include

define hdr_gen_rule
OTP_REG_HDRS += $$(OTP_REG_DIR)/$(1)_regs.h

$$(OTP_REG_DIR)/$(1)_regs.h: $(2) otp_$(1)
	@mkdir -p $$(dir $$@)
	$$(REGTOOL) --cdefines $$< > $$@
endef

$(eval $(call hdr_gen_rule,rv_plic,$(OTPROOT)/src/rv_plic/data/rv_plic.hjson))

otp_reg_hdrs: $(OTP_REG_HDRS)

otp:
	@echo '[PULP] Generate OpenTitan peripherals: PLIC Only'
	@$(MAKE) -B _otp
