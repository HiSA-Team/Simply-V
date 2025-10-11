# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Hold all the Xilinx-related utility targets

# Common scripts directory
XILINX_SCRIPTS_UTILS_ROOT := ${XILINX_SCRIPT_ROOT}/utils

# Open project in TCL mode
open_prj:
	cd ${XILINX_PROJECT_BUILD_DIR}; \
	${XILINX_VIVADO_ENV} ${XILINX_VIVADO_CMD} \
	-mode tcl ${XILINX_PROJECT_NAME}.xpr

# Open project and GUI
open_gui:
	cd ${XILINX_PROJECT_BUILD_DIR}; \
	${XILINX_VIVADO_ENV} ${XILINX_VIVADO_CMD} \
	-mode gui ${XILINX_PROJECT_NAME}.xpr

# Start hardware server
start_hw_server:
	${XILINX_HW_SERVER} -d -L- -stcp::${XILINX_HW_SERVER_PORT}

# Open Vivado hardware manager in tcl mode
open_hw_manager:
	${XILINX_VIVADO_ENV} ${XILINX_VIVADO_CMD} -mode tcl \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/$@.tcl

# Open ILA dashboard GUI
open_ila:
		${XILINX_VIVADO_ENV} ${XILINX_VIVADO_CMD} -mode gui \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/open_hw_manager.tcl \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/set_ila_trigger.tcl

# Read back from address
OFFSET	?= 0x00000
NUM_BYTES ?= 16

# Load the binary into SoC memory (BRAM for now)
# Call the specific load script based on the SOC_CONFIG (HPC or EMBEDDED)
readback: readback_${SOC_CONFIG}

# Embedded profile
readback_embedded:
	${XILINX_VIVADO_ENV} ${XILINX_VIVADO} \
	-source ${XILINX_SCRIPTS_UTILS_ROOT}/open_hw_manager.tcl \
	-source ${XILINX_SCRIPTS_UTILS_ROOT}/readback_jtag2axi.tcl -tclargs ${OFFSET} ${NUM_BYTES}

# HPC profile
readback_hpc:
	@bash -c "source ${XILINX_SCRIPTS_UTILS_ROOT}/readback_xdma.sh \
		${PCIE_BAR} ${OFFSET} ${NUM_BYTES}"

# Trigger a reset pulse on VIO probes
vio_resetn:
vio_%:
	${XILINX_VIVADO_ENV} ${XILINX_VIVADO} \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/open_hw_manager.tcl \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/vio_reset.tcl -tclargs $@

# Program the bitstream based on the SoC profile
program_bitstream: program_bitstream_${SOC_CONFIG}

# Program bitstream for embedded profile
program_bitstream_embedded:
	${XILINX_VIVADO} \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/open_hw_manager.tcl \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/program_bitstream.tcl

# Program bitstream for HPC profile
program_bitstream_hpc:
#	Kill pending virtual_uart instances (if any)
#	TODO: This might be overkill, as only that one instance should cause problems
	-killall virtual_uart
#	Program
	${XILINX_VIVADO} \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/open_hw_manager.tcl \
		-source ${XILINX_SCRIPTS_UTILS_ROOT}/program_bitstream.tcl
#	Rescan PCIe device
	sudo ${XILINX_SCRIPTS_UTILS_ROOT}/pcie_hot_reset.sh ${PCIE_BDF}

# PHONIES
.PHONY: open_prj open_gui start_hw_server open_hw_manager open_ila program_bitstream program_bitstream_embedded program_bitstream_hpc
