# This Makefile orchestrates the build of example application
#
# Usage:
#		make freertos # Clone FreeRTOS-Kernel sources
#		make all      # build all the applications
#
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>

ifndef ROOT_DIR
$(error Setup script settings.sh has not been sourced, aborting)
endif

APP_DIR := app
APPS    := $(notdir $(wildcard $(APP_DIR)/*))

# default = build all apps
all: freertos $(APPS)

# call make inside app/<name>
$(APPS):
	@$(MAKE) -C $(APP_DIR)/$@ all

# retrieve freertos source code
freertos:
	@echo "Retrieving FreeRTOS-Kernel code..."
	@git submodule update --init --recursive FreeRTOS-Kernel

# clean everything
clean:
	@for a in $(APPS); do \
		$(MAKE) -C $(APP_DIR)/$$a clean; \
	done

.PHONY: all clean
