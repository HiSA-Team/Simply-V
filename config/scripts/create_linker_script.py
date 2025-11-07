#!/bin/python3.10
# Author: Stefano Toscano 		<stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto 		<vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano 		<stefano.mercogliano@unina.it>
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
import pandas as pd

##############
# Parse args #
##############

# CSV configuration file path
config_file_names = [
		'config/configs/embedded/config_main_bus.csv',
		'config/configs/embedded/config_peripheral_bus.csv',
		'config/configs/embedded/config_highperformance_bus.csv',
	]

if len(sys.argv) >= len(config_file_names)+1:
	# Get the array of bus names from the second arg to the last but one
	config_file_names = sys.argv[1:len(config_file_names)+1]

# Target linker script file
ld_file_name = 'sw/SoC/common/UninaSoC.ld'
if len(sys.argv) >= 5:
	# Get the linker script name, the last arg
	ld_file_name = sys.argv[len(config_file_names)+1]


###############
# Read config #
###############
# Read CSV files for each bus
config_dfs = []
for name in config_file_names:
	config_dfs.append(pd.read_csv(name, sep=",", index_col=0))

# Each bus has an element in these vectors
NUM_MI = []
RANGE_NAMES = []
RANGE_BASE_ADDR = []
RANGE_ADDR_WIDTH = []
# For each bus
for config_df in config_dfs:

	# Skip DISABLE buses
	if config_df.loc["PROTOCOL"]["Value"] == "DISABLE":
		continue

	# Read number of masters interfaces
	NUM_MI.append(int(config_df.loc["NUM_MI"]["Value"]))
	# print("[DEBUG] NUM_MI", NUM_MI)

	# Read slaves' names
	RANGE_NAMES.append(config_df.loc["RANGE_NAMES"]["Value"].split())
	# print("[DEBUG] RANGE_NAMES", RANGE_NAMES)

	# Read address Ranges
	RANGE_BASE_ADDR.append(config_df.loc["RANGE_BASE_ADDR"]["Value"].split())
	# print("[DEBUG] RANGE_BASE_ADDR", RANGE_BASE_ADDR)

	# Read address widths
	RANGE_ADDR_WIDTH.append(config_df.loc["RANGE_ADDR_WIDTH"]["Value"].split())
	# Turns the values into Integers
	for i in range(len(RANGE_ADDR_WIDTH[-1])):
		RANGE_ADDR_WIDTH[-1][i] = int(RANGE_ADDR_WIDTH[-1][i])

# Currently the first memory device is selected as the boot memory device
BOOT_MEMORY_BLOCK = 0x0


################
# Sanity check #
################
# For each bus
for i in range(len(NUM_MI)):
	assert (NUM_MI[i] == len(RANGE_NAMES[i])) & (NUM_MI[i] == len(RANGE_BASE_ADDR[i]) ) & (NUM_MI[i]  == len(RANGE_ADDR_WIDTH[i])), \
		"Mismatch in lenght of configurations: NUM_MI(" + str(NUM_MI[i]) + "), RANGE_NAMES (" + str(len(RANGE_NAMES[i])) + \
		"), RANGE_BASE_ADDR(" + str(len(RANGE_BASE_ADDR[i])) + ") RANGE_ADDR_WIDTH(" + str(len(RANGE_ADDR_WIDTH[i])) + ")"

##########################
# Generate memory blocks #
##########################
# Currently only one copy of BRAM, DDR and HBM memory ranges are supported.

device_dict = {
	'memory':		[],
	'peripheral':	[]
}

counter = 0
# For each bus
for i in range(len(RANGE_NAMES)):
	for device in RANGE_NAMES[i]:
		match device:
			# memory blocks
			# TODO77: extend for multiple BRAMs
			case d if d in {"BRAM", "HBM"} or d.startswith("DDR4CH"):
				device_dict['memory'].append({'device': device, 'base': int(RANGE_BASE_ADDR[i][counter], 16), 'range': 1 << RANGE_ADDR_WIDTH[i][counter]})

			# peripherals
			case _:
				# Check if the device is not a bus (the last three chars are not BUS)
				if device[-3:] != "BUS":
					device_dict['peripheral'].append({'device': device, 'base': int(RANGE_BASE_ADDR[i][counter], 16), 'range': 1 << RANGE_ADDR_WIDTH[i][counter]})

		# Increment counter
		counter += 1
		# If we reach the last element of a bus we need to reset the counter to start with a new bus
		if counter == len(RANGE_NAMES[i]):
			counter = 0


###############################
# Generate Linker Script File #
###############################

# Create the Linker Script File
fd = open(ld_file_name,  "w")

# Write header
fd.write("/* This file is auto-generated with " + os.path.basename(__file__) + " */\n")

# Generate the memory blocks layout
fd.write("\n")
fd.write("/* Memory blocks */\n")
fd.write("MEMORY\n")
fd.write("{\n")

for block in device_dict['memory']:
	fd.write("\t" + block['device'] + " (xrw) : ORIGIN = 0x" + format(block['base'], "016x") + ",  LENGTH = " + hex(block['range']) + "\n")
fd.write("}\n")

# Generate symbols from peripherals
fd.write("\n")
fd.write("/* Peripherals symbols */\n")
for peripheral in device_dict['peripheral']:
	fd.write("_peripheral_" + peripheral['device'] + "_start = 0x" + format(peripheral['base'], "016x") + ";\n")
	fd.write("_peripheral_" + peripheral['device'] + "_end = 0x" + format(peripheral['base'] + peripheral['range'], "016x") + ";\n")

# Generate global symbols
fd.write("\n")
fd.write("/* Global symbols */\n")
# Vector table is placed at the beggining of the boot memory block.
# It is aligned to 256 bytes and is 32 words deep. (as described in risc-v spec)
#vector_table_start  =  memory_block_list[BOOT_MEMORY_BLOCK][DEVICE_ORIGIN]
vector_table_start  =  device_dict['memory'][BOOT_MEMORY_BLOCK]['base']
fd.write("_vector_table_start = 0x" + format(vector_table_start, "016x") + ";\n")
fd.write("_vector_table_end = 0x" + format(vector_table_start + 32*4, "016x") + ";\n")

# The stack is allocated at the end of first memory block
# _stack_end can be user-defined for the application, as bss and rodata
# _stack_end will be aligned to 64 bits, making it working for both 32 and 64 bits configurations

# Note: The memory size specified in the config.csv file may differ from the
# physical memory allocated for the SoC (refer to hw/xilinx/ips/common/xlnx_blk_mem_gen/config.tcl).
# Currently, the configuration process does not ensure alignment between config.csv
# and xlnx_blk_mem_gen/config.tcl. As a result, we assume a maximum memory size of
# 32KB for now, based on the current setting in `config.tcl`.

stack_start = device_dict['memory'][BOOT_MEMORY_BLOCK]['base'] + device_dict['memory'][BOOT_MEMORY_BLOCK]['range'] - 0x8
fd.write("_stack_start = 0x" + format(stack_start, "016x") + ";\n")

# Generate sections
# vector table and text sections are here defined.
# data, bss and rodata can be explicitly defined by the user application if required.
fd.write("\n")
fd.write("/* Sections */\n")
fd.write("SECTIONS\n")
fd.write("{\n")

# Vector Table section
fd.write("\t.vector_table _vector_table_start :\n")
fd.write("\t{\n")
fd.write("\t\tKEEP(*(.vector_table))\n")
fd.write("\t}> " + device_dict['memory'][BOOT_MEMORY_BLOCK]['device'] + "\n")

# Text section
fd.write("\n")
fd.write("\t.text :\n")
fd.write("\t{\n")
fd.write("\t\t. = ALIGN(32);\n")
fd.write("\t\t_text_start = .;\n")
fd.write("\t\t*(.text.handlers)\n")
fd.write("\t\t*(.text.start)\n")
fd.write("\t\t*(.text)\n")
fd.write("\t\t*(.text*)\n")
fd.write("\t\t. = ALIGN(32);\n")
fd.write("\t\t_text_end = .;\n")
fd.write("\t}> " + device_dict['memory'][BOOT_MEMORY_BLOCK]['device'] + "\n")

fd.write("}\n")

# Files closing
fd.write("\n")
fd.close()



