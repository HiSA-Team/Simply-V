# Import IP
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $::env(IP_NAME)

# COE file to pre-load in BRAM
# The bootrom default value is currently a (non-compressed) nop-slide ending with a WFI.
# TODO: implementation of a proper bootrom is deferred to issue #36
set coe_file $::env(IP_DIR)/initRV$::env(MBUS_DATA_WIDTH).coe

puts "$coe_file"

# Set the bram depth
# WARNING: Do not change the following line, it is modified by config-based script
set bram_depth {16384}

# Use envvars out of list
set_property CONFIG.Write_Width_A $::env(MBUS_DATA_WIDTH)     [get_ips $::env(IP_NAME)]
set_property CONFIG.Read_Width_A  $::env(MBUS_DATA_WIDTH)     [get_ips $::env(IP_NAME)]
set_property CONFIG.Write_Width_B $::env(MBUS_DATA_WIDTH)     [get_ips $::env(IP_NAME)]
set_property CONFIG.Read_Width_B  $::env(MBUS_DATA_WIDTH)     [get_ips $::env(IP_NAME)]
set_property CONFIG.AXI_ID_Width  $::env(MBUS_ID_WIDTH)       [get_ips $::env(IP_NAME)]

# Configure IP
set_property -dict [list CONFIG.Interface_Type {AXI4} \
                        CONFIG.AXI_Slave_Type {Memory_Slave} \
			CONFIG.Use_AXI_ID {true} \
			CONFIG.Use_Byte_Write_Enable {TRUE} \
                        CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
                        CONFIG.Byte_Size {8} \
                        CONFIG.Assume_Synchronous_Clk {true} \
                        CONFIG.Operating_Mode_A {READ_FIRST} \
                        CONFIG.Operating_Mode_B {READ_FIRST} \
                        CONFIG.Enable_B {Use_ENB_Pin} \
                        CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
                        CONFIG.Use_RSTB_Pin {true} \
                        CONFIG.Reset_Type {ASYNC} \
                        CONFIG.Port_B_Clock {100} \
                        CONFIG.Port_B_Enable_Rate {100} \
                        CONFIG.EN_SAFETY_CKT {true} \
                        CONFIG.Load_Init_File {true} \
                        CONFIG.Coe_File $coe_file \
                        CONFIG.Fill_Remaining_Memory_Locations {true} \
                        CONFIG.Write_Depth_A $bram_depth \
                ] [get_ips $::env(IP_NAME)]