#  **README.md — Dual MicroBlaze-V Integration on Simply-V SoC**

## **Overview**

This project extends *Simply-V* by integrating **two MicroBlaze-V RV32 cores** inside a **single rv_socket**, sharing the same UART and memory map while maintaining independent code and execution via XSCT/JTAG.

The document explains:

* how the hardware was modified
* how to configure the main bus
* how to generate the bitstream
* how to create software for the two cores
* how to load and execute the programs on the FPGA
* how to monitor UART output from both cores

---

# **1. Requirements**

### **Software (offline installation required)**

| Tool                          | Version                  | Notes                                                        |
| ----------------------------- | ------------------------ | ------------------------------------------------------------ |
| Vivado                        | 2024.2                   | Required for synthesis, implementation, bitstream generation |
| Vitis                         | 2024.2                   | Required for debugging via XSCT                              |
| riscv32-unknown-elf toolchain | Provided inside Simply-V | For compiling embedded software                              |

### **Hardware**

* Nexys4 DDR (Artix-7 XC7A100T)
* FTDI-USB (HW-417-V1.2)
* Single UART @ 9600 baud

---

# **2. Environment Setup**

Before running Vivado, Vitis, XSCT or any build script:

```bash
source /home/<user>/Xilinx/Vivado/2024.2/settings64.sh
```

XSCT is located at:

```bash
/home/<user>/Xilinx/Vivado/2024.2/xsct-trim/bin/xsct
```

---

# **3. Enabling Dual Debug Ports (MicroBlaze-V Debug Module)**

To control both MicroBlaze-V cores via XSCT, the MDM-V must expose **two debug ports**.

Edit:

```
hw/xilinx/ips/common/xlnx_microblazev_debug_module_v/config.tcl
```

Modify:

```tcl
set C_MB_DBG_PORTS 1
```

to:

```tcl
set C_MB_DBG_PORTS 2
```

---

# **4. Configuring the Main Bus**

Modify:

```
config/configs/embedded/config_main_bus.csv
```

Set:

```
NUM_SI,6
MASTER_NAMES,SYS_MASTER RV_SOCKET_DATA RV_SOCKET_INSTR RV_SOCKET_DATA1 RV_SOCKET_INSTR1 DBG_MASTER
```

These match the AXI declarations in `rv_socket.sv`.

Generate RTL files:

```bash
cd config/scripts
python3 declare_and_concat_buses_rtl.py ../configs/embedded/config_main_bus.csv
```

---

# **5. Propagating Config + Generating Bitstream**

From the HW folder:

```bash
cd hw/xilinx
make config     # Applies config and generates headers
make ips        # Regenerates IP including microblaze debug module
make bitstream  # Synthesis + Implementation
```

Output:

```
hw/xilinx/build/uninasoc.runs/impl_1/uninasoc.bit
```

---

# **6. FPGA Programming**

Open Vivado GUI:

```bash
make -C hw/xilinx open_gui
```

1. Open Hardware Manager
2. Open Target → Auto Connect
3. Program Device → select `uninasoc.bit`
4. LED “DONE” must turn on

Vivado can now be **closed**.

---

# **7. Software for Core0 and Core1**

Two copies of the example program were created:

```
sw/SoC/examples/hello_core0
sw/SoC/examples/hello_core1
```

Main programs differ only in a print statement:

```c
printf("Hello from CORE 0!\n");
```

and

```c
printf("Hello from CORE 1!\n");
```

---

# **8. Linker Script Split (Partitioning BRAM)**

The on-chip BRAM is split into two 32 KB regions:

* Core0 → `0x0000 – 0x7FFF`
* Core1 → `0x8000 – 0xFFFF`

Custom linker scripts:

```
sw/SoC/common/UninaSoC_core0.ld  
sw/SoC/common/UninaSoC_core1.ld
```

Each example links to its own script via:

```
hello_core0/ld/user.ld     → INCLUDE ../../common/UninaSoC_core0.ld
hello_core1/ld/user.ld     → INCLUDE ../../common/UninaSoC_core1.ld
```

---

# **9. Building the Programs**

```
cd sw
make
```

Expected output:

```
hello_core0.elf
hello_core1.elf
```

Verify memory regions with:

```bash
riscv64-unknown-elf-objdump -h hello_coreX.elf
```

---

# **10. Start hw_server **

Open terminal :

```bash
hw_server
```
Leave it open.
---

# **11. UART Output Terminal**

Open a new terminal and identify the FTDI device:

```bash
ls -l /dev/serial/by-id
```

Start Minicom @ 9600 baud:

```bash
minicom -D /dev/serial/by-id/<FTDI_DEVICE> -b 9600
```

---

# **12. Running the Programs on the FPGA (XSCT)**

In a new terminal start XSCT:

```bash
/home/<user>/Xilinx/Vivado/2024.2/xsct-trim/bin/xsct
```

Connect to hw_server:

```tcl
connect -url tcp:localhost:3121
targets
```

You should see:

```
6  Hart #0 (Running)
7  Hart #1 (Running)
```

### **Run program on Core 0**

```tcl
targets -set -filter {name =~ "Hart #0*"}
rst -processor
dow /path/to/hello_core0.elf
con
```

### **Run program on Core 1**

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

Both via **the same UART**, displayed in one Minicom window.

---

# **13. Functional Summary**

| Component       | Notes                                       |
| --------------- | ------------------------------------------- |
| UART            | Shared only one peripheral for whole SoC    |
| Memory          | BRAM partitioned manually via linker script |
| Debug interface | Two separate debug ports inside MDM-V       |
| Execution       | Via XSCT, no synchronization required       |



