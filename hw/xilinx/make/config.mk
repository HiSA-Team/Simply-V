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
MBUS_NUM_MI ?= 7
MBUS_ADDR_WIDTH ?= ${PHYSICAL_ADDR_WIDTH}
MBUS_DATA_WIDTH ?= ${XLEN}
MBUS_ID_WIDTH ?= 3

# PBUS
PBUS_NUM_MI ?= 3
PBUS_ID_WIDTH ?= 2

# HBUS
HBUS_NUM_MI ?= 2
HBUS_NUM_SI ?= 2
HBUS_ID_WIDTH ?= 3

# RV core
CORE_SELECTOR ?= CORE_MICROBLAZEV

# VIO resetn
VIO_RESETN_DEFAULT ?= 1

# Clock domains
MAIN_CLOCK_FREQ_MHZ ?= 100
RANGE_CLOCK_DOMAINS ?= MAIN_CLOCK_DOMAIN PBUS_HAS_CLOCK_DOMAIN HLS_CONTROL_HAS_CLOCK_DOMAIN DDR1_HAS_CLOCK_DOMAIN HBUS_HAS_CLOCK_DOMAIN
