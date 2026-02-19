#!/bin/sh

# This script loads OpenSBI firmware over GDB and prepares for the debug loading the symbol files for
# S-mode payload. The script simply create a gdb command based on paramters coming from build configuration.
# For futher documentation refer to README.md.
#
# To simply run a session just run this script with:
# make run
#
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>

set -eu pipefail

# Debug info
printf "[INFO] Connecting to %s\n" ${GDB_SERVER}
printf "[INFO] Payload: %s\n" ${FW_PAYLOAD_ELF_PATH}

# Build GDB command (POSIX sh compatible)
# If you are experiencing mismatch of the opensbi version (this is mostly due to the GLIBC version
# of the Host OS and Server OS incompatibility), you can switch to the newlib gdb version
# GDB_CMD="riscv${PLATFORM_RISCV_XLEN}-unknown-elf-gdb -ex 'set confirm off' -ex 'target remote ${GDB_SERVER}'"
GDB_CMD="${CROSS_COMPILE}gdb -ex 'set confirm off' -ex 'target remote ${GDB_SERVER}'"

# Add symbol file (always)
GDB_CMD="$GDB_CMD -ex 'add-symbol-file ${FW_PAYLOAD_ELF_PATH}'"

# Launch GDB based on firmware mode
if [ "${FW_JUMP:-}" = "y" ]; then

    if [ "${LOAD_JUMP_PAYLOAD:-}" = "y" ]; then
        GDB_CMD="$GDB_CMD -ex 'load ${FW_PAYLOAD_ELF_PATH}'"
    else
        printf "[INFO] Skipping payload loading\n"
    fi

    # Load the firmware
    GDB_CMD="$GDB_CMD -ex 'load'"
    GDB_CMD="$GDB_CMD build/platform/fpga/simply-v/firmware/fw_jump.elf"
else
    GDB_CMD="$GDB_CMD -ex 'load'"
    GDB_CMD="$GDB_CMD build/platform/fpga/simply-v/firmware/fw_payload.elf"
fi

# Execute the GDB command
eval "$GDB_CMD"
