# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Program bitstream, assuming an open connection to a device

# Set programming files
set_property PROGRAM.FILE $::env(XILINX_BITSTREAM) $hw_device
program_hw_devices $hw_device
refresh_hw_device  $hw_device

puts "Query the design"
# Debug
report_property -all [get_hw_targets $hw_target]
# Search for hw probes
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices $::env(XILINX_FPGA_DEVICE)] 0]