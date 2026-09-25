#!/bin/bash
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description:
#   This script downloads the RDMA RoCEv2 (lite) engine sources and copies them into the rtl directory.
#   Sources come from SimplyV_Custom_RDMA, a flattened copy of the upstream project
#   https://github.com/Gabriele-bot/100G-verilog-RoCEv2-lite (lib/eth included).
#   Only the files listed in assets/flist are copied, i.e. the dependency closure of network_wrapper_roce_generic
#   (every file in rtl/ is imported by the IP packaging flow).
#   NOTE: SimplyV_Custom_RDMA is a private repository; to clone it through SSH, or from a local clone, run e.g.
#         RDMA_GIT_URL=git@github.com:Pinosz/SimplyV_Custom_RDMA.git make units

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
IP_NAME=$( basename $(dirname $( realpath ${BASH_SOURCE[0]} ) ))

# Create rtl dir
mkdir -p rtl

# Clone repo
GIT_URL=${RDMA_GIT_URL:-https://github.com/Pinosz/SimplyV_Custom_RDMA.git}
GIT_BRANCH=main
# TODO: pin to the commit holding the upstream sync (b113b14) once it is pushed
GIT_COMMIT=${RDMA_GIT_COMMIT:-main}
CLONE_DIR=simplyv_custom_rdma
printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Cloning source repository${NC}\n"
git clone ${GIT_URL} -b ${GIT_BRANCH} ${CLONE_DIR}
cd ${CLONE_DIR};
git checkout ${GIT_COMMIT}
cd ..;

# Copy the RTL files listed in the flist into rtl dir
FLIST="$PWD/assets/flist"
LOOKUP_DIR="$PWD/${CLONE_DIR}"
RTL_DIR="$PWD/rtl"

printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Copy all sources into rtl${NC}\n"
while IFS= read -r filename; do
    # The repository is flat
    filepath="$LOOKUP_DIR/$filename"

    # If found
    if [ -f "$filepath" ]; then
        cp "$filepath" "$RTL_DIR/"
    # Error
    else
        printf "${RED}[FETCH_SOURCES $IP_NAME] Error: $filename not found in $LOOKUP_DIR${NC}\n"
        rm -rf ${RTL_DIR} ${CLONE_DIR}
        return 1 2>/dev/null || exit 1
    fi
done < "$FLIST"

# Remove temporary files
rm -rf ${CLONE_DIR}

# Info
printf "${GREEN}[FETCH_SOURCES $IP_NAME] Completed${NC}\n"
