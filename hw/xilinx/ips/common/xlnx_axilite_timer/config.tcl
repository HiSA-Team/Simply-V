# Import IP
create_ip -name axi_timer -vendor xilinx.com -library ip -version 2.0 -module_name $::env(IP_NAME)
# Configure IP
set_property -dict [list \
                        CONFIG.COUNT_WIDTH      {32} \
                        CONFIG.GEN0_ASSERT      {Active_High} \
                        CONFIG.GEN1_ASSERT      {Active_High} \
                        CONFIG.TRIG0_ASSERT     {Active_High} \
                        CONFIG.TRIG1_ASSERT     {Active_High} \
                        CONFIG.enable_timer2    {1} \
                        CONFIG.mode_64bit       {0} \
                      ] [get_ips $::env(IP_NAME)]

# Note: ADDR_WIDTH is fixed at 5 bits, DATA_WIDTH is fixed at 32
