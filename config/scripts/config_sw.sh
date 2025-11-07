#!/bin/bash
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
#   Replace config-based content of output file (sw/SoC/common/config.mk) based on XLEN values (system_config.csv)
#   Target values are parsed and from inputs and updated in output file.
#   Currently we only support 32 and 64 unknown toolchain.
#   In the future, we might support a more flexible toolchain selection flow (e.g. rv64-linux) and flags

# Args:
#   $1: System CSV config
#   $2: Target MK file (currently unmodified, left for forward compatibility)

##############
# Parse args #
##############

EXPECTED_ARGC=2;
ARGC=$#;

# Check argc
if [ $ARGC -ne $EXPECTED_ARGC ]; then
    echo  "[CONFIG_SW][ERROR] Invalid number of arguments, please check the inputs and try again";
    exit 1;
fi

# Read args
CONFIG_SYS_CSV=$1
OUTPUT_MK_FILE=$2

##########
# Script #
##########

xlen_value=$(grep "XLEN" ${CONFIG_SYS_CSV} | grep -v RANGE | awk -F "," '{print $2}');

# TODO: 64 supported yet
# if [[ "$xlen_value" == "32" || "$xlen_value" == "64" ]]; then
if [[ "$xlen_value" == "32" || "$xlen_value" == "64" ]]; then

    echo "[CONFIG_SW] Setting XLEN to ${xlen_value} "
    sed -E -i "s/XLEN.?\?=.+/XLEN \?= ${xlen_value}/g" ${OUTPUT_MK_FILE};

else
    echo "[CONFIG_SW][ERROR] Invalid XLEN=$xlen_value value; no toolchain is supported for this XLEN value";
    exit 1;
fi

echo "[CONFIG_SW] Output file is at ${OUTPUT_MK_FILE}"
