# Author: Federica Sarnataro
# Description: Clock wizard of the zynq profile, fed by the PS fabric clock
#   FCLK_CLK0 at 125 MHz (see xlnx_ps_wrapper). Same output clocks as
#   xlnx_clk_wiz (100, 50, 20, 10 MHz), with the MMCM settings derived by
#   Vivado for the 125 MHz input.
#
# TODO55: this IP lives in ips/common as a placeholder, but it is only used
#   with the Zynq-7000 PS (e.g. Pynq-Z1). Until the IP selector (#55) is
#   available, this IP is filtered out in make/environment.mk for boards
#   without a PS.

# Import IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name $::env(IP_NAME)

# Configure IP
set_property -dict [list CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
                        CONFIG.PRIM_IN_FREQ {125.000} \
                        CONFIG.RESET_BOARD_INTERFACE {Custom} \
                        CONFIG.RESET_TYPE {Active_Low} \
                        CONFIG.CLKOUT2_USED {true} \
                        CONFIG.CLKOUT3_USED {true} \
                        CONFIG.CLKOUT4_USED {true} \
                        CONFIG.CLK_OUT1_PORT {clk_100} \
                        CONFIG.CLK_OUT2_PORT {clk_50} \
                        CONFIG.CLK_OUT3_PORT {clk_20} \
                        CONFIG.CLK_OUT4_PORT {clk_10} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
                        CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {50.000} \
                        CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {20.000} \
                        CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {10.000} \
                        CONFIG.PRIM_SOURCE {No_buffer} \
                        CONFIG.USE_RESET {true} \
                        CONFIG.NUM_OUT_CLKS {4} \
					] [get_ips $::env(IP_NAME)]
