#!/bin/python3.10
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: utility functions to write RTL file for BUS declaration and concatenation

####################
# Import libraries #
####################
# Parse args
import sys
# Get env vars
import os
# Sub-scripts
import configuration
from utils import *

# Constants

# File comments
FILE_HEADER = \
f"// This file is auto-generated with {os.path.basename(__file__)}\n\n\
/////////////////////////////////////////\n\
// Buses declaration and concatenation //\n\
/////////////////////////////////////////\n"

FILE_MASTER_BUSES_HEADER = \
"\n/////////////////\n\
// AXI Masters //\n\
/////////////////\n"


FILE_SLAVE_BUSES_HEADER = \
"\n/////////////////\n\
// AXI Slaves  //\n\
/////////////////\n"

FILE_MASTER_CONCAT_HEADER = \
"\n//////////////////////////////////\n\
// Concatenate AXI master buses //\n\
//////////////////////////////////\n"

FILE_SLAVE_CONCAT_HEADER = \
"\n/////////////////////////////////\n\
// Concatenate AXI slave buses //\n\
/////////////////////////////////\n"



# Template strings
DECLARE_BUS_PREFIX                 = "`DECLARE_AXI_BUS("

DECLARE_AXILITE_BUS_PREFIX         = "`DECLARE_AXILITE_BUS("

DECLARE_BUS_ARRAY_PREFIX           = "`DECLARE_AXI_BUS_ARRAY("

DECLARE_AXILITE_BUS_ARRAY_PREFIX   = "`DECLARE_AXILITE_BUS_ARRAY("

CONCAT_SLAVE_BUS_PREFIX            = "`CONCAT_AXI_SLAVES_ARRAY"
CONCAT_MASTER_BUS_PREFIX           = "`CONCAT_AXI_MASTERS_ARRAY"

CONCAT_AXILITE_SLAVE_BUS_PREFIX    = "`CONCAT_AXILITE_SLAVES_ARRAY"
CONCAT_AXILITE_MASTER_BUS_PREFIX   = "`CONCAT_AXILITE_MASTERS_ARRAY"

BASE_SUFFIX                        = ")\n"

# RTL files to edit
RTL_FILES                = {
    "MBUS" : f"{os.environ.get('XILINX_ROOT')}/rtl/mbus_buses.svinc",
    "PBUS" : f"{os.environ.get('XILINX_ROOT')}/rtl/pbus_buses.svinc",
    "HBUS" : f"{os.environ.get('XILINX_ROOT')}/rtl/hbus_buses.svinc"
}

# Get the correct bus suffix depending on bus name
def GET_BUS_SUFFIX(busname) -> None:

    bus_suffix = ", "   + busname + "_DATA_WIDTH, " \
                        + busname + "_ADDR_WIDTH, " \
                        + busname + "_ID_WIDTH)\n"

    return bus_suffix


# Write the concatenation macro for master/slave buses to the rtl file
def concat_buses(lines : list, buses : list, is_master : bool, config : configuration.Configuration) -> None:
    bus_cnt_str        = str()
    buses_string       = str()
    suffix             = str()
    concat_prefix      = str()
    declare_prefix     = str()
    data_width         = str()

    # If is master
    if is_master:
        match (config.CONFIG_NAME):
            case "PBUS":
                bus_cnt_str    = "1"                               # The width of the bus array in case of PBUS (1 since the PBUS has just a master)
                concat_prefix  = CONCAT_AXILITE_MASTER_BUS_PREFIX  # The concatenation prefix in case of a PBUS
                declare_prefix = DECLARE_AXILITE_BUS_ARRAY_PREFIX  # The declaration prefix in case of a PBUS
            case  "MBUS":
                declare_prefix = DECLARE_BUS_ARRAY_PREFIX          # The declaration prefix in case of MBUS
                bus_cnt_str    = "MBUS_NUM_SI"                     # The width of the bus array in case of MBUS
                concat_prefix  = CONCAT_MASTER_BUS_PREFIX          # The concatenation prefix in case of MBUS
            case  "HBUS":
                declare_prefix = DECLARE_BUS_ARRAY_PREFIX          # The declaration prefix in case of MBUS
                # TODO: only MBUS and one accelerator interfaces supported for now
                bus_cnt_str    = "HBUS_NUM_SI"                     # The width of the bus array in case of MBUS
                concat_prefix  = CONCAT_MASTER_BUS_PREFIX          # The concatenation prefix in case of MBUS

        # The suffix of the bus array
        suffix = "_masters"

    # If is slave
    else:
        match (config.CONFIG_NAME):
            case "PBUS":
                bus_cnt_str    = "PBUS_NUM_MI"                     # The width of the bus array in case of PBUS
                concat_prefix  = CONCAT_AXILITE_SLAVE_BUS_PREFIX   # The concatenation prefix in case of a PBUS
                declare_prefix = DECLARE_AXILITE_BUS_ARRAY_PREFIX  # The declaration prefix in case of a PBUS
            case  "MBUS":
                declare_prefix = DECLARE_BUS_ARRAY_PREFIX          # The declaration prefix in case of MBUS
                bus_cnt_str    = "MBUS_NUM_MI"                     # The width of the bus array in case of MBUS
                concat_prefix  = CONCAT_SLAVE_BUS_PREFIX           # The concatenation prefix in case of MBUS
            case  "HBUS":
                declare_prefix = DECLARE_BUS_ARRAY_PREFIX          # The declaration prefix in case of HBUS
                # NOTE: loopback to MBUS + 1 DDR
                # TODO125: only one DDR channel supported for now
                bus_cnt_str    = "HBUS_NUM_MI"                     # The width of the bus array in case of HBUS
                concat_prefix  = CONCAT_SLAVE_BUS_PREFIX           # The concatenation prefix in case of HBUS

        # The suffix of the bus array
        suffix = "_slaves"

    for bus in buses:
        # Add each bus previously declared to the bus string
        # In the and it looks like (for masters): ..., MASTER1_to_BUS, MASTER0_to_BUS
        buses_string = f", {bus}{buses_string}"


    # Declare an AXI4/AXILITE BUS ARRAY master/slave
    lines.append(f"{declare_prefix}{config.CONFIG_NAME}{suffix}, {bus_cnt_str}{GET_BUS_SUFFIX(config.CONFIG_NAME)}")
    # Concatenate all master/slave buses with the declared AXI4/AXILITE BUS ARRAY
    lines.append(f"{concat_prefix}{len(buses)}({config.CONFIG_NAME}{suffix}{buses_string}{BASE_SUFFIX}")



# Write the declaration macro for the master/slave buses in the rtl file
def declare_buses(lines : list, is_master : bool, config : configuration.Configuration) -> list:
    # List of buses to declare
    buses = list()
    # Number of buses to declare
    buses_cnt = 0

    if is_master:
        # If is master the number of bus to declare is the number of masters (NUM_SI - slave interfaces)
        buses_cnt = config.NUM_SI
    else:
        # If is not master the number of bus to declare is the number of slaves (NUM_MI - master interfaces)
        buses_cnt = config.NUM_MI

    for i in range(buses_cnt):
        if is_master:
            # If is master the bus declaration is: MASTER_NAME_to_BUS_NAME
            buses.append(f"{config.MASTER_NAMES[i]}_to_{config.CONFIG_NAME}")
        else:
            # If not is master the bus declaration is: BUS_NAME_to_SLAVE_NAME
            buses.append(f"{config.CONFIG_NAME}_to_{config.RANGE_NAMES[i]}")

        if config.CONFIG_NAME == "PBUS":
            # If the bus is PBUS declare an AXILITE bus using the last created bus name
            lines.append(f"{DECLARE_AXILITE_BUS_PREFIX}{buses[-1]}{GET_BUS_SUFFIX(config.CONFIG_NAME)}")
        elif config.CONFIG_NAME in {"MBUS", "HBUS"}:
            # If the bus is not PBUS declare an AXI4 bus using the last created bus name
            lines.append(f"{DECLARE_BUS_PREFIX}{buses[-1]}{GET_BUS_SUFFIX(config.CONFIG_NAME)}")
    return buses


# Declare and concatenate the buses
def declare_and_concat_buses(file, config : configuration.Configuration) -> None:
    lines        = list()
    slave_buses  = list()
    master_buses = list()

    # Initialize the file with an header
    lines.append(FILE_HEADER)

    # MASTER buses declaration
    lines.append(FILE_MASTER_BUSES_HEADER)
    master_buses = declare_buses(lines, is_master=True, config=config)

    # SLAVE buses declaration
    lines.append(FILE_SLAVE_BUSES_HEADER)
    slave_buses  = declare_buses(lines, is_master=False, config=config)

    # MASTER buses concatenation
    lines.append(FILE_MASTER_CONCAT_HEADER)
    concat_buses(lines, master_buses, is_master=True, config=config)

    # SLAVE buses concatenation
    lines.append(FILE_SLAVE_CONCAT_HEADER)
    concat_buses(lines, slave_buses, is_master=False, config=config)

    # Write the file back
    file.seek(0)
    file.writelines(lines)

########
# MAIN #
########
if __name__ == "__main__":
    config_file_names = sys.argv[1:]
    configs = read_config(config_file_names)

    for config in configs:
        file = open(RTL_FILES[config.CONFIG_NAME], "w")
        declare_and_concat_buses(file, config)
        file.close()

