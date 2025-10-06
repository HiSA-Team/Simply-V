# Author: Vincenzo Maisto
# Description: Set Verilog defines for Ara/CVA6 sources,
#               then source the common IP script for further processing.

# Set verilog defines from Bender
source $::env(HW_UNITS_ROOT)/$::env(IP_NAME)/bender_vivado_defines.tcl

# Source common script
source $::env(XILINX_IPS_ROOT)/common/tcl/custom_config.tcl
