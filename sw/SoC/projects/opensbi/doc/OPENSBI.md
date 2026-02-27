# OpenSBI

This document contains additional information on how to customize OpenSBI build and change the memory layout.

> [!WARNING]
> Although supervisors can be built with the `newlib` toolchain, OpenSBI requires toolchains that are
> capable of generating Position Independent Executable (PIE) images. So toolchains like `riscv64-unknown-elf-gcc`
> are not supported. Users will have to use `riscv64-linux-gnu-gcc` or leverage the `Clang/LLVM`
> toolchains. More details in the OpenSBI [documentation](https://github.com/riscv-software-src/opensbi?tab=readme-ov-file#required-toolchain-and-packages).
> Refer to [documentation](../../../../doc/GCC_INSTALLATION.md) for installation process.

OpenSBI build contains is orchestrated using [simply-v/objects.mk](../simply-v/objects.mk): it
contains information for compiler, linker and assembler and needs to be updated with information about
libraries to link etc.

## Specifying a different payload
Users can specifiy a different payload (only for FW_PAYLOAD) by passing its path when building.
For example:

```sh
make OPENSBI_FW_PAYLOAD_BIN_PATH=path/to/bin
```

## Changing memory layout
Users will have to make sure that the entrypoint of the payload matches the address where OpenSBI is
going to jump. For OpenSBI FW_JUMP, there will be different offsets according to the `PLATFORM_RISCV_XLEN`:

```make
ifeq ($(PLATFORM_RISCV_XLEN), 32)
FW_JUMP_OFFSET=0x400000
else
FW_JUMP_OFFSET=0x200000
endif
```

Ideally, one would never really need to modify these offsets. The base address is automatically calculated
when using `make install` (using [create_config.py](../scripts/create_config.py) script) taking the base address of
the `DDR4CH1` memory device.

## Customizing the debug session

Users can change the default [platform_run.sh](../simply-v/platform_run.sh) by specifying the following parameters:

- OPENSBI_GDB_SERVER_ADDRESS: address of the GDB server, default to `localhost:3004`.
- OPENSBI_FW_JUMP: if `y` the FW_JUMP firmware is loaded
- LOAD_JUMP_PAYLOAD: if `n` does not load the payload
