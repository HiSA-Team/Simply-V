###########################
###  	INPUT FILES     ###
###########################

INPUT_MBUS_CSV  ?= $(CONFIG_ROOT)/configs/$(SOC_CONFIG)/config_mbus.csv
INPUT_PBUS_CSV  ?= $(CONFIG_ROOT)/configs/$(SOC_CONFIG)/config_pbus.csv
INPUT_HBUS_CSV  ?= $(CONFIG_ROOT)/configs/$(SOC_CONFIG)/config_hbus.csv
INPUT_SYSTEM_CSV ?= $(CONFIG_ROOT)/configs/common/config_system.csv

###########################
###  	OUTPUT FILES    ###
###########################

# Generated from "config_mbus"
OUTPUT_MBUS_CROSSBAR := $(XILINX_ROOT)/ips/common/xlnx_mbus_crossbar/config.tcl
OUTPUT_MBUS_SVINC    := $(XILINX_ROOT)/rtl/mbus_buses.svinc
OUTPUT_MBUS_CLK_ASSIGNMENTS := $(XILINX_ROOT)/rtl/uninasoc_clk_assignments.svinc

# Generated from "config_pbus"
OUTPUT_PBUS_CROSSBAR := $(XILINX_ROOT)/ips/common/xlnx_pbus_crossbar/config.tcl
OUTPUT_PBUS_SVINC    := $(XILINX_ROOT)/rtl/pbus_buses.svinc

# Generated from "config_hbus"
OUTPUT_HBUS_CROSSBAR := $(XILINX_ROOT)/ips/hpc/xlnx_hbus_crossbar/config.tcl
OUTPUT_HBUS_SVINC    := $(XILINX_ROOT)/rtl/hbus_buses.svinc
OUTPUT_HBUS_CLK_ASSIGNMENTS := $(XILINX_ROOT)/rtl/hbus_clk_assignments.svinc

# Generated from "config_sw"
OUTPUT_HAL_CONF := $(SW_ROOT)/SoC/lib/uninasoc/inc/uninasoc_conf.h
OUTPUT_SW_MK    := $(SW_ROOT)/SoC/common/config.mk
OUTPUT_LD       := $(SW_ROOT)/SoC/common/UninaSoC.ld

# Generated from "config_xilinx"
OUTPUT_XILINX_MK := $(XILINX_ROOT)/make/config.mk

# For now the cache functionality is only supported for ddr4 channel 0
# and the bram functionality is only supported for BRAM_0
# need to find a easily extensible way to manage configs files for multiple channels and brams
OUTPUT_DDR4_CH_0_CACHE := $(XILINX_IPS_ROOT)/hpc/xlnx_system_cache_0/config.tcl
OUTPUT_BRAM_0 := $(XILINX_IPS_ROOT)/common/xlnx_bram_0/config.tcl

# Generated from "config_dump"
OUTPUT_DUMP := $(CONFIG_ROOT)/dump.csv


###########################
###  	CMD PARAMS      ###
###########################

PYTHON ?= python3.10

CMD_ARGS = \
	--system $(INPUT_SYSTEM_CSV) \
	--mbus   $(INPUT_MBUS_CSV)  \
	--pbus   $(INPUT_PBUS_CSV)  \
	--hbus   $(INPUT_HBUS_CSV)

###########################
###  	 TARGETS        ###
###########################

all: config_mbus config_pbus config_hbus config_sw config_xilinx config_dump

# This target can be used to validate configuration without generating
# any output files, isn't needed as "prerequisite" for any other target
# because validation of configuration is implicit in the generation of files
config_check:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py --mode $@ $(CMD_ARGS) $(OUTPUT_FILES)


############################################################
###     		 BUS TARGETS (mbus, pbus, hbus)			 ###
############################################################

config_mbus: OUTPUT_FILES := $(OUTPUT_MBUS_CROSSBAR) $(OUTPUT_MBUS_SVINC) $(OUTPUT_MBUS_CLK_ASSIGNMENTS)
config_pbus: OUTPUT_FILES := $(OUTPUT_PBUS_CROSSBAR) $(OUTPUT_PBUS_SVINC)
config_hbus: OUTPUT_FILES := $(OUTPUT_HBUS_CROSSBAR) $(OUTPUT_HBUS_SVINC) $(OUTPUT_HBUS_CLK_ASSIGNMENTS)

config_%bus:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py --mode $@ --target_bus $*bus $(CMD_ARGS) $(OUTPUT_FILES)

############################################################
###					 SOFTWARE TARGETS					 ###
############################################################

config_sw: OUTPUT_FILES := $(OUTPUT_HAL_CONF) $(OUTPUT_SW_MK) $(OUTPUT_LD)
config_sw:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py --mode $@ $(CMD_ARGS) $(OUTPUT_FILES)


############################################################
###					 XILINX TARGET					 	 ###
############################################################

config_xilinx: OUTPUT_FILES := $(OUTPUT_XILINX_MK) $(OUTPUT_DDR4_CH_0_CACHE) $(OUTPUT_BRAM_0)
config_xilinx:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py --mode $@ $(CMD_ARGS) $(OUTPUT_FILES)


############################################################
###					  DUMP TARGET						 ###
############################################################

config_dump: OUTPUT_FILES := $(OUTPUT_DUMP)
config_dump:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py --mode $@ $(CMD_ARGS) $(OUTPUT_FILES)
