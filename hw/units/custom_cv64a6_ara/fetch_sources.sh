#!/bin/bash
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description:
#   This script is used to fetch CVA6+Ara sources from pulp-platform repos.

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
THIS_DIR=$(pwd)
ASSETS_DIR=${THIS_DIR}/assets
RTL_DIR=${THIS_DIR}/rtl

##################################
# Fetch sources and depencencies #
##################################

# Clone repo at main
GIT_URL=https://github.com/pulp-platform/ara.git
GIT_BRANCH=main
# 28/11/2025
GIT_COMMIT=e970f7736cde544eb2a44c6a44ad7eb0f8789f1a
CLONE_DIR=${THIS_DIR}/ara
printf "${YELLOW}[FETCH_SOURCES] Cloning source repository${NC}\n"
git clone ${GIT_URL} -b ${GIT_BRANCH} ${CLONE_DIR}
cd ${CLONE_DIR};
git checkout ${GIT_COMMIT}

# Download Bender
printf "${YELLOW}[FETCH_SOURCES] Download Bender${NC}\n"
# Version from Ara repo
BENDER_VERSION=0.27.3
curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh	-s -- ${BENDER_VERSION}

# Download dependencies (specify Target RTL and FPGA)
printf "${YELLOW}[FETCH_SOURCES] Resolve dependencies with Bender${NC}\n"
./bender checkout
# CVA6_BENDER_TARGET=cv64a6_imafdchsclic_sv39_wb # from cheshire/mp/ara-pulp-v2
CVA6_BENDER_TARGET=cv64a6_imafdcv_sv39 # from MaistoV/cheshire_fork
BENDER_TARGETS="-t xilinx -t bscane -t cva6 -t ${CVA6_BENDER_TARGET}"
BENDER_RTL_LIST=../rtl.flist
./bender script flist ${BENDER_TARGETS} > ${BENDER_RTL_LIST}
BENDER_DEFINES=../bender_vivado_defines.tcl
./bender script vivado ${BENDER_TARGETS} --only-defines > ${BENDER_DEFINES}
# Export to absolute paths
BENDER_RTL_LIST=$(realpath ${BENDER_RTL_LIST})
BENDER_DEFINES=$(realpath ${BENDER_DEFINES})

###########
# Patches #
###########

printf "${YELLOW}[FETCH_SOURCES] Patching Bender-generated file list${NC}\n"

# Remove include directives
sed -i "/+incdir+/d" ${BENDER_RTL_LIST}
# Remove unsupported AXI interface file
# - Vivado does not support SystemVerilog interfaces during IP packaging
sed -i -E '/.+axi_intf\.sv/d' ${BENDER_RTL_LIST}
# Remove decoder stub
# - Vivado picks this one instead of Ara's
sed -i -E '/.+cva6_accel_first_pass_decoder_stub\.sv/d' ${BENDER_RTL_LIST}
# Remove unused integration files
sed -i '/ara_system\.sv/d' ${BENDER_RTL_LIST}
sed -i '/ara_soc\.sv/d' ${BENDER_RTL_LIST}
# Remove unused apb modules
sed -i -E '/.+apb.*\.sv/d' ${BENDER_RTL_LIST}

# Remove silly constraint on FPGA support by PULP
# This is necessary to use FpgaEn=1 in CVA6 configuration
# Remove error-triggering file
sed -i "/fpga-support-stubs.sv/d" ${BENDER_RTL_LIST}
# Include FPGA-support files
FPGA_SUPPORT_RTL=${CLONE_DIR}/hardware/deps/cva6/vendor/pulp-platform/fpga-support/rtl/
fpga_files=($(ls ${FPGA_SUPPORT_RTL} ))
for fpga_file in "${fpga_files[@]}"; do
    echo ${FPGA_SUPPORT_RTL}/$fpga_file >> ${BENDER_RTL_LIST}
done

# Overwrite configuration file location in bender script
escaped=$(echo "${ASSETS_DIR}" | sed 's/\//\\\//g')
# sed -E -i "s/.+${CVA6_BENDER_TARGET}_config_pkg.sv/    ${escaped}\/cv64a6_config_pkg.sv/g" ${BENDER_SCRIPT}
sed -E -i "s/.+${CVA6_BENDER_TARGET}_config_pkg.sv/${escaped}\/cv64a6_config_pkg.sv/g" ${BENDER_RTL_LIST}

# Work around bender bug for Vivado filelist
# Replace tech cells with Xilinx versions
FPGA_SRC_DIR=${CLONE_DIR}/hardware/deps/tech_cells_generic/src/fpga
sed -i "s|.*/tech_cells_generic/src/rtl/tc_sram\.sv|${FPGA_SRC_DIR}/tc_sram_xilinx.sv|" ${BENDER_RTL_LIST}
sed -i "s|.*/tech_cells_generic/src/rtl/tc_clk\.sv|${FPGA_SRC_DIR}/tc_clk_xilinx.sv|" ${BENDER_RTL_LIST}
sed -i "s|.*/tech_cells_generic/src/deprecated/pad_functional\.sv|${FPGA_SRC_DIR}/pad_functional_xilinx.sv|" ${BENDER_RTL_LIST}

########################
# Copy-in target files #
########################

# Create RTL dir
mkdir -p ${RTL_DIR}

# List of target headers
mapfile -t headers < ${ASSETS_DIR}/headers.flist
# Replace ${DIR} placeholder with ${CLONE_DIR} in each element
for i in "${!headers[@]}"; do headers[$i]="${headers[$i]//\$\{DIR\}/${CLONE_DIR}}"; done

# Copy into new dir
printf "${YELLOW}[FETCH_SOURCES] Copy headers into RTL dir ${RTL_DIR}${NC}\n"
cp ${headers[*]} ${RTL_DIR}/

# Copy all files from bender flist
printf "${YELLOW}[FETCH_SOURCES] Copy sources into RTL dir ${RTL_DIR}${NC}\n"
cp $(cat ${BENDER_RTL_LIST}) ${RTL_DIR}

# Loop through all files in the rtl directory
echo -e "${YELLOW}[PATCH_SOURCES] Patching include paths for flat includes without specific substitutions${NC}"
for rtl_file in ${RTL_DIR}/*; do
    if [[ -f $rtl_file ]]; then
        # Flatten all includes
        sed -i 's#`include "[^/]*/\([^"]*\.svh\)"#`include "\1"#g' $rtl_file
    fi
done

########
# Exit #
########
# Info print
printf "${GREEN}[FETCH_SOURCES] Completed${NC}\n"
