# Description: Make target for simulation
# TODO: The simulation flow is not yet supported, this file is just a placeholder

sim_compile_simlib:
	${XILINX_VIVADO_BATCH} -source ${XILINX_SIM_TCL_ROOT}/compile_simlib.tcl

sim_export_%: ${XILINX_IPS_ROOT}/%/questa/compile.do
${XILINX_IPS_ROOT}/%/questa/compile.do: ${XILINX_SIM_IP_ROOT}
	cd ${XILINX_SIMLIB_PATH}; \
	VIVADO_PROJECT=${XILINX_IPS_ROOT}/$*/build/$*.xpr \
	${XILINX_VIVADO_BATCH} -source ${XILINX_SIM_TCL_ROOT}/export_simulation.tcl

${XILINX_SIM_IP_ROOT}/ips:
	mkdir -p $@

# Crossbar benches on xsim with the Xilinx AXI VIP, one directory per crossbar IP:
# sim_xsim_<bus>_xbar runs xsim/tb/<bus>_xbar/ in build/xsim/<bus>_xbar/ on the crossbar of the
# generated <bus>_crossbar.svinc, for XBAR_IMPL (e.g. make sim_xsim_xbar XBAR_IMPL=CUSTOM).
# The crossbar IP is rebuilt first if its config changed.
XSIM_BUILD_DIR := ${XILINX_ROOT}/sim/build/xsim
# environment.mk redefines XILINX_VIVADO, which the xsim tools read: restore it
XSIM_ROOT      := $(abspath $(dir $(shell which xsim))/..)
XSIM_ENV       := XILINX_VIVADO=${XSIM_ROOT}
# axi_vip_v1_1_19: AXI VIP library and module of Vivado 2024.2, also named in the benches
XSIM_LIBS      := -L xilinx_vip -L axi_vip_v1_1_19 -L unisims_ver
XSIM_DEFINES   := -d XBAR_IMPL=XBAR_${XBAR_IMPL} -d PBUS_ID_WIDTH=${MBUS_ID_WIDTH} \
	$(foreach v,MBUS_DATA_WIDTH MBUS_ADDR_WIDTH MBUS_ID_WIDTH MBUS_NUM_SI MBUS_NUM_MI PBUS_NUM_SI \
	PBUS_NUM_MI HBUS_NUM_SI HBUS_NUM_MI HBUS_ID_WIDTH CORE_SELECTOR,-d $(v)=${$(v)})
XSIM_XBAR_SRCS := ${XILINX_ROOT}/rtl/simplyv_pkg.sv ${XILINX_ROOT}/rtl/simplyv_axi_err_slv.sv \
	${XILINX_ROOT}/rtl/simplyv_axi_xbar.sv ${XILINX_ROOT}/rtl/simplyv_axilite_xbar.sv \
	${XSIM_ROOT}/data/verilog/src/glbl.v

sim_xsim_xbar: sim_xsim_mbus_xbar sim_xsim_pbus_xbar
sim_xsim_%_xbar: ips/xlnx_%_crossbar.xci
	mkdir -p ${XSIM_BUILD_DIR}/$*_xbar
	cd ${XSIM_BUILD_DIR}/$*_xbar && ${XSIM_ENV} xvlog -sv ${XSIM_LIBS} ${XSIM_DEFINES} \
		-i ${XILINX_ROOT}/rtl -i ${XILINX_ROOT}/rtl/headers ${XSIM_XBAR_SRCS} \
		${XILINX_IPS_ROOT}/common/xlnx_$*_crossbar/build/xlnx_$*_crossbar_prj.gen/sources_1/ip/xlnx_$*_crossbar/xlnx_$*_crossbar_sim_netlist.v \
		${XILINX_ROOT}/sim/xsim/tb/$*_xbar/$*_xbar_tb.sv
	cd ${XSIM_BUILD_DIR}/$*_xbar && ${XSIM_ENV} xelab ${XSIM_LIBS} -timescale 1ns/1ps -s $*_xbar $*_xbar_tb glbl
	cd ${XSIM_BUILD_DIR}/$*_xbar && ${XSIM_ENV} xsim $*_xbar -R --log $*_xbar.log
	grep -q 'XBAR\] .* PASS' ${XSIM_BUILD_DIR}/$*_xbar/$*_xbar.log && ! grep -qE 'ERROR|Error|Fatal|FATAL' ${XSIM_BUILD_DIR}/$*_xbar/$*_xbar.log

# PHONIES
.PHONY: sim_compile_simlib sim_xsim_xbar
