#!/bin/bash
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description: Launch GDB with a target ELF file and connecting to a specific backend port


EXPECTED_ARGC=2;
ARGC=$#;

# Print the right usage
help (){
    echo  "Usage: source ${BASH_SOURCE[0]} <elf_name> <backend_port>";
    echo  "    elf_name         :  path to the elf file";
    echo  "    backend_port     :  port backend (3333 for openocd, 3004 for vivado hw_server riscv 32 bit)";
    return;
}

# Check the argc
if [ $ARGC -ne $EXPECTED_ARGC ];
then
    echo  "Invalid number of arguments, please check the inputs and try again";
    help;
    return 1;
fi

# Get the args
ELF_NAME=$1;
BACKEND_PORT=$2;

echo "[INFO] Running GDB";
echo "[INFO] Loading ELF $ELF_NAME";
echo "[INFO] Connecting to port $BACKEND_PORT";

# Run with break-point and exit on termination
riscv32-unknown-elf-gdb \
    -batch \
    -ex 'set architecture riscv:rv'$XLEN \
    -ex 'target extended-remote:'$BACKEND_PORT \
    -ex "file $ELF_NAME" \
    -ex 'load ' \
    -ex "b _exit_wfi" \
    -ex "run" \
    -ex "quit"
