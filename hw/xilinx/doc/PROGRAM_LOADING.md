# Program Loading

Once the target board is programmed with a valid bitstream, a program can be loaded into SoC memory using different methods, depending on the selected RISC-V CPU specified by `CORE_SELECTOR`. Example programs can be compiled and built in the `sw/SoC` directory using `make`. Externally compiled programs can also be used, but ensure they are built with the appropriate compilation flags for the selected CPU.

We offer two loading options:
- **Binary Loading**: load the flat .bin file starting from a memory address
- **ELF Loading**: load the .elf file using sections

For both flows, the default application loaded is `sw/SoC/examples/blinky`

## Load an ELF file

To load a .elf file, a backend that supports the target platform and CPU is required. Currently, we support two backends:
[OpenOCD](../../../sw/doc/OPENOCD_INSTALLATION.md) and XSDB (coming with Vivado). Both connect to port 3004, which is used for RISC-V 32-bit (64-bit support is not yet available).
For loading, we primarily use the GDB debugger, though XSDB is also a viable option.

If `CORE_SELECTOR` is set to `CORE_MICROBLAZEV_RV32` or `CORE_MICROBLAZEV_RV64`, the .elf file can be loaded into memory and executed using:
``` bash
make xsdb_run
```
Instead, if the `CORE_SELECTOR` is another one (e.g. `CORE_CV32E40P`) use openocd (be sure to have closed connections with Xilinx HW server before)
``` bash
make openocd_run
```
Once the backend is enabled, load the .elf file using
``` bash
make gdb_run ELF_PATH=<path-to-elf>
```

## Load a binary file

Since not all CPUs supported by `CORE_SELECTOR` have a backend or dedicated loading infrastructure (e.g. `CORE_PICORV32`), memory can also be programmed with a flat binary using _Xilinx jtag2axi_ or _Xilinx DMA_ IPs, both integrated into our `rtl/sys_master` component. This binary loading process is straightforward, as it directly writes bytes into memory.

> NOTE: This loading flow writes a flat binary image, including zero-padding between memory sections. Therefore, during linking, you might need to keep an eye for this.

``` bash
make load_binary BIN_PATH=<path-to-bin> BASE_ADDRESS=<value> JTAG_READBACK=<false|true>
```
Once the binary is loaded, manually trigger a CPU reset with:
``` bash
make vio_resetn
```
The VIO resetn controls the CPU reset instead of GDB, allowing the user to directly manage the core reset.
**Warning**: this option works only if `VIO_RESETN_DEFAULT = 0` in `configs/<profile>/config_main_bus.csv`

