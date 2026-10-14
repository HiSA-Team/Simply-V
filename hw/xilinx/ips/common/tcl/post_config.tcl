# Generate
generate_target {instantiation_template} [get_files $::env(IP_NAME).xci]
generate_target all [get_files $::env(IP_NAME).xci]

# Synthesize
create_ip_run [get_files -of_objects [get_fileset sources_1] $::env(IP_NAME).xci]
launch_run -jobs 8 $::env(IP_NAME)_synth_1
wait_on_run $::env(IP_NAME)_synth_1