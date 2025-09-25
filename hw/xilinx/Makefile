# Environment check
ifndef XILINX_ROOT
$(error Setup script settings.sh has not been sourced, aborting)
endif

#########################
# Include configuration #
#########################

include make/config.mk

######################
# Vivado environment #
######################

include make/environment.mk

# Default target
all: bitstream

#########
# Build #
#########

include make/build.mk

#############
# Utilities #
#############

include make/utils.mk

##############
# Simulation #
##############

include make/sim.mk

###############
# Load binary #
###############

include make/load_binary.mk

############
# Cleaning #
############
# Clean up project
clean:
	rm -rf ${XILINX_PROJECT_BUILD_DIR}
	rm -rf vivado*.log vivado*.jou vivado*.str

clean_ips/%.xci:
	rm -rf ${XILINX_IPS_ROOT}/*/$*/build
	rm -rf ${XILINX_IPS_ROOT}/$*.xci

clean_ips:
	rm -rf ${XILINX_IPS_ROOT}/*/*/build
	rm -rf ${XILINX_IPS_ROOT}/*.xci

###########
# PHONIES #
###########
.PHONY: bitstream ips clean clean_ips

