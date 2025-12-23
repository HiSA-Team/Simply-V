# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description:
#    Hold all the environment variables for Xilinx tools and PCIe offsets.

# Basic variables for Vivado
XILINX_VIVADO_CMD ?= vivado
XILINX_VIVADO_MODE ?= batch
# Build directory
XILINX_PROJECT_BUILD_DIR ?= ${XILINX_ROOT}/build
# Vivado's compilation reports directory
XILINX_PROJECT_REPORTS_DIR ?= ${XILINX_PROJECT_BUILD_DIR}/reports
# Hardware server
XILINX_HW_SERVER ?= hw_server

##############
# Vivado IPs #
##############

# List of IP basenames to build and import in the design
# $(1): The directory path in which to search for subdirectories
define find_ip_dirs
$(shell find $(1) -maxdepth 1 -type d -regextype posix-extended -regex ".*/(xlnx_.*|custom_.*)" -exec basename {} \;)
endef
# Parsing from directory ips/ matching paths (common|hpc|embedded) and prefix (xlnx_*|custom_*)
# List of the Xilinx IPs
COMMON_IP_LIST   = $(call find_ip_dirs, ${XILINX_IPS_ROOT}/common  )
HPC_IP_LIST      = $(call find_ip_dirs, ${XILINX_IPS_ROOT}/hpc     )
EMBEDDED_IP_LIST = $(call find_ip_dirs, ${XILINX_IPS_ROOT}/embedded)

# Concatenate/create the full IP lists
# Profile-independent IP lists
IP_LIST     = ${COMMON_IP_LIST}
# Selecting profile: HPC or EMBEDDED
ifeq (${SOC_CONFIG}, hpc)
#   Append HPC IPs
    IP_LIST += ${HPC_IP_LIST}
else ifeq (${SOC_CONFIG}, embedded)
#   Append embedded IPs
    IP_LIST += ${EMBEDDED_IP_LIST}
else
$(error "Unsupported config ${SOC_CONFIG}")
endif

# Remove Microblaze-V and Microblaze Debug Module V when building with Vivado < 2024
# TODO55: quick workaround for PR 146, extend this for all selectable IPs
ifeq ($(shell [ ${XILINX_VIVADO_VERSION} -lt 2024 ] && echo true),true)
    FILTER_IP    = xlnx_microblazev_rv32 xlnx_microblazev_rv64 xlnx_microblaze_debug_module_v xlnx_dual_microblaze_debug_module_v
    TMP_IP_LIST  = ${IP_LIST}
    IP_LIST      = $(filter-out ${FILTER_IP},${TMP_IP_LIST})
endif

# List of IPs' xci files to import in main Vivado project
IP_LIST_XCI = $(foreach ip,${IP_LIST},$(shell find ${XILINX_IPS_ROOT} -type f -path "*/${ip}/build/${ip}_prj.srcs/sources_1/ip/${ip}/${ip}.xci"))

#########################
# Vivado run strategies #
#########################
# Vivado defaults
# SYNTH_STRATEGY    ?= "Vivado Synthesis Defaults"
# IMPL_STRATEGY     ?= "Vivado Implementation Defaults"
# Runtime optimized  (shorter runtime)
# SYNTH_STRATEGY    ?= Flow_RuntimeOptimized
# IMPL_STRATEGY     ?= Flow_RuntimeOptimized
# High-performace (longer runtime)
SYNTH_STRATEGY     ?= "Flow_PerfOptimized_high"
IMPL_STRATEGY      ?= "Performance_ExtraTimingOpt"

# Implementation artifacts
XILINX_BITSTREAM ?= ${XILINX_PROJECT_BUILD_DIR}/${XILINX_PROJECT_NAME}.runs/impl_1/${XILINX_PROJECT_NAME}.bit
XILINX_PROBE_LTX ?= ${XILINX_PROJECT_BUILD_DIR}/${XILINX_PROJECT_NAME}.runs/impl_1/${XILINX_PROJECT_NAME}.ltx

# Wheter to build for development or deployment (0|1)
# NOTE: Not reccomended to use with XILINX_ILA = 1
HIGH_PERF_BUILD ?= 0
# Routing directive, only used with HIGH_PERF_BUILD = 1
HIGH_PERF_ROUTING ?= HigherDelayCost
# Whether to use ILA probes (0|1)
XILINX_ILA ?= 0
# Clock net for ILA probes: use main clock by default
XILINX_ILA_CLOCK ?= main_clk

# Full environment variables list for Vivado
XILINX_VIVADO_ENV =                                 \
    MBUS_DATA_WIDTH=${MBUS_DATA_WIDTH}              \
    MBUS_ADDR_WIDTH=${MBUS_ADDR_WIDTH}              \
    CORE_SELECTOR=${CORE_SELECTOR}                  \
    VIO_RESETN_DEFAULT=${VIO_RESETN_DEFAULT}        \
    MBUS_NUM_SI=${MBUS_NUM_SI}                      \
    MBUS_NUM_MI=${MBUS_NUM_MI}                      \
    MBUS_ID_WIDTH=${MBUS_ID_WIDTH}                  \
    MAIN_CLOCK_FREQ_MHZ=${MAIN_CLOCK_FREQ_MHZ}      \
    RANGE_CLOCK_DOMAINS="${RANGE_CLOCK_DOMAINS}"    \
    PBUS_NUM_MI=${PBUS_NUM_MI}                      \
    PBUS_ID_WIDTH=${PBUS_ID_WIDTH}                  \
    HBUS_NUM_MI=${HBUS_NUM_MI}                      \
    HBUS_NUM_SI=${HBUS_NUM_SI}                      \
    HBUS_ID_WIDTH=${HBUS_ID_WIDTH}                  \
    HIGH_PERF_BUILD=${HIGH_PERF_BUILD}              \
    HIGH_PERF_ROUTING=${HIGH_PERF_ROUTING}          \
    XILINX_ILA=${XILINX_ILA}                        \
    XILINX_ILA_CLOCK=${XILINX_ILA_CLOCK}            \
    SYNTH_STRATEGY=${SYNTH_STRATEGY}                \
    IMPL_STRATEGY=${IMPL_STRATEGY}                  \
    XILINX_PART_NUMBER=${XILINX_PART_NUMBER}        \
    XILINX_PROJECT_NAME=${XILINX_PROJECT_NAME}      \
    SOC_CONFIG=${SOC_CONFIG}                        \
    XILINX_BOARD_PART=${XILINX_BOARD_PART}          \
    XILINX_HW_SERVER_HOST=${XILINX_HW_SERVER_HOST}  \
    XILINX_HW_SERVER_PORT=${XILINX_HW_SERVER_PORT}  \
    XILINX_FPGA_DEVICE=${XILINX_FPGA_DEVICE}        \
    XILINX_BITSTREAM=${XILINX_BITSTREAM}            \
    XILINX_PROBE_LTX=${XILINX_PROBE_LTX}            \
    IP_LIST_XCI="${IP_LIST_XCI}"                    \
    XILINX_ROOT=${XILINX_ROOT}                      \
    QUESTA_PATH=${QUESTA_PATH}                      \
    GCC_PATH=${GCC_PATH}                            \
    XILINX_SIMLIB_PATH=${XILINX_SIMLIB_PATH}

# Package Vivado command in a single variable
XILINX_VIVADO = ${XILINX_VIVADO_ENV} ${XILINX_VIVADO_CMD} -mode ${XILINX_VIVADO_MODE}
XILINX_VIVADO_BATCH = ${XILINX_VIVADO_ENV} ${XILINX_VIVADO_CMD} -mode batch

# PCIe device and address
PCIE_BDF ?= 01:00.0 # TODO: remove this and find the PCIE_BDF automatically
PCIE_BAR ?= 0x$(shell lspci -vv -s ${PCIE_BDF} | grep Region | awk '{print $$5}')
