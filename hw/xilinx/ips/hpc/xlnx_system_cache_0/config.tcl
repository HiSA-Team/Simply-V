# Author: Valerio Di Domenico <valerio.didomenico@unina.it>
# Description: AXI System Cache for DRAM channels. This IP also introduces support for AXI atomic operations
create_ip -name system_cache -vendor xilinx.com -library ip -version 5.0 -module_name $::env(IP_NAME)

##############
# Interfaces #
##############
# - Enable AXI memory interface (S0 generic port, S0_AXI_GEN_*)
#   - Data width: $::env(MBUS_DATA_WIDTH)
#   - ID width: $::env(MBUS_ID_WIDTH)
#   - Address width: $::env(MBUS_ADDR_WIDTH)
# - Enable AXI master interface (C_M0_AXI_*)
#   - Data width: 512 bit (keep same as DDR for now)
#   - Thread ID width: $::env(MBUS_ID_WIDTH)
#   - Address width: $::env(MBUS_ADDR_WIDTH)
# - Exclusive access support enabled (C_ENABLE_EXCLUSIVE = 1)
# - Base address: Absolute address of start of cachable range
# - High address: Absolute address of end of cachable range
# - Cache line length: 32 bytes, constant for now
# - CCIX0 cache line size: 128 bytes, constant for now
# - Other optional interfaces (ACE, CHI, CCIX, snoop, coherency, etc.) disabled

# Set the cache BASEADDR and HIGHADDR
# WARNING: Do not change the following line, it is modified by config-based script
set CACHE_BASEADDR {0x40000}
set CACHE_HIGHADDR {0x4ffff}

set_property -dict [list \
  CONFIG.C_CACHE_LINE_LENGTH {32} \
  CONFIG.C_FREQ {250} \
  CONFIG.C_CACHE_SIZE {32768} \
  CONFIG.C_M0_AXI_DATA_WIDTH {512} \
  CONFIG.C_S0_AXI_GEN_DATA_WIDTH $::env(MBUS_DATA_WIDTH) \
  CONFIG.C_NUM_OPTIMIZED_PORTS {0} \
  CONFIG.C_NUM_GENERIC_PORTS {1} \
  CONFIG.C_S0_AXI_GEN_ID_WIDTH $::env(MBUS_ID_WIDTH) \
  CONFIG.C_S0_AXI_GEN_ADDR_WIDTH $::env(MBUS_ADDR_WIDTH) \
  CONFIG.C_BASEADDR $CACHE_BASEADDR \
  CONFIG.C_HIGHADDR $CACHE_HIGHADDR \
  CONFIG.C_ENABLE_EXCLUSIVE {1} \
  CONFIG.C_CCIX0_CACHE_LINE_SIZE {128} \
  CONFIG.C_M0_AXI_THREAD_ID_WIDTH $::env(MBUS_ID_WIDTH) \
  CONFIG.C_M0_AXI_ADDR_WIDTH $::env(MBUS_ADDR_WIDTH) \
  CONFIG.C_ENABLE_COHERENCY {0} \
  CONFIG.C_ENABLE_SLAVE_COHERENCY {0} \
  CONFIG.C_ENABLE_MASTER_COHERENCY {0} \
  CONFIG.C_ENABLE_ACE_PROTOCOL {0} \
  CONFIG.C_ENABLE_CCIX_PROTOCOL {0} \
  CONFIG.C_ENABLE_CHI_PROTOCOL {0} \
  CONFIG.C_ENABLE_INTEGRITY {0} \
  CONFIG.C_ENABLE_NON_SECURE {0} \
  CONFIG.C_ENABLE_ERROR_HANDLING {0} \
  CONFIG.C_ENABLE_CTRL {0} \
  CONFIG.C_ENABLE_STATISTICS {0} \
  CONFIG.C_ENABLE_VERSION_REGISTER {0} \
  CONFIG.C_ENABLE_INTERRUPT {0} \
  CONFIG.C_ENABLE_ADDRESS_TRANSLATION {0} \
  CONFIG.C_NUM_WAYS {2} \
  CONFIG.C_NUM_SLAVE_TRANSACTIONS {16} \
  CONFIG.C_NUM_MASTER_TRANSACTIONS {32} \
  CONFIG.C_NUM_SNOOP_TRANSACTIONS {16} \
  CONFIG.C_NUM_OOO_CHANNELS {0} \
  CONFIG.C_CACHE_DATA_WIDTH {512} \
  CONFIG.C_CACHE_TAG_MEMORY_TYPE {0} \
  CONFIG.C_CACHE_DATA_MEMORY_TYPE {0} \
  CONFIG.C_CACHE_LRU_MEMORY_TYPE {0} \
  CONFIG.C_Lx_CACHE_LINE_LENGTH {4} \
  CONFIG.C_Lx_CACHE_SIZE {8192} \
  CONFIG.C_SUPPORT_SNOOP_FILTER {0} \
  CONFIG.C_SNOOP_KEEP_READ_ONCE {1} \
  CONFIG.C_SNOOP_KEEP_READ_SHARED {0} \
  CONFIG.C_SNOOP_KEEP_READ_CLEAN {0} \
  CONFIG.C_SNOOP_KEEP_READ_NSD {0} \
  CONFIG.C_SNOOP_KEEP_CLEAN_SHARED {0} \
  CONFIG.C_SNOOP_KEEP_SNPTOSC {0} \
  CONFIG.C_SNOOP_PASS_READ_ONCE {0} \
  CONFIG.C_SNOOP_PASS_READ_SHARED {0} \
  CONFIG.C_SNOOP_PASS_READ_CLEAN {0} \
  CONFIG.C_SNOOP_PASS_READ_NSD {0} \
  CONFIG.C_DEFAULT_DOMAIN {0} \
] [get_ips $::env(IP_NAME)]

# TODO152: This does not exist for Vivado 2023.1 and au280. Make this version/board dependent.
#  CONFIG.C_ENABLE_FAST_INIT_SIM {0}
