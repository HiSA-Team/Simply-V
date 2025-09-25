#!/bin/bash
# Author: Vincenzo Merola <vincenzo.merola2@unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Fetch HLS sources and build Verilog and C standalone drivers

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

WORK_DIR=$(pwd -P)
# Creating build/ dir
mkdir -p rtl
BUILD="$(pwd -P)/rtl"

# Rebuild HLS sources
cd assets
source rebuild_hls.sh

# Back to top
cd ${WORK_DIR}

printf "\n${GREEN}[FETCH_SOURCES] Completed${NC}\n"