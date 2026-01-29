# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: XDMA configuration file
create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 -module_name $::env(IP_NAME)

set_property -dict [list \
  CONFIG.PCIE_BOARD_INTERFACE {Custom} \
  CONFIG.SYS_RST_N_BOARD_INTERFACE {Custom} \
  CONFIG.functional_mode {AXI_Bridge} \
  CONFIG.en_axi_slave_if {false} \
  CONFIG.pf0_bar0_scale {Megabytes} \
  CONFIG.pf0_bar0_size {32} \
  CONFIG.axisten_freq {250} \
  CONFIG.axi_data_width {64_bit} \
  CONFIG.s_axi_id_width $::env(MBUS_ID_WIDTH) \
  CONFIG.en_gt_selection {true} \
  CONFIG.mode_selection {Advanced} \
  CONFIG.pl_link_cap_max_link_speed {2.5_GT/s} \
  CONFIG.pl_link_cap_max_link_width {X8} \
  CONFIG.ref_clk_freq {100_MHz} \
  CONFIG.pciebar2axibar_0 {0x000000000000000} \
] [get_ips $::env(IP_NAME)]

# NOTE: The safe (and adopted) maximum BAR size is 32 MB on the MSI Z590 PLUS (MS-7D11) motherboard,
#       but it strictly depends on the motherboard.