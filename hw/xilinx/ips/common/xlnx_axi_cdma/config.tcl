# ============================================================
# Xilinx AXI Central DMA (AXI CDMA) - config.tcl
# Modalità Simple DMA (C_INCLUDE_SG=0)
# Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
# ============================================================

# Import IP
create_ip -name axi_cdma -vendor xilinx.com -library ip -version 4.1 -module_name $::env(IP_NAME)

# ============================================================
# Parametri principali
# ============================================================
set CDMA_SG_MODE 0              ;# 0 = Simple DMA
set CDMA_DATA_WIDTH 32          ;# 32-bit workaround (64-bit bug)
set CDMA_ADDR_WIDTH 32
set CDMA_CLK_FREQ 100000000

# ============================================================
# Configurazione IP
# ============================================================
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

# ============================================================
# Checkpoint synthesis (per stabilità build)
# ============================================================
#set_property GENERATE_SYNTH_CHECKPOINT true [get_files $::env(IP_NAME).xci]
generate_target all [get_ips $::env(IP_NAME)]
import_files -fileset constrs_1 $::env(XILINX_IPS_ROOT)/common/xlnx_axi_cdma/xlnx_axi_cdma_fix.xdc




# ============================================================
# Fine configurazione IP
# ============================================================

