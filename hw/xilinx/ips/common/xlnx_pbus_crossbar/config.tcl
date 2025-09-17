# This file is auto-generated with bus.py
# Import IP
create_ip -name axi_crossbar -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)
# Configure IP
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE} \
                         CONFIG.ADDR_WIDTH {32} \
                         CONFIG.DATA_WIDTH {32} \
                         CONFIG.ID_WIDTH {4} \
                         CONFIG.NUM_SI {1} \
                         CONFIG.NUM_MI {3} \
                         CONFIG.ADDR_RANGES {1} \
                         CONFIG.M00_A00_BASE_ADDR {0x20000} \
                         CONFIG.M01_A00_BASE_ADDR {0x20020} \
                         CONFIG.M02_A00_BASE_ADDR {0x20040} \
                         CONFIG.M00_A00_ADDR_WIDTH {4} \
                         CONFIG.M01_A00_ADDR_WIDTH {5} \
                         CONFIG.M02_A00_ADDR_WIDTH {5} \
                         ] [get_ips $::env(IP_NAME)]