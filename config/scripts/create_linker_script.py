# Author: Stefano Toscano               <stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto               <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano           <stefano.mercogliano@unina.it>
# Author: Giuseppe Capasso              <giuseppe.capasso17@studenti.unina.it>
# Description:
#   Generate a linker script file from the CSV configuration.
# Note:
#   Addresses overlaps are not sanitized.
# Args:
#   1: Input configuration file
#   2: Output generated ld script

####################
# Import libraries #
####################
# Parse args
import sys

# For basename
import os

# Manipulate CSV
import csv

# Utils function
import utils

##############
# Parse args #
##############

# CSV configuration file path
if len(sys.argv) != 4:
    print("Usage: <CONFIG_MAIN_BUS_CSV> <CONFIG_HIGH_PERFORMANCE_BUS_CSV> <OUTPUT_LD_FILE>")
    sys.exit(1)

# The last argument must be the output file
config_file_names = sys.argv[1:-1]
ld_file_name = sys.argv[-1]

###############
# Read config #
###############
# Read CSV files for each bus
range_names = []
range_base_addr = []
range_addr_width = []

for fname in config_file_names:
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
    # TODO: tailor each memory block with specific permissions. Eg. BRAM (rx)
    if name in ["BRAM", "HBM"] or name.startswith("DDR4CH"):
        device_dict["memory"].append(
            {
                "device": name,
                "permissions": "xrw",
                "base": int(base_addr, 16),
                "range": 1 << int(addr_width),
            }
        )

# Currently the first memory device is selected as the boot memory device
BOOT_MEMORY_BLOCK = "BRAM"
boot_memory_device = next(d for d in device_dict["memory"] if d["device"] == BOOT_MEMORY_BLOCK)

# Note: The memory size specified in the config.csv file may differ from the
# physical memory allocated for the SoC (refer to hw/xilinx/ips/common/xlnx_blk_mem_gen/config.tcl).
# Currently, the configuration process does not ensure alignment between config.csv
# and xlnx_blk_mem_gen/config.tcl. As a result, we assume a maximum memory size of
# 32KB for now, based on the current setting in `config.tcl`.
device_dict["global_symbols"] = [
    # The stack is allocated at the end of first memory block
    # _stack_end can be user-defined for the application, as bss and rodata
    # _stack_end will be aligned to 64 bits, making it working for both 32 and 64 bits configurations
    (
        "PROVIDE(_stack_start",
        boot_memory_device["base"]
        + boot_memory_device["range"]
        # stack needs to be 16-byte aligned
        & 0x10")",
    ),
    ("PROVIDE(_vector_table_start", boot_memory_device["base"], ")"),
    ("PROVIDE(_vector_table_end", boot_memory_device["base"] + 32 * 4, ")"),
]

###############################
# Generate Linker Script File #
###############################

ld_template_str = """/* Auto-generated with {current_file_path} */

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


# Render memory blocks as a string. Each memory object is defined as follows
# {
#   "device": name,
#   "permissions": "xrw",
#   "base": int(base_addr, 16),
#   "range": 1 << int(addr_width),
# }
#
# The output of the should be a string in the linkerscript format. Eg:
# BRAM (xrw): ORIGIN = 0x0, LENGHTa = 0x10000
def create_linker_render_memory(memory: list) -> str:
    lines = []
    for m in memory:
        name = m["device"]
        permissions = m["permissions"]
        base = m["base"]
        len = m["range"]
        lines.append(
            f"\t{name} ({permissions}): ORIGIN = 0x{base:016x}, LENGTH = 0x{len:0x}"
        )
    return "\n".join(lines)


# Render memory global symbols as a string. Each symbol is defined as (name, value) which produces
# _stack_start = 0x000000000000fff0;
def create_linker_render_glomal_symbols(symbols: list) -> str:
    lines = []
    for s in symbols:
        name = s[0]
        value = s[1]
        lines.append(f"{name} = 0x{value:016x};")
    return "\n".join(lines)


if __name__ == "__main__":
    # The ld_template_str is a string which can be formatted (same as f-string). Provide {variable}
    # as strings. This is why we call render_* functions
    rendered = ld_template_str.format(
        current_file_path=os.path.basename(__file__),
        memory_block=create_linker_render_memory(device_dict["memory"]),
        globals_block=create_linker_render_glomal_symbols(device_dict["global_symbols"]),
        initial_memory_name=boot_memory_device["device"],
    )

    # Write the output
    with open(ld_file_name, "w") as f:
        f.write(rendered)
