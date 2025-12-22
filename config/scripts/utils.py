# Author: Manuel Maddaluno        <manuel.maddaluno@unina.it>
# Description: utility functions to properly read the config CSV file

####################
# Import libraries #
####################
# Manipulate CSV
import pandas as pd
# Sub-modules
import configuration
import parse_properties_wrapper
import csv

# Name of buses
CONFIG_NAMES = {
    "config_main_bus.csv"            : "MBUS",
    "config_peripheral_bus.csv"      : "PBUS",
    "config_highperformance_bus.csv" : "HBUS",
    "config_system.csv"              : "SYS"
}

###############
# Read config #
###############
def read_config(config_file_names : list) -> list:
    # List of configuration objects (one for each bus)
    configs = []
    for name in config_file_names:
        # Create a configuration object for each bus
        config = configuration.Configuration()

        # Naming the actual bus
        end_name = name.split("/")[-1]
        # Parse name first
        config.CONFIG_NAME = CONFIG_NAMES[end_name]

        # Reading the CSV
        for index, row in pd.read_csv(name, sep=",").iterrows():
            # Update the config
	        config = parse_properties_wrapper.parse_property(config, row["Property"], row["Value"])

        # Append the config to the list
        configs.append(config)

    return configs



############
# PRINTING #
############

# Print/debug stuff
PRINT_PREFIX = "[CHECK_CONFIG]"
PRINT_ERROR_PREFIX = "[ERROR]"
PRINT_WARNING_PREFIX = "[WARNING]"

# print info
def print_info(txt : str) -> None:
    print(f"{PRINT_PREFIX} {txt}")

# print warning
def print_warning(txt : str) -> None:
    print(f"{PRINT_PREFIX}{PRINT_WARNING_PREFIX} {txt}")

# print error
def print_error(txt : str) -> None:
    print(f"{PRINT_PREFIX}{PRINT_ERROR_PREFIX} {txt}")


#############
# CSV Utils #
#############

# Retrieves the value of a property by the CSV Reader
# @reader: a CSV reader object
# @property_name: the name of a the property to retrieve
def get_value_by_property(reader, property_name: str) -> str:
    return next(value for property, value in reader if property == property_name)
