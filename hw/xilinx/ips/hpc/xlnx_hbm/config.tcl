# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: HBM IP configuration file

create_ip -name hbm -vendor xilinx.com -library ip -version 1.0 -module_name $::env(IP_NAME)

set_property -dict [list \
  CONFIG.USER_APB_EN {true} \
  CONFIG.USER_HBM_DENSITY {8GB} \
  CONFIG.USER_SAXI_00 {true} \
  CONFIG.USER_SAXI_01 {false} \
  CONFIG.USER_SAXI_02 {false} \
  CONFIG.USER_SAXI_03 {false} \
  CONFIG.USER_SAXI_04 {false} \
  CONFIG.USER_SAXI_05 {false} \
  CONFIG.USER_SAXI_06 {false} \
  CONFIG.USER_SAXI_07 {false} \
  CONFIG.USER_SAXI_08 {false} \
  CONFIG.USER_SAXI_09 {false} \
  CONFIG.USER_SAXI_10 {false} \
  CONFIG.USER_SAXI_11 {false} \
  CONFIG.USER_SAXI_12 {false} \
  CONFIG.USER_SAXI_13 {false} \
  CONFIG.USER_SAXI_14 {false} \
  CONFIG.USER_SAXI_15 {false} \
  CONFIG.USER_SAXI_16 {false} \
  CONFIG.USER_SAXI_17 {false} \
  CONFIG.USER_SAXI_18 {false} \
  CONFIG.USER_SAXI_19 {false} \
  CONFIG.USER_SAXI_20 {false} \
  CONFIG.USER_SAXI_21 {false} \
  CONFIG.USER_SAXI_22 {false} \
  CONFIG.USER_SAXI_23 {false} \
  CONFIG.USER_SAXI_24 {false} \
  CONFIG.USER_SAXI_25 {false} \
  CONFIG.USER_SAXI_26 {false} \
  CONFIG.USER_SAXI_27 {false} \
  CONFIG.USER_SAXI_28 {false} \
  CONFIG.USER_SAXI_29 {false} \
  CONFIG.USER_SAXI_30 {false} \
  CONFIG.USER_SAXI_31 {false} \
  CONFIG.USER_XSDB_INTF_EN {true} \
] [get_ips $::env(IP_NAME)]