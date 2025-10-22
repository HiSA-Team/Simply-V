# Import IP by version
create_ip -name microblaze_riscv -vendor xilinx.com -library ip -version 1.0 -module_name $::env(IP_NAME)


# Configure IP

# Set configuration preset (1: Microcontroller, 2: Real-time, 4: RVIMC, 5: RVIMAC, 6: RVIMAFC)
# NOTE: Set this first, since it overrides other configs
set_property CONFIG.G_TEMPLATE_LIST         {1} [get_ips $::env(IP_NAME)]

##############
# Interfaces #
##############
# - Enable debug for MDMV (PG428)
# - Disable trace
# - Disable discrete
# - Enable only AXI memory
#   - AXI-full data port
#   - AXI-lite instruction port (no AXI-full support)
#   - Disable all other instruction/memory interfaces (ILMB/DLMB: local memory bus, IC/DC: Cache interfaces)
#   - Disable AXI stream
# - Changing C_HARTID is actually ineffective
set_property -dict [list \
        CONFIG.C_DEBUG_ENABLED              {1} \
        CONFIG.C_HARTID                     {0} \
        CONFIG.C_ENABLE_DISCRETE_PORTS      {0} \
        CONFIG.C_D_AXI                      {1} \
        CONFIG.C_I_AXI                      {1} \
        CONFIG.C_USE_DCACHE                 {0} \
        CONFIG.C_USE_ICACHE                 {0} \
        CONFIG.C_M_AXI_D_BUS_EXCEPTION      {1} \
        CONFIG.C_M_AXI_I_BUS_EXCEPTION      {1} \
        CONFIG.C_M_AXI_DP_EXCLUSIVE_ACCESS  {1} \
        CONFIG.C_D_LMB                      {0} \
        CONFIG.C_I_LMB                      {0} \
        CONFIG.C_USE_BARREL                 {1} \
        CONFIG.C_USE_COUNTERS               {1} \
        CONFIG.C_ILL_INSTR_EXCEPTION        {2} \
        CONFIG.C_USE_INTERRUPT              {1} \
    ] [get_ips $::env(IP_NAME)]

# More unset properties for future reference
# set_property -dict [list \
#         CONFIG.C_DEBUG_EVENT_COUNTERS       {0} \
#         CONFIG.C_DEBUG_LATENCY_COUNTERS     {0} \
#         CONFIG.C_FAULT_TOLERANT             {0} \
#         CONFIG.C_FSL_LINKS                  {0} \
#         CONFIG.C_LOCKSTEP_SELECT            {0} \
#         CONFIG.C_NUMBER_OF_PC_BRK           {1} \
#         CONFIG.C_NUMBER_OF_RD_ADDR_BRK      {0} \
#         CONFIG.C_NUMBER_OF_WR_ADDR_BRK      {0} \
#         CONFIG.C_TRACE                      {0} \
#         CONFIG.C_USE_BRANCH_TARGET_CACHE    {0} \
#         CONFIG.C_INTERCONNECT               {2} \
#     ] [get_ips $::env(IP_NAME)]

###############################
# AXI interconnect parameters #
###############################
# Data width
set_property CONFIG.C_DATA_SIZE 64 [get_ips $::env(IP_NAME)]
# Address width
# - If RV32, address width is fixed equal to data width
# - If RV64, supported: 32, 36, 40, 44, 48, 52, 56, 64
set_property CONFIG.C_ADDR_SIZE $::env(MBUS_ADDR_WIDTH)  [get_ips $::env(IP_NAME)]
# AXI ID width is fixed to 1

##########
# RISC-V #
##########
# C-ext
set_property CONFIG.C_USE_COMPRESSION       {1} [get_ips $::env(IP_NAME)]
# A-ext
set_property CONFIG.C_USE_ATOMIC            {1} [get_ips $::env(IP_NAME)]
# M-ext (1: STANDARD; 2: OPTIMIZED)
set_property CONFIG.C_USE_MULDIV            {1} [get_ips $::env(IP_NAME)]
# F/D-ext (0: none; 1: F; 2: D)
# - F only if RV32 (C_DATA_SIZE = 32)
# - D only if RV64 (C_DATA_SIZE = 64)
set_property CONFIG.C_USE_FPU               {0} [get_ips $::env(IP_NAME)]
# Bit-manipulation (Zba, Zbb, Zbc, Zbs)
set_property CONFIG.C_USE_BITMAN_A          {0} [get_ips $::env(IP_NAME)]
set_property CONFIG.C_USE_BITMAN_B          {0} [get_ips $::env(IP_NAME)]
set_property CONFIG.C_USE_BITMAN_C          {0} [get_ips $::env(IP_NAME)]
set_property CONFIG.C_USE_BITMAN_S          {0} [get_ips $::env(IP_NAME)]
# PMP entries and granularity
set_property CONFIG.C_PMP_ENTRIES           {0} [get_ips $::env(IP_NAME)]
set_property CONFIG.C_PMP_GRANULARITY       {2} [get_ips $::env(IP_NAME)]
# Enable User mode (no Supervisor for now)
set_property CONFIG.C_USE_MMU               {0} [get_ips $::env(IP_NAME)]
# set_property CONFIG.C_MMU_PRIVILEGED_INSTR  {0} [get_ips $::env(IP_NAME)]
# Illegal instruction exception (1:BASIC, 2: COMPLETE)
set_property CONFIG.C_ILL_INSTR_EXCEPTION   {2} [get_ips $::env(IP_NAME)]
