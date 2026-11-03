# SoC Simulation

The embedded SoC runs on two backends over the same DUT, selected with `BACKEND`:

    make sim TEST=hello_world                  # Verilator (default), from the repo root
    BACKEND=xsim make sim TEST=hello_world     # Vivado xsim

The DUT is the Simply-V RTL with the `VERIFICATION` seam (`simplyv_sim_wrapper.sv`): the
testbench drives the clocks, the PLL lock and the core reset (in place of clk_wiz and the VIO),
and loads the program through the AXI port of `sys_master` (in place of JTAG2AXI). The Xilinx
IPs are the funcsim netlists of their `make ips` builds; the BRAMs use the Xilinx behavioural
model (encrypted core), and on 64-bit SoCs `xlnx_axi_dwidth_64_to_32_converter` uses the model in
`models/` (encrypted FIFO). Vivado is therefore needed on both backends.

| | Verilator | xsim |
|-|-|-|
| Testbench | `verilator/tb/simplyv/simplyv_tb.cpp` | `xsim/tb/simplyv/simplyv_tb.sv` |
| AXI master VIP | `verilator/vip/axi_master.hpp` | Xilinx AXI VIP |
| UART VIP | `verilator/vip/uart.hpp` | in the testbench |
| Xilinx primitives | unisims copied from Vivado with the `=== 1'bz` checks folded, behind the LUT/FF models in `verilator/prims/` | `unisims_ver` |

## Flow

`make sim` regenerates the config from the CSVs with a simulation overlay, then builds what is
out of date and runs `TEST`:

1. Overlay: every MBUS slave on the main clock (one clock in simulation, so no PBUS clock
   converter), the uartlite at `SIM_UART_BAUD` (128000, the highest baud rate the IP accepts
   at 20 MHz), and the `CORE=` and `XBAR_IMPL=` overrides.
2. `make ips` for the Xilinx IPs of the DUT. The IPs whose `config.tcl` changes are rebuilt,
   also when switching between the simulation and the FPGA config (e.g. the uartlite), and so
   are the IPs rebuilt in between by a flow that does not record their config (an older branch).
3. `config_sim` writes `generated/simplyv.f`, the filelist of both backends.
4. The example is built, and the testbench holds the core in reset, writes the binary to BRAM_0
   with the word writes of `load_binary`, releases the core and compares the UART output with
   `stimuli/golden/<TEST>.uart.golden` (`[EMB] PASS`/`[EMB] FAIL`). `stimuli/<TEST>.in`, if
   present, is sent on the UART after the firmware prompt.

The tracked files the regen rewrites are restored when the run ends, also on Ctrl-C; a backup
left by a killed run is restored by the next `make sim`. To repair the tree by hand instead
(e.g. `git checkout`, `make config`), delete `build/config_backup.tar` first, or the next
`make sim` restores the stale backup. One sim per checkout: a second concurrent one fails on a
lock.

## Cores and tests

The core is `CORE_SELECTOR` in `config/configs/common/config_system.csv`, or an override for
one run:

    make sim CORE=<ibex|cv32e40p|picorv32|cv64a6|cv64a6_ara> TEST=<test> [XBAR_IMPL=CUSTOM]

Tests: `hello_world`, `echo`, `interrupts` (shorter timer periods in simulation) and
`xlnx_cdma_examples` (one round; RV32 only). picorv32 has no standard interrupt CSRs, so
`interrupts` does not run on it. The MicroBlaze-V cores have no simulation cone.

The run length is set by the characters the firmware prints (10 UART bit periods each, 160
cycles per bit at 128000 baud): `SIM_MAX_CYCLES` caps it (default 32000 bit periods, so it
follows `SIM_UART_BAUD`), and the run ends as soon as the golden is matched. Both backends count
the cycles from the core reset release, after the load. The UART VIPs take the bit period from
the uartlite `config.tcl`.

Prerequisites: Vivado (2024.2: the testbenches name its AXI VIP, `axi_vip_v1_1_19`),
Verilator 5, the `riscv32-unknown-elf-*` and `riscv64-unknown-elf-*` toolchains and the config
flow Python (`PYTHON=...`) on `PATH`, and the `sw/SoC/lib/tinyio` submodule.

## Crossbar benches

    make -C hw/xilinx sim_xsim_xbar [XBAR_IMPL=CUSTOM]

xsim benches of the MBUS and PBUS crossbars with the Xilinx AXI VIP, one directory per IP:
`xsim/tb/mbus_xbar/` and `xsim/tb/pbus_xbar/` (`sim_xsim_mbus_xbar` and `sim_xsim_pbus_xbar`
run one). Each crossbar IP is rebuilt first if its `config.tcl` changed.

## Local CI

    PYTHON=<python of the config flow env> bash hw/xilinx/sim/ci/run_ci.sh

pytest, then Verilator: every core with the Xilinx crossbar and ibex with the custom one, on
every test they support. `cv64a6_ara` runs `hello_world` only; `SIM_CI_FULL=1` runs its full
suite. xsim is not in CI.
