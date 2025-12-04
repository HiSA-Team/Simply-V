# Import IP by version
create_ip -name mdm_riscv -vendor xilinx.com -library ip -version 1.0 -module_name $::env(IP_NAME)

# Configure IP
set_property -dict [list CONFIG.C_DBG_MEM_ACCESS {0} \
						 CONFIG.C_DBG_REG_ACCESS {0} \
						 CONFIG.C_JTAG_CHAIN {2} \
	                     CONFIG.C_MB_DBG_PORTS {2} \
	                     CONFIG.C_USE_BSCAN {0} \
	                     CONFIG.C_USE_UART {0}
				   ] [get_ips $::env(IP_NAME)]
