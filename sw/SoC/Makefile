# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
#  This is a global makefile for the System-on-Chip software projects.
#  It can be used to compile all default examples

# Environment check
ifndef ROOT_DIR
$(error Setup script settings.sh has not been sourced, aborting)
endif

EXAMPLES_NAMES := $(shell basename --multiple $(SW_ROOT)/SoC/examples/*)
EXAMPLES_LIST  := $(foreach ip,${EXAMPLES_NAMES},$(SW_ROOT)/SoC/examples/${ip})

# We need to import the XLEN envvar
include $(SW_ROOT)/SoC/common/config.mk

all: lib examples

# Compile all examples in the example dir
examples:
	@echo "[Make] Compile all the example projects"
	@for example in ${EXAMPLES_LIST}; do \
		echo "[Make] Compiling project $$example" ; \
		${MAKE} -C $$example && \
		echo "\n[Make] Done\n" ; \
	done

# Build all libraries
lib:
	@echo "[Make] Compile all the libraries"
#	Build TinyIO
	${MAKE} -C lib/tinyio XLEN=${XLEN} C_EXTENSION=Y
#	Build light-weight HAL
	${MAKE} -C lib/uninasoc

clean:
	@echo "[Make] Clean all the example projects"
	@for example in ${EXAMPLES_LIST}; do \
		echo "[Make] Compiling project $$example" ; \
		${MAKE} -C $$example clean; \
		echo "\n[Make] Done\n" ; \
	done


.PHONY: examples lib
