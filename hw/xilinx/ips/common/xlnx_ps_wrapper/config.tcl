# Author: Federica Sarnataro
# Description: Zynq-7000 Processing System (PS7), as a plain Xilinx IP.
#   The PS is configured with the preset of the board part (DDR, MIO, clocks),
#   read from the preset.xml next to the board.xml. Then the ports towards
#   Simply-V are enabled:
#     - M_AXI_GP0     : PS master port, towards the Simply-V MBUS
#     - S_AXI_GP0     : PS slave port, from the Simply-V MBUS
#     - FCLK_CLK0     : PS fabric clock, 125 MHz (input of xlnx_clk_wiz_zynq)
#     - FCLK_RESET0_N : PS fabric reset (active low)
#
# TODO55: this IP lives in ips/common as a placeholder, but it only builds for
#   Zynq-7000 targets (e.g. Pynq-Z1). The PS does not exist on other parts
#   (e.g. Arty-A7), where the build of this IP fails. Until the IP selector
#   (#55) is available, this IP is filtered out in make/environment.mk for
#   boards without a PS.

# Import IP
create_ip -name processing_system7 -vendor xilinx.com -library ip -version 5.5 -module_name $::env(IP_NAME)
set ps [get_ips $::env(IP_NAME)]

# Read the processing_system7 section of the board preset
set board_dir [file dirname [get_property FILE_NAME [current_board_part]]]
set fp [open [file join $board_dir preset.xml] r]
set preset_xml [read $fp]
close $fp
set ps7_start [string first {name="processing_system7"} $preset_xml]
set ps7_end   [string first {</ip>} $preset_xml $ps7_start]
if { $ps7_start < 0 || $ps7_end < 0 } {
    puts "\[ERROR\] No processing_system7 preset found in $board_dir/preset.xml"
    exit 1
}
set ps7_preset [string range $preset_xml $ps7_start $ps7_end]

# Apply the preset values that differ from the IP defaults
foreach {-> name value} [regexp -all -inline {<user_parameter name="(CONFIG\.[^"]+)" value="([^"]*)"} $ps7_preset] {
    if { [get_property $name $ps] ne $value } {
        set_property $name $value $ps
    }
}

# Enable the ports towards Simply-V
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0            {1}   \
    CONFIG.PCW_USE_S_AXI_GP0            {1}   \
    CONFIG.PCW_EN_CLK0_PORT             {1}   \
    CONFIG.PCW_EN_RST0_PORT             {1}   \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125} \
] $ps
