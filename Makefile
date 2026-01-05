# Environment check
ifndef ROOT_DIR
$(error Setup script settings.sh has not been sourced, aborting)
endif

all: hw sw

config:
	${MAKE} -C ${CONFIG_ROOT}

hw: xilinx

# Limit the number of parallel Vivado instances
MAX_VIVADO_INSTANCES ?= 6 # This should be safe for a 16-cores CPU
xilinx: units config
	${MAKE} -C ${XILINX_ROOT} -j ${MAX_VIVADO_INSTANCES}

# We don't really need to limit the number of parallel fetching of sources
MAX_UNITS_INSTANCES ?= 99
units:
	${MAKE} -C ${HW_UNITS_ROOT} -j ${MAX_UNITS_INSTANCES}

sw: config
	${MAKE} -C ${SW_ROOT}

clean:
	${MAKE} -C ${XILINX_ROOT} clean clean_ips
	${MAKE} -C ${HW_UNITS_ROOT} clean
	${MAKE} -C ${SW_ROOT} clean

.PHONY: config hw sw xilinx units
