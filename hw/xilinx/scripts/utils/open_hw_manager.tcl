# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Open Vivado Hardware Manager and set probe file

# Connect to hw server
open_hw_manager
set url $::env(XILINX_HW_SERVER_HOST):$::env(XILINX_HW_SERVER_PORT)
if {[catch {connect_hw_server -url $url} 0]} {
    puts stderr "WARNING: Another connection is already up, proceeding using the existing connection instead"
}
set target_path $::env(XILINX_HW_SERVER_HOST):$::env(XILINX_HW_SERVER_PORT)/$::env(XILINX_HW_SERVER_FPGA_PATH)

# Search the target with the right device
foreach target [get_hw_target $target_path] {
    open_hw_target $target
    # Let's keep JTAG frequency to 5000000 so that it works with all supported SoC frequencies
    set_property PARAM.FREQUENCY 5000000 [get_hw_targets $target]

    # Check if the actual target has the right device
    set hw_devices [get_hw_devices]
    set hw_device_id [lsearch -exact $hw_devices $::env(XILINX_HW_DEVICE)]

    # Set the hw device
    if {$hw_device_id >= 0} {
        set hw_target $target
        set hw_device [lindex $hw_devices $hw_device_id]
        break
    }

    # Close the hw target if not have the right device
    close_hw_target
}

# Set bitstream path
set_property PROGRAM.FILE $::env(XILINX_BITSTREAM) $hw_device

##############
# Probe file #
##############

# Add probe file
puts "\[ILA\] Using probe file $::env(XILINX_PROBE_LTX)"
if {[catch { exec ls $::env(XILINX_PROBE_LTX) } 0]} {
    puts "[INFO] Probe $::env(XILINX_PROBE_LTX) file not found"
} else {
    set_property PROBES.FILE      $::env(XILINX_PROBE_LTX) $hw_device
    set_property FULL_PROBES.FILE $::env(XILINX_PROBE_LTX) $hw_device
}
current_hw_device $hw_device

###################
# Get debug cores #
###################
refresh_hw_device $hw_device
