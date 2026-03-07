## Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
## Description: Import RTL sources for Vivado

# Define a list of all the source files
set src_file_list [ list \
    $::env(XILINX_ROOT)/rtl/simplyv_pkg.sv                                        \
    $::env(XILINX_ROOT)/rtl/headers/simplyv_axi.svh                               \
    $::env(XILINX_ROOT)/rtl/headers/simplyv_pcie.svh                              \
    $::env(XILINX_ROOT)/rtl/headers/simplyv_ddr4.svh                              \
    $::env(XILINX_ROOT)/rtl/generated/interconnects/mbus_interconnect.svinc       \
    $::env(XILINX_ROOT)/rtl/generated/interconnects/pbus_interconnect.svinc       \
    $::env(XILINX_ROOT)/rtl/generated/interconnects/hbus_interconnect.svinc       \
    $::env(XILINX_ROOT)/rtl/generated/clk_assignments/mbus_clk_assignments.svinc  \
    $::env(XILINX_ROOT)/rtl/generated/clk_assignments/hbus_clk_assignments.svinc  \
    $::env(XILINX_ROOT)/rtl/wrappers/axi_clock_converter_wrapper.sv               \
    $::env(XILINX_ROOT)/rtl/wrappers/ddr4_channel_wrapper.sv                      \
    $::env(XILINX_ROOT)/rtl/wrappers/hls_conv2d_wrapper.sv                        \
    $::env(XILINX_ROOT)/rtl/wrappers/plic_wrapper.sv                              \
    $::env(XILINX_ROOT)/rtl/wrappers/clint_wrapper.sv                             \
    $::env(XILINX_ROOT)/rtl/wrappers/uart_wrapper.sv                              \
    $::env(XILINX_ROOT)/rtl/hbus.sv                                               \
    $::env(XILINX_ROOT)/rtl/pbus.sv                                               \
    $::env(XILINX_ROOT)/rtl/rv_socket.sv                                          \
    $::env(XILINX_ROOT)/rtl/sys_master.sv                                         \
    $::env(XILINX_ROOT)/rtl/virtual_uart.sv                                       \
    $::env(XILINX_ROOT)/rtl/simplyv.sv                                            \
]

# Add files to project
add_files -norecurse -fileset [current_fileset] $src_file_list
