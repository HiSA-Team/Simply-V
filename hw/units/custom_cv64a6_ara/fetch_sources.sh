#!/bin/bash
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description:
#   This script is used to fetch CVA6+Ara sources from pulp-platform repos.

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
RTL_DIR=$(pwd)/rtl
mkdir ${RTL_DIR}

ASSETS_DIR=$(pwd)/assets

##################################
# Fetch sources and depencencies #
##################################

# Clone repo at main @ 03/10/2025
GIT_URL=https://github.com/pulp-platform/ara.git
GIT_BRANCH=main
GIT_COMMIT=a6436df6ad4011c77b5b40e0432acdbf4668639f
CLONE_DIR=ara
printf "${YELLOW}[FETCH_SOURCES] Cloning source repository${NC}\n"
git clone ${GIT_URL} -b ${GIT_BRANCH} ${CLONE_DIR}
cd ${CLONE_DIR};
git checkout ${GIT_COMMIT}

# Download Bender
printf "${YELLOW}[FETCH_SOURCES] Download Bender${NC}\n"
curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh

# Download dependencies (specify Target RTL and FPGA)
printf "${YELLOW}[FETCH_SOURCES] Resolve dependencies with Bender${NC}\n"
./bender checkout
# CVA6_BENDER_TARGET=cv64a6_imafdchsclic_sv39_wb # from cheshire/mp/ara-pulp-v2
CVA6_BENDER_TARGET=cv64a6_imafdcv_sv39 # from MaistoV/cheshire_fork
BENDER_TARGETS="-t xilinx -t bscane -t rtl -t cva6 -t ${CVA6_BENDER_TARGET}"
BENDER_SCRIPT=../bender_vivado.tcl
# ./bender script flist ${BENDER_TARGETS} > rtl.flist
./bender script vivado ${BENDER_TARGETS} > ${BENDER_SCRIPT}

##########
# Config #
##########

# Overwrite configuration file location in bender script
escaped=$(echo "${ASSETS_DIR}" | sed 's/\//\\\//g')
sed -E -i "s/.+${CVA6_BENDER_TARGET}_config_pkg.sv/    ${escaped}\/cv64a6_config_pkg.sv/g" ${BENDER_SCRIPT}

###########
# Patches #
###########
# Remove GPLEN (from H-ext)
TARGET_FILE=$(find . -name intf_typedef.svh)
sed -E -i '/.+logic \[CVA6Cfg\.GPLEN-1:0\] tval2;/s/^/\/\//' ${TARGET_FILE}

############
# Clean up #
############

# Delete the cloned repo and temporary flist
# printf "${YELLOW}[FETCH_SOURCES] Clean all artifacts${NC}\n"
# sudo rm -rf ${CLONE_DIR}
# rm rtl.flist bender
# printf "${GREEN}[FETCH_SOURCES] Completed${NC}\n"
