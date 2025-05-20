
## Description: Utility variables and macros for AXI interconnections in SimplyV

# Define a list of all the source files
set src_file_list [ list \
    $::env(XILINX_ROOT)/rtl/simplyv_pkg.sv                  \
    $::env(XILINX_ROOT)/rtl/simplyv_axi.svh                 \
    $::env(XILINX_ROOT)/rtl/simplyv_pcie.svh                \
    $::env(XILINX_ROOT)/rtl/simplyv_ddr4.svh                \
    $::env(XILINX_ROOT)/rtl/mbus_buses.svinc                 \
    $::env(XILINX_ROOT)/rtl/pbus_buses.svinc                 \
    $::env(XILINX_ROOT)/rtl/hbus_buses.svinc                 \
    $::env(XILINX_ROOT)/rtl/highperformance_bus.sv           \
    $::env(XILINX_ROOT)/rtl/hls_conv2d_wrapper.sv            \
    $::env(XILINX_ROOT)/rtl/simplyv_clk_assignments.svinc   \
    $::env(XILINX_ROOT)/rtl/axi_clock_converter_wrapper.sv   \
    $::env(XILINX_ROOT)/rtl/sys_master.sv                    \
    $::env(XILINX_ROOT)/rtl/rv_socket.sv                     \
    $::env(XILINX_ROOT)/rtl/virtual_uart.sv                  \
    $::env(XILINX_ROOT)/rtl/axilite_uart.sv                  \
    $::env(XILINX_ROOT)/rtl/peripheral_bus.sv                \
    $::env(XILINX_ROOT)/rtl/ddr4_channel_wrapper.sv          \
    $::env(XILINX_ROOT)/rtl/plic_wrapper.sv                  \
    $::env(XILINX_ROOT)/rtl/simplyv.sv                      \
    $::env(XILINX_ROOT)/rtl/plic_wrapper.sv                  \
]

# Add files to project
add_files -norecurse -fileset [current_fileset] $src_file_list