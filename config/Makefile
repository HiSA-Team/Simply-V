# Variables
PYTHON ?= python3.10 # Requires >= 3.10

# Configurations
CONFIG_MBUS_CSV ?= ${CONFIG_ROOT}/configs/${SOC_CONFIG}/config_main_bus.csv
CONFIG_PBUS_CSV ?= ${CONFIG_ROOT}/configs/${SOC_CONFIG}/config_peripheral_bus.csv
CONFIG_HBUS_CSV ?= ${CONFIG_ROOT}/configs/${SOC_CONFIG}/config_highperformance_bus.csv
# csv for system-level configuration
CONFIG_SYSTEM_CSV ?= ${CONFIG_ROOT}/configs/common/config_system.csv
# CSVs list
CONFIG_BUS_CSVS ?= ${CONFIG_MBUS_CSV} \
			   ${CONFIG_PBUS_CSV} \
			   ${CONFIG_HBUS_CSV}

all: config_main_bus config_peripheral_bus config_highperformance_bus config_ld config_sw config_xilinx

config_main_bus:
config_peripheral_bus:
config_highperformance_bus:
config_%_bus: CONFIG_BUS_CSV = ${CONFIG_ROOT}/configs/${SOC_CONFIG}/config_$*_bus.csv
config_%_bus: OUTPUT_TCL_FILE = ${XILINX_ROOT}/ips/common/xlnx_$*_crossbar/config.tcl
config_%_bus: config_check
	${PYTHON} ${CONFIG_ROOT}/scripts/create_crossbar_config.py \
		${CONFIG_SYSTEM_CSV} \
		${CONFIG_BUS_CSV} \
		${OUTPUT_TCL_FILE}
	${PYTHON} ${CONFIG_ROOT}/scripts/declare_and_concat_buses_rtl.py ${CONFIG_BUS_CSV}
	${PYTHON} ${CONFIG_ROOT}/scripts/declare_and_assign_clocks_rtl.py ${CONFIG_BUS_CSV}


OUTPUT_LD_FILE ?= ${SW_ROOT}/SoC/common/UninaSoC.ld
# Generate HAL configuration file
OUTPUT_HAL_CONF_FILE ?= ${SW_ROOT}/SoC/lib/uninasoc/inc/uninasoc_conf.h

config_ld: config_check
	${PYTHON} ${CONFIG_ROOT}/scripts/create_linker_script.py \
		${CONFIG_BUS_CSVS} \
		${OUTPUT_LD_FILE}
	@echo "[CONFIG] Output file is at ${OUTPUT_LD_FILE}"


config_check:
	${PYTHON} ${CONFIG_ROOT}/scripts/check_config.py ${CONFIG_SYSTEM_CSV} ${CONFIG_BUS_CSVS}

# Update config Makefiles
OUTPUT_XILINX_MK_FILE ?= ${XILINX_ROOT}/make/config.mk
OUTPUT_SW_MK_FILE ?= $(SW_ROOT)/SoC/common/config.mk
config_xilinx:
	${CONFIG_ROOT}/scripts/config_xilinx.sh ${CONFIG_SYSTEM_CSV} ${CONFIG_BUS_CSVS} ${OUTPUT_XILINX_MK_FILE}

config_sw: config_check
	${CONFIG_ROOT}/scripts/config_sw.sh ${CONFIG_SYSTEM_CSV} ${OUTPUT_SW_MK_FILE}
	${PYTHON} ${CONFIG_ROOT}/scripts/create_uninasoc_conf_header.py ${CONFIG_PBUS_CSV} ${OUTPUT_HAL_CONF_FILE}


