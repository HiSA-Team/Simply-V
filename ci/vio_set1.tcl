# =============================================================================
# Simply-V — VIO reset release script (used by the CI HIL job)
#
# Sets vio_resetn = 1, releasing the CPU/debug module from reset. Required
# before OpenOCD can successfully halt the core over JTAG — without this
# step, dtmcontrol stays at 0 and the debug module never responds.
# Assumes open_hw_manager.tcl has already run and connected/programmed
# the device.
# =============================================================================

set hw_vio [get_hw_vios -of_objects [get_hw_devices $::env(XILINX_HW_DEVICE)] -filter {CELL_NAME=~vio_inst}]
if { $hw_vio == "" } {
    error "\[CI\] VIO not found on device"
}

set hw_probe [get_hw_probes vio_resetn -of_objects [get_hw_vios $hw_vio]]
if { $hw_probe == "" } {
    error "\[CI\] Probe vio_resetn not found"
}

set_property OUTPUT_VALUE 1 [get_hw_probes $hw_probe]
commit_hw_vio [get_hw_probes $hw_probe]
puts "\[CI\] vio_resetn set to 1"
