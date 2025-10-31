# Workaround bug Vivado Opt 31-67 - unconnected LUT input in AXI CDMA
set_msg_config -id {Opt 31-67} -new_severity {Warning}

# Disabilita le ottimizzazioni che causano il bug
set_param logicopt.flow.disableLutPush true
set_param logicopt.flow.disableAggressiveOpt true

