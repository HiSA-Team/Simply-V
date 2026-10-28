# Author: Federica Sarnataro
# Description: Zynq-7000 Processing System (PS7) in a Block Design, packaged as an IP.
#   Xilinx supports the PS7 only inside a Block Design, so the Block Design with the
#   PS is packaged as an IP and used as any other IP of the Simply-V IPs flow.
#   The PS is configured with the board preset (DDR, MIO, clocks), then the ports
#   towards Simply-V are enabled:
#     - M_AXI_GP0     : PS master port, towards the Simply-V MBUS, at 0x4000_0000 (1 GB)
#     - S_AXI_GP0     : PS slave port, from the Simply-V MBUS
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

# Make the AXI interfaces, clocks and reset external, keeping the PS port names
foreach intf {M_AXI_GP0 S_AXI_GP0} {
    make_bd_intf_pins_external [get_bd_intf_pins ps7/$intf]
    set_property name $intf [get_bd_intf_ports ${intf}_0]
}
foreach pin {FCLK_CLK0 FCLK_RESET0_N M_AXI_GP0_ACLK S_AXI_GP0_ACLK} {
    make_bd_pins_external [get_bd_pins ps7/$pin]
    set_property name $pin [get_bd_ports ${pin}_0]
}

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
