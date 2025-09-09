# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: CMAC XBAR (axilite) IP configuration file
#              This IP is used for accessing the CMAC subsystem register spaces
#              For now two components are present:
#                  - CMAC
#                  - AXI Stram FIFO

# Set base address this is modified by config-based script
set base_offset {0x40000}
set cmac_base_address [format 0x%X [expr $base_offset + 0x0]]
set axis_fifo_base_address [format 0x%X [expr $base_offset + 0x10000]]
set rules_match_engine_base_address [format 0x%X [expr $base_offset + 0x20000]]

# Import IP
create_ip -name axi_crossbar -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)
# Configure IP
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE} \
                         CONFIG.CONNECTIVITY_MODE {SAMD} \
                         CONFIG.ADDR_WIDTH {32} \
                         CONFIG.DATA_WIDTH {32} \
                         CONFIG.ID_WIDTH {2} \
                         CONFIG.NUM_SI {1} \
                         CONFIG.NUM_MI {3} \
                         CONFIG.ADDR_RANGES {1} \
                         CONFIG.STRATEGY {0} \
                         CONFIG.R_REGISTER {0} \
                         CONFIG.AWUSER_WIDTH {0} \
                         CONFIG.ARUSER_WIDTH {0} \
                         CONFIG.WUSER_WIDTH {0} \
                         CONFIG.RUSER_WIDTH {0} \
                         CONFIG.BUSER_WIDTH {0} \
                         CONFIG.M00_A00_BASE_ADDR $cmac_base_address \
                         CONFIG.M01_A00_BASE_ADDR $axis_fifo_base_address \
                         CONFIG.M02_A00_BASE_ADDR $rules_match_engine_base_address \
                         CONFIG.M00_A00_ADDR_WIDTH {16} \
                         CONFIG.M01_A00_ADDR_WIDTH {16} \
                         CONFIG.M02_A00_ADDR_WIDTH {16} \
                         ] [get_ips $::env(IP_NAME)]