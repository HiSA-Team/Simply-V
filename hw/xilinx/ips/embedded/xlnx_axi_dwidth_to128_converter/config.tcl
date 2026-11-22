# Description: Adapt the embedded AXI bus to the 128-bit DDR2 MIG interface.

create_ip -name axi_dwidth_converter -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)

set_property -dict [list \
    CONFIG.SI_DATA_WIDTH $::env(MBUS_DATA_WIDTH) \
    CONFIG.MI_DATA_WIDTH {128} \
    CONFIG.ADDR_WIDTH $::env(MBUS_ADDR_WIDTH) \
    CONFIG.SI_ID_WIDTH $::env(MBUS_ID_WIDTH) \
] [get_ips $::env(IP_NAME)]
