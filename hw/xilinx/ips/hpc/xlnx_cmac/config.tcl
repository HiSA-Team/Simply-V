# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: CMAC configuration file

create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name $::env(IP_NAME)

# TODO: For now the DIFFCLK_BOARD_INTERFACE and the ETHERNET_BOARD_INTERFACE are hardcoded. Need to be parametrized
set_property CONFIG.DIFFCLK_BOARD_INTERFACE qsfp0_156mhz [get_ips $::env(IP_NAME)]
set_property CONFIG.ETHERNET_BOARD_INTERFACE qsfp0_4x [get_ips $::env(IP_NAME)]

# QSFP0 CMAC core and GT quad are board dependent
if { $::env(BOARD) == "au280" } {
    set cmac_core_select {CMACE4_X0Y6}
    set gt_group_select  {X0Y40~X0Y43}
} else {
    # Alveo U250 (default)
    set cmac_core_select {CMACE4_X0Y8}
    set gt_group_select  {X1Y44~X1Y47}
}

# RX_MAX_PACKET_LEN: jumbo frames, needed by RoCE with PMTU larger than 1024 B
# INCLUDE_STATISTICS_COUNTERS: STAT_* counters readable through AXI-lite (used by sw/SoC/examples/hello_rdma)
set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.CMAC_CORE_SELECT $cmac_core_select \
  CONFIG.GT_GROUP_SELECT $gt_group_select \
  CONFIG.ENABLE_AXI_INTERFACE {1} \
  CONFIG.INCLUDE_STATISTICS_COUNTERS {1} \
  CONFIG.RX_MAX_PACKET_LEN {9600} \
  CONFIG.USER_INTERFACE {AXIS} \
  CONFIG.INCLUDE_RS_FEC {1} \
  CONFIG.GT_DRP_CLK {100} \
] [get_ips $::env(IP_NAME)]