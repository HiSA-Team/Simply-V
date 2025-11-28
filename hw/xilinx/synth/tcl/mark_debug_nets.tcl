# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Mark nets in the post-syntesis netlist for debug

#######
# AXI #
#######

# CVA6
set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/cva6_axi*]
# Ara
set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/ara_narrow_axi*]
# AXI Inval filter
#set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/inst/ara_axi_inval_filter_u/*]
# DTM
#set_property mark_debug true [get_nets rv_socket_u/dm_rv64_gen.riscv_dbg_u/*axi*]

#####################
# Microarchitecture #
#####################

# Accelerator interface
#set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/inst/acc_req*]
#set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/inst/acc_resp*]

# Exception CSRs
# set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/inst/rvfi_probes_cva6\[*mepc* ]
# set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/inst/rvfi_probes_cva6\[*mcause* ]
# set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/inst/rvfi_probes_cva6\[*mtval* ]

# Debug request
set_property mark_debug true [get_nets rv_socket_u/debug_req_core]
# PC
# set_property mark_debug true [get_nets rv_socket_u/core_cv64a6_ara.cv64a6_ara_core/inst/cva6_u/pc_commit*] # done in sources


