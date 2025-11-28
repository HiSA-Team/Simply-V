#!/bin/bash
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
# This script downloads LowRISC Ibex sources and flattens them into the rtl directory

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Create rtl dir
mkdir -p rtl

# clone repo (Ibex releases are inconsistent, therefore we must stick to a specific commit).
GIT_URL=https://github.com/lowRISC/ibex.git
GIT_BRANCH=master
GIT_COMMIT=6e466c1504b61333d1b2ba85c69bff94b65e9284
CLONE_DIR=ibex
printf "${YELLOW}[FETCH_SOURCES] Cloning source repository${NC}\n"
git clone ${GIT_URL} -b ${GIT_BRANCH} ${CLONE_DIR}
cd ${CLONE_DIR};
git checkout ${GIT_COMMIT}

# Copy all RTL files into rtl dir
# We use the flist pre-generated with fusesoc and saved in assets
# the flist is generated using:
#   fusesoc --cores-root . run --target=lint --setup --build-root ./build/ibex_out lowrisc:ibex:ibex_top
#   Python version 3.6
cd ..;
FLIST="$PWD/assets/flist"
LOOKUP_DIR="$PWD/ibex"
RTL_DIR="$PWD/rtl"

printf "${YELLOW}[FETCH_SOURCES] Copy all sources into rtl${NC}\n" s
while IFS= read -r filename; do
    # Find the file in LOOKUP_DIR
    filepath=$(find "$LOOKUP_DIR" -type f -name "$filename" 2>/dev/null | head -n 1)

    # If found
    if [ -n "$filepath" ]; then
        cp "$filepath" "$RTL_DIR/"
    # Error
    else
        printf "${RED}[FETCH_SOURCES] Error: $filename not found in $LOOKUP_DIR${NC}\n"
        exit 1
    fi
done < "$FLIST"

# Info
printf "${GREEN}[FETCH_SOURCES] Completed${NC}\n"

