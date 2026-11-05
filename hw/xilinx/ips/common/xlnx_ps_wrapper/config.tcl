# Author: Federica Sarnataro
# Description: Zynq-7000 Processing System (PS7) in a Block Design, packaged as an IP.
#   Xilinx supports the PS7 only inside a Block Design, so the Block Design with the
#   PS is packaged as an IP and used as any other IP of the Simply-V IPs flow.
#   The PS is configured with the board preset (DDR, MIO, clocks), then the ports
#   towards Simply-V are enabled:
#     - M_AXI_GP0     : PS master port, towards the Simply-V MBUS, at 0x4000_0000 (1 GB),
#                       converted from AXI3 to AXI4 inside the Block Design
#     - S_AXI_GP0     : PS slave port, from the Simply-V MBUS,
#                       AXI4-Lite, converted to AXI3 inside the Block Design
#     - FCLK_CLK0     : PS fabric clock, 125 MHz (input of xlnx_clk_wiz_zynq)
#     - FCLK_RESET0_N : PS fabric reset (active low)
#   The hardware platform (.xsa) of the PS is exported for the PS software.
#
# TODO55: this IP lives in ips/common as a placeholder, but it only builds for
#   Zynq-7000 targets (e.g. Pynq-Z1). The PS does not exist on other parts
#   (e.g. Arty-A7), where the build of this IP fails. Until the IP selector
#   (#55) is available, this IP is filtered out in make/environment.mk for
#   boards without a PS.

# Create the Block Design
set bd_name $::env(IP_NAME)_bd
create_bd_design $bd_name

# Add the PS and apply the board preset, with DDR and FIXED_IO external
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} $ps

# Enable the ports towards Simply-V
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0                 {1}   \
    CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {1}   \
    CONFIG.PCW_USE_S_AXI_GP0                 {1}   \
    CONFIG.PCW_EN_CLK0_PORT                  {1}   \
    CONFIG.PCW_EN_RST0_PORT                  {1}   \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ      {125} \
] $ps

# Make the clocks and reset external, keeping the PS port names
foreach pin {FCLK_CLK0 FCLK_RESET0_N M_AXI_GP0_ACLK S_AXI_GP0_ACLK} {
    make_bd_pins_external [get_bd_pins ps7/$pin]
    set_property name $pin [get_bd_ports ${pin}_0]
}

# M_AXI_GP0: AXI3 to AXI4 converter inside the Block Design, so that this IP exports AXI4,
# in the M_AXI_GP0_ACLK domain
set gp0_conv [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 m_axi_gp0_axi3_to_axi4]
set_property -dict [list \
    CONFIG.SI_PROTOCOL      {AXI3}       \
    CONFIG.MI_PROTOCOL      {AXI4}       \
    CONFIG.READ_WRITE_MODE  {READ_WRITE} \
] $gp0_conv
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins m_axi_gp0_axi3_to_axi4/S_AXI]
connect_bd_net [get_bd_ports M_AXI_GP0_ACLK] [get_bd_pins m_axi_gp0_axi3_to_axi4/aclk]
# Converter reset: FCLK_RESET0_N synchronized to its clock (M_AXI_GP0_ACLK) by a proc_sys_reset
set gp0_rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 m_axi_gp0_rst]
connect_bd_net [get_bd_ports M_AXI_GP0_ACLK] [get_bd_pins m_axi_gp0_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports FCLK_RESET0_N]  [get_bd_pins m_axi_gp0_rst/ext_reset_in]
connect_bd_net [get_bd_pins m_axi_gp0_rst/peripheral_aresetn] [get_bd_pins m_axi_gp0_axi3_to_axi4/aresetn]
make_bd_intf_pins_external [get_bd_intf_pins m_axi_gp0_axi3_to_axi4/M_AXI]
set_property name M_AXI_GP0 [get_bd_intf_ports M_AXI_0]

# S_AXI_GP0: AXI4-Lite to AXI3 converter inside the Block Design, so that this IP exports AXI4-Lite,
# in the S_AXI_GP0_ACLK domain. The MBUS IDs are stored outside, by xlnx_axi4_to_axilite_d32_converter
set sgp0_conv [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 s_axi_gp0_axilite_to_axi3]
set_property -dict [list \
    CONFIG.SI_PROTOCOL      {AXI4LITE}   \
    CONFIG.MI_PROTOCOL      {AXI3}       \
    CONFIG.READ_WRITE_MODE  {READ_WRITE} \
] $sgp0_conv
connect_bd_intf_net [get_bd_intf_pins s_axi_gp0_axilite_to_axi3/M_AXI] [get_bd_intf_pins ps7/S_AXI_GP0]
connect_bd_net [get_bd_ports S_AXI_GP0_ACLK] [get_bd_pins s_axi_gp0_axilite_to_axi3/aclk]
# Converter reset: FCLK_RESET0_N synchronized to its clock (S_AXI_GP0_ACLK) by a proc_sys_reset
set sgp0_rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 s_axi_gp0_rst]
connect_bd_net [get_bd_ports S_AXI_GP0_ACLK] [get_bd_pins s_axi_gp0_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports FCLK_RESET0_N]  [get_bd_pins s_axi_gp0_rst/ext_reset_in]
connect_bd_net [get_bd_pins s_axi_gp0_rst/peripheral_aresetn] [get_bd_pins s_axi_gp0_axilite_to_axi3/aresetn]
make_bd_intf_pins_external [get_bd_intf_pins s_axi_gp0_axilite_to_axi3/S_AXI]
set_property name S_AXI_GP0 [get_bd_intf_ports S_AXI_0]

# Address map: Simply-V in the whole M_AXI_GP0 window (base first, then range)
assign_bd_address
set gp0_seg [get_bd_addr_segs ps7/Data/SEG_M_AXI_GP0_Reg]
set_property offset 0x40000000 $gp0_seg
set_property range  1G         $gp0_seg

# Validate, save and create the HDL wrapper
validate_bd_design
save_bd_design
make_wrapper -files [get_files $bd_name.bd] -top -import
generate_target all [get_files $bd_name.bd]

# Export the hardware platform of the PS, for the PS software (xsct)
write_hw_platform -fixed -force $::env(IP_DIR)/build/$::env(IP_NAME).xsa

# Package the Block Design as an IP and import it, as for the custom IPs
set ip_repo $::env(IP_DIR)/build/ip_repo
ipx::package_project -root_dir $ip_repo -vendor user.org -library user -taxonomy /UserIP -module $bd_name -import_files
ipx::save_core [ipx::current_core]
set_property ip_repo_paths $ip_repo [current_project]
update_ip_catalog
create_ip -vlnv user.org:user:${bd_name}:1.0 -module_name $::env(IP_NAME)
