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
MBUS_NUM_MI ?= 6
MBUS_ADDR_WIDTH ?= 32
MBUS_DATA_WIDTH ?= 32
MBUS_ID_WIDTH ?= 5

# PBUS
PBUS_NUM_SI ?= 1
PBUS_NUM_MI ?= 5
PBUS_ID_WIDTH ?= 5

# HBUS
HBUS_NUM_MI ?= 2
HBUS_NUM_SI ?= 2
HBUS_ID_WIDTH ?= 4

# RV core
CORE_SELECTOR ?= CORE_CV32E40P

# VIO resetn
VIO_RESETN_DEFAULT ?= 1

# Clock domains
MAIN_CLOCK_FREQ_MHZ ?= 20
RANGE_CLOCK_DOMAINS ?= MAIN_CLOCK_DOMAIN PBUS_HAS_CLOCK_DOMAIN
