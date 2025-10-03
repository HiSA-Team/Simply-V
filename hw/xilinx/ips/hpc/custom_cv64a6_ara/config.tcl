# Author:
# Description:

# Define the top_module name (NB: IP Name must be different from the top_module name)
set top_module custom_top_wrapper

# Define directories
set dir_name $::env(HW_UNITS_ROOT)/$::env(IP_NAME)
# set rtl_dir_name ${dir_name}/rtl
set unina_soc_dir $::env(XILINX_ROOT)/rtl

# Define paths for the uninasoc files (and wrapper file)
set mem_macro_path ${unina_soc_dir}/uninasoc_mem.svh
set axi_macro_path ${unina_soc_dir}/uninasoc_axi.svh
set pkg_path ${unina_soc_dir}/uninasoc_pkg.sv
set top_module_path ${dir_name}/${top_module}.sv


# Append svh files and top module
set src_file_list {}
lappend src_file_list ${mem_macro_path}
lappend src_file_list ${axi_macro_path}
lappend src_file_list ${pkg_path}
lappend src_file_list ${top_module_path}

# Import files by Bender script
source ${dir_name}/bender_vivado.tcl

# Package the IP with the specified file list and top module
source $::env(XILINX_SYNTH_TCL_ROOT)/package_ip.tcl
