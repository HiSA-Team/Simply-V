# PS Mailbox (Zynq-7000)

PS side of the PS <-> Simply-V mailbox test.
The program runs bare-metal on the Cortex-A9 #0 of the Zynq-7000 PS and exchanges a value with the Simply-V CPU through a mailbox in `BRAM_0`, reached through `M_AXI_GP0`.
The CPU side is in `sw/SoC/examples/ps_mailbox`.

## Build

Requirements: Simply-V configured and built for the `zynq` profile, so that the XSA of the PS exists (`hw/xilinx/ips/common/xlnx_ps_wrapper/build/xlnx_ps_wrapper.xsa`):
```
source settings.sh zynq pynq_z1
make config
make -C hw/xilinx bitstream
```

Build the PS program with the Vitis Python API:
```
vitis -s sw/host/zynq/build_ps_app.py ps_mailbox
```
The script:
- creates the platform and the BSP from the XSA (only the first time, then they are reused);
- generates `ps_hw.h` with the `M_AXI_GP0` base address, read from the device tree of the XSA;
- builds the application. The linker script and the startup code come from Vitis.

The ELF is `sw/host/zynq/ps_mailbox/bin/ps_mailbox/build/ps_mailbox.elf`.

Build the CPU program:
```
make -C sw/SoC/examples/ps_mailbox
```

## Run

```
xsdb hw/xilinx/scripts/load_binary/xsdb_run_elf.tcl \
    sw/SoC/examples/ps_mailbox/bin/ps_mailbox.elf \
    hw/xilinx/build/simplyv.runs/impl_1/simplyv.bit \
    hw/xilinx/build/simplyv.gen/sources_1/ip/xlnx_ps_wrapper/src/xlnx_ps_wrapper_bd_ps7_0/ps7_init.tcl \
    sw/host/zynq/ps_mailbox/bin/ps_mailbox/build/ps_mailbox.elf
```
The script resets the system, programs the bitstream, initializes the PS (`ps7_init`, `ps7_post_config`), keeps the Cortex-A9 #1 halted, runs the CPU program on Simply-V and then the PS program on the Cortex-A9 #0.

## Expected output

On the Simply-V UART:
```
[CPU] Mailbox at 0x00008000, waiting for the PS
[CPU] Read from the PS: 0xcafe0123
[CPU] Wrote to the PS: 0x3501fedc
```

On the PS UART (115200 baud):
```
[PS] Mailbox at 0x40008000, waiting for the CPU
[PS] Wrote to the CPU: 0xcafe0123
[PS] Read from the CPU: 0x3501fedc
[PS] Test passed
```

## Troubleshooting

- **`Directory does not have write permission` when setting the workspace.**
  This is a limitation of Vitis on Windows with WSL: Vitis refuses a workspace inside the WSL file system.
  In this case, set `WS_DIR` in `build_ps_app.py` to a folder on the Windows file system, only locally.
- **The build fails at random on Windows** (`ninja: build stopped: subcommand failed`, `CreateProcess`, `Access is denied` / error 5).
  This is likely caused by the antivirus locking files during the build.
  The script checks the output files and retries up to 5 times; if it still fails, run it again.
- **`xsct` hangs on `app create`.**
  In Vitis 2025.2 `app create` calls the classic Vitis, which is no longer available.
  Use `build_ps_app.py` instead.
