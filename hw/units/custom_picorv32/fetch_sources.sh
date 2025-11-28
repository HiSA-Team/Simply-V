#!/bin/bash
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
# This script downloads picorv32 sources and flattens them into the rtl directory

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create rtl dir
mkdir rtl

# clone repo (Branch main, Release v1.0 Mar 2, 2019, Commit 87c89ac)
GIT_URL=https://github.com/YosysHQ/picorv32.git
GIT_COMMIT=87c89ac
printf "${YELLOW}[FETCH_SOURCES] Cloning source repository${NC}\n"
git clone ${GIT_URL} --depth 1 picorv32
cd picorv32;
git reset --hard ${GIT_COMMIT}

# Copy all RTL files into rtl dir
printf "${YELLOW}[FETCH_SOURCES] Copy all sources into rtl${NC}\n" s
cp picorv32.v ../rtl

# Info
printf "${GREEN}[FETCH_SOURCES] Completed${NC}\n"
