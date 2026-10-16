# Author: Federica Sarnataro
# Description: AXI3 to AXI4-Lite protocol converter for the Zynq-7000 PS master port (M_AXI_GP0).
#              The PS GP ports are AXI3 with 12-bit IDs, the AXI4-Lite side drops the IDs,
#              then xlnx_axilite_to_axi4_d32_converter brings it back to AXI4 with the MBUS ID width.
# TODO55: quick workaround, this IP is only used with Zynq-7000 targets (filtered out in environment.mk)

# Import IP by version
create_ip -name axi_protocol_converter -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)

# Configure IP
set_property -dict  [list   CONFIG.SI_PROTOCOL      {AXI3} \
                            CONFIG.MI_PROTOCOL      {AXI4LITE} \
                            CONFIG.READ_WRITE_MODE  {READ_WRITE} \
                            CONFIG.TRANSLATION_MODE {2} \
                    ] [get_ips $::env(IP_NAME)]

# PS7 M_AXI_GP0: 32-bit data, 32-bit address, 12-bit ID
set_property CONFIG.DATA_WIDTH  32  [get_ips $::env(IP_NAME)]
set_property CONFIG.ADDR_WIDTH  32  [get_ips $::env(IP_NAME)]
set_property CONFIG.ID_WIDTH    12  [get_ips $::env(IP_NAME)]
