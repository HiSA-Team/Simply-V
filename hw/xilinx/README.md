# Xilinx FPGA Flow
This tree holds the building environment for Xilinx FPGAs.

## Installation

Additional installation-related technical documentation can be found in the `doc/` folder for:
* [UART FDTI connection](doc/UART_CONNECTION.md).
* [Board-specific installation instructions](doc/BOARDS_INSTALLATION.md).
* [Linux-specific instructions for Vivado](doc/INSTALL_CABLE_DRIVERS.md).
* [Vivado-specific patches](doc/VIVADO_PATCHES.md).


## Build Bitstream and Program Device
In order to build the bitstream all sources for custom IPs must be available for the project.
Check [hw/units/README.md](../units/README.md) for more info.

To build Xilinx and custom IPs:
``` bash
make ips -j <jobs>
make ips/<IP name>.xci # For a single IP
```

To build the bitstream just run:
``` bash
make bistream
```
Bitstream build parameters:

| Parameter           | Description                                   | Default                    | Supported values          |
|---------------------|-----------------------------------------------|----------------------------|---------------------------|
| SYNTH_STRATEGY      | Vivado synthesis strategy                     | Flow_PerfOptimized_high    | Vivado version compatible |
| IMPL_STRATEGY       | Vivado implementation strategy                | Performance_ExtraTimingOpt | Vivado version compatible |
| HIGH_PERF_BUILD     | Select high-performance of development build  | 0                          | 0,1                       |
| HIGH_PERF_ROUTING   | Routing directive if `HIGH_PERF_BUILD=1`      | HigherDelayCost            | Vivado version compatible |
| XILINX_ILA          | Enable ILA for marked nets  (see below)       | 0                          | 0,1                       |
| XILINX_ILA_CLOCK    | Clock for ILA probes                          | main_clk                   | Legal clock in the design |

Once the build is completed, program target device running:
``` bash
make program_bitstream
```
Program bitstream parameters:
| Parameter                | Description               | Default         | Supported values |
|--------------------------|---------------------------|-----------------|------------------|
| XILINX_VIVADO_MODE       | Vivado `-mode` flag value | batch           | batch, tcl, gui  |
| XILINX_PROJECT_BUILD_DIR | Target build directory    | hw/xilinx/build | Legal directory  |
| XILINX_BITSTREAM         | Target bitstream file     | `${XILINX_PROJECT_BUILD_DIR}`/uninasoc.runs/impl_1/uninasoc.bit | Legal file path  |
| XILINX_PROBE_LTX         | Target probe file         | `${XILINX_PROJECT_BUILD_DIR}`/uninasoc.runs/impl_1/uninasoc.ltx | Legal file path  |

## Directory Structure
This tree is structured as follows:
```
├── ips                             # Xilinx IPs directory
│   ├── common                      # Common IPs (both hpc and embedded)
│   │   ├── tcl                     # Common IP flow scripts
│   │   |   ├── post_config.tcl
|   |   |   └── pre_config.tcl
│   |   └── <ip_name>               # IP directory, configuration-specific
│   │       └── config.tcl          # Script setting IP properties
|   ├── embedded                    # Embedded IPs
|   └── hpc                         # HPC IPs
├── make                            # Included Makefiles
├── Makefile                        # Top Make file for Xilinx flow
├── README.md                       # This file
├── rtl                             # RTL sources
├── scripts                         # Utilty scripts
├── sim                             # Xilinx-specific simulation
└── synth                           # Xilinx-specific synthesis
    ├── constraints                 # Constraint files for Xilinx FPGA designs
    └── tcl                         # Synthesis-related TCL scripts
```

## IPs Flow
The system features both Xilinx-provided and custom IPs.

### Add and Configure a Xilinx IP
IPs are characterized by being profile-specific (hpc or embedded) or common:
* `ips/common/`
* `ips/embedded/`
* `ips/hpc/`

The name of the directory will be the name of your IP in the design. In the directory, put a single file `config.tcl` with the two basic commands to import your target IP:
* `create_ip ... -module_name $::env(IP_NAME)`
* `set_property -dict [list CONFIG.<property_key> {<property_value>} CONFIG.<property_key> {<property_value>} ...] [get_ips $::env(IP_NAME)]`

(Re-)configure the IP by:
1. Editing the property keys and values in `config.tcl`;
2. Running `make ips/<ip_name>.xci`
> NOTE: Vivado versions must match between IP build and IP import during system build.

## Custom IPs
Custom IPs are built alongside Xilinx IPs.

For further info on custom IPs see [related documentation](../units/README.md).

## In-system Debug Probing with Xilinx ILAs
This environment supports the automatic insertion of Internal Logic Analyzer (ILA) probes, ([PG172](https://docs.amd.com/v/u/en-US/pg172-ila) ).

ILA probes are enabled by default, and can be disabled by setting the envvar `XILINX_ILA=0`.
To add probe on a net, you should mark it as `MARK_DEBUG=1` or `TRUE`, in one of the following ways:
* Mark it in RTL with a source code specifier, e.g. `(* MARK_DEBUG = "TRUE" *) wire debug_wire;`
* Mark it in the [hw/xilinx/synth/tcl/mark_debug_nets.tcl](hw/xilinx/synth/tcl/mark_debug_nets.tcl) script, e.g. `set_property MARK_DEBUG true [get_nets ...]`

### Notes on Using ILAs
1. Using the ILA core adds a few minutes to the synthesis flow.
2. Max 1023 nets can be probed in the current single-ILA setup.
3. Adding many probes might complicate the design and make it more difficult to route.

## Running Software
To load and run software on the platform, check the [related documentation](doc/PROGRAM_LOADING.md).
