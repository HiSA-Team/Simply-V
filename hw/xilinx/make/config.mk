# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description:
#    Hold all the configurable variables.
#    This file is meant to be updated by the configuration flow.

##########
# Values #
##########

# System
XLEN ?= 32
PHYSICAL_ADDR_WIDTH ?= 32

# MBUS
MBUS_NUM_SI ?= 5
MBUS_NUM_MI ?= 5
MBUS_ADDR_WIDTH ?= ${PHYSICAL_ADDR_WIDTH}
MBUS_DATA_WIDTH ?= ${XLEN}
MBUS_ID_WIDTH ?= 4

# PBUS
PBUS_NUM_MI ?= 5
PBUS_ID_WIDTH ?= 4

# HBUS
HBUS_NUM_MI ?= 0
HBUS_NUM_SI ?= 0
HBUS_ID_WIDTH ?= 0

# RV core
CORE_SELECTOR ?= CORE_CV32E40P

# VIO resetn
VIO_RESETN_DEFAULT ?= 1

# Clock domains
MAIN_CLOCK_FREQ_MHZ ?= 20
RANGE_CLOCK_DOMAINS ?= MAIN_CLOCK_DOMAIN PBUS_HAS_CLOCK_DOMAIN