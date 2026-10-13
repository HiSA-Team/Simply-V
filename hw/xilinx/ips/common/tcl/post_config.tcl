# Block Design (e.g. xlnx_ps_wrapper): generate the output products and the
# HDL wrapper, then stop, since the .xci flow below does not apply to BDs
if { [llength [get_files -quiet $::env(IP_NAME).bd]] > 0 } {
    set bd_file [get_files $::env(IP_NAME).bd]
    generate_target all $bd_file
    make_wrapper -files $bd_file -top
    return
}

# Generate
generate_target {instantiation_template} [get_files $::env(IP_NAME).xci]
generate_target all [get_files $::env(IP_NAME).xci]

# Synthesize
create_ip_run [get_files -of_objects [get_fileset sources_1] $::env(IP_NAME).xci]
launch_run -jobs 8 $::env(IP_NAME)_synth_1
wait_on_run $::env(IP_NAME)_synth_1