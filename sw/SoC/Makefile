# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
# Description:
#  This is a global makefile for the System-on-Chip software projects.
#  It can be used to compile all default examples

# Environment check
ifndef ROOT_DIR
$(error Setup script settings.sh has not been sourced, aborting)
endif

EXAMPLES_NAMES := $(shell basename --multiple $(SW_ROOT)/SoC/examples/*)
EXAMPLES_LIST  := $(foreach ip,${EXAMPLES_NAMES},$(SW_ROOT)/SoC/examples/${ip})
PROJECTS_NAMES := $(shell basename --multiple $(SW_ROOT)/SoC/projects/*)
PROJECTS_LIST  := $(foreach ip,${PROJECTS_NAMES},$(SW_ROOT)/SoC/projects/${ip})

# We need to import the XLEN envvar
include $(SW_ROOT)/SoC/common/config.mk

all: lib examples projects

# Compile all examples in the example dir
examples: lib
	@echo "[Make] Compile all the example projects"
	@for example in ${EXAMPLES_LIST}; do \
		echo "[Make] Compiling example $$example" ; \
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

projects: lib
	@echo "[Make] Compile all the projects"
	@for project in ${PROJECTS_LIST}; do \
		echo "[Make] Compiling project $$project" ; \
		${MAKE} -C $$project && \
		echo "\n[Make] Done\n" ; \
	done

clean:
	@echo "[Make] Clean all the example projects"
	@for example in ${EXAMPLES_LIST}; do \
		${MAKE} -C $$example clean ; \
	done
	@for project in ${PROJECTS_LIST}; do \
		${MAKE} -C $$project clean ; \
	done
	@echo "[Make] Clean library projects"
	${MAKE} -C lib/tinyio clean
	${MAKE} -C lib/uninasoc clean

.PHONY: examples lib
