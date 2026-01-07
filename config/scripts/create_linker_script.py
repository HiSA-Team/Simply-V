# Author: Stefano Toscano <stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
# Description:
#   Generate a linker script file from the CSV configuration.
# Note:
#   Addresses overlaps are not sanitized.
# Args:
#   1: Input configuration file for system
#   2: Input configuration files for buses
#   3: Output generated ld script

####################
# Import libraries #
####################

import sys # Parse args
import os # For basename
import csv # Manipulate CSVs
import utils # Utils function

##############
# Parse args #
##############

# CSV configuration file path
if len(sys.argv) != 5:
    print("Usage: <CONFIG_SYSTEM_CSV> <CONFIG_MAIN_BUS_CSV> <CONFIG_HIGH_PERFORMANCE_BUS_CSV> <OUTPUT_LD_FILE>")
    sys.exit(1)

# The last argument must be the output file
config_system_file_name = sys.argv[1]
config_bus_file_names = sys.argv[2:-1]
ld_file_name = sys.argv[-1]

###############
# Read config #
###############

# Read system CSV file
BOOT_MEMORY_BLOCK = "BRAM"
with open(config_system_file_name, "r") as file:
    reader = csv.reader(file)
    BOOT_MEMORY_BLOCK = utils.get_value_by_property(reader, "BOOT_MEMORY_BLOCK")

# Read CSV files for each bus
range_names = []
range_base_addr = []
range_addr_width = []

for fname in config_bus_file_names:
    # Open the configuration files and parse them as csv
    with open(fname, "r") as file:
        reader = csv.reader(file)

        # next gets a single value
        protocol = utils.get_value_by_property(reader, "PROTOCOL")
        if protocol == "DISABLE":
            continue

        range_names += utils.get_value_by_property(reader, "RANGE_NAMES").split(" ")
        range_base_addr += utils.get_value_by_property(reader, "RANGE_BASE_ADDR").split(" ")
        range_addr_width += utils.get_value_by_property(reader, "RANGE_ADDR_WIDTH").split(" ")

# Make sure BOOT_MEMORY_BLOCK is enabled
assert( BOOT_MEMORY_BLOCK in range_names )

##########################
# Generate memory blocks #
##########################
# Currently only one copy of BRAM, DDR and HBM memory ranges are supported.
device_dict = {
    "memory": [],
}

# For each range_name, if it's  memory device (BRAM, HBM or starts with DDR4CH) add it to the map
for name, base_addr, addr_width in zip(range_names, range_base_addr, range_addr_width):
    # memory blocks
    # TODO77: extend for multiple BRAMs
    if name in ["BRAM", "HBM"] or name.startswith("DDR4CH"):
        device_dict["memory"].append(
            {
                "device": name,
                "permissions": "xrw",
                "base": int(base_addr, 16),
                "range": 1 << int(addr_width),
            }
        )

# Select memory device for boot
boot_memory_device = next(d for d in device_dict["memory"] if d["device"] == BOOT_MEMORY_BLOCK)

# Set dict of global symbols names and values
device_dict["global_symbols"] = [
    (
        "_stack_start",
        # - Stack is allocated at the end of first memory block
        # - Aligned at 16 bytes
        (boot_memory_device["base"] + boot_memory_device["range"] - 0x10) & (~0x0000000000000010)
    ),
    ("_vector_table_start", boot_memory_device["base"], ")"),
    ("_vector_table_end", boot_memory_device["base"] + 32 * 4),
]

###############################
# Generate Linker Script File #
###############################

# Render memory blocks as a string. Each memory object is defined as follows
# {
#   "device": name,
#   "permissions": "xrw",
#   "base": int(base_addr, 16),
#   "range": 1 << int(addr_width),
# }
#
# The output is key-value string in linker script format, e.g.:
# BRAM (xrw): ORIGIN = 0x0, LENGHT = 0x10000
lines = []
for m in device_dict["memory"]:
    name = m["device"]
    permissions = m["permissions"]
    base = m["base"]
    len = m["range"]
    lines.append(
        f"\t{name} ({permissions}): ORIGIN = 0x{base:016x}, LENGTH = 0x{len:0x}"
    )
memory_block = "\n".join(lines)

# Render memory global symbols as a string.
# Each symbol is defined as (name, value) which produces, e.g.: PROVIDE(_stack_start = 0x000000000000fff0);
lines = []
for s in device_dict["global_symbols"]:
    name = s[0]
    value = s[1]
    lines.append(f"PROVIDE({name} = 0x{value:016x});")
globals_block = "\n".join(lines)

# Template string
ld_template_str = """/* Auto-generated with {current_file_path} */

/* Memory blocks */
MEMORY
{{
{memory_block}
}}

/* Global symbols */
{globals_block}

SECTIONS
{{
    .vector_table _vector_table_start :
    {{
        KEEP(*(.vector_table))
    }}> {initial_memory_name}

    .text :
    {{
        . = ALIGN(32);
        _text_start = .;
        *(.text.handlers)
        *(.text.start)
        *(.text)
        *(.text*)
        . = ALIGN(32);
        _text_end = .;
    }}> {initial_memory_name}
}}
"""

# The ld_template_str is a string which can be formatted (same as f-string). Provide {variable}
# as strings.
rendered = ld_template_str.format(
    current_file_path=os.path.basename(__file__),
    memory_block=memory_block,
    globals_block=globals_block,
    initial_memory_name=boot_memory_device["device"],
)

# Write the output
with open(ld_file_name, "w") as f:
    f.write(rendered)
