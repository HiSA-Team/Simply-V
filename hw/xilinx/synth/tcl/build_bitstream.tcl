# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: Create a Vivado project, import sources and IPs and run: elaboration,
#              synthesis and implementation up to bitstream generation.
# Input args:
#    None
# Note:
#   This script entirely relies on enironment variables

########################
# Setup Vivado project #
########################
# Create new project (force)
create_project $::env(XILINX_PROJECT_NAME) . -part $::env(XILINX_PART_NUMBER) -force
set_property board_part $::env(XILINX_BOARD_PART) [current_project]

#######################
# Suppress Message(s) #
#######################
source $::env(XILINX_SYNTH_TCL_ROOT)/suppress_messages.tcl

###################
# Verilog defines #
###################
source $::env(XILINX_SYNTH_TCL_ROOT)/verilog_defines.tcl

###############
# Add sources #
###############

# RTL
source $::env(XILINX_SYNTH_TCL_ROOT)/add_xilinx_sources.tcl

# Load constraints
import_files -fileset constrs_1 -norecurse $::env(XILINX_ROOT)/synth/constraints/$::env(XILINX_PROJECT_NAME).xdc
import_files -fileset constrs_1 -norecurse $::env(XILINX_ROOT)/synth/constraints/$::env(BOARD).xdc

# Import IPS
import_ip $::env(IP_LIST_XCI)

######################
# Project properties #
######################
# TODO: Which memory IP was this for?
set_property XPM_LIBRARIES XPM_MEMORY [current_project]

# Set top level module
set_property top $::env(XILINX_PROJECT_NAME) [current_fileset]

# Generate compilation order
update_compile_order -fileset sources_1

# Reports directory
set project_dir [get_property directory [current_project]]
set report_dir $project_dir/reports
exec mkdir -p $report_dir

##########
# Linter #
##########

# Run linter
set lint_filename $report_dir/lint.log
synth_design -lint -file $lint_filename

# Read-back file
set fp [open $lint_filename r]
set file_data [read $fp]
close $fp
# Parse for critical warnings
set lines [split $file_data "\n"]
set substring "CRITICAL WARNING"
set line_cnt 0
set critical_found "false"
foreach line_value $lines {
    set line_cnt [expr $line_cnt + 1]
    if {[string first $substring $line_value] != -1} {
        puts "\[ERROR\] Found $substring during linting! $lint_filename:$line_cnt"
        set critical_found "true"
    }
}
# Exit if found
if { $critical_found == "true" } {
    exit 1
}

###################
# RTL elaboration #
###################
synth_design -rtl -name rtl_1

#############
# Synthesis #
#############
# Set strategy
set_property STRATEGY                                           $::env(SYNTH_STRATEGY)   [get_runs synth_1]
# Preserve the net names and hierarchy for debug
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY          none                     [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.KEEP_EQUIVALENT_REGISTERS  true                     [get_runs synth_1]
# # Enable retiming in synthesis
# set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING                   true                     [get_runs synth_1]

# Run
launch_runs synth_1
wait_on_run synth_1
# Open synthesized design
open_run synth_1 -name synth_1
# Genate reports
check_timing -verbose                                       -file $report_dir/$::env(XILINX_PROJECT_NAME).post_synth.check_timing.rpt
report_utilization -hierarchical -hierarchical_percentage   -file $report_dir/$::env(XILINX_PROJECT_NAME).post_synth.utilization.rpt

############
# Add ILAs #
############
if { $::env(XILINX_ILA) == 1 } {
    source $::env(XILINX_SYNTH_TCL_ROOT)/mark_debug_nets.tcl
    source $::env(XILINX_SYNTH_TCL_ROOT)/add_ila.tcl
}

##################
# Implementation #
##################
# Runtime optimized build
# set_property "steps.place_design.args.directive"            "RuntimeOptimized"       [get_runs impl_1]
# set_property "steps.route_design.args.directive"            "RuntimeOptimized"       [get_runs impl_1]
# # Set strategy
set_property STRATEGY                                       $::env(IMPL_STRATEGY)    [get_runs impl_1]
# # Enable physical optimizations (longer runtime)
# set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED                 true                     [get_runs impl_1]
# set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED    true                     [get_runs impl_1]

# Run
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
# Open implemented design
open_run impl_1

# Generate reports
check_timing                                                              -file $report_dir/$::env(XILINX_PROJECT_NAME).post_impl.check_timing.rpt
report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack   -file $report_dir/$::env(XILINX_PROJECT_NAME).post_impl.timing_WORST_100.rpt
report_timing -nworst 1 -delay_type max -sort_by group                    -file $report_dir/$::env(XILINX_PROJECT_NAME).post_impl.timing.rpt
report_utilization -hierarchical -hierarchical_percentage                 -file $report_dir/$::env(XILINX_PROJECT_NAME).post_impl.utilization.rpt
report_timing_summary                                                     -file $report_dir/$::env(XILINX_PROJECT_NAME).post_impl.timing_summary.rpt

# Print info
puts "    \[REPORT\] prj         [current_project]
    \[REPORT\] strategy    [get_property STRATEGY       [get_runs]]
    \[REPORT\] status      [get_property status         [get_runs]]
    \[REPORT\] elapsed     [get_property stats.elapsed  [get_runs]]
    \[REPORT\] wns         [get_property stats.wns      [get_runs impl_1]]
    \[REPORT\] whs         [get_property stats.whs      [get_runs impl_1]]
"
