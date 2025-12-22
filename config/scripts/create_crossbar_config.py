# Author: Stefano Toscano <stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
#   Generate an AXI Crossbar tcl configuration file.
# Note:
#   Addresses overlaps are not sanitized.
# Args:
#   1: Input configuration file
#   2: Output generated tcl file

####################
# Import libraries #
####################
# Parse args
import os
import sys
# Manipulate CSV
import pandas as pd
# Sub-scripts
import parse_properties_wrapper
import write_tcl
import configuration

##############
# Parse args #
##############

# CSV system configuration file path
sys_config_file_name = 'config/configs/common/config_system.csv'
if len(sys.argv) >= 2:
	sys_config_file_name = sys.argv[1]

# CSV bus configuration file path
bus_config_file_name = 'config/configs/embedded/config_main_bus.csv'
# bus_config_file_name = 'config/axi_memory_map/configs/PoC_config.csv'
if len(sys.argv) >= 3:
	bus_config_file_name = sys.argv[2]

# Target TCL file
config_tcl_file_name = 'hw/xilinx/ips/common/xlnx_axi_crossbar/config.tcl'
if len(sys.argv) >= 4:
	config_tcl_file_name = sys.argv[3]

###############
# Environment #
###############
# utility function to compose 2-digit index
def compose_index ( index_int : int ):
    # Return value
    index_string = ""

    # Add a zero char and cast
    if (index_int < 10):
        index_string = "0" + str(index_int)
    # just cast
    else:
        index_string = str(index_int)

    # Return
    return index_string

# Avoid Pandas print truncations
# pd.set_option('display.max_colwidth', 1000)

# Init configuration
config = configuration.Configuration()

# Assign config bus name
if "main_bus" in bus_config_file_name:
    config.CONFIG_NAME = "MBUS"
elif "peripheral_bus" in bus_config_file_name:
    config.CONFIG_NAME = "PBUS"
elif "highperformance_bus" in bus_config_file_name:
    config.CONFIG_NAME = "HBUS"

# TODO127:
# In the previous version we first read the sys config and then the bus config
# This is now broken because of how we assign datawidth and address width
# and the relative order of these assignments.
# By swapping the order (bus config first and system after) it works.
# nevertheless, it must be corrected in the proper branch

###################
# Read Bus config #
###################
# Read CSV file
config_df = pd.read_csv(bus_config_file_name, sep=",")

########################
# Update configuration #
########################
# Update configuration by calling wrapper function for each property
for index, row in config_df.iterrows():
    config = parse_properties_wrapper.parse_property(config, row["Property"], row["Value"])

# Skip DISABLE buses
if config.PROTOCOL == "DISABLE":
    print("[CONFIG] Skipping DISABLE bus", config.CONFIG_NAME )
    exit(0)

###################
# Read Sys config #
###################

config_df = pd.read_csv(sys_config_file_name, sep=",")

for index, row in config_df.iterrows():
    config = parse_properties_wrapper.parse_property(config, row["Property"], row["Value"])

####################
# Prepare commands #
####################
# List of tcl key-value pairs
config_list = []

# Basic configurations
config_list.append("CONFIG.PROTOCOL {"          + config.PROTOCOL          + "}")
config_list.append("CONFIG.CONNECTIVITY_MODE {" + config.CONNECTIVITY_MODE + "}")
config_list.append("CONFIG.ADDR_WIDTH {"        + str(config.ADDR_WIDTH)   + "}")
config_list.append("CONFIG.DATA_WIDTH {"        + str(config.DATA_WIDTH)   + "}")
config_list.append("CONFIG.ID_WIDTH {"          + str(config.ID_WIDTH)     + "}")
config_list.append("CONFIG.NUM_SI {"            + str(config.NUM_SI)       + "}")
config_list.append("CONFIG.NUM_MI {"            + str(config.NUM_MI)       + "}")
config_list.append("CONFIG.ADDR_RANGES {"       + str(config.ADDR_RANGES)  + "}")
config_list.append("CONFIG.STRATEGY {"          + str(config.STRATEGY)     + "}")
config_list.append("CONFIG.R_REGISTER {"        + str(config.R_REGISTER)   + "}")
# AXI user
config_list.append("CONFIG.AWUSER_WIDTH {"  + str(config.AWUSER_WIDTH) + "}")
config_list.append("CONFIG.ARUSER_WIDTH {"  + str(config.ARUSER_WIDTH) + "}")
config_list.append("CONFIG.WUSER_WIDTH {"   + str(config.WUSER_WIDTH)  + "}")
config_list.append("CONFIG.RUSER_WIDTH {"   + str(config.RUSER_WIDTH)  + "}")
config_list.append("CONFIG.BUSER_WIDTH {"   + str(config.BUSER_WIDTH)  + "}")

# Address ranges
BASE_ADDR_config_list           = []
RANGE_ADDR_WIDTH_config_list    = []
# Master interfaces configurations
MI_READ_ISSUING_config_list    = []
MI_WRITE_ISSUING_config_list    = []
Secure_config_list              = []
# Slave to master connectivity
read_connectivity_config_list  = []
WRITE_CONNECTIVITY_config_list  = []

# For each master interface
for i in range (config.NUM_MI):
    # Compose master index
    master_index = compose_index ( i )

    # MI-specific
    if config.MI_READ_ISSUING != []:
        MI_READ_ISSUING_config_list .append("CONFIG.M" + master_index + "_READ_ISSUING {"  + str(config.MI_READ_ISSUING[i])  + "}")
    if config.MI_WRITE_ISSUING != []:
        MI_WRITE_ISSUING_config_list.append("CONFIG.M" + master_index + "_WRITE_ISSUING {" + str(config.MI_WRITE_ISSUING[i]) + "}")
    if config.SECURE != []:
        Secure_config_list          .append("CONFIG.M" + master_index + "_SECURE {"        + str(config.SECURE[i])           + "}")

    # Address ranges
    # For each address range
    for j in range (config.ADDR_RANGES):
        # Compose range index
        range_index = compose_index ( j )
        # Prepare configs
        BASE_ADDR_config_list       .append("CONFIG.M" + master_index + "_A" + range_index + "_BASE_ADDR {"  +            config.BASE_ADDR[(config.ADDR_RANGES * i) + j]  + "}")
        RANGE_ADDR_WIDTH_config_list.append("CONFIG.M" + master_index + "_A" + range_index + "_ADDR_WIDTH {" + str(config.RANGE_ADDR_WIDTH[(config.ADDR_RANGES * i) + j]) + "}")

    # Slave to master connectivity
    # For each slave interface
    for j in range (config.NUM_SI):
        # Compose slave index
        slave_index = compose_index ( j )
        # Prepare configs
        if config.READ_CONNECTIVITY != []:
            read_connectivity_config_list .append("CONFIG.M" + master_index + "_S" + slave_index + "_READ_CONNECTIVITY {"  + str(config.READ_CONNECTIVITY[config.NUM_SI*i+j])  + "}")
        if config.WRITE_CONNECTIVITY != []:
            WRITE_CONNECTIVITY_config_list.append("CONFIG.M" + master_index + "_S" + slave_index + "_WRITE_CONNECTIVITY {" + str(config.WRITE_CONNECTIVITY[config.NUM_SI*i+j]) + "}")

# Append to list
config_list.extend(BASE_ADDR_config_list)
config_list.extend(RANGE_ADDR_WIDTH_config_list)
config_list.extend(read_connectivity_config_list)
config_list.extend(WRITE_CONNECTIVITY_config_list)
config_list.extend(MI_READ_ISSUING_config_list)
config_list.extend(MI_WRITE_ISSUING_config_list)
config_list.extend(Secure_config_list)

# Slave interfaces configurations
Slave_Priorities_config_list    = []
SI_READ_ACCEPTANCE_config_list  = []
SI_WRITE_ACCEPTANCE_config_list = []
THREAD_ID_WIDTH_config_list     = []
SINGLE_THREAD_config_list       = []
BASE_ID_config_list             = []
# For each slave interface
for i in range (config.NUM_SI):
    # Compose slave index
    slave_index = compose_index ( i )

    # Prepare configs
    if config.Slave_Priorities != []:
        Slave_Priorities_config_list    .append("CONFIG.S" + slave_index + "_ARB_PRIORITY {"     + str(config.Slave_Priorities[i])    + "}")
    if config.SI_READ_ACCEPTANCE != []:
        SI_READ_ACCEPTANCE_config_list  .append("CONFIG.S" + slave_index + "_READ_ACCEPTANCE {"  + str(config.SI_READ_ACCEPTANCE[i])  + "}")
    if config.SI_WRITE_ACCEPTANCE != []:
        SI_WRITE_ACCEPTANCE_config_list .append("CONFIG.S" + slave_index + "_WRITE_ACCEPTANCE {" + str(config.SI_WRITE_ACCEPTANCE[i]) + "}")
    if config.THREAD_ID_WIDTH != []:
        THREAD_ID_WIDTH_config_list     .append("CONFIG.S" + slave_index + "_THREAD_ID_WIDTH {"  + str(config.THREAD_ID_WIDTH[i])     + "}")
    if config.SINGLE_THREAD != []:
        SINGLE_THREAD_config_list       .append("CONFIG.S" + slave_index + "_SINGLE_THREAD {"    + str(config.SINGLE_THREAD[i])       + "}")
    if config.BASE_ID != []:
        BASE_ID_config_list             .append("CONFIG.S" + slave_index + "_BASE_ID {"          + config.BASE_ID[i]                  + "}")

# Append to list
config_list.extend(Slave_Priorities_config_list)
config_list.extend(SI_READ_ACCEPTANCE_config_list)
config_list.extend(SI_WRITE_ACCEPTANCE_config_list)
config_list.extend(THREAD_ID_WIDTH_config_list)
config_list.extend(SINGLE_THREAD_config_list)
config_list.extend(BASE_ID_config_list)

##################
# Write TCL file #
##################

# Creates the actual TCL file
file = open(config_tcl_file_name,  "w")
# Write header lines
write_tcl.initialize_File(file, os.path.basename(__file__))

# Write properties
for command in config_list:
	write_tcl.write_single_value_configuration(file, command)
	# Add new line
	file.write(" \\\n                         ")

# Write closing lines
write_tcl.end_File(file)

# Close file
file.close

# Print filename
print("[CONFIG] Output file is at " + config_tcl_file_name)
