#!/bin/bash
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
#   This script is used to fetch CV64A6 Sources from OpenHW repo.
#   It is updated to the latest release till Feb 2025.
#   We use the stock configuration file from OpenHW repo, with some
#   Modifications to make it fit also for the embedded profile and on FPGA

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
RTL_DIR=$(pwd)/rtl
mkdir ${RTL_DIR}

ASSETS_DIR=$(pwd)/assets

#######################################
# Fetch CVA6 sources and depencencies #
#######################################

# clone repo ( Release v5.3.0 Feb 3 2025 )
GIT_URL=https://github.com/openhwgroup/cva6.git
GIT_TAG=v5.3.0
CLONE_DIR=$(pwd)/cva6
FLIST=${ASSETS_DIR}/flist

printf "${YELLOW}[FETCH_SOURCES] Cloning source repository${NC}\n"
git clone ${GIT_URL} -b ${GIT_TAG} --depth 1 ${CLONE_DIR}
cd ${CLONE_DIR};
git submodule update --init --recursive
cd ..;

######################
# Prepare file lists #
######################

# Load file lines into an array
mapfile -t sources < ${ASSETS_DIR}/sources.flist
mapfile -t headers < ${ASSETS_DIR}/headers.flist

# Replace ${DIR} with ${CLONE_DIR} in each element
for i in "${!sources[@]}"; do sources[$i]="${sources[$i]//\$\{DIR\}/${CLONE_DIR}}"; done
for i in "${!headers[@]}"; do headers[$i]="${headers[$i]//\$\{DIR\}/${CLONE_DIR}}"; done

################################
# Move source files to RTL dir #
################################

printf "${YELLOW}[FETCH_SOURCES] Copy all sources into rtl${NC}\n" s
for rtl_file in "${sources[@]}" ; do
    cp $rtl_file ${RTL_DIR}
done;

################################
# Move header files to RTL dir #
################################

printf "${YELLOW}[FETCH_SOURCES] Copy all headers into rtl${NC}\n" s
for rtl_file in "${headers[@]}" ; do

    filename=$(basename "$rtl_file")

    if [[ "$rtl_file" == *"axi"* ]]; then
        filename="axi_${filename}"
    elif [[ "$rtl_file" == *"register_interface"* ]]; then
        filename="register_interface_${filename}"
    fi

    cp "$rtl_file" "${RTL_DIR}/${filename}"

done;

#################
# Patch sources #
#################

# Loop through all files in the rtl directory
echo -e "${YELLOW}[PATCH_SOURCES] Patching include paths for flat includes and specific substitutions${NC}"
for rtl_file in ${RTL_DIR}/*; do
    if [[ -f $rtl_file ]]; then
        # Substitute AXI includes
        sed -i "s|\`include \"axi/typedef.svh\"|\`include \"axi_typedef.svh\"|g" $rtl_file
        sed -i "s|\`include \"axi/assign.svh\"|\`include \"axi_assign.svh\"|g" $rtl_file

        # Flatten remaining includes
        sed -i 's#`include "[^/]*/\([^"]*\.svh\)"#`include "\1"#g' $rtl_file
    fi
done

# Selectively patch exe_stage: superscalarity on forwarding signals is not supported (in the current version)
sed -i '/<=/ s/rs1_forwarding_i/rs1_forwarding_i[0]/g' ${RTL_DIR}/ex_stage.sv
sed -i '/<=/ s/rs2_forwarding_i/rs2_forwarding_i[0]/g' ${RTL_DIR}/ex_stage.sv

# The unread.sv file used in the openhw repo is not VIVADO compatible.
# Therefore we save the PULP one in the assets and copy it on demand
cp ${ASSETS_DIR}/unread.sv ${RTL_DIR}

# Symbolic link configuration file. Check in assets for further info
ln -s ${ASSETS_DIR}/cv64a6_config_pkg.sv ${RTL_DIR}

# Info
echo -e "${GREEN}[FETCH_SOURCES] Completed${NC}"