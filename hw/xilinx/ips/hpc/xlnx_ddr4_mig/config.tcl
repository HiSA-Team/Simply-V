# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: DDR4 SDRAM (MIG) IP configuration file

create_ip -name ddr4 -vendor xilinx.com -library ip -version 2.2 -module_name $::env(IP_NAME)

set_property -dict [list \
    CONFIG.System_Clock {Differential} \
    CONFIG.C0.DDR4_AUTO_AP_COL_A3 {true} \
    CONFIG.C0.DDR4_AxiAddressWidth {34} \
    CONFIG.C0.DDR4_AxiDataWidth {512} \
    CONFIG.C0.DDR4_AxiSelection {true} \
    CONFIG.C0.DDR4_CasLatency {17} \
    CONFIG.C0.DDR4_Ecc {true} \
    CONFIG.C0.DDR4_InputClockPeriod {3332} \
    CONFIG.C0.DDR4_Mem_Add_Map {ROW_COLUMN_BANK_INTLV} \
    CONFIG.C0.DDR4_MemoryPart {MTA18ASF2G72PZ-2G3} \
    CONFIG.C0.DDR4_MemoryType {RDIMMs} \
    CONFIG.C0.DDR4_TimePeriod {833} \
] [get_ips $::env(IP_NAME)]

# Use envvars out of list
set_property CONFIG.C0.DDR4_AxiIDWidth    $::env(MBUS_ID_WIDTH)    [get_ips $::env(IP_NAME)]