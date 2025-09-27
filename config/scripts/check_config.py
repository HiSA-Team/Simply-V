#!/bin/python3.10
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
#   Check the validity of the CSV configurations
#   The checks are split in two part: 1) intra configuration checks and 2) inter configuration checks
#
#       1) intra configuration checks:
#           a) check the validity of the given axi protocol (AXI4, AXI4LITE)
#           b) check the correspondence of NUM_MI with RANGE_NAMES, BASE_ADDR, and RANGE_ADDR_WIDTH (e.g. NUM_MI=2 -> len(RANGE_NAMES)=2 etc.)
#           c) check the minimum width of each address range (12 if AXI4, 1 if AXI4LITE)
#           d) check the validity of the address ranges, if they do not overlap each other and if the RANGE_ADDR_WIDTH match the BASE_ADDR
#
#       2) inter configuration checks:
#           a) for each bus check if it has a child bus, and if yes,
#              verify that the total address range of the child is contained in the right address range of the parent
#
#    IMPORTANT NOTE: the address range of a child bus in its configuration .csv file must be an absolute address range,
#                    this means that if the child bus is mapped in the parent bus at the address 0x1000 to 0x1FFF, then
#                    the peripherals in the child bus must be in the address range 0x1000 to 0x1FFF


####################
# Import libraries #
####################
# Parse args
import sys
# Get env
import os
# Sub-scripts
import configuration
from utils import *

# Constants
VALID_PROTOCOLS = ["AXI4", "AXI4LITE", "DISABLE"] # AXI3 not implemented yet
MIN_AXI4_ADDR_WIDTH = 12
MIN_AXI4LITE_ADDR_WIDTH = 1
SOC_CONFIG = os.getenv("SOC_CONFIG", "embedded")
# NOTE: These frequencies depend on the clock_wizard configuration (config.tcl)
SUPPORTED_CLOCK_DOMAINS_EMBEDDED = [10, 20, 50, 100]
SUPPORTED_CLOCK_DOMAINS_HPC      = [10, 20, 50, 100, 250]
SUPPORTED_CLOCK_DOMAINS = {
    "embedded" : SUPPORTED_CLOCK_DOMAINS_EMBEDDED,
    "hpc"      : SUPPORTED_CLOCK_DOMAINS_HPC
}
# These slaves reside statically in the MAIN_CLOCK_DOMAIN
MAIN_CLOCK_DOMAIN_SLAVES = ["BRAM", "DM_mem", "PLIC"]
# The DDR clock must have the same frequency of the DDR board clock
DDR_FREQUENCY = 300

#############################
# Check intra configuration #
#############################
def check_intra_config(config : configuration.Configuration, config_file_name: str) -> bool:

    # Core is selected in the SYS configuration file
    if config.CONFIG_NAME == "SYS":
        # Supported cores
        if config.CORE_SELECTOR not in config.SUPPORTED_CORES:
            print_error(f"Invalid core {config.CORE_SELECTOR} in {config_file_name}")
            return False
        # Valid XLEN values
        if config.XLEN not in [32, 64]:
            print_error(f"Invalid XLEN={config.XLEN} value")
            return False
        # VIO_RESETN value
        if config.CORE_SELECTOR == "CORE_PICORV32" and config.VIO_RESETN_DEFAULT != 0:
            print_error(f"CORE_PICORV32 only supports VIO_RESETN_DEFAULT = 0! {config.VIO_RESETN_DEFAULT}")
            return False
        # Microblaze-V is not allowed when building for au280
        if (config.CORE_SELECTOR == "CORE_MICROBLAZEV_RV64" or config.CORE_SELECTOR == "CORE_MICROBLAZEV_RV32") and os.getenv("BOARD") == "au280":
            print_error(f"CORE_MICROBLAZEV is not allowed when building for au280")
        # Match XLEN with MicroblazeV type
        if ((config.CORE_SELECTOR == "CORE_MICROBLAZEV_RV64" and config.XLEN == 32) or \
            (config.CORE_SELECTOR == "CORE_MICROBLAZEV_RV32" and config.XLEN == 64)):
            print_error(f"XLEN={config.XLEN} doesn't match {config.CORE_SELECTOR} data width.")
            return False

        # All check passed
        return True
    # If a non-system config wants to select a core
    elif config.CORE_SELECTOR != "":
        print_error(f"Can't set CORE_SELECTOR core in {config_file_name} , but only in system config")
        return False

    # Check if the protocol is valid
    if config.PROTOCOL not in VALID_PROTOCOLS:
        print_error(f"Invalid protocol {config.PROTOCOL} in {config_file_name}")
        return False

    # Check the number of slaves and relative data (range names, addresses, address widths, and clock domains)
    if config.NUM_MI != len(config.RANGE_NAMES):
        print_error(f"The NUM_MI value {config.NUM_MI} does not match the number of RANGE_NAMES in {config_file_name}")
        return False
    if config.NUM_MI != len(config.BASE_ADDR):
        print_info(config.BASE_ADDR)
        print_error(f"The NUM_MI value {config.NUM_MI} does not match the number of BASE_ADDR in {config_file_name}")
        return False
    if config.NUM_MI != len(config.RANGE_ADDR_WIDTH):
        print_error(f"The NUM_MI value {config.NUM_MI} does not match the number of ADDR_WIDTH in {config_file_name}")
        return False
    if config.CONFIG_NAME == "MBUS":
        if config.NUM_MI != len(config.RANGE_CLOCK_DOMAINS):
            print_error(f"The NUM_MI value {config.NUM_MI} does not match the number of RANGE_CLOCK_DOMAINS in {config_file_name}")
            return False

    # Check the number of masters and relative master names
    if config.NUM_SI != len(config.MASTER_NAMES):
        print_error(f"The NUM_SI does not match MASTER_NAMES in {config_file_name}")
        return False

    # Check the minimum widths (AXI4 12, AXI4LITE 1)
    for addr_width in config.RANGE_ADDR_WIDTH:
        if addr_width > config.ADDR_WIDTH:
            print_error(f"RANGE_ADDR_WIDTH is greater than {config.ADDR_WIDTH} in {config_file_name}")
        if config.PROTOCOL == "AXI4" and addr_width < MIN_AXI4_ADDR_WIDTH:
            print_error(f"RANGE_ADDR_WIDTH is less than {MIN_AXI4_ADDR_WIDTH} in {config_file_name}")
            return False
        if config.PROTOCOL == "AXI4LITE" and addr_width < MIN_AXI4LITE_ADDR_WIDTH:
            print_error(f"RANGE_ADDR_WIDTH is less than {MIN_AXI4LITE_ADDR_WIDTH} in {config_file_name}")
            return False

    # Check the address range
    # List of base and end addresses for each slave (e.g. with range_width=12 -> base_addr: 0x0, end_add: 0xfff)
    base_addresses = list()
    end_addresses = list()
    for i in range(len(config.BASE_ADDR)):
        base_address = int(config.BASE_ADDR[i], 16)
        end_address = base_address + ~(~1 << (config.RANGE_ADDR_WIDTH[i]-1))

        # Check if the base addr does not fall into the addr range (e.g. base_addr: 0x100 is not allowed with range_width=12)
        if (base_address & ~(~1 << (config.RANGE_ADDR_WIDTH[i]-1)) ) != 0:
            print_error(f"BASE_ADDR does not match RANGE_ADDR_WIDTH in {config_file_name}")
            return False

        if i > 0:
            # Check if the current address does not fall into the addr range one of the previous slaves
            for j in range(len(base_addresses)):
                if  ((base_address <= end_addresses[j])   and (base_address >= base_addresses[j])) or \
                    ((end_address >= base_addresses[j])   and (base_address <= base_addresses[j])) or \
                    ((base_address <= base_addresses[j])  and (end_address >= end_addresses[j])  ) or \
                    ((base_address >= base_addresses[j])  and (end_address <= end_addresses[j])  ):

                    print_error(f"Address of {config.RANGE_NAMES[i]} overlaps with {config.RANGE_NAMES[i-1]} in {config_file_name}")
                    return False
        base_addresses.append(base_address)
        end_addresses.append(end_address)

    # Check valid main clock domain
    if config.CONFIG_NAME == "MBUS":
        if config.MAIN_CLOCK_DOMAIN not in SUPPORTED_CLOCK_DOMAINS[SOC_CONFIG]:
            print_error(f"The clock domain {clok_domain}MHz is not supported")
            return False
        # Check valid clock domains
        for i in range(len(config.RANGE_CLOCK_DOMAINS)):
            # Check if the clock frequency is valid (DDR has its own clock domain)
            # TODO: decide a prefix for HBUS-attached accelerators here, maybe ACC_* or HBUS_*
            if config.RANGE_CLOCK_DOMAINS[i] not in SUPPORTED_CLOCK_DOMAINS[SOC_CONFIG] and config.RANGE_NAMES[i] not in {"DDR", "HBUS"}:
                print_error(f"The clock domain {config.RANGE_CLOCK_DOMAINS[i]}MHz is not supported")
                return False
            # Check if all the main_clock_domain slaves have the same frequency as MAIN_CLOCK_DOMAIN
            if config.RANGE_NAMES[i] in MAIN_CLOCK_DOMAIN_SLAVES:
                if config.RANGE_CLOCK_DOMAINS[i] != config.MAIN_CLOCK_DOMAIN:
                    print_error(f"The {config.RANGE_NAMES[i]} frequency {config.RANGE_CLOCK_DOMAINS[i]} must be the same as MAIN_CLOCK_DOMAIN {config.MAIN_CLOCK_DOMAIN}")
                    return False
            # Check if the DDR has the right frequency
            if config.RANGE_NAMES[i] in {"DDR", "HBUS"}:
                if config.RANGE_CLOCK_DOMAINS[i] != DDR_FREQUENCY:
                    print_error(f"The DDR and HBUS frequency {config.RANGE_CLOCK_DOMAINS[i]} must be the same of DDR board clock {DDR_FREQUENCY}")
                    return False

    # Check the presence of multiple BRAMs, for now a single occurrence of BRAM is supported
    # Assume BRAM as prefix for any BRAM declaration
    bram_name = "BRAM"
    bram_prefix = len(bram_name)
    bram_cnt = 0
    for name in config.RANGE_NAMES:
        if name[0:bram_prefix] == bram_name:
            bram_cnt += 1
    if bram_cnt > 1:
        print_error(f"Found {bram_cnt} BRAMs, just one BRAM is supported")
        return False

    return True

#############################
# Check inter configuration #
#############################
# Check configuration validity between parent and child buses
def check_inter_config(configs : list) -> bool:

    # For each Configuration
    for config in configs:

        # If the config is the System one, skip checks (not a bus)
        if config.CONFIG_NAME == "SYS":
            continue

        # For each master of the current Configuration
        for mi_index in range(config.NUM_MI):
            # If a master is a bus (is in the CONFIG_NAME dict)
            if config.RANGE_NAMES[mi_index] in CONFIG_NAMES.values():
                # Find the child bus configuration
                for child_config in configs:
                    # TODO: allow loop back to MBUS
                    if child_config.CONFIG_NAME == config.RANGE_NAMES[mi_index] and child_config.CONFIG_NAME != "MBUS":
                        # Compute the base and the end address of the parent bus
                        parent_base_address = int(config.BASE_ADDR[mi_index], 16)
                        parent_end_address = parent_base_address + ~(~1 << (config.RANGE_ADDR_WIDTH[mi_index]-1))

                        # Compute the base and the end address of the child bus
                        child_base_address = int(child_config.BASE_ADDR[0], 16)
                        last_base_address = int(child_config.BASE_ADDR[-1], 16) # Base address of last MI interface of this child
                        child_end_address = last_base_address + ~(~1 << (child_config.RANGE_ADDR_WIDTH[-1]-1))

                        # Do the checks
                        # Check if the address space of the child is containted in the address space of the parent
                        if child_base_address < parent_base_address or child_end_address > parent_end_address:
                            # Except for HBUS, which can loop back to MBUS
                            # TODO: revise this, maybe assume only one (first?) HBUS MI to loop back and skip check for that one only
                            if child_config.CONFIG_NAME != "HBUS":
                                print_error(f"Address of {child_config.CONFIG_NAME} is not properly contained in {config.CONFIG_NAME}")
                                return False
    return True

##############
# Parse args #
##############
def parse_args(argv : list) -> list:
    print_info("Parsing arguments...")
    # CSV configuration file path
    config_file_names = CONFIG_NAMES
    if len(sys.argv) >= 5:
        # Get the array of bus/system names from the second arg to the last but one
        config_file_names = sys.argv[1:len(CONFIG_NAMES)+1]
    print_info("Parsing done!")
    return config_file_names


if __name__ == "__main__":
    config_file_names = parse_args(sys.argv)
    print_info("Reading configuration...")
    configs = read_config(config_file_names)
    print_info("Configuration read!")

    status = True

    # Intra-config check
    print_info(f"Starting checking {len(configs)} config...")
    print_info("Checking intra config validity")
    for i in range(len(configs)):
        print_info(f"Checking {configs[i].CONFIG_NAME} config...")
        status = check_intra_config(configs[i], config_file_names[i])
        # This check failed
        if status == False:
            exit(1)

    # Success intra-config check
    print_info("Checking intra config validity done!")


    # Inter-config check
    print_info("Checking inter config validity")

    status = check_inter_config(configs)
    # Some check failed
    if status == False:
        exit(1)

    # Success inter-config check
    print_info("Checking configuration done!")
    exit(0)