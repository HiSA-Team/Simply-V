# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description:
#  Top Makefile for the software flow. It just redirects to sub-folders' Makefiles.

# Environment check
ifndef SW_ROOT
$(error Setup script settings.sh has not been sourced, aborting)
endif


all: host SoC

VIRTUAL_UART_PATH = ${SW_HOST_ROOT}/virtual_uart
host:
#	Virtual UART is the only host application so far
	make -C ${VIRTUAL_UART_PATH}

SoC:
#	Init and checkout tinyIO
	git submodule update --init SoC/lib/tinyio
#	Build SoC sw 	
	make -C ${SW_SOC_ROOT}

clean:
	make -C ${VIRTUAL_UART_PATH} clean
	make -C ${SW_SOC_ROOT} clean

.PHONY: host SoC