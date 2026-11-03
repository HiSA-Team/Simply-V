# Description: Make target for simulation
# SoC simulation (make sim BACKEND=verilator|xsim TEST=<example>): see hw/xilinx/sim/README.md

XILINX_SIM_ROOT      := ${XILINX_ROOT}/sim
XILINX_SIM_BUILD_DIR := ${XILINX_SIM_ROOT}/build

sim_compile_simlib:
	${XILINX_VIVADO_BATCH} -source ${XILINX_SIM_TCL_ROOT}/compile_simlib.tcl

sim_export_%: ${XILINX_IPS_ROOT}/%/questa/compile.do
${XILINX_IPS_ROOT}/%/questa/compile.do: ${XILINX_SIM_IP_ROOT}
	cd ${XILINX_SIMLIB_PATH}; \
	VIVADO_PROJECT=${XILINX_IPS_ROOT}/$*/build/$*.xpr \
	${XILINX_VIVADO_BATCH} -source ${XILINX_SIM_TCL_ROOT}/export_simulation.tcl

${XILINX_SIM_IP_ROOT}/ips:
	mkdir -p $@

#######################
# Embedded SoC: setup #
#######################

BACKEND ?= verilator
TEST    ?= hello_world
# Core override for one run (e.g. CI): CORE=ibex|cv32e40p|picorv32|cv64a6|cv64a6_ara
CORE    ?=
CORE_SELECTOR_ibex       := CORE_IBEX
CORE_SELECTOR_cv32e40p   := CORE_CV32E40P
CORE_SELECTOR_picorv32   := CORE_PICORV32
CORE_SELECTOR_cv64a6     := CORE_CV64A6
CORE_SELECTOR_cv64a6_ara := CORE_CV64A6_ARA
PYTHON ?= python3

# Xilinx IPs of the DUT: the embedded xlnx_* without the ones the VERIFICATION seam removes
# (JTAG2AXI, VIO, clk_wiz), the clock converters (single clock in simulation), the 64-to-32
# dwidth converter (hand-written model) and the IPs of the MicroBlaze-V cores, which are not
# simulated (the cores, their debug modules and the AXI-Lite to AXI4 converter in rv_socket)
SIM_IP_LIST := $(filter-out xlnx_jtag_axi xlnx_vio xlnx_clk_wiz xlnx_axi_d%_clock_converter \
	xlnx_axi_dwidth_64_to_32_converter xlnx_axilite_to_axi4_d32_converter xlnx_microblazev_rv% \
	xlnx_microblaze_debug_module_v xlnx_dual_microblaze_debug_module_v, \
	$(filter xlnx_%,${IP_LIST}))

# Two makes: the first regenerates the config from the CSVs with the simulation overlay, the
# second re-reads config.mk. The tracked files the regen rewrites are saved before and
# restored at the end, also on INT/TERM/HUP; a backup left by a killed run is restored first.
# ips/<ip>.tcl holds the config.tcl the IP was built from: sim_ip_sync aligns the config.tcl
# mtime to the stamp, so an IP is rebuilt only if its config changed (also when switching
# sim/FPGA). The copy is trusted only if not older than the stamp, which a build that does
# not write it (e.g. an older branch) touches.
SIM_CFG_FILES  := hw/xilinx/make/config.mk sw/SoC/common/config.mk sw/SoC/lib/simplyv/inc/simplyv_conf.h \
	$(patsubst ${SIMPLYV_ROOT_DIR}/%,%,$(wildcard ${SIMPLYV_ROOT_DIR}/sw/SoC/common/ld/*.ld \
	${XILINX_ROOT}/rtl/generated/*/*.svinc ${XILINX_IPS_ROOT}/*/*/config.tcl))
SIM_CFG_BACKUP := ${XILINX_SIM_BUILD_DIR}/config_backup.tar
SIM_LOCK       := ${XILINX_SIM_BUILD_DIR}/sim.lock
MAX_VIVADO_INSTANCES ?= 4
sim_ip_sync = for c in ${XILINX_IPS_ROOT}/*/xlnx_*/config.tcl; do \
	s=${XILINX_ROOT}/ips/$$(basename $$(dirname $$c)).xci; t=$${s%.xci}.tcl; \
	[ -f $$s ] && [ -f $$t ] || continue; \
	if ! [ $$s -nt $$t ] && cmp -s $$c $$t; then touch -r $$s $$c; else touch $$c; fi; done
sim:
	@[ -f ${TEST_GOLDEN} ] || { echo "[sim] unknown TEST=${TEST}: no ${TEST_GOLDEN}"; exit 1; }
	mkdir -p ${XILINX_SIM_BUILD_DIR}
	exec 9>${SIM_LOCK}; \
	flock -n 9 || { echo "[sim] another sim is running in this checkout"; exit 1; }; \
	restore() { tar -C ${SIMPLYV_ROOT_DIR} -xf ${SIM_CFG_BACKUP} && rm -f ${SIM_CFG_BACKUP} && ${sim_ip_sync}; }; \
	if [ -f ${SIM_CFG_BACKUP} ]; then \
		echo "[sim] restoring the config saved by an interrupted run"; restore || exit 1; fi; \
	tar -C ${SIMPLYV_ROOT_DIR} -cf ${SIM_CFG_BACKUP}.tmp ${SIM_CFG_FILES} || exit 1; \
	mv ${SIM_CFG_BACKUP}.tmp ${SIM_CFG_BACKUP}; \
	trap restore EXIT; trap 'exit 130' INT; trap 'exit 143' TERM; trap 'exit 129' HUP; \
	${MAKE} sim_config_regen && ${sim_ip_sync} && \
	${MAKE} -j ${MAX_VIVADO_INSTANCES} ips IP_LIST="${SIM_IP_LIST}" && ${MAKE} sim_${BACKEND}

# Simulation overlay on the user CSVs: every MBUS slave on the main clock (one clock in
# simulation, no PBUS clock converter), plus the CORE= and XBAR_IMPL= overrides
SIM_SYSTEM_CSV := ${XILINX_SIM_BUILD_DIR}/config_system.csv
comma := ,
SIM_MBUS_CSV   := ${XILINX_SIM_BUILD_DIR}/config_mbus.csv
# The uartlite runs at SIM_UART_BAUD, the highest baud rate within the 3% error the IP accepts
# at 20 MHz: the simulation length is bound by the characters the firmware prints
SIM_UART_TCL   := ${XILINX_IPS_ROOT}/embedded/xlnx_axi_uartlite/config.tcl
SIM_UART_BAUD  ?= 128000
sim_config_regen:
	sed -e '$(if ${CORE},s/^CORE_SELECTOR.*/CORE_SELECTOR$(comma)${CORE_SELECTOR_${CORE}}/)' \
		-e '$(if $(filter command line,$(origin XBAR_IMPL)),s/^XBAR_IMPL.*/XBAR_IMPL$(comma)${XBAR_IMPL}/)' \
		${CONFIG_ROOT}/configs/common/config_system.csv > ${SIM_SYSTEM_CSV}
	sed "/^RANGE_CLOCK_DOMAINS/s/MBUS_[0-9]*/$$(sed -n 's/^MAIN_CLOCK_DOMAIN, *//p' ${SIM_SYSTEM_CSV})/g" \
		${CONFIG_ROOT}/configs/${SIMPLYV_PROFILE}/config_mbus.csv > ${SIM_MBUS_CSV}
	${MAKE} -C ${CONFIG_ROOT} config_mbus config_pbus config_sw config_xilinx config_sim PYTHON=${PYTHON} \
		INPUT_SYSTEM_CSV=${SIM_SYSTEM_CSV} INPUT_MBUS_CSV=${SIM_MBUS_CSV} SIM_IPS="${SIM_IP_LIST}"
	sed -i 's/C_BAUDRATE {[0-9]*}/C_BAUDRATE {${SIM_UART_BAUD}}/' ${SIM_UART_TCL}

# Patched unisims for Verilator: the `=== 1'bz` input checks become constants
SIM_UNISIMS_DIR := ${XILINX_SIM_BUILD_DIR}/unisims
${SIM_UNISIMS_DIR}:
	mkdir -p $@
	for f in ${XSIM_ROOT}/data/verilog/src/unisims/*.v ${XSIM_ROOT}/data/verilog/src/retarget/*.v; do \
		sed -E -e "s/\b[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])? *=== *1'bz/1'b0/g" \
			-e "s/\b[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])? *!== *1'bz/1'b1/g" $$f > $@/$$(basename $$f); \
	done

# Program and golden of TEST: sw/SoC/examples/<TEST>, stimuli/golden/<TEST>.uart.golden and the
# optional UART input stimuli/<TEST>.in. Shorter timer periods and one CDMA round in simulation.
TEST_PROG_DIR := ${SIMPLYV_ROOT_DIR}/sw/SoC/examples/${TEST}
TEST_BIN      := ${TEST_PROG_DIR}/bin/${TEST}.bin
TEST_GOLDEN   := ${XILINX_SIM_ROOT}/stimuli/golden/${TEST}.uart.golden
TEST_STIM     := $(wildcard ${XILINX_SIM_ROOT}/stimuli/${TEST}.in)
TEST_EXTRA_MACROS_interrupts         := -DTIM0_COUNT_US=500u -DSLEEP_US=200u
TEST_EXTRA_MACROS_xlnx_cdma_examples := -DNUM_ROUNDS=1u
# Rebuilt on every run, libs included, for the core of this run
${TEST_BIN}: FORCE
	for d in ${TEST_PROG_DIR} ${SIMPLYV_ROOT_DIR}/sw/SoC/lib/tinyio ${SIMPLYV_ROOT_DIR}/sw/SoC/lib/simplyv; do \
		${MAKE} -C $$d clean; done
	${MAKE} -C ${SIMPLYV_ROOT_DIR}/sw/SoC/lib/tinyio
	${MAKE} -C ${SIMPLYV_ROOT_DIR}/sw/SoC/lib/simplyv
	${MAKE} -C ${TEST_PROG_DIR} bin/${TEST}.bin PROGRAM_NAME=${TEST} EXTRA_MACROS="${TEST_EXTRA_MACROS_${TEST}}"
FORCE:

# Uartlite bit period in ticks of its clock, from its config.tcl: 16x oversampling with the
# divider rounded as the IP does (CALC_RATIO). Expanded only by the sim recipes
SIM_UART_CFG = $(shell sed -n 's/.*CONFIG.$(1) {\([0-9]*\)}.*/\1/p' ${SIM_UART_TCL})
SIM_UART_FREQ = $(call SIM_UART_CFG,C_S_AXI_ACLK_FREQ_HZ)
SIM_UART_RATE = $(call SIM_UART_CFG,C_BAUDRATE)
SIM_UART_CYCLES_PER_BIT = $(shell echo $$(( 16 * ((${SIM_UART_FREQ} + 8 * ${SIM_UART_RATE} - 1) / (16 * ${SIM_UART_RATE})) )))
# Cycle cap of a run after the load, which ends as soon as the golden is matched: 32000 bit
# periods, twice the longest test (xlnx_cdma_examples, UART bound: 10 bit periods per character)
SIM_MAX_CYCLES ?= $(shell echo $$(( 32000 * ${SIM_UART_CYCLES_PER_BIT} )))

SIM_FLIST   := ${XILINX_SIM_ROOT}/generated/simplyv.f
SIM_DEFINES := EMBEDDED=1 VERIFICATION ASSERTS_OFF XBAR_IMPL=XBAR_${XBAR_IMPL} PBUS_ID_WIDTH=${MBUS_ID_WIDTH} \
	$(foreach v,MBUS_DATA_WIDTH MBUS_ADDR_WIDTH MBUS_ID_WIDTH MBUS_NUM_SI MBUS_NUM_MI PBUS_NUM_SI PBUS_NUM_MI \
	HBUS_NUM_SI HBUS_NUM_MI HBUS_ID_WIDTH CORE_SELECTOR MAIN_CLOCK_FREQ_MHZ,$(v)=${$(v)}) \
	$(foreach d,${RANGE_CLOCK_DOMAINS},$(d)=$(d))
# BRAM behavioural models read their .mif from the working directory
SIM_MIFS    := $(foreach b,0 1,${XILINX_IPS_ROOT}/common/xlnx_bram_$(b)/build/xlnx_bram_$(b)_prj.gen/sources_1/ip/xlnx_bram_$(b)/xlnx_bram_$(b).mif)

###########################
# Embedded SoC: Verilator #
###########################

# One build per core and crossbar; the netlists need glbl, the patched unisims and, first
# in the search path, the simplified LUT/FF primitives
VL_DIR     := ${XILINX_SIM_BUILD_DIR}/verilator/${CORE_SELECTOR}_${XBAR_IMPL}
# Evaluation threads: one is the fastest on the 32-bit cores
VL_THREADS ?= 1
sim_verilator: ${TEST_BIN} ${SIM_UNISIMS_DIR}
	mkdir -p ${VL_DIR}
	verilator --cc --exe --build -j 0 -O3 --no-timing --threads ${VL_THREADS} -Mdir ${VL_DIR} \
		-Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-REDEFMACRO -Wno-TIMESCALEMOD -Wno-MODDUP \
		-Wno-IEEEMAYDEPRECATE -Wno-SPECIFYIGN -Wno-STMTDLY -Wno-COMBDLY -Wno-UNOPTFLAT \
		$(addprefix +define+,${SIM_DEFINES}) --top-module simplyv_sim_wrapper -f ${SIM_FLIST} \
		${XSIM_ROOT}/data/verilog/src/glbl.v ${XSIM_ROOT}/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv \
		-y ${XILINX_SIM_ROOT}/verilator/prims -y ${SIM_UNISIMS_DIR} \
		${XILINX_SIM_ROOT}/verilator/tb/simplyv/simplyv_tb.cpp -CFLAGS "-I${XILINX_SIM_ROOT}/verilator/vip \
		-DSIM_UART_CYCLES_PER_BIT=${SIM_UART_CYCLES_PER_BIT} -DSIM_MAX_CYCLES=${SIM_MAX_CYCLES}L"
	cp ${SIM_MIFS} ${VL_DIR}
	cd ${VL_DIR} && ./Vsimplyv_sim_wrapper +BIN=${TEST_BIN} $(addprefix +STIMULUS=,${TEST_STIM}) ${TEST_GOLDEN}

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
.PHONY: sim_compile_simlib sim_xsim_xbar sim sim_config_regen sim_verilator FORCE
