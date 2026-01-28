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
OUTPUT_MBUS_INTERCONNECT    := $(XILINX_ROOT)/rtl/mbus_buses.svinc
OUTPUT_MBUS_CLK_ASSIGNMENTS := $(XILINX_ROOT)/rtl/uninasoc_clk_assignments.svinc

# Generated from "config_pbus"
OUTPUT_PBUS_CROSSBAR := $(XILINX_ROOT)/ips/common/xlnx_pbus_crossbar/config.tcl
OUTPUT_PBUS_INTERCONNECT    := $(XILINX_ROOT)/rtl/pbus_buses.svinc

# Generated from "config_hbus"
OUTPUT_HBUS_CROSSBAR := $(XILINX_ROOT)/ips/hpc/xlnx_hbus_crossbar/config.tcl
OUTPUT_HBUS_INTERCONNECT    := $(XILINX_ROOT)/rtl/hbus_buses.svinc
OUTPUT_HBUS_CLK_ASSIGNMENTS := $(XILINX_ROOT)/rtl/hbus_clk_assignments.svinc

# Generated from "config_sw"
OUTPUT_HAL_CONF := $(SW_ROOT)/SoC/lib/uninasoc/inc/uninasoc_conf.h
OUTPUT_SW_MK    := $(SW_ROOT)/SoC/common/config.mk
OUTPUT_LD       := $(SW_ROOT)/SoC/common/UninaSoC.ld

# Generated from "config_xilinx"
OUTPUT_XILINX_MK := $(XILINX_ROOT)/make/config.mk

# Generated from "config_xilinx"
OUTPUT_DDR4_ROOT := $(XILINX_IPS_ROOT)/hpc
OUTPUT_BRAM_ROOT := $(XILINX_IPS_ROOT)/common
OUTPUT_UART_ROOT := $(XILINX_IPS_ROOT)/embedded

# Generated from "config_dump"
OUTPUT_DUMP := $(CONFIG_ROOT)/dump.csv


###########################
###  	CMD PARAMS      ###
###########################

PYTHON ?= python3.10

INPUT_ARGS = \
	--system_csv $(INPUT_SYSTEM_CSV) \
	--mbus_csv   $(INPUT_MBUS_CSV)  \
	--pbus_csv   $(INPUT_PBUS_CSV)  \
	--hbus_csv   $(INPUT_HBUS_CSV)

CONFIG_MBUS_ARGS = \
	--config_mbus \
	--mbus_tcl $(OUTPUT_MBUS_CROSSBAR) \
	--mbus_interconnect $(OUTPUT_MBUS_INTERCONNECT) \
	--mbus_clock $(OUTPUT_MBUS_CLK_ASSIGNMENTS)

CONFIG_PBUS_ARGS = \
	--config_pbus \
	--pbus_tcl $(OUTPUT_PBUS_CROSSBAR) \
	--pbus_interconnect $(OUTPUT_PBUS_INTERCONNECT) 

CONFIG_HBUS_ARGS = \
	--config_hbus \
	--hbus_tcl $(OUTPUT_HBUS_CROSSBAR) \
	--hbus_interconnect $(OUTPUT_HBUS_INTERCONNECT) \
	--hbus_clock $(OUTPUT_HBUS_CLK_ASSIGNMENTS)

CONFIG_SW_ARGS = \
	--config_sw \
	--hal_conf $(OUTPUT_HAL_CONF) \
	--sw_mk $(OUTPUT_SW_MK) \
	--ld_conf $(OUTPUT_LD)

CONFIG_HW_ARGS = \
	--config_xilinx \
	--xilinx_mk $(OUTPUT_XILINX_MK) \
	--ddr4_root $(OUTPUT_DDR4_ROOT) \
	--bram_root $(OUTPUT_BRAM_ROOT) \
	--uart_root $(OUTPUT_UART_ROOT)

CONFIG_DUMP_ARGS = \
	--config_dump \
	--dump_path $(OUTPUT_DUMP)
				 

###########################
###  	 TARGETS        ###
###########################

all: 
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py $(INPUT_ARGS) $(CONFIG_MBUS_ARGS) $(CONFIG_PBUS_ARGS)\
			   $(CONFIG_HBUS_ARGS) $(CONFIG_SW_ARGS) $(CONFIG_HW_ARGS) $(CONFIG_DUMP_ARGS)


# This target can be used to validate configuration without generating
# any output files, isn't needed as "prerequisite" for any other target
# because validation of configuration is implicit in the generation of files
config_check:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py $(INPUT_ARGS)


############################################################
###     		 BUS TARGETS (mbus, pbus, hbus)			 ###
############################################################

config_mbus: CONFIG_BUS_ARGS := $(CONFIG_MBUS_ARGS)
config_pbus: CONFIG_BUS_ARGS := $(CONFIG_PBUS_ARGS)
config_hbus: CONFIG_BUS_ARGS := $(CONFIG_HBUS_ARGS)

config_%bus:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py $(INPUT_ARGS) $(CONFIG_BUS_ARGS)

############################################################
###					 SOFTWARE TARGETS					 ###
############################################################

config_sw:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py $(INPUT_ARGS) $(CONFIG_SW_ARGS) 


############################################################
###					 XILINX TARGET					 	 ###
############################################################

config_xilinx:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py $(INPUT_ARGS) $(CONFIG_HW_ARGS) 


############################################################
###					  DUMP TARGET						 ###
############################################################

config_dump:
	@$(PYTHON) $(CONFIG_ROOT)/simply_v_conf/main.py $(INPUT_ARGS) $(CONFIG_DUMP_ARGS) 
