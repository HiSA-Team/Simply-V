
# Import IP
create_ip -name axi_uartlite -vendor xilinx.com -library ip -version 2.0 -module_name $::env(IP_NAME)
# Configure IP
set_property -dict [list                        \
                    CONFIG.C_BAUDRATE {9600}    \
                    CONFIG.C_DATA_BITS {8} \
                    CONFIG.C_S_AXI_ACLK_FREQ_HZ {250000000} \
                    CONFIG.PARITY {No_Parity} \
                      ] [get_ips $::env(IP_NAME)]

# UART frequency and BaudRate relationships

# Clock/Baudrate    9600    19200   38400   57600   115200
# 5Mhz              V       X       X       X       X
# 10Mhz             V       V       X       X       X
# 20Mhz             V       V       V       X       X
# 50Mhz             V       V       V       V       V
# 100Mhz            V       V       V       V       V