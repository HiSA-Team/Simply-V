#!/bin/bash
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description:
#   This script downloads PULP CLINT from https://github.com/pulp-platform/clint.git/ sources and flattens them into the rtl directory

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
IP_NAME=$( basename $(dirname $( realpath ${BASH_SOURCE[0]} ) ))

# Create rtl dir
RTL_DIR=${PWD}/rtl
mkdir ${RTL_DIR}

##############
# Bender.yml #
##############

# Move into assets dir
cd assets/

# Download Bender
BENDER_VERSION=0.29.1
printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Download Bender ${BENDER_VERSION}${NC}\n"
curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh	-s -- ${BENDER_VERSION}

# Download dependencies (specify Target RTL and FPGA)
printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Resolve dependencies with Bender${NC}\n"
./bender checkout
make -C $(./bender path clint) clint CLINTCORES=1
BENDER_FILE_LIST=../rtl.flist
BENDER_TARGETS="-t xilinx -t fpga"
./bender script flist-plus ${BENDER_TARGETS} > ${BENDER_FILE_LIST}
# Save include directories
INCPATHS_string=($(grep incdir ${BENDER_FILE_LIST}))

INCPATH_list=()
for path in ${INCPATHS_string[*]}; do
    INCPATH_list=(${INCPATH_list[*]} $(echo $path | sed 's/^+incdir+//g'))
done

###########
# Patches #
###########

# Remove include directives
sed -i '/+incdir+/d' ${BENDER_FILE_LIST}
# Remove defines
sed -i '/+define+/d' ${BENDER_FILE_LIST}
# Remove interface-based files, since Vivado does not like them
sed -i '/apb_intf.sv/d' ${BENDER_FILE_LIST}
sed -i '/axi_intf.sv/d' ${BENDER_FILE_LIST}
sed -i '/reg_intf.sv/d' ${BENDER_FILE_LIST}
sed -i '/stream_intf.sv/d' ${BENDER_FILE_LIST}

########
# Copy #
########

# Copy all RTL files into rtl dir
printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Copy all sources into ${RTL_DIR}/${NC}\n"
for rtl_file in $(cat ${BENDER_FILE_LIST}) ; do
    cp $rtl_file ${RTL_DIR}
done;

# Add header files, not listed by bender
printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Copy and rename headers into ${RTL_DIR}${NC}\n"
CLONE_DIR=.bender
cd ${CLONE_DIR}
# For each include path
for include_path in ${INCPATH_list[*]}; do
    FILEPATH_list=($(find ${include_path} -name *.svh))
    # For each header
    for file in ${FILEPATH_list[*]}; do
        cp ${file} ${RTL_DIR}/$(basename $(dirname $file))_$(basename $file)
    done
done

###########
# Patches #
###########

# Patch files for flat includes
printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Flatten all includes ${NC}\n"
for rtl_file in ${RTL_DIR}/* ; do
    if [[ -f $rtl_file ]]; then
        # Flatten all includes
        sed -i 's#`include "\([^/]*/\)\([^"]*\.svh\)"#`include "\1_\2"#g' $rtl_file
        sed -i 's/\/_/_/' $rtl_file
    fi
done

# Info
printf "${GREEN}[FETCH_SOURCES $IP_NAME] Completed${NC}\n"