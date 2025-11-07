# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Cyril Koenig <cykoenig@iis.ee.ethz.ch>
# Description: Create an ILA core and attach all nets in the design marked as MARK_DEBUG.

# ILA clock from SoC design
# Choose a clock net as fast as the fastest net to probe
set ila_clk_net [get_nets $::env(XILINX_ILA_CLOCK)]

# Get market nets
set debug_nets [lsort -dictionary [get_nets -hier -filter {MARK_DEBUG == 1}]]

# Return if there is any marked net
if { ![llength $debug_nets] } {
    puts "\[ILA\] No nets marked for debug"
    return
}

# Create and configure debug core
puts "\[ILA\] Creating debug core..."
create_debug_core ila_u ila
set_property -dict [list \
        ALL_PROBE_SAME_MU       {true}  \
        ALL_PROBE_SAME_MU_CNT   {4}     \
        C_ADV_TRIGGER           {true}  \
        C_DATA_DEPTH            {16384} \
        C_EN_STRG_QUAL          {true}  \
        C_INPUT_PIPE_STAGES     {0}     \
        C_TRIGIN_EN             {false} \
        C_TRIGOUT_EN            {false} \
    ] [get_debug_cores ila_u]

# Connect SoC clock
set_property port_width 1 [get_debug_ports ila_u/clk]
connect_debug_port ila_u/clk [get_nets $ila_clk_net]

# Loop through debug nets (add extra list element to ensure last net is processed)
set net_name_last ""
set i 0
foreach net [concat $debug_nets {""}] {
    # Remove trailing array index
    regsub {\[[0-9]*\]$} $net {} net_name
    # Create probe after all signals with the same name have been collected
    if { $net_name_last != $net_name } {
        if { $net_name_last != "" } {
            puts "\[ILA\] Creating probe $i of width [llength $sig_list] for `$net_name_last`."
            # probe0 already exists, and does not need to be created
            if { $i != 0 } { create_debug_port ila_u probe }
            set_property port_width [llength $sig_list] [get_debug_ports ila_u/probe$i]
            # Set all probes both as data and trigger, although it might be overkill and could be simplified for more challenging designs
            set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports ila_u/probe$i]
            connect_debug_port ila_u/probe$i [get_nets $sig_list]
            incr i
        }
        set sig_list ""
    }
    lappend sig_list $net
    set net_name_last $net_name
}

# Save constraints, then implement the debug core
save_constraints -force
implement_debug_core
