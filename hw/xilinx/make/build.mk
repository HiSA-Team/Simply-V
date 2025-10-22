# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description: Make target to build Xilinx IPs and bitstream

# Build bitstream from scratch
bitstream: ips
	mkdir -p ${XILINX_PROJECT_REPORTS_DIR}
	cd ${XILINX_PROJECT_BUILD_DIR}; \
	${XILINX_VIVADO} -source ${XILINX_SYNTH_TCL_ROOT}/build_bitstream.tcl

# Generate ips
IP_NAMES ?= $(addprefix ips/, $(addsuffix .xci, ${IP_LIST}))
ips: ${IP_NAMES}

# Common recipe for building IPs
define build_ip
	mkdir -p ${IP_DIR}/build;                                \
	cd	   ${IP_DIR}/build;                                  \
	export IP_DIR=${IP_DIR};                                 \
	export IP_NAME=$(patsubst ips/%.xci,%,$@);               \
	export IP_PRJ_NAME=$${IP_NAME}_prj;                      \
	${XILINX_VIVADO}                                         \
		-source ${XILINX_IPS_ROOT}/common/tcl/pre_config.tcl \
		-source ${IP_DIR}/config.tcl                         \
		-source ${XILINX_IPS_ROOT}/common/tcl/post_config.tcl
	touch $@
endef

# For Xilinx IPs
ips/xlnx_%.xci: IP_DIR=$(firstword $(shell find ${XILINX_IPS_ROOT} -name 'xlnx_$*'))
ips/xlnx_%.xci: ${XILINX_IPS_ROOT}/*/xlnx_%/config.tcl
#	Call common recepie
	$(build_ip)

# For custom IPs, also depend on RTL wrapper
ips/custom_%.xci: IP_DIR=$(firstword $(shell find ${XILINX_IPS_ROOT} -name 'custom_$*'))
ips/custom_%.xci: ${XILINX_IPS_ROOT}/*/custom_%/config.tcl ${HW_UNITS_ROOT}/custom_%/custom_top_wrapper.sv
#	Call common recepie
	$(build_ip)
