# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description: Package Vivado IP from $src_file_list over $top_module, from an opened project
# Input args:
#    None

# Add files to project
import_files -norecurse -fileset [current_fileset] $src_file_list
update_compile_order -fileset sources_1
set_property top ${top_module} [current_fileset]

# Suppress: WARNING: [IP_Flow 19-3833] Unreferenced file from the top module is not packaged: <...>.
set_msg_config -id {[IP_Flow 19-3833]} -suppress

# Package the IP and update the catalog
ipx::package_project -root_dir $::env(IP_DIR)/build/$::env(IP_PRJ_NAME).srcs/sources_1/imports -vendor user.org -library user -taxonomy /UserIP
set_property name $::env(IP_PRJ_NAME) [ipx::current_core]
set_property core_revision 2 [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
set_property  ip_repo_paths  $::env(IP_DIR)/build/$::env(IP_PRJ_NAME).srcs/sources_1/imports [current_project]
update_ip_catalog

# Import IP into the project
create_ip -vlnv user.org:user:$::env(IP_PRJ_NAME):1.0 -module_name $::env(IP_NAME)
