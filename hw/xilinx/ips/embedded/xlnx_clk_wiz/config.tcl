# Import IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name $::env(IP_NAME)

# Configure IP
set_property -dict [list CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
                        CONFIG.PRIM_IN_FREQ $::env(BOARD_INPUT_CLK_MHZ) \
                        CONFIG.RESET_BOARD_INTERFACE {Custom} \
                        CONFIG.RESET_TYPE {Active_Low} \
                        CONFIG.CLKOUT2_USED {true} \
                        CONFIG.CLKOUT3_USED {true} \
                        CONFIG.CLKOUT4_USED {true} \
                        CONFIG.CLK_OUT1_PORT {clk_100} \
                        CONFIG.CLK_OUT2_PORT {clk_50} \
                        CONFIG.CLK_OUT3_PORT {clk_20} \
                        CONFIG.CLK_OUT4_PORT {clk_10} \
                        CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {50.000} \
                        CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {20.000} \
                        CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {10.000} \
                        CONFIG.PRIM_SOURCE {No_buffer} \
                        CONFIG.USE_RESET {true} \
                        CONFIG.MMCM_CLKOUT1_DIVIDE {20} \
                        CONFIG.MMCM_CLKOUT2_DIVIDE {50} \
                        CONFIG.MMCM_CLKOUT3_DIVIDE {100} \
                        CONFIG.NUM_OUT_CLKS {4} \
                        CONFIG.CLKOUT2_JITTER {132.683} \
                        CONFIG.CLKOUT2_PHASE_ERROR {87.180} \
                        CONFIG.CLKOUT3_JITTER {162.167} \
                        CONFIG.CLKOUT3_PHASE_ERROR {87.180} \
                        CONFIG.CLKOUT4_JITTER {188.586} \
                        CONFIG.CLKOUT4_PHASE_ERROR {87.180} \
					] [get_ips $::env(IP_NAME)]

