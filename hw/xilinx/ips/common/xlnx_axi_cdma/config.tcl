# Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
# Description: Simple DMA Mode (C_INCLUDE_SG=0) for AXI CDMA IP

# Import the IP core
create_ip -name axi_cdma -vendor xilinx.com -library ip -version 4.1 -module_name $::env(IP_NAME)

# Main Parameters
set CDMA_SG_MODE 0              ;# 0 = Simple DMA
set CDMA_DATA_WIDTH 32          ;# 32-bit workaround (64-bit bug)
set CDMA_ADDR_WIDTH 32
set CDMA_CLK_FREQ 100000000

# IP Core Configuration
set_property -dict [list \
    CONFIG.C_INCLUDE_SG              $CDMA_SG_MODE \
    CONFIG.C_INCLUDE_DRE             {1} \
    CONFIG.C_INCLUDE_SF              {1} \
    CONFIG.C_USE_DATAMOVER_LITE      {0} \
    CONFIG.C_ENABLE_KEYHOLE          {0} \
    CONFIG.C_AXI_LITE_IS_ASYNC       {0} \
    CONFIG.C_ADDR_WIDTH              $CDMA_ADDR_WIDTH \
    CONFIG.C_M_AXI_DATA_WIDTH        $CDMA_DATA_WIDTH \
    CONFIG.C_M_AXI_MAX_BURST_LEN     {256} \
    CONFIG.C_READ_ADDR_PIPE_DEPTH    {1} \
    CONFIG.C_WRITE_ADDR_PIPE_DEPTH   {1} \
    CONFIG.M_AXI_ACLK.FREQ_HZ        $CDMA_CLK_FREQ \
    CONFIG.S_AXI_LITE_ACLK.FREQ_HZ   $CDMA_CLK_FREQ \
] [get_ips $::env(IP_NAME)]
