# Author: Federica Sarnataro
# Description: AXI3 to AXI4 protocol converter for the Zynq-7000 PS master port (M_AXI_GP0).
#              With static remap the PS port has 6-bit IDs: the IDs pass unchanged, so the
#              MBUS ID width must be the same as the PS one.
# TODO55: quick workaround, this IP is only used with Zynq-7000 targets (filtered out in environment.mk)

# Import IP by version
create_ip -name axi_protocol_converter -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)

# Configure IP
set_property -dict  [list   CONFIG.SI_PROTOCOL      {AXI3} \
                            CONFIG.MI_PROTOCOL      {AXI4} \
                            CONFIG.READ_WRITE_MODE  {READ_WRITE} \
                    ] [get_ips $::env(IP_NAME)]

# PS7 M_AXI_GP0: 32-bit data, 32-bit address, MBUS ID width
set_property CONFIG.DATA_WIDTH  32                      [get_ips $::env(IP_NAME)]
set_property CONFIG.ADDR_WIDTH  32                      [get_ips $::env(IP_NAME)]
set_property CONFIG.ID_WIDTH    $::env(MBUS_ID_WIDTH)   [get_ips $::env(IP_NAME)]
