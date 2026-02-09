# Author: Vincenzo Maisto <vincenzo.maisto@unina.it>
# Description: Load and run dual_hello_world example, assuming bitstream is programmed

# Load ELF for core 1
targets -set -filter {name =~ "Hart #0*"}
rst -processor
dow hello_core0/bin/hello_core0.elf

# Load ELF for core 1
targets -set -filter {name =~ "Hart #1*"}
rst -processor
dow hello_core1/bin/hello_core1.elf

# Start core 0
targets -set -filter {name =~ "Hart #0*"}
con
# Wait half a second
after 500
# Start core 1
targets -set -filter {name =~ "Hart #1*"}
con
