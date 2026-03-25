# Import IP by version
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name $::env(IP_NAME)

# Configure IP
set_property -dict [list CONFIG.C_NUM_PROBE_OUT       {2}   \
                         CONFIG.C_PROBE_OUT0_WIDTH    {1}   \
                         CONFIG.C_PROBE_OUT1_WIDTH    {1}   \
                         CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
                         CONFIG.C_NUM_PROBE_IN        {1}   \
                         CONFIG.C_PROBE_IN0_WIDTH     {1}   \
                   ] [get_ips $::env(IP_NAME)]

# Setup VIO_reset value (mapped on probe 0)
set_property CONFIG.C_PROBE_OUT0_INIT_VAL $::env(VIO_RESETN_DEFAULT)     [get_ips $::env(IP_NAME)]