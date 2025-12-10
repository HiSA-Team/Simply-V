#!/bin/bash
# Author: Vincenzo Merola <vincenzo.merola2@unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description:
#   Rebuild HLS sources to Verilog  and copy in rtl/ dir.
#   Package C standalone drivers and copy to UninaSoC software dir

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###################
# Local variables #
###################
TOP_DIR=$PWD

# This script dir
WORK_DIR=$( dirname $( realpath -se ${BASH_SOURCE[0]} ) )
cd $WORK_DIR
# Get the first dir in this path
HLS_DIR=$(realpath $(find ./ -maxdepth 1 -mindepth 1 -type d))
COMPONENT_NAME=$(basename ${HLS_DIR})

# Clean old sources
RTL_DIR=$(realpath $WORK_DIR/../rtl)
printf "\n${YELLOW}[REBUILD_HLS] Cleaning old RTL from ${RTL_DIR} ${NC}\n"
rm -rf $(ls -A ${RTL_DIR})
mkdir -p ${RTL_DIR}

# Move into HLS project
cd ${HLS_DIR}/hw

# Synthesizing and copying verilog rtl files
printf "\n${YELLOW}[REBUILD_HLS] Starting c-synthesis for HLS sources${NC}\n"
make clean
make syn
printf "\n${YELLOW}[REBUILD_HLS] Copying all sources into rtl${NC}\n"
cp ${HLS_DIR}/hw/${COMPONENT_NAME}/hls/syn/verilog/* ${RTL_DIR}/

# Packaging for the C driver files
# NOTE: requires Vitis HLS 2024
CUSTOM_IP_NAME=$(basename $(realpath $WORK_DIR/..))
printf "\n${YELLOW}[FETCH_SOURCES] Packaging for C standalone driver files${NC}\n"
make package

# Back to top
cd ${TOP_DIR}
unset TOP_DIR
