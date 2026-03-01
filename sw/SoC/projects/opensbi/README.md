# OpenSBI on Simply-V

> [!WARNING]
> The tested OpenSBI version is v1.7. Prior versions will not work since v1.7 is the first that allows
to compile without atomics, but just with `zalrsc` extension.

Currently, OpenSBI can be executed only with `CORE_CVA64A6` and `CORE_CVA64A6_ARA` because it is
the only core that supports S-mode. [doc/](doc/) contains additional documentation on how to modify
memory layout of the system.

## Getting started

To get started, pull OpenSBI sources and install the Simply-V platform:

> [!WARNING]
> The installation process generates a `config.mk` file.
Any changes to the SoC configuration will require a new `make install` command.

```
make install
```

## Configuring OpenSBI firmware
If users want to modify the firmware configuration (for example use the OpenSBI provided XILINX Serial
driver instead of the tinyIO implementation), they can use:

```sh
make menuconfig
```

Users can also directly edit the `simply-v/configs/defconfig` instead of using menuconfig.
After saving the configuration, users can start a build process.

## Building a supervisor payload
In [payloads/](payloads/), we provide a simple infrastructure to build S-mode payloads for OpenSBI.

Payloads can share the linkerscript and Makefile in [common/](common/) and can be built with:

```sh
make payloads
```

We provide an S-mode [payloads/hello_world](payloads/hello_world) program illustrates how to use SBI extension to
write a bare-metal kernel. It can be selectively built with:

```sh
make hello_world
```

Build artifacts are in `payloads/hello_world/build` named as `hello_world.elf` and `hello_world.bin`.

OpenSBI is a M-mode firmware implementing Supervisor Binary Interface (SBI) for S-mode software.
OpenSBI primarly acts as a bootloader to launch the S-mode payload (typically an OS).
We provide support for 2 different payload modes:

- `FW_JUMP`: OpenSBI jumps to a specific offset starting from its base address. In this case, users
will have to load the payload manually. This is the most common way to build opensbi since it allows
to change S-mode payload without rebuilding the firmware.
-  `FW_PAYLAOD`: the S-mode payload is embedded within OpenSBI image as a flat binary


## Building the OpenSBI firmware

Once the target payload has been built, build the firmware (both FW_PAYLOAD and FW_JUMP) with:

```sh
make opensbi
```

The default payload is S-mode `hello_world`, but it can be overridden with:
- `OPENSBI_FW_PAYLOAD_BIN_PATH=path/to/your/payload.bin` for `FW_PAYLAOD`, and
- `OPENSBI_FW_PAYLOAD_ELF_PATH=path/to/your/payload.elf` for `FW_JUMP`

Build artifacts are in `opensbi/build/platform/fpga/simply/firmware/` named as `fw_payload.elf` and
`fw_jump.elf`. By the default the `payloads/hello_world` is used.

Users can change parameters by passing them to the `make` command.
Refer to [simply-v/objects.mk](./simply-v/objects.mk) for further OpenSBI build customizations.

## Running a supervisor payload

We provide the [simply-v/platform_run.sh](./simply-v/platform_run.sh) script (installed in OpenSBI via `make install`) to start a
debug session and program the SoC. The script can be executed with:

```sh
make run
```

By default, the script uses `fw_payload.elf` and loads the `.elf` of the binary file specified
during build phase (default `payloads/hello_world/build/hello_world.bin`) and connects to `localhost:3004`
for the GDB server.

Alternatively, the same script can be used for `FW_JUMP` to load the OpenSBI firmware and payload separately with GDB:

```sh
make run OPENSBI_FW_JUMP=y
```

Users can skip the payload loading (ie. they prefer to load using the PCIe bus) using:

```sh
make run OPENSBI_FW_JUMP=y OPENSBI_LOAD_JUMP_PAYLOAD=n
```

The `platform_run.sh` script always adds the `OPENSBI_FW_PAYLOAD_ELF_PATH` as symbol file to ease debug.

### Running the supervisor payload manually

For large paylaods such as a full OS image, using GDB can be lengthy, hence we provide the means for a high-speed load though PCIe.

E.g., from the top of directory of the Simply-V project, to load hello_world supervisor payload and OpenSBI separately, run:

```sh
make -C hw/xilinx/ load_binary \
    BIN_PATH=$(realpath sw/project/opensbi/sw/SoC/projects/opensbi/payloads/hello_world/build/hello_world.bin) \
    OFFSET=0x1200000
make -C sw/SoC/projects/opensbi run OPENSBI_FW_JUMP=y OPENSBI_LOAD_JUMP_PAYLOAD=n
```
