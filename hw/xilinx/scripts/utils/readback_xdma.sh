#!/bin/sh
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Bash script to read back from AXI using busybox devmem
# Arguments:
#   $1: PCIe BAR
#   $2: Offset in SoC
#   $2: Number of bytes to read

# --------------------------
# Usage and argument parsing
# --------------------------
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <PCIE_BAR> <offset> <num_bytes>"
    echo "Example: $0 0x92000000 0x40000 64"
    OFFSET=0x0000
    NUM_BYTES=16
else
    PCIE_BAR=$1
    OFFSET=$2
    NUM_BYTES=$3
fi

# --------------------------
# Constants and setup
# --------------------------
BURST_SIZE=4  # bytes per read
READ_SIZE_BITS=$(($BURST_SIZE * 8)) # bits per read
NUM_BURSTS=$((NUM_BYTES / BURST_SIZE))

echo "PCIe BAR: $PCIE_BAR"
echo "Base address: $OFFSET"
echo "Number of bytes to read: $NUM_BYTES"
echo "Reading $NUM_BURSTS bursts of $BURST_SIZE bytes each"
echo "-------------------------------------------"

# --------------------------
# Convert hex to decimal for arithmetic
# --------------------------
base_dec=$(($OFFSET + $PCIE_BAR))

# --------------------------
# Read loop
# --------------------------
for ((i=0; i<NUM_BURSTS; i++)); do
    addr=$((base_dec + i * BURST_SIZE))
    printf "Reading from address 0x%08X = " "$addr"
    value=$(sudo busybox devmem "$addr" $READ_SIZE_BITS)
    echo "$value"
done

echo "-------------------------------------------"
echo "Readback complete."
