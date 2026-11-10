#!/bin/bash
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description: Launch GDB with a target ELF file and connecting to a specific backend port


ARGC=$#;

# Print the right usage
help (){
    echo  "Usage: source ${BASH_SOURCE[0]} <elf_name> <backend_port>";
    echo  "    elf_name          :  path to the elf file";
    echo  "    backend [ip:port] :  port backend (We use 3004 for both vivado hw_server (32-bits) and openocd. Port 3005 for vivado hw_server riscv 64 bits)";
    echo  "    xlen              :  system xlen (32 or 64 bits)";
    echo  "    mode (optional)   :  \"detach\" to load the ELF, let the CPU run and detach GDB";
    return;
}

# Check the argc
if [ $ARGC -ne 3 ] && [ $ARGC -ne 4 ];
then
    echo  "Invalid number of arguments, please check the inputs and try again";
    help;
    return 1;
fi

# Get the args
ELF_NAME=$1;
BACKEND_IP_PORT=$2;
XLEN=$3
MODE=$4

# Default: run until the end of the program, then quit
GDB_RUN=(-ex "b _exit_wfi_ok" -ex "b _exit_wfi_error" -ex "c")
# Detach: let the CPU run and detach GDB, e.g. when the program waits for another
# master (Zynq PL-first sequence, the CPU program waits for the PS one)
if [ "$MODE" == "detach" ]; then
    GDB_RUN=(-ex "monitor resume" -ex "detach")
fi

echo "Running GDB $XLEN-bits version";
echo "Loading ELF $ELF_NAME";
echo "Connecting to $BACKEND_IP_PORT";

# Run GDB
riscv$XLEN-unknown-elf-gdb $ELF_NAME \
    -ex 'set confirm off' \
    -ex 'set pagination off' \
    -ex 'set architecture riscv:rv'$XLEN \
    -ex 'target extended-remote '$BACKEND_IP_PORT \
    -ex "file $ELF_NAME" \
    -ex 'load ' \
    "${GDB_RUN[@]}" \
    -ex "quit"
