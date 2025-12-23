# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description:
#   Top Makefile for sub-directories


# List of targets
HELLO_CORES = $(shell basename --multiple $$PWD/hello_core*)

all: hello_cores

# Single target
hello_cores:
	for dir in ${HELLO_CORES}; do \
		${MAKE} -C $${dir} all; \
	done

# Clean target
clean:
	for dir in ${HELLO_CORES}; do \
		${MAKE} -C $${dir} clean; \
	done

# PHONY
.PHONY: ${HELLO_CORES}