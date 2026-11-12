# PS DDR (Zynq-7000)

PS side of the PS DDR test.
The program runs bare-metal on the Cortex-A9 #0 of the Zynq-7000 PS and exchanges data with the Simply-V CPU through a shared area in the PS DDR, at `0x1000_0000`.
The Simply-V CPU reaches it through the `PSDDR` range of the MBUS and the PS slave port `S_AXI_GP0`, at the same address.
The CPU side is in `sw/SoC/examples/ps_ddr`.

The PS writes 8 words, the CPU reads and checks them and writes back their bitwise NOT, then the PS reads and checks them.
The CPU writes the DDR without passing through the PS caches, so the PS makes the shared area not cacheable (one 1 MB MMU section, with `Xil_SetTlbAttributes`) before using it.

## Build

Requirements: Simply-V configured and built for the `zynq` profile, as for `sw/host/zynq/ps_mailbox`.

Build the PS program with the Vitis Python API:
```
vitis -s sw/host/zynq/build_ps_app.py ps_ddr
```
The ELF is `sw/host/zynq/ps_ddr/bin/ps_ddr/build/ps_ddr.elf`.

Build the CPU program:
```
make -C sw/SoC/examples/ps_ddr
```

## Run

As for `sw/host/zynq/ps_mailbox`, with `ps_ddr` instead of `ps_mailbox`.

## Expected output

On the Simply-V UART:
```
[CPU] Shared area in the PS DDR at 0x10000000, waiting for the PS
[CPU] Read from the PS DDR [0]: 0xa5a50000
...
[CPU] Read from the PS DDR [7]: 0xa5a50007
[CPU] PS words OK, wrote back their bitwise NOT
```

On the PS UART (115200 baud):
```
[PS] Shared area in the DDR at 0x10000000, waiting for the CPU
[PS] Wrote 8 words to the DDR
[PS] Read from the CPU [0]: 0x5A5AFFFF
...
[PS] Read from the CPU [7]: 0x5A5AFFF8
[PS] Test passed
```
