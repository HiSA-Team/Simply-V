// This file is auto-generated with crossbar_template.py
# Import IP
create_ip -name axi_crossbar -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)
# Configure IP
set_property -dict [list
CONFIG.PROTOCOL {AXI4} \
                         CONFIG.ADDR_WIDTH {32} \
                         CONFIG.DATA_WIDTH {512} \
                         CONFIG.ID_WIDTH {4} \
                         CONFIG.NUM_SI {2} \
                         CONFIG.NUM_MI {2} \
                         CONFIG.ADDR_RANGES {2} \
                         CONFIG.M00_A00_BASE_ADDR {0x0} \
                         CONFIG.M00_A01_BASE_ADDR {0x90000} \
                         CONFIG.M01_A00_BASE_ADDR {0x80000} \
                         CONFIG.M01_A01_BASE_ADDR {0x88000} \
                         CONFIG.M00_A00_ADDR_WIDTH {19} \
                         CONFIG.M00_A01_ADDR_WIDTH {16} \
                         CONFIG.M01_A00_ADDR_WIDTH {15} \
                         CONFIG.M01_A01_ADDR_WIDTH {15}
 \

] [get_ips $::env(IP_NAME)]
