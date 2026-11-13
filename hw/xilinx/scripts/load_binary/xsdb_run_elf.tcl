# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Args:
#   $1: Path to target ELF
#   $2: Path to target bitstream (optional)
#   $3: Path to ps7_init.tcl (optional, Zynq-7000 only, together with $4)
#   $4: Path to the PS ELF (optional, Zynq-7000 only, together with $3)
#   Any argument can be "-" to skip that step, e.g. "-" as target ELF when the CPU
#   is loaded with OpenOCD/GDB, or "-" "-" "-" <ps_elf> to only run the PS ELF on a
#   system that is already programmed and initialized.
# Description:
#   Basic XSDB script to load and run an ELF file.
#   Optionally, it can also configure the FPGA with a new bitstream.
#   On Zynq-7000, it can also initialize the PS and run an ELF on the
#   Cortex-A9 #0, after the target ELF.

##############
# Parse args #
##############
if { $argc < 1 || $argc == 3 || $argc > 4 } {
    puts "Usage <elf_file> <bitstream> <ps7_init> <ps_elf_file>"
    puts "elf_file      : path to elf file to transfer (\"-\" to skip)"
    puts "bitstream     : path to bitstream file (optional, \"-\" to skip)"
    puts "ps7_init      : path to ps7_init.tcl (optional, Zynq-7000 only, \"-\" to skip)"
    puts "ps_elf_file   : path to PS elf file (optional, Zynq-7000 only, \"-\" to skip)"
    return
}

# Set target elf, if any
set ELF_FILE [lindex $argv 0]
set run_elf [expr {$ELF_FILE ne "-"}]

# Set bitstream, if any
set program_bitstream 0
if { $argc >= 2 && [lindex $argv 1] ne "-" } {
    set program_bitstream   1
    set BITSTREAM           [lindex $argv 1]
}

# Set PS init script and PS elf, if any (Zynq-7000)
set init_ps    0
set run_ps_elf 0
if { $argc == 4 } {
    set PS7_INIT    [lindex $argv 2]
    set PS_ELF_FILE [lindex $argv 3]
    set init_ps     [expr {$PS7_INIT    ne "-"}]
    set run_ps_elf  [expr {$PS_ELF_FILE ne "-"}]
}

########
# Init #
########

# Connect to hw_server
connect -host $::env(XILINX_HW_SERVER_HOST) -port $::env(XILINX_HW_SERVER_PORT)

# Zynq-7000: system reset first, since it also resets the PL
if { $init_ps == 1 } {
    puts "\[INFO\] Resetting the system"
    targets -set -filter {name =~ "APU*"}
    rst -system
    after 1000
}

# Configure FPGA
if { $program_bitstream == 1 } {
    puts "\[INFO\] Programming bistream $BITSTREAM"
    fpga $BITSTREAM
}

# Zynq-7000: initialize the PS (clocks, DDR, MIO, FCLK) and enable the PS-PL interface.
# Before ps7_post_config, Simply-V has no clock and Hart #0 is not visible.
if { $init_ps == 1 } {
    puts "\[INFO\] Initializing the PS with $PS7_INIT"
    source $PS7_INIT
    ps7_init
    ps7_post_config
    after 1000
    # Use only the Cortex-A9 #0: keep the Cortex-A9 #1 halted
    puts "\[INFO\] Halting ARM Cortex-A9 MPCore #1"
    targets -set -filter {name =~ "ARM Cortex-A9 MPCore #1"}
    stop
}

# Load and run the target elf, if any
if { $run_elf == 1 } {
    # Filter and set target
    puts "\[INFO\] Selecting target Hart #0"
    targets -set -filter {name  =~ "*Hart #0*"}
    # Reset target core
    # Zynq-7000: after ps7_post_config the CPU is already halted at 0x0, and a second
    # rst -processor lets it run again, so that it can no longer be halted: skip it
    if { $init_ps == 0 } {
        puts "\[INFO\] Resetting target"
        rst -processor
    }
    # Load elf into memory
    puts "\[INFO\] Downloading elf $ELF_FILE"
    dow $ELF_FILE
    # Wait 0.5 seconds
    after 500
    # Start execution
    puts "\[INFO\] Starting execution"
    con
}

# Zynq-7000: run the PS elf on the Cortex-A9 #0, after the target elf
if { $run_ps_elf == 1 } {
    after 1000
    puts "\[INFO\] Selecting target ARM Cortex-A9 MPCore #0"
    targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
    puts "\[INFO\] Downloading PS elf $PS_ELF_FILE"
    dow $PS_ELF_FILE
    after 500
    puts "\[INFO\] Starting PS execution"
    con
}
