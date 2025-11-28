#!/bin/bash
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
# This script downloads cv32e40p cv32e40p_v1.8.3 sources and flattens them into the rtl directory

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create rtl dir
mkdir rtl

# clone repo (Release v1.8.3 Jul 15 2024)
GIT_URL=https://github.com/openhwgroup/cv32e40p.git
GIT_TAG=cv32e40p_v1.8.3
CLONE_DIR=cv32e40p
printf "${YELLOW}[FETCH_SOURCES] Cloning source repository${NC}\n"
git clone ${GIT_URL} -b ${GIT_TAG} --depth 1 ${CLONE_DIR}
cd ${CLONE_DIR};

# Clone Bender
printf "${YELLOW}[FETCH_SOURCES] Download Bender${NC}\n"
curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh

# Download dependencies (specify Target RTL and FPGA)
printf "${YELLOW}[FETCH_SOURCES] Resolve dependencies with Bender${NC}\n"
# Inject pre-solved conflicts
# - package `riscv` requires `^0.1.1`
# - package `common_cells` requires `^0.2.11`
cp ../assets/cv32e40_Bender.lock Bender.lock
# Checkout
./bender checkout
BENDER_TARGETS="-t xilinx -t fpga"
./bender script flist ${BENDER_TARGETS} > rtl.flist
./bender script flist > rtl.flist
cp cv32e40p_fpu_manifest.flist ../local.flist

# Process remote.flist (just save the .bender files)
printf "${YELLOW}[FETCH_SOURCES] Create final rtl file list${NC}\n"
grep .bender ../remote.flist > ../rtl.flist

# Process local.flist
cd rtl;
DIR=$(pwd)
cd ../..;
grep -v '^/' local.flist > local_tmp.flist
grep -v '^+' local_tmp.flist > local_tmp_2.flist
sed 's/${DESIGN_RTL_DIR}/DESIGN_RTL_DIR/g' local_tmp_2.flist > local_tmp_3.flist
sed -i "s|DESIGN_RTL_DIR|$DIR|" local_tmp_3.flist
cat local_tmp_3.flist >> rtl.flist

# Copy all RTL files into rtl dir
printf "${YELLOW}[FETCH_SOURCES] Copy all sources into rtl${NC}\n" s
for rtl_file in $(cat rtl.flist) ; do
    cp $rtl_file rtl
done;

# Info
printf "${GREEN}[FETCH_SOURCES] Completed${NC}\n"
