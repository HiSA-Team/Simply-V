# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
# Description:
#   Generate config.mk to ensure proper `FW_TEXT_START` variable for OpenSBI:
# Note:
#   Addresses overlaps are not sanitized.
# Args:
#   1: [IN] Input configuration file for main bus
#   5: [OUT] Output config file

####################
# Import libraries #
####################

import sys # Parse args
import os # For basename
import csv # Manipulate CSVs

##############
# Parse args #
##############

def get_value_by_property(reader, property_name: str) -> str:
    return next(value for property, value in reader if property == property_name)

# CSV configuration file path
if len(sys.argv) != (1 + 2):
    print(f"""Usage: {sys.argv[0]}  <CONFIG_MAIN_BUS_CSV> <OUTPUT_CONFIG_FILE>""")
    sys.exit(1)

# first parameter is ignored, since it contains the script path
_, config_main_bus, config_file = sys.argv

###############
# Read config #
###############

# Read system CSV file
OPENSBI_BOOT_MEMORY_BLOCK = "DDR4CH1"

# Read CSV file
with open(config_main_bus, "r") as file:
    reader = csv.reader(file)

    range_names = get_value_by_property(reader, "RANGE_NAMES").split()
    range_base_addr = get_value_by_property(reader, "RANGE_BASE_ADDR").split()
    range_addr_width = get_value_by_property(reader, "RANGE_ADDR_WIDTH").split()

# Make sure BOOT_MEMORY_BLOCK is enabled
assert( OPENSBI_BOOT_MEMORY_BLOCK in range_names )

#######################################
# Generate OPENSBI_BOOT_MEMORY_BLOCK  #
#######################################

# Find our boot memory device for OpenSBI, (we just need the start address) and generate the string.
for name, base_addr, addr_width in zip(range_names, range_base_addr, range_addr_width):
    if name == OPENSBI_BOOT_MEMORY_BLOCK:
        # The output is key-value string in Makefile, e.g.:
        # FW_TEXT_START := 0x80000000
        base = int(base_addr, 16)
        fw_text_start = f"FW_TEXT_START = 0x{base:016x}"

###############################
# Generate Config File        #
###############################
config_template_str = """# Auto-generated with {current_file_path}
# OpenSBI firmware starts from here
{fw_text_start}"""

# The *_template_str is a string which can be formatted (same as f-string). Provide {variable}
# as strings.
rendered = config_template_str.format(
    current_file_path=os.path.basename(__file__),
    fw_text_start=fw_text_start,
)

# Write the output
with open(config_file, "w") as f:
    f.write(rendered)
