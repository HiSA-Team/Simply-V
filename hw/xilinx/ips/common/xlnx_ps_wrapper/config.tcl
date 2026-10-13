# Author: Federica Sarnataro
# Description: Block Design wrapping the Zynq-7000 Processing System (PS7).
#   The PS is configured with the board preset (DDR, MIO, clocks).
#   The BD exposes:
#     - M_AXI_GP0       : PS master port, towards the Simply-V MBUS
#     - S_AXI_GP0       : PS slave port, from the Simply-V MBUS
#     - FCLK_CLK0       : PS fabric clock
#     - FCLK_RESET0_N   : PS fabric reset (active low)
#     - M_AXI_GP0_ACLK  : clock input of M_AXI_GP0
#     - S_AXI_GP0_ACLK  : clock input of S_AXI_GP0
#     - DDR, FIXED_IO   : PS fixed I/O, to be routed to the top level
#
# TODO55: this IP lives in ips/common as a placeholder, but it only builds for
#   Zynq-7000 targets (e.g. Pynq-Z1). The PS does not exist on other parts
#   (e.g. Arty-A7), where the build of this IP fails. Until the IP selector
#   (#55) is available, this IP is filtered out in make/environment.mk for
#   boards without a PS.

# Create the Block Design, named as the IP
create_bd_design $::env(IP_NAME)

# Add the Zynq-7000 PS
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]

# Apply the board preset and make DDR and FIXED_IO external
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} $ps

# Enable the ports towards Simply-V
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_GP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT  {1} \
    CONFIG.PCW_EN_RST0_PORT  {1} \
] $ps

# Make the AXI interfaces external, keeping the PS port names
foreach intf {M_AXI_GP0 S_AXI_GP0} {
    make_bd_intf_pins_external [get_bd_intf_pins ps7/$intf]
    set_property name $intf [get_bd_intf_ports ${intf}_0]
}

# Make clocks and reset external, keeping the PS port names
foreach pin {FCLK_CLK0 FCLK_RESET0_N M_AXI_GP0_ACLK S_AXI_GP0_ACLK} {
    make_bd_pins_external [get_bd_pins ps7/$pin]
    set_property name $pin [get_bd_ports ${pin}_0]
}

# Assign addresses, validate and save
assign_bd_address
validate_bd_design
save_bd_design
