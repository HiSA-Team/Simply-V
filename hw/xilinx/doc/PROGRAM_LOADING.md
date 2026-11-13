# Program Loading

Once the target board is programmed with a valid bitstream, a program can be loaded into SoC memory using different methods, depending on the selected RISC-V CPU specified by `CORE_SELECTOR`. Example programs can be compiled and built in the `sw/SoC` directory using `make`. Externally compiled programs can also be used, but ensure they are built with the appropriate compilation flags for the selected CPU.

We offer two loading options:
- **Binary Loading**: load the flat .bin file starting from a memory address
- **ELF Loading**: load the ELF file using sections

For both flows, the default application loaded is `sw/SoC/examples/blinky`

## Load an ELF file

To load an ELF file, a backend that supports the target platform and CPU is required. Currently, we support two backends:
[OpenOCD](../../../sw/doc/OPENOCD_INSTALLATION.md) and XSDB (coming with Vivado).

Both connect to port 3004 for all cores, except for `CORE_MICROBLAZEV_RV64`, which requires port 3005.

For loading, we primarily use GDB, though XSDB is also a viable option for Microblaze-V CPUs.

If `CORE_SELECTOR` is set to `CORE_MICROBLAZEV_RV32`, `CORE_DUAL_MICROBLAZEV_RV32`,  `CORE_MICROBLAZEV_RV64`, the ELF file can be loaded into memory and executed using:
``` bash
make xsdb_run
```
> NOTE: XSDB might require to reset the processor across runs. In the XSDB shell, use the command `rst -processor`.

Instead, if the `CORE_SELECTOR` is another one (e.g. `CORE_CV32E40P`) use openocd (be sure to have closed connections with Xilinx HW server before)
``` bash
make openocd_run
```
Once the backend is enabled, load an example ELF file using:
``` bash
make gdb_run EXAMPLE=hello_world
```
Or explicitly pick your ELF:
``` bash
make gdb_run ELF_PATH=<path-to-elf>
```

## Zynq-7000 (PS+PL)

On the `zynq` profile, Simply-V gets its clock from the PS, so the PS must be initialized (`ps7_init`, `ps7_post_config`) after the bitstream.
This is done with XSDB and `scripts/load_binary/xsdb_run_elf.tcl`, where any argument can be `-` to skip that step.

With Microblaze-V, `xsdb_run_elf.tcl` can program the bitstream and run both the CPU and the PS programs in one go (see `sw/host/zynq/ps_mailbox`).
With the other CPUs (e.g. `CORE_CV32E40P`), the CPU program is loaded with OpenOCD and GDB, and the PS program with XSDB, in one of the two sequences below.
OpenOCD and XSDB use the same JTAG cable: close one before starting the other.

### PS-first sequence

1. Program the bitstream, initialize the PS and run the PS program with XSDB:
``` bash
xsdb scripts/load_binary/xsdb_run_elf.tcl - \
    build/simplyv.runs/impl_1/simplyv.bit \
    build/simplyv.gen/sources_1/ip/xlnx_ps_wrapper/src/xlnx_ps_wrapper_bd_ps7_0/ps7_init.tcl \
    <path-to-ps-elf>
```
2. XSDB exits leaving the PS running: make sure that `hw_server` is closed.
3. Load and run the CPU program:
``` bash
make openocd_run
make gdb_run EXAMPLE=<example>
```

### PL-first sequence

1. Program the bitstream and initialize the PS (`program_bitstream_zynq`):
``` bash
make program_bitstream
```
2. Load the CPU program, let it run and exit from GDB (`GDB_MODE=detach`), then close OpenOCD:
``` bash
make openocd_run
make gdb_run EXAMPLE=<example> GDB_MODE=detach
```
3. Run the PS program with XSDB, without programming the bitstream again:
``` bash
xsdb scripts/load_binary/xsdb_run_elf.tcl - - - <path-to-ps-elf>
```

## Load a binary file

Since not all CPUs supported by `CORE_SELECTOR` have a backend or dedicated loading infrastructure (e.g. `CORE_PICORV32`), memory can also be programmed with a flat binary using _Xilinx jtag2axi_ or _Xilinx DMA_ IPs, both integrated into our `rtl/sys_master` component. This binary loading process is straightforward, as it directly writes bytes into memory.

> NOTE: This loading flow writes a flat binary image, including zero-padding between memory sections. Therefore, during linking, you might need to keep an eye for large binaries.

``` bash
make load_binary BIN_PATH=<path-to-bin> OFFSET=<value> LOAD_BINARY_READBACK=<false|true>
```
Once the binary is loaded, manually trigger a CPU reset with:
``` bash
make vio_resetn
```
The VIO resetn controls the CPU and debug module reset instead of GDB, allowing the user to directly manage the core reset.

