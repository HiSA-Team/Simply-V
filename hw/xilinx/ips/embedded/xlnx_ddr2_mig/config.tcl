# Description: Nexys A7 DDR2 SDRAM (7-series MIG) IP configuration file

switch -glob -- "$::env(XILINX_PART_NUMBER) $::env(XILINX_BOARD_PART)" {
    "xc7a100tcsg324-1 digilentinc.com:nexys-a7-100t:part0:*" {
        set mig_project nexys_a7_100t.prj
    }
    "xc7a50ticsg324-1L digilentinc.com:nexys-a7-50t:part0:*" {
        set mig_project nexys_a7_50t.prj
    }
    default {
        error "Unsupported Nexys DDR2 board/part: $::env(XILINX_BOARD_PART) / $::env(XILINX_PART_NUMBER)"
    }
}

# MIG reads the AXI ID width from its project file. Configure a build copy.
set input [open $::env(IP_DIR)/$mig_project r]
set mig_config [read $input]
close $input
regsub {<ModuleName>[^<]*</ModuleName>} $mig_config \
    "<ModuleName>$::env(IP_NAME)</ModuleName>" mig_config
regsub {<C0_S_AXI_ID_WIDTH>[0-9]+</C0_S_AXI_ID_WIDTH>} $mig_config \
    "<C0_S_AXI_ID_WIDTH>$::env(MBUS_ID_WIDTH)</C0_S_AXI_ID_WIDTH>" mig_config
set mig_project [file normalize $::env(IP_DIR)/build/$::env(IP_NAME).prj]
set output [open $mig_project w]
puts -nonewline $output $mig_config
close $output

create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.2 -module_name $::env(IP_NAME)
set_property CONFIG.XML_INPUT_FILE $mig_project [get_ips $::env(IP_NAME)]
