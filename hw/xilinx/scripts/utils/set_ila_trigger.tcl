# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Set ILA triggers, control and arm
# Note: Assuming a single ILA IP in the design and hw_server already connected

#####################
# ILA configuration #
#####################
puts "\[ILA\] Setting triggers"

# Set trigger control
set_property CONTROL.TRIGGER_MODE       BASIC_ONLY  [get_hw_ilas]
set_property CONTROL.TRIGGER_CONDITION  OR          [get_hw_ilas]
set_property CONTROL.TRIGGER_POSITION   4096        [get_hw_ilas]

# Set triggers
set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes sys_master_to_xbar_axi_arvalid -of_objects [get_hw_ilas]]
set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes sys_master_to_xbar_axi_awvalid -of_objects [get_hw_ilas]]
set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes sys_master_to_xbar_axi_wvalid  -of_objects [get_hw_ilas]]

###########
# Arm ILA #
###########

# Display (empty) waveforms -> run immediate trigger
display_hw_ila_data [upload_hw_ila_data [get_hw_ilas]]

# Arm ILA
# puts "\[ILA\] Arming ILA"
# run_hw_ila [get_hw_ilas]