# Environment check
ifndef ROOT_DIR
$(error Setup script settings.sh has not been sourced, aborting)
endif

SHELL := /bin/bash

# All custom IPs directories, excluding custom_template
IP_RTL_LIST = $(filter-out custom_template, $(shell basename --multiple ${HW_UNITS_ROOT}/custom_*) )

all: units

units: $(addsuffix /rtl, ${IP_RTL_LIST})

# Fetch sources for all IPs without local rtl
custom_%/rtl:
	cd ${HW_UNITS_ROOT}/custom_$*; source fetch_sources.sh \
# 	Check if sources are preset, error otherwise and clean stale dir
	if [ -z "$(shell ls -A $${HW_UNITS_ROOT}/$$@)" ]; then \
		echo "[UNITS] Failed to fetch sources for $@"  >&2; \
		rm -rf $@; \
		false; \
	fi

# Selectively remove a single RTL dir
clean_custom_%:
	rm -rf ${HW_UNITS_ROOT}/custom_$*/rtl

# Remove all RTL dirs
clean:
	rm -rf ${HW_UNITS_ROOT}/*/rtl


.PHONY: clean
