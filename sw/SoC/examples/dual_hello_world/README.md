# Dual MicroBlaze-V Integration on Simply-V SoC

## Overview

This project extends Simply-V by integrating two MicroBlaze-V RV32 cores inside a single rv_socket, sharing the same UART and memory map while maintaining independent code and execution via `xsdb`/JTAG.

The document explains:

* how to configure Simply-V to use two cores
* how to generate the bitstream
* how to create software for the two cores
* how to load and execute the programs on the FPGA

# Configuring the Main Bus

Modify `config/configs/common/config_system.csv`, setting `CORE_SELECTOR`:

```
CORE_SELECTOR,CORE_DUAL_MICROBLAZEV_RV32
```

Modify `config/configs/embedded/config_main_bus.csv`, adding two additional `RV_SOCKET` ports:

```
NUM_SI,6
MASTER_NAMES,SYS_MASTER RV_SOCKET_DATA RV_SOCKET_INSTR RV_SOCKET_DATA1 RV_SOCKET_INSTR1 DBG_MASTER
```

> These names match the AXI ports of `rv_socket.sv`.

Generate RTL files and bitstream:

```bash
make config
make hw
```

# Software for Core0 and Core1

##  Functional Summary

| Component       | Notes                                       |
| --------------- | ------------------------------------------- |
| UART            | Shared only one peripheral for whole SoC    |
| Memory          | BRAM partitioned manually via linker script |
| Debug interface | Two separate debug ports inside MDM-V       |
| Execution       | Via `xsdb`, no synchronization required     |


Two copies of the example program were created:

```
sw/SoC/examples/dual_hello_wolrd/hello_core0.elf
sw/SoC/examples/dual_hello_wolrd/hello_core1.elf
```

Main programs differ only in a print statement:

```c
printf("Hello from CORE 0!\n");
```

and

```c
printf("Hello from CORE 1!\n");
```

## Linker Script Split (Partitioning BRAM)

The on-chip BRAM is split into two 32 KB regions:

* Core0 → `0x0000 – 0x7FFF`
* Core1 → `0x8000 – 0xFFFF`

Custom linker scripts:

```
sw/SoC/common/dual_hello_wolrd/hello_core0/user.ld
sw/SoC/common/dual_hello_wolrd/hello_core1/user.ld
```

## Building

```
make sw
```

## Running the Programs on the FPGA (`xsdb`)

In a new terminal start `xsdb`:

```bash
xsdb
```

Connect to hw_server:

```tcl
connect -url tcp:localhost:3121
targets
```

Among other targets, you should see:

```
6  Hart #0 (Running)
7  Hart #1 (Running)
```

### Run program on Core 0

```tcl
targets -set -filter {name =~ "Hart #0*"}
rst -processor
dow /path/to/hello_core0.elf
con
```

### Run program on Core 1

```tcl
targets -set -filter {name =~ "Hart #1*"}
rst -processor
dow /path/to/hello_core1.elf
con
```

### Expected UART output:

```
Hello from CORE 0!
Hello from CORE 1!
```

Both via the same UART, displayed in one TTY window.


