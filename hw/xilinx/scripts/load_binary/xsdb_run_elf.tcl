# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Args:
#   $1: Path to target ELF
#   $2: Path to target bitstream (optional)
# Description:
#   Basic XSDB script to load and run an ELF file.
#   Optionally, it can also configure the FPGA with a new bitstream.

##############
# Parse args #
##############
if { $argc < 1 } {
    puts "Usage <elf_file> <bitstream>"
    puts "elf_file      : path to elf file to transfer"
    puts "bitstream     : path to bitstream file (optional)"
    return
}

# Set target elf
set ELF_FILE [lindex $argv 0]

# Set bitstream, if any
set program_bitstream 0
if { $argc == 2 } {
    set program_bitstream   1
    set BITSTREAM           [lindex $argv 1]
}

########
# Init #
########

# Connect to hw_server
connect -host $::env(XILINX_HW_SERVER_HOST) -port $::env(XILINX_HW_SERVER_PORT)

# Configure FPGA
if { $program_bitstream == 1 } {
    puts "\[INFO\] Programming bistream $BITSTREAM"
    fpga $BITSTREAM
}

# Filter and set target
puts "\[INFO\] Selecting target Hart #0"
targets -set -filter {name  =~ "*Hart #0*"}
# Reset target core
puts "\[INFO\] Resetting target"
rst -processor
# Load elf into memory
puts "\[INFO\] Downloading elf $ELF_FILE"
dow $ELF_FILE
# Wait 0.5 seconds
after 500
# Start execution
puts "\[INFO\] Starting execution"
con
