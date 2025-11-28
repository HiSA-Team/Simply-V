#!/bin/bash
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description:
#   This script downloads axi_to_mem from https://github.com/pulp-platform/axi/ sources and flattens them into the rtl directory

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create rtl dir
RTL_DIR=rtl
mkdir ${RTL_DIR}

# clone repo
GIT_URL=https://github.com/pulp-platform/axi.git
GIT_TAG=v0.39.6
CLONE_DIR=axi
printf "${YELLOW}[FETCH_SOURCES] Cloning source repository at ${GIT_TAG} ${NC}\n"
git clone ${GIT_URL} -b ${GIT_TAG} --depth 1 ${CLONE_DIR}
cd ${CLONE_DIR};

# Clone Bender
printf "${YELLOW}[FETCH_SOURCES] Download Bender${NC}\n"
curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh

# Download dependencies (specify Target RTL and FPGA)
printf "${YELLOW}[FETCH_SOURCES] Resolve dependencies with Bender${NC}\n"
./bender checkout
BENDER_TARGETS="-t xilinx -t fpga"
./bender script flist ${BENDER_TARGETS} > ../rtl.flist
cd ..

# Copy all RTL files into rtl dir
printf "${YELLOW}[FETCH_SOURCES] Copy all sources into ${RTL_DIR}/${NC}\n" s
for rtl_file in $(cat rtl.flist) ; do
    cp $rtl_file ${RTL_DIR}
done;

# Add header files, not listed by bender
cp $(find ${CLONE_DIR} -name typedef.svh) ${RTL_DIR}/
cp $(find ${CLONE_DIR} -name assertions.svh) ${RTL_DIR}/
cp $(find ${CLONE_DIR} -name registers.svh) ${RTL_DIR}/
cp $(find ${CLONE_DIR} -name assign.svh) ${RTL_DIR}/

# Remove interface-based files, since Vivado does not like them
rm $(find ${RTL_DIR}/ -name axi_intf.sv)

# Patch files for flat includes
for rtl_file in ${RTL_DIR}/* ; do
    sed -i "s|\`include \"common_cells\/|\`include \"|g" $rtl_file
    sed -i "s|\`include \"axi\/|\`include \"|g" $rtl_file
done

# Info
printf "${GREEN}[FETCH_SOURCES] Completed${NC}\n"