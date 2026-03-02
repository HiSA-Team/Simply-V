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
printf "[INFO] Firmware Start Address from config: %s\n" ${FW_TEXT_START}
printf "[INFO] OPENSBI_FW_JUMP=${OPENSBI_FW_JUMP}\n"
printf "[INFO] OPENSBI_LOAD_JUMP_PAYLOAD=${OPENSBI_LOAD_JUMP_PAYLOAD}\n"

# Build GDB command (POSIX sh compatible)
# If you are experiencing mismatch of the opensbi version (this is mostly due to the GLIBC version
# of the Host OS and Server OS incompatibility), you can switch to the newlib gdb version
# GDB_CMD="riscv${PLATFORM_RISCV_XLEN}-unknown-elf-gdb -ex 'set confirm off' -ex 'target extended-remote ${GDB_SERVER}'"
GDB_CMD="${CROSS_COMPILE}gdb -ex 'set confirm off' -ex 'target extended-remote ${GDB_SERVER}'"

# Launch GDB based on firmware mode
if [ "${OPENSBI_FW_JUMP:-}" = "y" ]; then

    # Whether to explicitly load the payload with GDB
    if [ "${OPENSBI_LOAD_JUMP_PAYLOAD:-}" = "y" ]; then
        printf "[INFO] Loading payload ${FW_PAYLOAD_ELF_PATH}\n"
        GDB_CMD="$GDB_CMD -ex 'load ${FW_PAYLOAD_ELF_PATH}'"
    else
        printf "[INFO] Skipping payload loading\n"
        printf "[INFO] Just adding symbols from ${FW_PAYLOAD_ELF_PATH}\n"

        # Just add symbol file
        GDB_CMD="$GDB_CMD -ex 'add-symbol-file ${FW_PAYLOAD_ELF_PATH}'"
    fi

    # OPENSBI_FW_JUMP
    printf "[INFO] Running OPENSBI_FW_JUMP\n"
    GDB_CMD="$GDB_CMD build/platform/simply-v/firmware/fw_jump.elf"
else
    # FW_PAYLOAD
    printf "[INFO] Running FW_PAYLOAD\n"
    GDB_CMD="$GDB_CMD build/platform/simply-v/firmware/fw_payload.elf"
fi

# Load and run OpenSBI firmware
GDB_CMD="$GDB_CMD -ex 'load'"
GDB_CMD="$GDB_CMD -ex 'j _fw_start'"
GDB_CMD="$GDB_CMD -ex 'c'"

# Execute the GDB command
eval "$GDB_CMD"
