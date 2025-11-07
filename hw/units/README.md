# Custom IP Implementation and Simulation

The source files for the custom IPs used in the SoC are located in this directory. These custom IPs are packaged using the Makefile IPs flow found in the `hw/xilinx` directory. Each IP's build and packaging process directly references the source files in `units/custom_IP_NAME`.

## Custom Units Integration

Each custom IP, or unit, is represented by two subdirectories: one in `hw/units` and another in `hw/xilinx/ips`.

```
├── units
│   └── custom_<IP name>
|       ├── assets/
|       ├── custom_top_wrapper.sv
|       └── fetch_sources.sh
└── xilinx
    ├── doc
    └── ips
        ├── common
        │   └── custom_<IP name>
        |       └── config.tcl -> ../tcl/custom_config.tcl
        ├── embedded
        └── hpc
```

These two directories must share the same name, both using the `custom_` prefix:
- The directory in `hw/xilinx/ips`, only need a `config.tcl` scrtipt, usually simply soft-linking to the `ips/common/config.tcl` file.
- The directory in `hw/units` must expose:
    1. A `fetch_sources.sh` script.
    1. A `custom_top_wrapper.sv` RTL source to wrap all RTL in a single top module.
    1. An  `assets/` directory holding any other file used by the one script or wrapper above, e.g. a configuration file, a static file list, an RTL source, etc.

If the custom IP originates from a remote repository (e.g., a GitHub project), the  `fetch_sources.sh` script should:
1. create an `rtl/` directory,
1. clone and copy all source files into the `rtl/` directory in a **flattened structure**, and
1. remove all temporary files created during this process.

> The `custom_template/` directory contains a template project for custom IPs, including a wrapper module and a script.

With such tree in place, you can fetch rtl sources for all custom IPs with:
```
make units
```

Once all sources are flattened in the `hw/units/<common|embedded|hpc>/custom_<IP name>` directory, the make flow in `hw/xilinx` will take care of building a out-of-context IP, `custom_<IP name>`, out of them.

### Using MEM and AXI interfaces

The file `custom_top_wrapper.sv` RTL wrapper can leverage platform-compatible interfaces, namely MEM, AXI4 and AXI-lite.

It can leverage the `hw/xilinx/rtl/uninasoc_mem.svh` and `hw/xilinx/rtl/uninasoc_axi.svh` headers (which are already included in the Vivado project packaging flow) to define macros for the MEM and AXI bus interfaces. While custom signals are allowed, we expect the custom IP to primarily communicate via either AXI (preferably) or MEM.

> NOTE: [[#121](https://github.com/HiSA-Team/Simply-V/issues/121)] Vivado does not allow macros when exporting SystemVerilog IPs.
So we can't import config-based parameters, e.g. `MBUS_ID_WIDTH`, and IP interfaces must be manually aligned with configuration.
