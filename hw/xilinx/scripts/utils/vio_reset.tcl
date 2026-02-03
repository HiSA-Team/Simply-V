# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Utility script to toggle (1 -> 0) VIO probe
# Args:
#  $1: VIO probe name

##############
# Parse args #
##############
if { $argc != 1 } {
    puts "Usage: vio_reset.tcl <probe_name>"
    puts "probe_name    : name of probe to toggle"
    return
}
set probe_name        [lindex $argv 0]

##############
# VIO toggle #
##############

# Select VIO instance
set vio_name "vio_inst"
puts "\[INFO\] Searching for VIO $vio_name"
set hw_vio [get_hw_vios -of_objects [get_hw_devices $hw_device] -filter {CELL_NAME=~vio_inst}]
if {$hw_vio == "" } {
    error "\[ERROR\] VIO $vio_name not found!"
    return
}
puts $hw_vio

# Select probe
puts "\[INFO\] Searching for probe $probe_name"
set hw_probe [get_hw_probes $probe_name -of_objects [get_hw_vios $hw_vio]]
if { $hw_probe == "" } {
    error "\[ERROR\] Probe $probe_name not found!"
    return
}
puts $hw_probe

# Set 1
set value 1
puts "\[INFO\] Setting probe $probe_name to $value"
set_property OUTPUT_VALUE $value [get_hw_probes $hw_probe]
commit_hw_vio [get_hw_probes $hw_probe]

# Wait 0.5s
puts "\[INFO\] Waiting 0.5 seconds..."
after 500

# Set 0
set value 0
puts "\[INFO\] Setting probe $probe_name to $value"
set_property OUTPUT_VALUE $value [get_hw_probes $hw_probe]
commit_hw_vio [get_hw_probes $hw_probe]
