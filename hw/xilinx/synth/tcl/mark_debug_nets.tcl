# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Description: Mark nets in the post-syntesis netlist for debug

set cell_name hls_conv2d_wrapper_u/custom_hls_conv_hbus_u

###############
# HLS control #
###############

# AR
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_araddr*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_arvalid*"} ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_arready*"} ]
# R
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_rvalid*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_rdata*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_rready*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_rresp*"}  ]
# AW
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_awaddr*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_awvalid*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_awready*"}  ]
# W
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_wready*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_wvalid*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_wdata*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_wstrb*"}  ]
# B
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_bvalid*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_bresp*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axilite_bready*"}  ]

#####################
# Post clock bridge #
#####################
# All nets
set_property MARK_DEBUG 1 [get_nets hls_conv2d_wrapper_u/sync_HLS_CONTROL_axi_*]

##################
# 512-bit master #
##################

# AW channel
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awid*"}     ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awaddr*"}   ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awlen*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awsize*"}   ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awburst*"}  ]
# # set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awlock*"}   ]
# # set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awcache*"}  ]
# # set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awprot*"}   ]
# # set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awqos*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awvalid*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awready*"}  ]
# # set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_awregion*"} ]

# W channel
# Special case for 512 data: let's avoid using too many nets, by only getting the first 64-bits
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_wdata*"}    ]
set all_data_nets [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_wdata*"} ]
set probed_data_nets [filter -regexp $all_data_nets {NAME =~ {^.*\[(0|[1-9]|[1-5][0-9]|6[0-3])\]$}}]
set_property MARK_DEBUG 1 [get_nets $probed_data_nets]

set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_wstrb*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_wlast*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_wvalid*"}   ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_wready*"}   ]

# B channel
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_bid*"}      ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_bresp*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_bvalid*"}   ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_bready*"}   ]

# AR channel
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_araddr*"}   ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arlen*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arsize*"}   ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arburst*"}  ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arlock*"}   ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arcache*"}  ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arprot*"}   ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arqos*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arvalid*"}  ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arready*"}  ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arid*"}     ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_arregion*"} ]
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_rid*"}      ]

# R channel
# Special case for 512 data: let's avoid using too many nets, by only getting the first 64-bits
# set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_rdata*"}    ]
set all_data_nets [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_rdata*"} ]
set probed_data_nets [filter -regexp $all_data_nets {NAME =~ {^.*\[(0|[1-9]|[1-5][0-9]|6[0-3])\]$}}]
set_property MARK_DEBUG 1 [get_nets $probed_data_nets]

set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_rresp*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_rlast*"}    ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_rvalid*"}   ]
set_property MARK_DEBUG 1 [get_nets -of [get_cells $cell_name] -filter {NAME=~"*_axi_rready*"}  ]