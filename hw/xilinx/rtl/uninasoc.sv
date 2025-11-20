// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Author: Zaira Abdel Majid <z.abdelmajid@studenti.unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Description: FPGA-ready top-level soft-SoC module for both hpc and embedded profiles.

// System architecture:
//
//                                                     __________                     ________
//   ____________                                     |          |                   |        |
//  |            |                                    |          |------------------>|  BRAM  |
//  | sys_master |----------------------------------->|          |                   |________|
//  |____________|                                    |          |                    ___________
//   ______________                                   |          |                   |           |
//  |              |--------------------------------->|          |------------------>|  DDR4CH1  |
//  | Debug Module |                                  |   Main   |                   |___________|
//  |______________|<---------------------------------|   Bus    |                    __________________
//                                                    |  (MBUS)  |                   |                  |
//                                                    |          |------------------>| High-performance |
//                                                    |          |                   |       bus        |<------\
//                                                    |          |<------------------|     (HBUS)       |       |
//                                                    |          |                   |__________________|       |
//                                                    |          |                    ______________            |
//                                                    |          |                   |              |-----------/
//                                                    |          |------------------>|  HLS wrapper |
//                                                    |          |                   |______________|-----------\
//                                                    |          |                    ________________          |
//                                                    |          |                   |                |         v
//                                                    |          |------------------>| Peripheral bus |---------\
//                                                    |          |                   |     (PBUS)     |         |
//                                                    |          |                   |________________|         | peripheral
//   _________              ____________              |          |                    ________________          | interrupts
//  |         |            |            |             |          |                   |                |         |
//  |   vio   |----------->| rv_socket  |------------>|          |------------------>|      PLIC      |<--------/
//  |_________|            |____________|             |          |                   |________________|
//                                ^                   |          |                            |
//                                |                   |__________|                            |
//                                |                                                           |
//                                \___________________________________________________________/
//                                                 platform interrupt

/////////////////////
// Import packages //
/////////////////////

import uninasoc_pkg::*;

////////////////////
// Import headers //
////////////////////

`include "uninasoc_axi.svh"

// Concatenate 7 slave buses
`define CONCAT_AXI_MASTERS_ARRAY7(array_name, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
    assign ``array_name``_axi_awid     = {``bus_name6``_axi_awid      , ``bus_name5``_axi_awid      , ``bus_name4``_axi_awid      , ``bus_name3``_axi_awid      , ``bus_name2``_axi_awid      , ``bus_name1``_axi_awid      , ``bus_name0``_axi_awid     }; \
    assign ``array_name``_axi_awaddr   = {``bus_name6``_axi_awaddr    , ``bus_name5``_axi_awaddr    , ``bus_name4``_axi_awaddr    , ``bus_name3``_axi_awaddr    , ``bus_name2``_axi_awaddr    , ``bus_name1``_axi_awaddr    , ``bus_name0``_axi_awaddr   }; \
    assign ``array_name``_axi_awlen    = {``bus_name6``_axi_awlen     , ``bus_name5``_axi_awlen     , ``bus_name4``_axi_awlen     , ``bus_name3``_axi_awlen     , ``bus_name2``_axi_awlen     , ``bus_name1``_axi_awlen     , ``bus_name0``_axi_awlen    }; \
    assign ``array_name``_axi_awsize   = {``bus_name6``_axi_awsize    , ``bus_name5``_axi_awsize    , ``bus_name4``_axi_awsize    , ``bus_name3``_axi_awsize    , ``bus_name2``_axi_awsize    , ``bus_name1``_axi_awsize    , ``bus_name0``_axi_awsize   }; \
    assign ``array_name``_axi_awburst  = {``bus_name6``_axi_awburst   , ``bus_name5``_axi_awburst   , ``bus_name4``_axi_awburst   , ``bus_name3``_axi_awburst   , ``bus_name2``_axi_awburst   , ``bus_name1``_axi_awburst   , ``bus_name0``_axi_awburst  }; \
    assign ``array_name``_axi_awlock   = {``bus_name6``_axi_awlock    , ``bus_name5``_axi_awlock    , ``bus_name4``_axi_awlock    , ``bus_name3``_axi_awlock    , ``bus_name2``_axi_awlock    , ``bus_name1``_axi_awlock    , ``bus_name0``_axi_awlock   }; \
    assign ``array_name``_axi_awcache  = {``bus_name6``_axi_awcache   , ``bus_name5``_axi_awcache   , ``bus_name4``_axi_awcache   , ``bus_name3``_axi_awcache   , ``bus_name2``_axi_awcache   , ``bus_name1``_axi_awcache   , ``bus_name0``_axi_awcache  }; \
    assign ``array_name``_axi_awprot   = {``bus_name6``_axi_awprot    , ``bus_name5``_axi_awprot    , ``bus_name4``_axi_awprot    , ``bus_name3``_axi_awprot    , ``bus_name2``_axi_awprot    , ``bus_name1``_axi_awprot    , ``bus_name0``_axi_awprot   }; \
    assign ``array_name``_axi_awqos    = {``bus_name6``_axi_awqos     , ``bus_name5``_axi_awqos     , ``bus_name4``_axi_awqos     , ``bus_name3``_axi_awqos     , ``bus_name2``_axi_awqos     , ``bus_name1``_axi_awqos     , ``bus_name0``_axi_awqos    }; \
    assign ``array_name``_axi_awvalid  = {``bus_name6``_axi_awvalid   , ``bus_name5``_axi_awvalid   , ``bus_name4``_axi_awvalid   , ``bus_name3``_axi_awvalid   , ``bus_name2``_axi_awvalid   , ``bus_name1``_axi_awvalid   , ``bus_name0``_axi_awvalid  }; \
    assign ``array_name``_axi_awregion = {``bus_name6``_axi_awregion  , ``bus_name5``_axi_awregion  , ``bus_name4``_axi_awregion  , ``bus_name3``_axi_awregion  , ``bus_name2``_axi_awregion  , ``bus_name1``_axi_awregion  , ``bus_name0``_axi_awregion }; \
    assign ``array_name``_axi_wdata    = {``bus_name6``_axi_wdata     , ``bus_name5``_axi_wdata     , ``bus_name4``_axi_wdata     , ``bus_name3``_axi_wdata     , ``bus_name2``_axi_wdata     , ``bus_name1``_axi_wdata     , ``bus_name0``_axi_wdata    }; \
    assign ``array_name``_axi_wstrb    = {``bus_name6``_axi_wstrb     , ``bus_name5``_axi_wstrb     , ``bus_name4``_axi_wstrb     , ``bus_name3``_axi_wstrb     , ``bus_name2``_axi_wstrb     , ``bus_name1``_axi_wstrb     , ``bus_name0``_axi_wstrb    }; \
    assign ``array_name``_axi_wlast    = {``bus_name6``_axi_wlast     , ``bus_name5``_axi_wlast     , ``bus_name4``_axi_wlast     , ``bus_name3``_axi_wlast     , ``bus_name2``_axi_wlast     , ``bus_name1``_axi_wlast     , ``bus_name0``_axi_wlast    }; \
    assign ``array_name``_axi_wvalid   = {``bus_name6``_axi_wvalid    , ``bus_name5``_axi_wvalid    , ``bus_name4``_axi_wvalid    , ``bus_name3``_axi_wvalid    , ``bus_name2``_axi_wvalid    , ``bus_name1``_axi_wvalid    , ``bus_name0``_axi_wvalid   }; \
    assign ``array_name``_axi_bready   = {``bus_name6``_axi_bready    , ``bus_name5``_axi_bready    , ``bus_name4``_axi_bready    , ``bus_name3``_axi_bready    , ``bus_name2``_axi_bready    , ``bus_name1``_axi_bready    , ``bus_name0``_axi_bready   }; \
    assign ``array_name``_axi_araddr   = {``bus_name6``_axi_araddr    , ``bus_name5``_axi_araddr    , ``bus_name4``_axi_araddr    , ``bus_name3``_axi_araddr    , ``bus_name2``_axi_araddr    , ``bus_name1``_axi_araddr    , ``bus_name0``_axi_araddr   }; \
    assign ``array_name``_axi_arlen    = {``bus_name6``_axi_arlen     , ``bus_name5``_axi_arlen     , ``bus_name4``_axi_arlen     , ``bus_name3``_axi_arlen     , ``bus_name2``_axi_arlen     , ``bus_name1``_axi_arlen     , ``bus_name0``_axi_arlen    }; \
    assign ``array_name``_axi_arsize   = {``bus_name6``_axi_arsize    , ``bus_name5``_axi_arsize    , ``bus_name4``_axi_arsize    , ``bus_name3``_axi_arsize    , ``bus_name2``_axi_arsize    , ``bus_name1``_axi_arsize    , ``bus_name0``_axi_arsize   }; \
    assign ``array_name``_axi_arburst  = {``bus_name6``_axi_arburst   , ``bus_name5``_axi_arburst   , ``bus_name4``_axi_arburst   , ``bus_name3``_axi_arburst   , ``bus_name2``_axi_arburst   , ``bus_name1``_axi_arburst   , ``bus_name0``_axi_arburst  }; \
    assign ``array_name``_axi_arlock   = {``bus_name6``_axi_arlock    , ``bus_name5``_axi_arlock    , ``bus_name4``_axi_arlock    , ``bus_name3``_axi_arlock    , ``bus_name2``_axi_arlock    , ``bus_name1``_axi_arlock    , ``bus_name0``_axi_arlock   }; \
    assign ``array_name``_axi_arcache  = {``bus_name6``_axi_arcache   , ``bus_name5``_axi_arcache   , ``bus_name4``_axi_arcache   , ``bus_name3``_axi_arcache   , ``bus_name2``_axi_arcache   , ``bus_name1``_axi_arcache   , ``bus_name0``_axi_arcache  }; \
    assign ``array_name``_axi_arprot   = {``bus_name6``_axi_arprot    , ``bus_name5``_axi_arprot    , ``bus_name4``_axi_arprot    , ``bus_name3``_axi_arprot    , ``bus_name2``_axi_arprot    , ``bus_name1``_axi_arprot    , ``bus_name0``_axi_arprot   }; \
    assign ``array_name``_axi_arqos    = {``bus_name6``_axi_arqos     , ``bus_name5``_axi_arqos     , ``bus_name4``_axi_arqos     , ``bus_name3``_axi_arqos     , ``bus_name2``_axi_arqos     , ``bus_name1``_axi_arqos     , ``bus_name0``_axi_arqos    }; \
    assign ``array_name``_axi_arvalid  = {``bus_name6``_axi_arvalid   , ``bus_name5``_axi_arvalid   , ``bus_name4``_axi_arvalid   , ``bus_name3``_axi_arvalid   , ``bus_name2``_axi_arvalid   , ``bus_name1``_axi_arvalid   , ``bus_name0``_axi_arvalid  }; \
    assign ``array_name``_axi_arid     = {``bus_name6``_axi_arid      , ``bus_name5``_axi_arid      , ``bus_name4``_axi_arid      , ``bus_name3``_axi_arid      , ``bus_name2``_axi_arid      , ``bus_name1``_axi_arid      , ``bus_name0``_axi_arid     }; \
    assign ``array_name``_axi_arregion = {``bus_name6``_axi_arregion  , ``bus_name5``_axi_arregion  , ``bus_name4``_axi_arregion  , ``bus_name3``_axi_arregion  , ``bus_name2``_axi_arregion  , ``bus_name1``_axi_arregion  , ``bus_name0``_axi_arregion }; \
    assign ``array_name``_axi_rready   = {``bus_name6``_axi_rready    , ``bus_name5``_axi_rready    , ``bus_name4``_axi_rready    , ``bus_name3``_axi_rready    , ``bus_name2``_axi_rready    , ``bus_name1``_axi_rready    , ``bus_name0``_axi_rready   }; \
    assign {``bus_name6``_axi_awready    , ``bus_name5``_axi_awready    , ``bus_name4``_axi_awready    , ``bus_name3``_axi_awready    , ``bus_name2``_axi_awready    , ``bus_name1``_axi_awready   , ``bus_name0``_axi_awready  } = ``array_name``_axi_awready ; \
    assign {``bus_name6``_axi_wready     , ``bus_name5``_axi_wready     , ``bus_name4``_axi_wready     , ``bus_name3``_axi_wready     , ``bus_name2``_axi_wready     , ``bus_name1``_axi_wready    , ``bus_name0``_axi_wready   } = ``array_name``_axi_wready  ; \
    assign {``bus_name6``_axi_bid        , ``bus_name5``_axi_bid        , ``bus_name4``_axi_bid        , ``bus_name3``_axi_bid        , ``bus_name2``_axi_bid        , ``bus_name1``_axi_bid       , ``bus_name0``_axi_bid      } = ``array_name``_axi_bid     ; \
    assign {``bus_name6``_axi_bresp      , ``bus_name5``_axi_bresp      , ``bus_name4``_axi_bresp      , ``bus_name3``_axi_bresp      , ``bus_name2``_axi_bresp      , ``bus_name1``_axi_bresp     , ``bus_name0``_axi_bresp    } = ``array_name``_axi_bresp   ; \
    assign {``bus_name6``_axi_bvalid     , ``bus_name5``_axi_bvalid     , ``bus_name4``_axi_bvalid     , ``bus_name3``_axi_bvalid     , ``bus_name2``_axi_bvalid     , ``bus_name1``_axi_bvalid    , ``bus_name0``_axi_bvalid   } = ``array_name``_axi_bvalid  ; \
    assign {``bus_name6``_axi_arready    , ``bus_name5``_axi_arready    , ``bus_name4``_axi_arready    , ``bus_name3``_axi_arready    , ``bus_name2``_axi_arready    , ``bus_name1``_axi_arready   , ``bus_name0``_axi_arready  } = ``array_name``_axi_arready ; \
    assign {``bus_name6``_axi_rid        , ``bus_name5``_axi_rid        , ``bus_name4``_axi_rid        , ``bus_name3``_axi_rid        , ``bus_name2``_axi_rid        , ``bus_name1``_axi_rid       , ``bus_name0``_axi_rid      } = ``array_name``_axi_rid     ; \
    assign {``bus_name6``_axi_rdata      , ``bus_name5``_axi_rdata      , ``bus_name4``_axi_rdata      , ``bus_name3``_axi_rdata      , ``bus_name2``_axi_rdata      , ``bus_name1``_axi_rdata     , ``bus_name0``_axi_rdata    } = ``array_name``_axi_rdata   ; \
    assign {``bus_name6``_axi_rresp      , ``bus_name5``_axi_rresp      , ``bus_name4``_axi_rresp      , ``bus_name3``_axi_rresp      , ``bus_name2``_axi_rresp      , ``bus_name1``_axi_rresp     , ``bus_name0``_axi_rresp    } = ``array_name``_axi_rresp   ; \
    assign {``bus_name6``_axi_rlast      , ``bus_name5``_axi_rlast      , ``bus_name4``_axi_rlast      , ``bus_name3``_axi_rlast      , ``bus_name2``_axi_rlast      , ``bus_name1``_axi_rlast     , ``bus_name0``_axi_rlast    } = ``array_name``_axi_rlast   ; \
    assign {``bus_name6``_axi_rvalid     , ``bus_name5``_axi_rvalid     , ``bus_name4``_axi_rvalid     , ``bus_name3``_axi_rvalid     , ``bus_name2``_axi_rvalid     , ``bus_name1``_axi_rvalid    , ``bus_name0``_axi_rvalid   } = ``array_name``_axi_rvalid  ;

// Assign master bus interface to port
`define ASSIGN_AXI_PORT(port_name, bus_name)                    \
    .``port_name``_axi_awid     ( ``bus_name``_axi_awid      ), \
    .``port_name``_axi_awaddr   ( ``bus_name``_axi_awaddr    ), \
    .``port_name``_axi_awlen    ( ``bus_name``_axi_awlen     ), \
    .``port_name``_axi_awsize   ( ``bus_name``_axi_awsize    ), \
    .``port_name``_axi_awburst  ( ``bus_name``_axi_awburst   ), \
    .``port_name``_axi_awlock   ( ``bus_name``_axi_awlock    ), \
    .``port_name``_axi_awcache  ( ``bus_name``_axi_awcache   ), \
    .``port_name``_axi_awprot   ( ``bus_name``_axi_awprot    ), \
    .``port_name``_axi_awqos    ( ``bus_name``_axi_awqos     ), \
    .``port_name``_axi_awvalid  ( ``bus_name``_axi_awvalid   ), \
    .``port_name``_axi_awregion ( ``bus_name``_axi_awregion  ), \
    .``port_name``_axi_wdata    ( ``bus_name``_axi_wdata     ), \
    .``port_name``_axi_wstrb    ( ``bus_name``_axi_wstrb     ), \
    .``port_name``_axi_wlast    ( ``bus_name``_axi_wlast     ), \
    .``port_name``_axi_wvalid   ( ``bus_name``_axi_wvalid    ), \
    .``port_name``_axi_araddr   ( ``bus_name``_axi_araddr    ), \
    .``port_name``_axi_arlen    ( ``bus_name``_axi_arlen     ), \
    .``port_name``_axi_arsize   ( ``bus_name``_axi_arsize    ), \
    .``port_name``_axi_arburst  ( ``bus_name``_axi_arburst   ), \
    .``port_name``_axi_arlock   ( ``bus_name``_axi_arlock    ), \
    .``port_name``_axi_arcache  ( ``bus_name``_axi_arcache   ), \
    .``port_name``_axi_arprot   ( ``bus_name``_axi_arprot    ), \
    .``port_name``_axi_arqos    ( ``bus_name``_axi_arqos     ), \
    .``port_name``_axi_arvalid  ( ``bus_name``_axi_arvalid   ), \
    .``port_name``_axi_arid     ( ``bus_name``_axi_arid      ), \
    .``port_name``_axi_arregion ( ``bus_name``_axi_arregion  ), \
    .``port_name``_axi_rready   ( ``bus_name``_axi_rready    ), \
    .``port_name``_axi_bready   ( ``bus_name``_axi_bready    ), \
    .``port_name``_axi_awready  ( ``bus_name``_axi_awready   ), \
    .``port_name``_axi_wready   ( ``bus_name``_axi_wready    ), \
    .``port_name``_axi_bid      ( ``bus_name``_axi_bid       ), \
    .``port_name``_axi_bresp    ( ``bus_name``_axi_bresp     ), \
    .``port_name``_axi_bvalid   ( ``bus_name``_axi_bvalid    ), \
    .``port_name``_axi_arready  ( ``bus_name``_axi_arready   ), \
    .``port_name``_axi_rid      ( ``bus_name``_axi_rid       ), \
    .``port_name``_axi_rdata    ( ``bus_name``_axi_rdata     ), \
    .``port_name``_axi_rresp    ( ``bus_name``_axi_rresp     ), \
    .``port_name``_axi_rlast    ( ``bus_name``_axi_rlast     ), \
    .``port_name``_axi_rvalid   ( ``bus_name``_axi_rvalid    )

// Concatenate 6 master buses
`define CONCAT_AXI_MASTERS_ARRAY6(array_name, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
    assign ``array_name``_axi_awid     = {``bus_name5``_axi_awid      , ``bus_name4``_axi_awid      , ``bus_name3``_axi_awid      , ``bus_name2``_axi_awid      , ``bus_name1``_axi_awid      , ``bus_name0``_axi_awid     }; \
    assign ``array_name``_axi_awaddr   = {``bus_name5``_axi_awaddr    , ``bus_name4``_axi_awaddr    , ``bus_name3``_axi_awaddr    , ``bus_name2``_axi_awaddr    , ``bus_name1``_axi_awaddr    , ``bus_name0``_axi_awaddr   }; \
    assign ``array_name``_axi_awlen    = {``bus_name5``_axi_awlen     , ``bus_name4``_axi_awlen     , ``bus_name3``_axi_awlen     , ``bus_name2``_axi_awlen     , ``bus_name1``_axi_awlen     , ``bus_name0``_axi_awlen    }; \
    assign ``array_name``_axi_awsize   = {``bus_name5``_axi_awsize    , ``bus_name4``_axi_awsize    , ``bus_name3``_axi_awsize    , ``bus_name2``_axi_awsize    , ``bus_name1``_axi_awsize    , ``bus_name0``_axi_awsize   }; \
    assign ``array_name``_axi_awburst  = {``bus_name5``_axi_awburst   , ``bus_name4``_axi_awburst   , ``bus_name3``_axi_awburst   , ``bus_name2``_axi_awburst   , ``bus_name1``_axi_awburst   , ``bus_name0``_axi_awburst  }; \
    assign ``array_name``_axi_awlock   = {``bus_name5``_axi_awlock    , ``bus_name4``_axi_awlock    , ``bus_name3``_axi_awlock    , ``bus_name2``_axi_awlock    , ``bus_name1``_axi_awlock    , ``bus_name0``_axi_awlock   }; \
    assign ``array_name``_axi_awcache  = {``bus_name5``_axi_awcache   , ``bus_name4``_axi_awcache   , ``bus_name3``_axi_awcache   , ``bus_name2``_axi_awcache   , ``bus_name1``_axi_awcache   , ``bus_name0``_axi_awcache  }; \
    assign ``array_name``_axi_awprot   = {``bus_name5``_axi_awprot    , ``bus_name4``_axi_awprot    , ``bus_name3``_axi_awprot    , ``bus_name2``_axi_awprot    , ``bus_name1``_axi_awprot    , ``bus_name0``_axi_awprot   }; \
    assign ``array_name``_axi_awqos    = {``bus_name5``_axi_awqos     , ``bus_name4``_axi_awqos     , ``bus_name3``_axi_awqos     , ``bus_name2``_axi_awqos     , ``bus_name1``_axi_awqos     , ``bus_name0``_axi_awqos    }; \
    assign ``array_name``_axi_awvalid  = {``bus_name5``_axi_awvalid   , ``bus_name4``_axi_awvalid   , ``bus_name3``_axi_awvalid   , ``bus_name2``_axi_awvalid   , ``bus_name1``_axi_awvalid   , ``bus_name0``_axi_awvalid  }; \
    assign ``array_name``_axi_awregion = {``bus_name5``_axi_awregion  , ``bus_name4``_axi_awregion  , ``bus_name3``_axi_awregion  , ``bus_name2``_axi_awregion  , ``bus_name1``_axi_awregion  , ``bus_name0``_axi_awregion }; \
    assign ``array_name``_axi_wdata    = {``bus_name5``_axi_wdata     , ``bus_name4``_axi_wdata     , ``bus_name3``_axi_wdata     , ``bus_name2``_axi_wdata     , ``bus_name1``_axi_wdata     , ``bus_name0``_axi_wdata    }; \
    assign ``array_name``_axi_wstrb    = {``bus_name5``_axi_wstrb     , ``bus_name4``_axi_wstrb     , ``bus_name3``_axi_wstrb     , ``bus_name2``_axi_wstrb     , ``bus_name1``_axi_wstrb     , ``bus_name0``_axi_wstrb    }; \
    assign ``array_name``_axi_wlast    = {``bus_name5``_axi_wlast     , ``bus_name4``_axi_wlast     , ``bus_name3``_axi_wlast     , ``bus_name2``_axi_wlast     , ``bus_name1``_axi_wlast     , ``bus_name0``_axi_wlast    }; \
    assign ``array_name``_axi_wvalid   = {``bus_name5``_axi_wvalid    , ``bus_name4``_axi_wvalid    , ``bus_name3``_axi_wvalid    , ``bus_name2``_axi_wvalid    , ``bus_name1``_axi_wvalid    , ``bus_name0``_axi_wvalid   }; \
    assign ``array_name``_axi_bready   = {``bus_name5``_axi_bready    , ``bus_name4``_axi_bready    , ``bus_name3``_axi_bready    , ``bus_name2``_axi_bready    , ``bus_name1``_axi_bready    , ``bus_name0``_axi_bready   }; \
    assign ``array_name``_axi_araddr   = {``bus_name5``_axi_araddr    , ``bus_name4``_axi_araddr    , ``bus_name3``_axi_araddr    , ``bus_name2``_axi_araddr    , ``bus_name1``_axi_araddr    , ``bus_name0``_axi_araddr   }; \
    assign ``array_name``_axi_arlen    = {``bus_name5``_axi_arlen     , ``bus_name4``_axi_arlen     , ``bus_name3``_axi_arlen     , ``bus_name2``_axi_arlen     , ``bus_name1``_axi_arlen     , ``bus_name0``_axi_arlen    }; \
    assign ``array_name``_axi_arsize   = {``bus_name5``_axi_arsize    , ``bus_name4``_axi_arsize    , ``bus_name3``_axi_arsize    , ``bus_name2``_axi_arsize    , ``bus_name1``_axi_arsize    , ``bus_name0``_axi_arsize   }; \
    assign ``array_name``_axi_arburst  = {``bus_name5``_axi_arburst   , ``bus_name4``_axi_arburst   , ``bus_name3``_axi_arburst   , ``bus_name2``_axi_arburst   , ``bus_name1``_axi_arburst   , ``bus_name0``_axi_arburst  }; \
    assign ``array_name``_axi_arlock   = {``bus_name5``_axi_arlock    , ``bus_name4``_axi_arlock    , ``bus_name3``_axi_arlock    , ``bus_name2``_axi_arlock    , ``bus_name1``_axi_arlock    , ``bus_name0``_axi_arlock   }; \
    assign ``array_name``_axi_arcache  = {``bus_name5``_axi_arcache   , ``bus_name4``_axi_arcache   , ``bus_name3``_axi_arcache   , ``bus_name2``_axi_arcache   , ``bus_name1``_axi_arcache   , ``bus_name0``_axi_arcache  }; \
    assign ``array_name``_axi_arprot   = {``bus_name5``_axi_arprot    , ``bus_name4``_axi_arprot    , ``bus_name3``_axi_arprot    , ``bus_name2``_axi_arprot    , ``bus_name1``_axi_arprot    , ``bus_name0``_axi_arprot   }; \
    assign ``array_name``_axi_arqos    = {``bus_name5``_axi_arqos     , ``bus_name4``_axi_arqos     , ``bus_name3``_axi_arqos     , ``bus_name2``_axi_arqos     , ``bus_name1``_axi_arqos     , ``bus_name0``_axi_arqos    }; \
    assign ``array_name``_axi_arvalid  = {``bus_name5``_axi_arvalid   , ``bus_name4``_axi_arvalid   , ``bus_name3``_axi_arvalid   , ``bus_name2``_axi_arvalid   , ``bus_name1``_axi_arvalid   , ``bus_name0``_axi_arvalid  }; \
    assign ``array_name``_axi_arid     = {``bus_name5``_axi_arid      , ``bus_name4``_axi_arid      , ``bus_name3``_axi_arid      , ``bus_name2``_axi_arid      , ``bus_name1``_axi_arid      , ``bus_name0``_axi_arid     }; \
    assign ``array_name``_axi_arregion = {``bus_name5``_axi_arregion  , ``bus_name4``_axi_arregion  , ``bus_name3``_axi_arregion  , ``bus_name2``_axi_arregion  , ``bus_name1``_axi_arregion  , ``bus_name0``_axi_arregion }; \
    assign ``array_name``_axi_rready   = {``bus_name5``_axi_rready    , ``bus_name4``_axi_rready    , ``bus_name3``_axi_rready    , ``bus_name2``_axi_rready    , ``bus_name1``_axi_rready    , ``bus_name0``_axi_rready   }; \
    assign {``bus_name5``_axi_awready    , ``bus_name4``_axi_awready    , ``bus_name3``_axi_awready    , ``bus_name2``_axi_awready    , ``bus_name1``_axi_awready   , ``bus_name0``_axi_awready  } = ``array_name``_axi_awready ; \
    assign {``bus_name5``_axi_wready     , ``bus_name4``_axi_wready     , ``bus_name3``_axi_wready     , ``bus_name2``_axi_wready     , ``bus_name1``_axi_wready    , ``bus_name0``_axi_wready   } = ``array_name``_axi_wready  ; \
    assign {``bus_name5``_axi_bid        , ``bus_name4``_axi_bid        , ``bus_name3``_axi_bid        , ``bus_name2``_axi_bid        , ``bus_name1``_axi_bid       , ``bus_name0``_axi_bid      } = ``array_name``_axi_bid     ; \
    assign {``bus_name5``_axi_bresp      , ``bus_name4``_axi_bresp      , ``bus_name3``_axi_bresp      , ``bus_name2``_axi_bresp      , ``bus_name1``_axi_bresp     , ``bus_name0``_axi_bresp    } = ``array_name``_axi_bresp   ; \
    assign {``bus_name5``_axi_bvalid     , ``bus_name4``_axi_bvalid     , ``bus_name3``_axi_bvalid     , ``bus_name2``_axi_bvalid     , ``bus_name1``_axi_bvalid    , ``bus_name0``_axi_bvalid   } = ``array_name``_axi_bvalid  ; \
    assign {``bus_name5``_axi_arready    , ``bus_name4``_axi_arready    , ``bus_name3``_axi_arready    , ``bus_name2``_axi_arready    , ``bus_name1``_axi_arready   , ``bus_name0``_axi_arready  } = ``array_name``_axi_arready ; \
    assign {``bus_name5``_axi_rid        , ``bus_name4``_axi_rid        , ``bus_name3``_axi_rid        , ``bus_name2``_axi_rid        , ``bus_name1``_axi_rid       , ``bus_name0``_axi_rid      } = ``array_name``_axi_rid     ; \
    assign {``bus_name5``_axi_rdata      , ``bus_name4``_axi_rdata      , ``bus_name3``_axi_rdata      , ``bus_name2``_axi_rdata      , ``bus_name1``_axi_rdata     , ``bus_name0``_axi_rdata    } = ``array_name``_axi_rdata   ; \
    assign {``bus_name5``_axi_rresp      , ``bus_name4``_axi_rresp      , ``bus_name3``_axi_rresp      , ``bus_name2``_axi_rresp      , ``bus_name1``_axi_rresp     , ``bus_name0``_axi_rresp    } = ``array_name``_axi_rresp   ; \
    assign {``bus_name5``_axi_rlast      , ``bus_name4``_axi_rlast      , ``bus_name3``_axi_rlast      , ``bus_name2``_axi_rlast      , ``bus_name1``_axi_rlast     , ``bus_name0``_axi_rlast    } = ``array_name``_axi_rlast   ; \
    assign {``bus_name5``_axi_rvalid     , ``bus_name4``_axi_rvalid     , ``bus_name3``_axi_rvalid     , ``bus_name2``_axi_rvalid     , ``bus_name1``_axi_rvalid    , ``bus_name0``_axi_rvalid   } = ``array_name``_axi_rvalid  ;

// Concatenate 8 slave buses
`define CONCAT_AXI_SLAVES_ARRAY8(array_name, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
    assign {``bus_name7``_axi_awid, ``bus_name6``_axi_awid, ``bus_name5``_axi_awid, ``bus_name4``_axi_awid, ``bus_name3``_axi_awid, ``bus_name2``_axi_awid, ``bus_name1``_axi_awid, ``bus_name0``_axi_awid} = ``array_name``_axi_awid; \
    assign {``bus_name7``_axi_awaddr, ``bus_name6``_axi_awaddr, ``bus_name5``_axi_awaddr, ``bus_name4``_axi_awaddr, ``bus_name3``_axi_awaddr, ``bus_name2``_axi_awaddr, ``bus_name1``_axi_awaddr, ``bus_name0``_axi_awaddr} = ``array_name``_axi_awaddr; \
    assign {``bus_name7``_axi_awlen, ``bus_name6``_axi_awlen, ``bus_name5``_axi_awlen, ``bus_name4``_axi_awlen, ``bus_name3``_axi_awlen, ``bus_name2``_axi_awlen, ``bus_name1``_axi_awlen, ``bus_name0``_axi_awlen} = ``array_name``_axi_awlen; \
    assign {``bus_name7``_axi_awsize, ``bus_name6``_axi_awsize, ``bus_name5``_axi_awsize, ``bus_name4``_axi_awsize, ``bus_name3``_axi_awsize, ``bus_name2``_axi_awsize, ``bus_name1``_axi_awsize, ``bus_name0``_axi_awsize} = ``array_name``_axi_awsize; \
    assign {``bus_name7``_axi_awburst, ``bus_name6``_axi_awburst, ``bus_name5``_axi_awburst, ``bus_name4``_axi_awburst, ``bus_name3``_axi_awburst, ``bus_name2``_axi_awburst, ``bus_name1``_axi_awburst, ``bus_name0``_axi_awburst} = ``array_name``_axi_awburst; \
    assign {``bus_name7``_axi_awlock, ``bus_name6``_axi_awlock, ``bus_name5``_axi_awlock, ``bus_name4``_axi_awlock, ``bus_name3``_axi_awlock, ``bus_name2``_axi_awlock, ``bus_name1``_axi_awlock, ``bus_name0``_axi_awlock} = ``array_name``_axi_awlock; \
    assign {``bus_name7``_axi_awcache, ``bus_name6``_axi_awcache, ``bus_name5``_axi_awcache, ``bus_name4``_axi_awcache, ``bus_name3``_axi_awcache, ``bus_name2``_axi_awcache, ``bus_name1``_axi_awcache, ``bus_name0``_axi_awcache} = ``array_name``_axi_awcache; \
    assign {``bus_name7``_axi_awprot, ``bus_name6``_axi_awprot, ``bus_name5``_axi_awprot, ``bus_name4``_axi_awprot, ``bus_name3``_axi_awprot, ``bus_name2``_axi_awprot, ``bus_name1``_axi_awprot, ``bus_name0``_axi_awprot} = ``array_name``_axi_awprot; \
    assign {``bus_name7``_axi_awqos, ``bus_name6``_axi_awqos, ``bus_name5``_axi_awqos, ``bus_name4``_axi_awqos, ``bus_name3``_axi_awqos, ``bus_name2``_axi_awqos, ``bus_name1``_axi_awqos, ``bus_name0``_axi_awqos} = ``array_name``_axi_awqos; \
    assign {``bus_name7``_axi_awvalid, ``bus_name6``_axi_awvalid, ``bus_name5``_axi_awvalid, ``bus_name4``_axi_awvalid, ``bus_name3``_axi_awvalid, ``bus_name2``_axi_awvalid, ``bus_name1``_axi_awvalid, ``bus_name0``_axi_awvalid} = ``array_name``_axi_awvalid; \
    assign {``bus_name7``_axi_awregion, ``bus_name6``_axi_awregion, ``bus_name5``_axi_awregion, ``bus_name4``_axi_awregion, ``bus_name3``_axi_awregion, ``bus_name2``_axi_awregion, ``bus_name1``_axi_awregion, ``bus_name0``_axi_awregion} = ``array_name``_axi_awregion; \
    assign {``bus_name7``_axi_wdata, ``bus_name6``_axi_wdata, ``bus_name5``_axi_wdata, ``bus_name4``_axi_wdata, ``bus_name3``_axi_wdata, ``bus_name2``_axi_wdata, ``bus_name1``_axi_wdata, ``bus_name0``_axi_wdata} = ``array_name``_axi_wdata; \
    assign {``bus_name7``_axi_wstrb, ``bus_name6``_axi_wstrb, ``bus_name5``_axi_wstrb, ``bus_name4``_axi_wstrb, ``bus_name3``_axi_wstrb, ``bus_name2``_axi_wstrb, ``bus_name1``_axi_wstrb, ``bus_name0``_axi_wstrb} = ``array_name``_axi_wstrb; \
    assign {``bus_name7``_axi_wlast, ``bus_name6``_axi_wlast, ``bus_name5``_axi_wlast, ``bus_name4``_axi_wlast, ``bus_name3``_axi_wlast, ``bus_name2``_axi_wlast, ``bus_name1``_axi_wlast, ``bus_name0``_axi_wlast} = ``array_name``_axi_wlast; \
    assign {``bus_name7``_axi_wvalid, ``bus_name6``_axi_wvalid, ``bus_name5``_axi_wvalid, ``bus_name4``_axi_wvalid, ``bus_name3``_axi_wvalid, ``bus_name2``_axi_wvalid, ``bus_name1``_axi_wvalid, ``bus_name0``_axi_wvalid} = ``array_name``_axi_wvalid; \
    assign {``bus_name7``_axi_bready, ``bus_name6``_axi_bready, ``bus_name5``_axi_bready, ``bus_name4``_axi_bready, ``bus_name3``_axi_bready, ``bus_name2``_axi_bready, ``bus_name1``_axi_bready, ``bus_name0``_axi_bready} = ``array_name``_axi_bready; \
    assign {``bus_name7``_axi_araddr, ``bus_name6``_axi_araddr, ``bus_name5``_axi_araddr, ``bus_name4``_axi_araddr, ``bus_name3``_axi_araddr, ``bus_name2``_axi_araddr, ``bus_name1``_axi_araddr, ``bus_name0``_axi_araddr} = ``array_name``_axi_araddr; \
    assign {``bus_name7``_axi_arlen, ``bus_name6``_axi_arlen, ``bus_name5``_axi_arlen, ``bus_name4``_axi_arlen, ``bus_name3``_axi_arlen, ``bus_name2``_axi_arlen, ``bus_name1``_axi_arlen, ``bus_name0``_axi_arlen} = ``array_name``_axi_arlen; \
    assign {``bus_name7``_axi_arsize, ``bus_name6``_axi_arsize, ``bus_name5``_axi_arsize, ``bus_name4``_axi_arsize, ``bus_name3``_axi_arsize, ``bus_name2``_axi_arsize, ``bus_name1``_axi_arsize, ``bus_name0``_axi_arsize} = ``array_name``_axi_arsize; \
    assign {``bus_name7``_axi_arburst, ``bus_name6``_axi_arburst, ``bus_name5``_axi_arburst, ``bus_name4``_axi_arburst, ``bus_name3``_axi_arburst, ``bus_name2``_axi_arburst, ``bus_name1``_axi_arburst, ``bus_name0``_axi_arburst} = ``array_name``_axi_arburst; \
    assign {``bus_name7``_axi_arlock, ``bus_name6``_axi_arlock, ``bus_name5``_axi_arlock, ``bus_name4``_axi_arlock, ``bus_name3``_axi_arlock, ``bus_name2``_axi_arlock, ``bus_name1``_axi_arlock, ``bus_name0``_axi_arlock} = ``array_name``_axi_arlock; \
    assign {``bus_name7``_axi_arcache, ``bus_name6``_axi_arcache, ``bus_name5``_axi_arcache, ``bus_name4``_axi_arcache, ``bus_name3``_axi_arcache, ``bus_name2``_axi_arcache, ``bus_name1``_axi_arcache, ``bus_name0``_axi_arcache} = ``array_name``_axi_arcache; \
    assign {``bus_name7``_axi_arprot, ``bus_name6``_axi_arprot, ``bus_name5``_axi_arprot, ``bus_name4``_axi_arprot, ``bus_name3``_axi_arprot, ``bus_name2``_axi_arprot, ``bus_name1``_axi_arprot, ``bus_name0``_axi_arprot} = ``array_name``_axi_arprot; \
    assign {``bus_name7``_axi_arqos, ``bus_name6``_axi_arqos, ``bus_name5``_axi_arqos, ``bus_name4``_axi_arqos, ``bus_name3``_axi_arqos, ``bus_name2``_axi_arqos, ``bus_name1``_axi_arqos, ``bus_name0``_axi_arqos} = ``array_name``_axi_arqos; \
    assign {``bus_name7``_axi_arvalid, ``bus_name6``_axi_arvalid, ``bus_name5``_axi_arvalid, ``bus_name4``_axi_arvalid, ``bus_name3``_axi_arvalid, ``bus_name2``_axi_arvalid, ``bus_name1``_axi_arvalid, ``bus_name0``_axi_arvalid} = ``array_name``_axi_arvalid; \
    assign {``bus_name7``_axi_arid, ``bus_name6``_axi_arid, ``bus_name5``_axi_arid, ``bus_name4``_axi_arid, ``bus_name3``_axi_arid, ``bus_name2``_axi_arid, ``bus_name1``_axi_arid, ``bus_name0``_axi_arid} = ``array_name``_axi_arid; \
    assign {``bus_name7``_axi_arregion, ``bus_name6``_axi_arregion, ``bus_name5``_axi_arregion, ``bus_name4``_axi_arregion, ``bus_name3``_axi_arregion, ``bus_name2``_axi_arregion, ``bus_name1``_axi_arregion, ``bus_name0``_axi_arregion} = ``array_name``_axi_arregion; \
    assign {``bus_name7``_axi_rready, ``bus_name6``_axi_rready, ``bus_name5``_axi_rready, ``bus_name4``_axi_rready, ``bus_name3``_axi_rready, ``bus_name2``_axi_rready, ``bus_name1``_axi_rready, ``bus_name0``_axi_rready} = ``array_name``_axi_rready; \
    assign ``array_name``_axi_awready = {``bus_name7``_axi_awready, ``bus_name6``_axi_awready, ``bus_name5``_axi_awready, ``bus_name4``_axi_awready, ``bus_name3``_axi_awready, ``bus_name2``_axi_awready, ``bus_name1``_axi_awready, ``bus_name0``_axi_awready}; \
    assign ``array_name``_axi_wready = {``bus_name7``_axi_wready, ``bus_name6``_axi_wready, ``bus_name5``_axi_wready, ``bus_name4``_axi_wready, ``bus_name3``_axi_wready, ``bus_name2``_axi_wready, ``bus_name1``_axi_wready, ``bus_name0``_axi_wready}; \
    assign ``array_name``_axi_bid = {``bus_name7``_axi_bid, ``bus_name6``_axi_bid, ``bus_name5``_axi_bid, ``bus_name4``_axi_bid, ``bus_name3``_axi_bid, ``bus_name2``_axi_bid, ``bus_name1``_axi_bid, ``bus_name0``_axi_bid}; \
    assign ``array_name``_axi_bresp = {``bus_name7``_axi_bresp, ``bus_name6``_axi_bresp, ``bus_name5``_axi_bresp, ``bus_name4``_axi_bresp, ``bus_name3``_axi_bresp, ``bus_name2``_axi_bresp, ``bus_name1``_axi_bresp, ``bus_name0``_axi_bresp}; \
    assign ``array_name``_axi_bvalid = {``bus_name7``_axi_bvalid, ``bus_name6``_axi_bvalid, ``bus_name5``_axi_bvalid, ``bus_name4``_axi_bvalid, ``bus_name3``_axi_bvalid, ``bus_name2``_axi_bvalid, ``bus_name1``_axi_bvalid, ``bus_name0``_axi_bvalid}; \
    assign ``array_name``_axi_arready = {``bus_name7``_axi_arready, ``bus_name6``_axi_arready, ``bus_name5``_axi_arready, ``bus_name4``_axi_arready, ``bus_name3``_axi_arready, ``bus_name2``_axi_arready, ``bus_name1``_axi_arready, ``bus_name0``_axi_arready}; \
    assign ``array_name``_axi_rid = {``bus_name7``_axi_rid, ``bus_name6``_axi_rid, ``bus_name5``_axi_rid, ``bus_name4``_axi_rid, ``bus_name3``_axi_rid, ``bus_name2``_axi_rid, ``bus_name1``_axi_rid, ``bus_name0``_axi_rid}; \
    assign ``array_name``_axi_rdata = {``bus_name7``_axi_rdata, ``bus_name6``_axi_rdata, ``bus_name5``_axi_rdata, ``bus_name4``_axi_rdata, ``bus_name3``_axi_rdata, ``bus_name2``_axi_rdata, ``bus_name1``_axi_rdata, ``bus_name0``_axi_rdata}; \
    assign ``array_name``_axi_rresp = {``bus_name7``_axi_rresp, ``bus_name6``_axi_rresp, ``bus_name5``_axi_rresp, ``bus_name4``_axi_rresp, ``bus_name3``_axi_rresp, ``bus_name2``_axi_rresp, ``bus_name1``_axi_rresp, ``bus_name0``_axi_rresp}; \
    assign ``array_name``_axi_rlast = {``bus_name7``_axi_rlast, ``bus_name6``_axi_rlast, ``bus_name5``_axi_rlast, ``bus_name4``_axi_rlast, ``bus_name3``_axi_rlast, ``bus_name2``_axi_rlast, ``bus_name1``_axi_rlast, ``bus_name0``_axi_rlast}; \
    assign ``array_name``_axi_rvalid = {``bus_name7``_axi_rvalid, ``bus_name6``_axi_rvalid, ``bus_name5``_axi_rvalid, ``bus_name4``_axi_rvalid, ``bus_name3``_axi_rvalid, ``bus_name2``_axi_rvalid, ``bus_name1``_axi_rvalid, ``bus_name0``_axi_rvalid};

// Concatenate 8 master buses
`define CONCAT_AXI_MASTERS_ARRAY8(array_name, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
    assign ``array_name``_axi_awid     = {``bus_name7``_axi_awid      , ``bus_name6``_axi_awid      , ``bus_name5``_axi_awid      , ``bus_name4``_axi_awid      , ``bus_name3``_axi_awid      , ``bus_name2``_axi_awid      , ``bus_name1``_axi_awid      , ``bus_name0``_axi_awid     }; \
    assign ``array_name``_axi_awaddr   = {``bus_name7``_axi_awaddr    , ``bus_name6``_axi_awaddr    , ``bus_name5``_axi_awaddr    , ``bus_name4``_axi_awaddr    , ``bus_name3``_axi_awaddr    , ``bus_name2``_axi_awaddr    , ``bus_name1``_axi_awaddr    , ``bus_name0``_axi_awaddr   }; \
    assign ``array_name``_axi_awlen    = {``bus_name7``_axi_awlen     , ``bus_name6``_axi_awlen     , ``bus_name5``_axi_awlen     , ``bus_name4``_axi_awlen     , ``bus_name3``_axi_awlen     , ``bus_name2``_axi_awlen     , ``bus_name1``_axi_awlen     , ``bus_name0``_axi_awlen    }; \
    assign ``array_name``_axi_awsize   = {``bus_name7``_axi_awsize    , ``bus_name6``_axi_awsize    , ``bus_name5``_axi_awsize    , ``bus_name4``_axi_awsize    , ``bus_name3``_axi_awsize    , ``bus_name2``_axi_awsize    , ``bus_name1``_axi_awsize    , ``bus_name0``_axi_awsize   }; \
    assign ``array_name``_axi_awburst  = {``bus_name7``_axi_awburst   , ``bus_name6``_axi_awburst   , ``bus_name5``_axi_awburst   , ``bus_name4``_axi_awburst   , ``bus_name3``_axi_awburst   , ``bus_name2``_axi_awburst   , ``bus_name1``_axi_awburst   , ``bus_name0``_axi_awburst  }; \
    assign ``array_name``_axi_awlock   = {``bus_name7``_axi_awlock    , ``bus_name6``_axi_awlock    , ``bus_name5``_axi_awlock    , ``bus_name4``_axi_awlock    , ``bus_name3``_axi_awlock    , ``bus_name2``_axi_awlock    , ``bus_name1``_axi_awlock    , ``bus_name0``_axi_awlock   }; \
    assign ``array_name``_axi_awcache  = {``bus_name7``_axi_awcache   , ``bus_name6``_axi_awcache   , ``bus_name5``_axi_awcache   , ``bus_name4``_axi_awcache   , ``bus_name3``_axi_awcache   , ``bus_name2``_axi_awcache   , ``bus_name1``_axi_awcache   , ``bus_name0``_axi_awcache  }; \
    assign ``array_name``_axi_awprot   = {``bus_name7``_axi_awprot    , ``bus_name6``_axi_awprot    , ``bus_name5``_axi_awprot    , ``bus_name4``_axi_awprot    , ``bus_name3``_axi_awprot    , ``bus_name2``_axi_awprot    , ``bus_name1``_axi_awprot    , ``bus_name0``_axi_awprot   }; \
    assign ``array_name``_axi_awqos    = {``bus_name7``_axi_awqos     , ``bus_name6``_axi_awqos     , ``bus_name5``_axi_awqos     , ``bus_name4``_axi_awqos     , ``bus_name3``_axi_awqos     , ``bus_name2``_axi_awqos     , ``bus_name1``_axi_awqos     , ``bus_name0``_axi_awqos    }; \
    assign ``array_name``_axi_awvalid  = {``bus_name7``_axi_awvalid   , ``bus_name6``_axi_awvalid   , ``bus_name5``_axi_awvalid   , ``bus_name4``_axi_awvalid   , ``bus_name3``_axi_awvalid   , ``bus_name2``_axi_awvalid   , ``bus_name1``_axi_awvalid   , ``bus_name0``_axi_awvalid  }; \
    assign ``array_name``_axi_awregion = {``bus_name7``_axi_awregion  , ``bus_name6``_axi_awregion  , ``bus_name5``_axi_awregion  , ``bus_name4``_axi_awregion  , ``bus_name3``_axi_awregion  , ``bus_name2``_axi_awregion  , ``bus_name1``_axi_awregion  , ``bus_name0``_axi_awregion }; \
    assign ``array_name``_axi_wdata    = {``bus_name7``_axi_wdata     , ``bus_name6``_axi_wdata     , ``bus_name5``_axi_wdata     , ``bus_name4``_axi_wdata     , ``bus_name3``_axi_wdata     , ``bus_name2``_axi_wdata     , ``bus_name1``_axi_wdata     , ``bus_name0``_axi_wdata    }; \
    assign ``array_name``_axi_wstrb    = {``bus_name7``_axi_wstrb     , ``bus_name6``_axi_wstrb     , ``bus_name5``_axi_wstrb     , ``bus_name4``_axi_wstrb     , ``bus_name3``_axi_wstrb     , ``bus_name2``_axi_wstrb     , ``bus_name1``_axi_wstrb     , ``bus_name0``_axi_wstrb    }; \
    assign ``array_name``_axi_wlast    = {``bus_name7``_axi_wlast     , ``bus_name6``_axi_wlast     , ``bus_name5``_axi_wlast     , ``bus_name4``_axi_wlast     , ``bus_name3``_axi_wlast     , ``bus_name2``_axi_wlast     , ``bus_name1``_axi_wlast     , ``bus_name0``_axi_wlast    }; \
    assign ``array_name``_axi_wvalid   = {``bus_name7``_axi_wvalid    , ``bus_name6``_axi_wvalid    , ``bus_name5``_axi_wvalid    , ``bus_name4``_axi_wvalid    , ``bus_name3``_axi_wvalid    , ``bus_name2``_axi_wvalid    , ``bus_name1``_axi_wvalid    , ``bus_name0``_axi_wvalid   }; \
    assign ``array_name``_axi_bready   = {``bus_name7``_axi_bready    , ``bus_name6``_axi_bready    , ``bus_name5``_axi_bready    , ``bus_name4``_axi_bready    , ``bus_name3``_axi_bready    , ``bus_name2``_axi_bready    , ``bus_name1``_axi_bready    , ``bus_name0``_axi_bready   }; \
    assign ``array_name``_axi_araddr   = {``bus_name7``_axi_araddr    , ``bus_name6``_axi_araddr    , ``bus_name5``_axi_araddr    , ``bus_name4``_axi_araddr    , ``bus_name3``_axi_araddr    , ``bus_name2``_axi_araddr    , ``bus_name1``_axi_araddr    , ``bus_name0``_axi_araddr   }; \
    assign ``array_name``_axi_arlen    = {``bus_name7``_axi_arlen     , ``bus_name6``_axi_arlen     , ``bus_name5``_axi_arlen     , ``bus_name4``_axi_arlen     , ``bus_name3``_axi_arlen     , ``bus_name2``_axi_arlen     , ``bus_name1``_axi_arlen     , ``bus_name0``_axi_arlen    }; \
    assign ``array_name``_axi_arsize   = {``bus_name7``_axi_arsize    , ``bus_name6``_axi_arsize    , ``bus_name5``_axi_arsize    , ``bus_name4``_axi_arsize    , ``bus_name3``_axi_arsize    , ``bus_name2``_axi_arsize    , ``bus_name1``_axi_arsize    , ``bus_name0``_axi_arsize   }; \
    assign ``array_name``_axi_arburst  = {``bus_name7``_axi_arburst   , ``bus_name6``_axi_arburst   , ``bus_name5``_axi_arburst   , ``bus_name4``_axi_arburst   , ``bus_name3``_axi_arburst   , ``bus_name2``_axi_arburst   , ``bus_name1``_axi_arburst   , ``bus_name0``_axi_arburst  }; \
    assign ``array_name``_axi_arlock   = {``bus_name7``_axi_arlock    , ``bus_name6``_axi_arlock    , ``bus_name5``_axi_arlock    , ``bus_name4``_axi_arlock    , ``bus_name3``_axi_arlock    , ``bus_name2``_axi_arlock    , ``bus_name1``_axi_arlock    , ``bus_name0``_axi_arlock   }; \
    assign ``array_name``_axi_arcache  = {``bus_name7``_axi_arcache   , ``bus_name6``_axi_arcache   , ``bus_name5``_axi_arcache   , ``bus_name4``_axi_arcache   , ``bus_name3``_axi_arcache   , ``bus_name2``_axi_arcache   , ``bus_name1``_axi_arcache   , ``bus_name0``_axi_arcache  }; \
    assign ``array_name``_axi_arprot   = {``bus_name7``_axi_arprot    , ``bus_name6``_axi_arprot    , ``bus_name5``_axi_arprot    , ``bus_name4``_axi_arprot    , ``bus_name3``_axi_arprot    , ``bus_name2``_axi_arprot    , ``bus_name1``_axi_arprot    , ``bus_name0``_axi_arprot   }; \
    assign ``array_name``_axi_arqos    = {``bus_name7``_axi_arqos     , ``bus_name6``_axi_arqos     , ``bus_name5``_axi_arqos     , ``bus_name4``_axi_arqos     , ``bus_name3``_axi_arqos     , ``bus_name2``_axi_arqos     , ``bus_name1``_axi_arqos     , ``bus_name0``_axi_arqos    }; \
    assign ``array_name``_axi_arvalid  = {``bus_name7``_axi_arvalid   , ``bus_name6``_axi_arvalid   , ``bus_name5``_axi_arvalid   , ``bus_name4``_axi_arvalid   , ``bus_name3``_axi_arvalid   , ``bus_name2``_axi_arvalid   , ``bus_name1``_axi_arvalid   , ``bus_name0``_axi_arvalid  }; \
    assign ``array_name``_axi_arid     = {``bus_name7``_axi_arid      , ``bus_name6``_axi_arid      , ``bus_name5``_axi_arid      , ``bus_name4``_axi_arid      , ``bus_name3``_axi_arid      , ``bus_name2``_axi_arid      , ``bus_name1``_axi_arid      , ``bus_name0``_axi_arid     }; \
    assign ``array_name``_axi_arregion = {``bus_name7``_axi_arregion  , ``bus_name6``_axi_arregion  , ``bus_name5``_axi_arregion  , ``bus_name4``_axi_arregion  , ``bus_name3``_axi_arregion  , ``bus_name2``_axi_arregion  , ``bus_name1``_axi_arregion  , ``bus_name0``_axi_arregion }; \
    assign ``array_name``_axi_rready   = {``bus_name7``_axi_rready    , ``bus_name6``_axi_rready    , ``bus_name5``_axi_rready    , ``bus_name4``_axi_rready    , ``bus_name3``_axi_rready    , ``bus_name2``_axi_rready    , ``bus_name1``_axi_rready    , ``bus_name0``_axi_rready   }; \
    assign {``bus_name7``_axi_awready    , ``bus_name6``_axi_awready    , ``bus_name5``_axi_awready    , ``bus_name4``_axi_awready    , ``bus_name3``_axi_awready    , ``bus_name2``_axi_awready   , ``bus_name1``_axi_awready   , ``bus_name0``_axi_awready  } = ``array_name``_axi_awready ; \
    assign {``bus_name7``_axi_wready     , ``bus_name6``_axi_wready     , ``bus_name5``_axi_wready     , ``bus_name4``_axi_wready     , ``bus_name3``_axi_wready     , ``bus_name2``_axi_wready    , ``bus_name1``_axi_wready    , ``bus_name0``_axi_wready   } = ``array_name``_axi_wready  ; \
    assign {``bus_name7``_axi_bid        , ``bus_name6``_axi_bid        , ``bus_name5``_axi_bid        , ``bus_name4``_axi_bid        , ``bus_name3``_axi_bid        , ``bus_name2``_axi_bid       , ``bus_name1``_axi_bid       , ``bus_name0``_axi_bid      } = ``array_name``_axi_bid     ; \
    assign {``bus_name7``_axi_bresp      , ``bus_name6``_axi_bresp      , ``bus_name5``_axi_bresp      , ``bus_name4``_axi_bresp      , ``bus_name3``_axi_bresp      , ``bus_name2``_axi_bresp     , ``bus_name1``_axi_bresp     , ``bus_name0``_axi_bresp    } = ``array_name``_axi_bresp   ; \
    assign {``bus_name7``_axi_bvalid     , ``bus_name6``_axi_bvalid     , ``bus_name5``_axi_bvalid     , ``bus_name4``_axi_bvalid     , ``bus_name3``_axi_bvalid     , ``bus_name2``_axi_bvalid    , ``bus_name1``_axi_bvalid    , ``bus_name0``_axi_bvalid   } = ``array_name``_axi_bvalid  ; \
    assign {``bus_name7``_axi_arready    , ``bus_name6``_axi_arready    , ``bus_name5``_axi_arready    , ``bus_name4``_axi_arready    , ``bus_name3``_axi_arready    , ``bus_name2``_axi_arready   , ``bus_name1``_axi_arready   , ``bus_name0``_axi_arready  } = ``array_name``_axi_arready ; \
    assign {``bus_name7``_axi_rid        , ``bus_name6``_axi_rid        , ``bus_name5``_axi_rid        , ``bus_name4``_axi_rid        , ``bus_name3``_axi_rid        , ``bus_name2``_axi_rid       , ``bus_name1``_axi_rid       , ``bus_name0``_axi_rid      } = ``array_name``_axi_rid     ; \
    assign {``bus_name7``_axi_rdata      , ``bus_name6``_axi_rdata      , ``bus_name5``_axi_rdata      , ``bus_name4``_axi_rdata      , ``bus_name3``_axi_rdata      , ``bus_name2``_axi_rdata     , ``bus_name1``_axi_rdata     , ``bus_name0``_axi_rdata    } = ``array_name``_axi_rdata   ; \
    assign {``bus_name7``_axi_rresp      , ``bus_name6``_axi_rresp      , ``bus_name5``_axi_rresp      , ``bus_name4``_axi_rresp      , ``bus_name3``_axi_rresp      , ``bus_name2``_axi_rresp     , ``bus_name1``_axi_rresp     , ``bus_name0``_axi_rresp    } = ``array_name``_axi_rresp   ; \
    assign {``bus_name7``_axi_rlast      , ``bus_name6``_axi_rlast      , ``bus_name5``_axi_rlast      , ``bus_name4``_axi_rlast      , ``bus_name3``_axi_rlast      , ``bus_name2``_axi_rlast     , ``bus_name1``_axi_rlast     , ``bus_name0``_axi_rlast    } = ``array_name``_axi_rlast   ; \
    assign {``bus_name7``_axi_rvalid     , ``bus_name6``_axi_rvalid     , ``bus_name5``_axi_rvalid     , ``bus_name4``_axi_rvalid     , ``bus_name3``_axi_rvalid     , ``bus_name2``_axi_rvalid    , ``bus_name1``_axi_rvalid    , ``bus_name0``_axi_rvalid   } = ``array_name``_axi_rvalid  ;

// // Concatenate 10 master buses
// `define CONCAT_AXI_MASTERS_ARRAY10(array_name, bus_name9, bus_name8, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
//     assign ``array_name``_axi_awid     = {``bus_name9``_axi_awid      , ``bus_name8``_axi_awid      , ``bus_name7``_axi_awid      , ``bus_name6``_axi_awid      , ``bus_name5``_axi_awid      , ``bus_name4``_axi_awid      , ``bus_name3``_axi_awid      , ``bus_name2``_axi_awid      , ``bus_name1``_axi_awid      , ``bus_name0``_axi_awid     }; \
//     assign ``array_name``_axi_awaddr   = {``bus_name9``_axi_awaddr    , ``bus_name8``_axi_awaddr    , ``bus_name7``_axi_awaddr    , ``bus_name6``_axi_awaddr    , ``bus_name5``_axi_awaddr    , ``bus_name4``_axi_awaddr    , ``bus_name3``_axi_awaddr    , ``bus_name2``_axi_awaddr    , ``bus_name1``_axi_awaddr    , ``bus_name0``_axi_awaddr   }; \
//     assign ``array_name``_axi_awlen    = {``bus_name9``_axi_awlen     , ``bus_name8``_axi_awlen     , ``bus_name7``_axi_awlen     , ``bus_name6``_axi_awlen     , ``bus_name5``_axi_awlen     , ``bus_name4``_axi_awlen     , ``bus_name3``_axi_awlen     , ``bus_name2``_axi_awlen     , ``bus_name1``_axi_awlen     , ``bus_name0``_axi_awlen    }; \
//     assign ``array_name``_axi_awsize   = {``bus_name9``_axi_awsize    , ``bus_name8``_axi_awsize    , ``bus_name7``_axi_awsize    , ``bus_name6``_axi_awsize    , ``bus_name5``_axi_awsize    , ``bus_name4``_axi_awsize    , ``bus_name3``_axi_awsize    , ``bus_name2``_axi_awsize    , ``bus_name1``_axi_awsize    , ``bus_name0``_axi_awsize   }; \
//     assign ``array_name``_axi_awburst  = {``bus_name9``_axi_awburst   , ``bus_name8``_axi_awburst   , ``bus_name7``_axi_awburst   , ``bus_name6``_axi_awburst   , ``bus_name5``_axi_awburst   , ``bus_name4``_axi_awburst   , ``bus_name3``_axi_awburst   , ``bus_name2``_axi_awburst   , ``bus_name1``_axi_awburst   , ``bus_name0``_axi_awburst  }; \
//     assign ``array_name``_axi_awlock   = {``bus_name9``_axi_awlock    , ``bus_name8``_axi_awlock    , ``bus_name7``_axi_awlock    , ``bus_name6``_axi_awlock    , ``bus_name5``_axi_awlock    , ``bus_name4``_axi_awlock    , ``bus_name3``_axi_awlock    , ``bus_name2``_axi_awlock    , ``bus_name1``_axi_awlock    , ``bus_name0``_axi_awlock   }; \
//     assign ``array_name``_axi_awcache  = {``bus_name9``_axi_awcache   , ``bus_name8``_axi_awcache   , ``bus_name7``_axi_awcache   , ``bus_name6``_axi_awcache   , ``bus_name5``_axi_awcache   , ``bus_name4``_axi_awcache   , ``bus_name3``_axi_awcache   , ``bus_name2``_axi_awcache   , ``bus_name1``_axi_awcache   , ``bus_name0``_axi_awcache  }; \
//     assign ``array_name``_axi_awprot   = {``bus_name9``_axi_awprot    , ``bus_name8``_axi_awprot    , ``bus_name7``_axi_awprot    , ``bus_name6``_axi_awprot    , ``bus_name5``_axi_awprot    , ``bus_name4``_axi_awprot    , ``bus_name3``_axi_awprot    , ``bus_name2``_axi_awprot    , ``bus_name1``_axi_awprot    , ``bus_name0``_axi_awprot   }; \
//     assign ``array_name``_axi_awqos    = {``bus_name9``_axi_awqos     , ``bus_name8``_axi_awqos     , ``bus_name7``_axi_awqos     , ``bus_name6``_axi_awqos     , ``bus_name5``_axi_awqos     , ``bus_name4``_axi_awqos     , ``bus_name3``_axi_awqos     , ``bus_name2``_axi_awqos     , ``bus_name1``_axi_awqos     , ``bus_name0``_axi_awqos    }; \
//     assign ``array_name``_axi_awvalid  = {``bus_name9``_axi_awvalid   , ``bus_name8``_axi_awvalid   , ``bus_name7``_axi_awvalid   , ``bus_name6``_axi_awvalid   , ``bus_name5``_axi_awvalid   , ``bus_name4``_axi_awvalid   , ``bus_name3``_axi_awvalid   , ``bus_name2``_axi_awvalid   , ``bus_name1``_axi_awvalid   , ``bus_name0``_axi_awvalid  }; \
//     assign ``array_name``_axi_awregion = {``bus_name9``_axi_awregion  , ``bus_name8``_axi_awregion  , ``bus_name7``_axi_awregion  , ``bus_name6``_axi_awregion  , ``bus_name5``_axi_awregion  , ``bus_name4``_axi_awregion  , ``bus_name3``_axi_awregion  , ``bus_name2``_axi_awregion  , ``bus_name1``_axi_awregion  , ``bus_name0``_axi_awregion }; \
//     assign ``array_name``_axi_wdata    = {``bus_name9``_axi_wdata     , ``bus_name8``_axi_wdata     , ``bus_name7``_axi_wdata     , ``bus_name6``_axi_wdata     , ``bus_name5``_axi_wdata     , ``bus_name4``_axi_wdata     , ``bus_name3``_axi_wdata     , ``bus_name2``_axi_wdata     , ``bus_name1``_axi_wdata     , ``bus_name0``_axi_wdata    }; \
//     assign ``array_name``_axi_wstrb    = {``bus_name9``_axi_wstrb     , ``bus_name8``_axi_wstrb     , ``bus_name7``_axi_wstrb     , ``bus_name6``_axi_wstrb     , ``bus_name5``_axi_wstrb     , ``bus_name4``_axi_wstrb     , ``bus_name3``_axi_wstrb     , ``bus_name2``_axi_wstrb     , ``bus_name1``_axi_wstrb     , ``bus_name0``_axi_wstrb    }; \
//     assign ``array_name``_axi_wlast    = {``bus_name9``_axi_wlast     , ``bus_name8``_axi_wlast     , ``bus_name7``_axi_wlast     , ``bus_name6``_axi_wlast     , ``bus_name5``_axi_wlast     , ``bus_name4``_axi_wlast     , ``bus_name3``_axi_wlast     , ``bus_name2``_axi_wlast     , ``bus_name1``_axi_wlast     , ``bus_name0``_axi_wlast    }; \
//     assign ``array_name``_axi_wvalid   = {``bus_name9``_axi_wvalid    , ``bus_name8``_axi_wvalid    , ``bus_name7``_axi_wvalid    , ``bus_name6``_axi_wvalid    , ``bus_name5``_axi_wvalid    , ``bus_name4``_axi_wvalid    , ``bus_name3``_axi_wvalid    , ``bus_name2``_axi_wvalid    , ``bus_name1``_axi_wvalid    , ``bus_name0``_axi_wvalid   }; \
//     assign ``array_name``_axi_bready   = {``bus_name9``_axi_bready    , ``bus_name8``_axi_bready    , ``bus_name7``_axi_bready    , ``bus_name6``_axi_bready    , ``bus_name5``_axi_bready    , ``bus_name4``_axi_bready    , ``bus_name3``_axi_bready    , ``bus_name2``_axi_bready    , ``bus_name1``_axi_bready    , ``bus_name0``_axi_bready   }; \
//     assign ``array_name``_axi_araddr   = {``bus_name9``_axi_araddr    , ``bus_name8``_axi_araddr    , ``bus_name7``_axi_araddr    , ``bus_name6``_axi_araddr    , ``bus_name5``_axi_araddr    , ``bus_name4``_axi_araddr    , ``bus_name3``_axi_araddr    , ``bus_name2``_axi_araddr    , ``bus_name1``_axi_araddr    , ``bus_name0``_axi_araddr   }; \
//     assign ``array_name``_axi_arlen    = {``bus_name9``_axi_arlen     , ``bus_name8``_axi_arlen     , ``bus_name7``_axi_arlen     , ``bus_name6``_axi_arlen     , ``bus_name5``_axi_arlen     , ``bus_name4``_axi_arlen     , ``bus_name3``_axi_arlen     , ``bus_name2``_axi_arlen     , ``bus_name1``_axi_arlen     , ``bus_name0``_axi_arlen    }; \
//     assign ``array_name``_axi_arsize   = {``bus_name9``_axi_arsize    , ``bus_name8``_axi_arsize    , ``bus_name7``_axi_arsize    , ``bus_name6``_axi_arsize    , ``bus_name5``_axi_arsize    , ``bus_name4``_axi_arsize    , ``bus_name3``_axi_arsize    , ``bus_name2``_axi_arsize    , ``bus_name1``_axi_arsize    , ``bus_name0``_axi_arsize   }; \
//     assign ``array_name``_axi_arburst  = {``bus_name9``_axi_arburst   , ``bus_name8``_axi_arburst   , ``bus_name7``_axi_arburst   , ``bus_name6``_axi_arburst   , ``bus_name5``_axi_arburst   , ``bus_name4``_axi_arburst   , ``bus_name3``_axi_arburst   , ``bus_name2``_axi_arburst   , ``bus_name1``_axi_arburst   , ``bus_name0``_axi_arburst  }; \
//     assign ``array_name``_axi_arlock   = {``bus_name9``_axi_arlock    , ``bus_name8``_axi_arlock    , ``bus_name7``_axi_arlock    , ``bus_name6``_axi_arlock    , ``bus_name5``_axi_arlock    , ``bus_name4``_axi_arlock    , ``bus_name3``_axi_arlock    , ``bus_name2``_axi_arlock    , ``bus_name1``_axi_arlock    , ``bus_name0``_axi_arlock   }; \
//     assign ``array_name``_axi_arcache  = {``bus_name9``_axi_arcache   , ``bus_name8``_axi_arcache   , ``bus_name7``_axi_arcache   , ``bus_name6``_axi_arcache   , ``bus_name5``_axi_arcache   , ``bus_name4``_axi_arcache   , ``bus_name3``_axi_arcache   , ``bus_name2``_axi_arcache   , ``bus_name1``_axi_arcache   , ``bus_name0``_axi_arcache  }; \
//     assign ``array_name``_axi_arprot   = {``bus_name9``_axi_arprot    , ``bus_name8``_axi_arprot    , ``bus_name7``_axi_arprot    , ``bus_name6``_axi_arprot    , ``bus_name5``_axi_arprot    , ``bus_name4``_axi_arprot    , ``bus_name3``_axi_arprot    , ``bus_name2``_axi_arprot    , ``bus_name1``_axi_arprot    , ``bus_name0``_axi_arprot   }; \
//     assign ``array_name``_axi_arqos    = {``bus_name9``_axi_arqos     , ``bus_name8``_axi_arqos     , ``bus_name7``_axi_arqos     , ``bus_name6``_axi_arqos     , ``bus_name5``_axi_arqos     , ``bus_name4``_axi_arqos     , ``bus_name3``_axi_arqos     , ``bus_name2``_axi_arqos     , ``bus_name1``_axi_arqos     , ``bus_name0``_axi_arqos    }; \
//     assign ``array_name``_axi_arvalid  = {``bus_name9``_axi_arvalid   , ``bus_name8``_axi_arvalid   , ``bus_name7``_axi_arvalid   , ``bus_name6``_axi_arvalid   , ``bus_name5``_axi_arvalid   , ``bus_name4``_axi_arvalid   , ``bus_name3``_axi_arvalid   , ``bus_name2``_axi_arvalid   , ``bus_name1``_axi_arvalid   , ``bus_name0``_axi_arvalid  }; \
//     assign ``array_name``_axi_arid     = {``bus_name9``_axi_arid      , ``bus_name8``_axi_arid      , ``bus_name7``_axi_arid      , ``bus_name6``_axi_arid      , ``bus_name5``_axi_arid      , ``bus_name4``_axi_arid      , ``bus_name3``_axi_arid      , ``bus_name2``_axi_arid      , ``bus_name1``_axi_arid      , ``bus_name0``_axi_arid     }; \
//     assign ``array_name``_axi_arregion = {``bus_name9``_axi_arregion  , ``bus_name8``_axi_arregion  , ``bus_name7``_axi_arregion  , ``bus_name6``_axi_arregion  , ``bus_name5``_axi_arregion  , ``bus_name4``_axi_arregion  , ``bus_name3``_axi_arregion  , ``bus_name2``_axi_arregion  , ``bus_name1``_axi_arregion  , ``bus_name0``_axi_arregion }; \
//     assign ``array_name``_axi_rready   = {``bus_name9``_axi_rready    , ``bus_name8``_axi_rready    , ``bus_name7``_axi_rready    , ``bus_name6``_axi_rready    , ``bus_name5``_axi_rready    , ``bus_name4``_axi_rready    , ``bus_name3``_axi_rready    , ``bus_name2``_axi_rready    , ``bus_name1``_axi_rready    , ``bus_name0``_axi_rready   }; \
//     assign {``bus_name9``_axi_awready    , ``bus_name8``_axi_awready    , ``bus_name7``_axi_awready    , ``bus_name6``_axi_awready    , ``bus_name5``_axi_awready   , ``bus_name4``_axi_awready   , ``bus_name3``_axi_awready   , ``bus_name2``_axi_awready   , ``bus_name1``_axi_awready   , ``bus_name0``_axi_awready  } = ``array_name``_axi_awready ; \
//     assign {``bus_name9``_axi_wready     , ``bus_name8``_axi_wready     , ``bus_name7``_axi_wready     , ``bus_name6``_axi_wready     , ``bus_name5``_axi_wready    , ``bus_name4``_axi_wready    , ``bus_name3``_axi_wready    , ``bus_name2``_axi_wready    , ``bus_name1``_axi_wready    , ``bus_name0``_axi_wready   } = ``array_name``_axi_wready  ; \
//     assign {``bus_name9``_axi_bid        , ``bus_name8``_axi_bid        , ``bus_name7``_axi_bid        , ``bus_name6``_axi_bid        , ``bus_name5``_axi_bid       , ``bus_name4``_axi_bid       , ``bus_name3``_axi_bid       , ``bus_name2``_axi_bid       , ``bus_name1``_axi_bid       , ``bus_name0``_axi_bid      } = ``array_name``_axi_bid     ; \
//     assign {``bus_name9``_axi_bresp      , ``bus_name8``_axi_bresp      , ``bus_name7``_axi_bresp      , ``bus_name6``_axi_bresp      , ``bus_name5``_axi_bresp     , ``bus_name4``_axi_bresp     , ``bus_name3``_axi_bresp     , ``bus_name2``_axi_bresp     , ``bus_name1``_axi_bresp     , ``bus_name0``_axi_bresp    } = ``array_name``_axi_bresp   ; \
//     assign {``bus_name9``_axi_bvalid     , ``bus_name8``_axi_bvalid     , ``bus_name7``_axi_bvalid     , ``bus_name6``_axi_bvalid     , ``bus_name5``_axi_bvalid    , ``bus_name4``_axi_bvalid    , ``bus_name3``_axi_bvalid    , ``bus_name2``_axi_bvalid    , ``bus_name1``_axi_bvalid    , ``bus_name0``_axi_bvalid   } = ``array_name``_axi_bvalid  ; \
//     assign {``bus_name9``_axi_arready    , ``bus_name8``_axi_arready    , ``bus_name7``_axi_arready    , ``bus_name6``_axi_arready    , ``bus_name5``_axi_arready   , ``bus_name4``_axi_arready   , ``bus_name3``_axi_arready   , ``bus_name2``_axi_arready   , ``bus_name1``_axi_arready   , ``bus_name0``_axi_arready  } = ``array_name``_axi_arready ; \
//     assign {``bus_name9``_axi_rid        , ``bus_name8``_axi_rid        , ``bus_name7``_axi_rid        , ``bus_name6``_axi_rid        , ``bus_name5``_axi_rid       , ``bus_name4``_axi_rid       , ``bus_name3``_axi_rid       , ``bus_name2``_axi_rid       , ``bus_name1``_axi_rid       , ``bus_name0``_axi_rid      } = ``array_name``_axi_rid     ; \
//     assign {``bus_name9``_axi_rdata      , ``bus_name8``_axi_rdata      , ``bus_name7``_axi_rdata      , ``bus_name6``_axi_rdata      , ``bus_name5``_axi_rdata     , ``bus_name4``_axi_rdata     , ``bus_name3``_axi_rdata     , ``bus_name2``_axi_rdata     , ``bus_name1``_axi_rdata     , ``bus_name0``_axi_rdata    } = ``array_name``_axi_rdata   ; \
//     assign {``bus_name9``_axi_rresp      , ``bus_name8``_axi_rresp      , ``bus_name7``_axi_rresp      , ``bus_name6``_axi_rresp      , ``bus_name5``_axi_rresp     , ``bus_name4``_axi_rresp     , ``bus_name3``_axi_rresp     , ``bus_name2``_axi_rresp     , ``bus_name1``_axi_rresp     , ``bus_name0``_axi_rresp    } = ``array_name``_axi_rresp   ; \
//     assign {``bus_name9``_axi_rlast      , ``bus_name8``_axi_rlast      , ``bus_name7``_axi_rlast      , ``bus_name6``_axi_rlast      , ``bus_name5``_axi_rlast     , ``bus_name4``_axi_rlast     , ``bus_name3``_axi_rlast     , ``bus_name2``_axi_rlast     , ``bus_name1``_axi_rlast     , ``bus_name0``_axi_rlast    } = ``array_name``_axi_rlast   ; \
//     assign {``bus_name9``_axi_rvalid     , ``bus_name8``_axi_rvalid     , ``bus_name7``_axi_rvalid     , ``bus_name6``_axi_rvalid     , ``bus_name5``_axi_rvalid    , ``bus_name4``_axi_rvalid    , ``bus_name3``_axi_rvalid    , ``bus_name2``_axi_rvalid    , ``bus_name1``_axi_rvalid    , ``bus_name0``_axi_rvalid   } = ``array_name``_axi_rvalid  ;

// Concatenate 10 slave buses
`define CONCAT_AXI_SLAVES_ARRAY10(array_name, bus_name9, bus_name8, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
    assign {``bus_name9``_axi_awid, ``bus_name8``_axi_awid, ``bus_name7``_axi_awid, ``bus_name6``_axi_awid, ``bus_name5``_axi_awid, ``bus_name4``_axi_awid, ``bus_name3``_axi_awid, ``bus_name2``_axi_awid, ``bus_name1``_axi_awid, ``bus_name0``_axi_awid} = ``array_name``_axi_awid; \
    assign {``bus_name9``_axi_awaddr, ``bus_name8``_axi_awaddr, ``bus_name7``_axi_awaddr, ``bus_name6``_axi_awaddr, ``bus_name5``_axi_awaddr, ``bus_name4``_axi_awaddr, ``bus_name3``_axi_awaddr, ``bus_name2``_axi_awaddr, ``bus_name1``_axi_awaddr, ``bus_name0``_axi_awaddr} = ``array_name``_axi_awaddr; \
    assign {``bus_name9``_axi_awlen, ``bus_name8``_axi_awlen, ``bus_name7``_axi_awlen, ``bus_name6``_axi_awlen, ``bus_name5``_axi_awlen, ``bus_name4``_axi_awlen, ``bus_name3``_axi_awlen, ``bus_name2``_axi_awlen, ``bus_name1``_axi_awlen, ``bus_name0``_axi_awlen} = ``array_name``_axi_awlen; \
    assign {``bus_name9``_axi_awsize, ``bus_name8``_axi_awsize, ``bus_name7``_axi_awsize, ``bus_name6``_axi_awsize, ``bus_name5``_axi_awsize, ``bus_name4``_axi_awsize, ``bus_name3``_axi_awsize, ``bus_name2``_axi_awsize, ``bus_name1``_axi_awsize, ``bus_name0``_axi_awsize} = ``array_name``_axi_awsize; \
    assign {``bus_name9``_axi_awburst, ``bus_name8``_axi_awburst, ``bus_name7``_axi_awburst, ``bus_name6``_axi_awburst, ``bus_name5``_axi_awburst, ``bus_name4``_axi_awburst, ``bus_name3``_axi_awburst, ``bus_name2``_axi_awburst, ``bus_name1``_axi_awburst, ``bus_name0``_axi_awburst} = ``array_name``_axi_awburst; \
    assign {``bus_name9``_axi_awlock, ``bus_name8``_axi_awlock, ``bus_name7``_axi_awlock, ``bus_name6``_axi_awlock, ``bus_name5``_axi_awlock, ``bus_name4``_axi_awlock, ``bus_name3``_axi_awlock, ``bus_name2``_axi_awlock, ``bus_name1``_axi_awlock, ``bus_name0``_axi_awlock} = ``array_name``_axi_awlock; \
    assign {``bus_name9``_axi_awcache, ``bus_name8``_axi_awcache, ``bus_name7``_axi_awcache, ``bus_name6``_axi_awcache, ``bus_name5``_axi_awcache, ``bus_name4``_axi_awcache, ``bus_name3``_axi_awcache, ``bus_name2``_axi_awcache, ``bus_name1``_axi_awcache, ``bus_name0``_axi_awcache} = ``array_name``_axi_awcache; \
    assign {``bus_name9``_axi_awprot, ``bus_name8``_axi_awprot, ``bus_name7``_axi_awprot, ``bus_name6``_axi_awprot, ``bus_name5``_axi_awprot, ``bus_name4``_axi_awprot, ``bus_name3``_axi_awprot, ``bus_name2``_axi_awprot, ``bus_name1``_axi_awprot, ``bus_name0``_axi_awprot} = ``array_name``_axi_awprot; \
    assign {``bus_name9``_axi_awqos, ``bus_name8``_axi_awqos, ``bus_name7``_axi_awqos, ``bus_name6``_axi_awqos, ``bus_name5``_axi_awqos, ``bus_name4``_axi_awqos, ``bus_name3``_axi_awqos, ``bus_name2``_axi_awqos, ``bus_name1``_axi_awqos, ``bus_name0``_axi_awqos} = ``array_name``_axi_awqos; \
    assign {``bus_name9``_axi_awvalid, ``bus_name8``_axi_awvalid, ``bus_name7``_axi_awvalid, ``bus_name6``_axi_awvalid, ``bus_name5``_axi_awvalid, ``bus_name4``_axi_awvalid, ``bus_name3``_axi_awvalid, ``bus_name2``_axi_awvalid, ``bus_name1``_axi_awvalid, ``bus_name0``_axi_awvalid} = ``array_name``_axi_awvalid; \
    assign {``bus_name9``_axi_awregion, ``bus_name8``_axi_awregion, ``bus_name7``_axi_awregion, ``bus_name6``_axi_awregion, ``bus_name5``_axi_awregion, ``bus_name4``_axi_awregion, ``bus_name3``_axi_awregion, ``bus_name2``_axi_awregion, ``bus_name1``_axi_awregion, ``bus_name0``_axi_awregion} = ``array_name``_axi_awregion; \
    assign {``bus_name9``_axi_wdata, ``bus_name8``_axi_wdata, ``bus_name7``_axi_wdata, ``bus_name6``_axi_wdata, ``bus_name5``_axi_wdata, ``bus_name4``_axi_wdata, ``bus_name3``_axi_wdata, ``bus_name2``_axi_wdata, ``bus_name1``_axi_wdata, ``bus_name0``_axi_wdata} = ``array_name``_axi_wdata; \
    assign {``bus_name9``_axi_wstrb, ``bus_name8``_axi_wstrb, ``bus_name7``_axi_wstrb, ``bus_name6``_axi_wstrb, ``bus_name5``_axi_wstrb, ``bus_name4``_axi_wstrb, ``bus_name3``_axi_wstrb, ``bus_name2``_axi_wstrb, ``bus_name1``_axi_wstrb, ``bus_name0``_axi_wstrb} = ``array_name``_axi_wstrb; \
    assign {``bus_name9``_axi_wlast, ``bus_name8``_axi_wlast, ``bus_name7``_axi_wlast, ``bus_name6``_axi_wlast, ``bus_name5``_axi_wlast, ``bus_name4``_axi_wlast, ``bus_name3``_axi_wlast, ``bus_name2``_axi_wlast, ``bus_name1``_axi_wlast, ``bus_name0``_axi_wlast} = ``array_name``_axi_wlast; \
    assign {``bus_name9``_axi_wvalid, ``bus_name8``_axi_wvalid, ``bus_name7``_axi_wvalid, ``bus_name6``_axi_wvalid, ``bus_name5``_axi_wvalid, ``bus_name4``_axi_wvalid, ``bus_name3``_axi_wvalid, ``bus_name2``_axi_wvalid, ``bus_name1``_axi_wvalid, ``bus_name0``_axi_wvalid} = ``array_name``_axi_wvalid; \
    assign {``bus_name9``_axi_bready, ``bus_name8``_axi_bready, ``bus_name7``_axi_bready, ``bus_name6``_axi_bready, ``bus_name5``_axi_bready, ``bus_name4``_axi_bready, ``bus_name3``_axi_bready, ``bus_name2``_axi_bready, ``bus_name1``_axi_bready, ``bus_name0``_axi_bready} = ``array_name``_axi_bready; \
    assign {``bus_name9``_axi_araddr, ``bus_name8``_axi_araddr, ``bus_name7``_axi_araddr, ``bus_name6``_axi_araddr, ``bus_name5``_axi_araddr, ``bus_name4``_axi_araddr, ``bus_name3``_axi_araddr, ``bus_name2``_axi_araddr, ``bus_name1``_axi_araddr, ``bus_name0``_axi_araddr} = ``array_name``_axi_araddr; \
    assign {``bus_name9``_axi_arlen, ``bus_name8``_axi_arlen, ``bus_name7``_axi_arlen, ``bus_name6``_axi_arlen, ``bus_name5``_axi_arlen, ``bus_name4``_axi_arlen, ``bus_name3``_axi_arlen, ``bus_name2``_axi_arlen, ``bus_name1``_axi_arlen, ``bus_name0``_axi_arlen} = ``array_name``_axi_arlen; \
    assign {``bus_name9``_axi_arsize, ``bus_name8``_axi_arsize, ``bus_name7``_axi_arsize, ``bus_name6``_axi_arsize, ``bus_name5``_axi_arsize, ``bus_name4``_axi_arsize, ``bus_name3``_axi_arsize, ``bus_name2``_axi_arsize, ``bus_name1``_axi_arsize, ``bus_name0``_axi_arsize} = ``array_name``_axi_arsize; \
    assign {``bus_name9``_axi_arburst, ``bus_name8``_axi_arburst, ``bus_name7``_axi_arburst, ``bus_name6``_axi_arburst, ``bus_name5``_axi_arburst, ``bus_name4``_axi_arburst, ``bus_name3``_axi_arburst, ``bus_name2``_axi_arburst, ``bus_name1``_axi_arburst, ``bus_name0``_axi_arburst} = ``array_name``_axi_arburst; \
    assign {``bus_name9``_axi_arlock, ``bus_name8``_axi_arlock, ``bus_name7``_axi_arlock, ``bus_name6``_axi_arlock, ``bus_name5``_axi_arlock, ``bus_name4``_axi_arlock, ``bus_name3``_axi_arlock, ``bus_name2``_axi_arlock, ``bus_name1``_axi_arlock, ``bus_name0``_axi_arlock} = ``array_name``_axi_arlock; \
    assign {``bus_name9``_axi_arcache, ``bus_name8``_axi_arcache, ``bus_name7``_axi_arcache, ``bus_name6``_axi_arcache, ``bus_name5``_axi_arcache, ``bus_name4``_axi_arcache, ``bus_name3``_axi_arcache, ``bus_name2``_axi_arcache, ``bus_name1``_axi_arcache, ``bus_name0``_axi_arcache} = ``array_name``_axi_arcache; \
    assign {``bus_name9``_axi_arprot, ``bus_name8``_axi_arprot, ``bus_name7``_axi_arprot, ``bus_name6``_axi_arprot, ``bus_name5``_axi_arprot, ``bus_name4``_axi_arprot, ``bus_name3``_axi_arprot, ``bus_name2``_axi_arprot, ``bus_name1``_axi_arprot, ``bus_name0``_axi_arprot} = ``array_name``_axi_arprot; \
    assign {``bus_name9``_axi_arqos, ``bus_name8``_axi_arqos, ``bus_name7``_axi_arqos, ``bus_name6``_axi_arqos, ``bus_name5``_axi_arqos, ``bus_name4``_axi_arqos, ``bus_name3``_axi_arqos, ``bus_name2``_axi_arqos, ``bus_name1``_axi_arqos, ``bus_name0``_axi_arqos} = ``array_name``_axi_arqos; \
    assign {``bus_name9``_axi_arvalid, ``bus_name8``_axi_arvalid, ``bus_name7``_axi_arvalid, ``bus_name6``_axi_arvalid, ``bus_name5``_axi_arvalid, ``bus_name4``_axi_arvalid, ``bus_name3``_axi_arvalid, ``bus_name2``_axi_arvalid, ``bus_name1``_axi_arvalid, ``bus_name0``_axi_arvalid} = ``array_name``_axi_arvalid; \
    assign {``bus_name9``_axi_arid, ``bus_name8``_axi_arid, ``bus_name7``_axi_arid, ``bus_name6``_axi_arid, ``bus_name5``_axi_arid, ``bus_name4``_axi_arid, ``bus_name3``_axi_arid, ``bus_name2``_axi_arid, ``bus_name1``_axi_arid, ``bus_name0``_axi_arid} = ``array_name``_axi_arid; \
    assign {``bus_name9``_axi_arregion, ``bus_name8``_axi_arregion, ``bus_name7``_axi_arregion, ``bus_name6``_axi_arregion, ``bus_name5``_axi_arregion, ``bus_name4``_axi_arregion, ``bus_name3``_axi_arregion, ``bus_name2``_axi_arregion, ``bus_name1``_axi_arregion, ``bus_name0``_axi_arregion} = ``array_name``_axi_arregion; \
    assign {``bus_name9``_axi_rready, ``bus_name8``_axi_rready, ``bus_name7``_axi_rready, ``bus_name6``_axi_rready, ``bus_name5``_axi_rready, ``bus_name4``_axi_rready, ``bus_name3``_axi_rready, ``bus_name2``_axi_rready, ``bus_name1``_axi_rready, ``bus_name0``_axi_rready} = ``array_name``_axi_rready; \
    assign ``array_name``_axi_awready = {``bus_name9``_axi_awready, ``bus_name8``_axi_awready, ``bus_name7``_axi_awready, ``bus_name6``_axi_awready, ``bus_name5``_axi_awready, ``bus_name4``_axi_awready, ``bus_name3``_axi_awready, ``bus_name2``_axi_awready, ``bus_name1``_axi_awready, ``bus_name0``_axi_awready}; \
    assign ``array_name``_axi_wready = {``bus_name9``_axi_wready, ``bus_name8``_axi_wready, ``bus_name7``_axi_wready, ``bus_name6``_axi_wready, ``bus_name5``_axi_wready, ``bus_name4``_axi_wready, ``bus_name3``_axi_wready, ``bus_name2``_axi_wready, ``bus_name1``_axi_wready, ``bus_name0``_axi_wready}; \
    assign ``array_name``_axi_bid = {``bus_name9``_axi_bid, ``bus_name8``_axi_bid, ``bus_name7``_axi_bid, ``bus_name6``_axi_bid, ``bus_name5``_axi_bid, ``bus_name4``_axi_bid, ``bus_name3``_axi_bid, ``bus_name2``_axi_bid, ``bus_name1``_axi_bid, ``bus_name0``_axi_bid}; \
    assign ``array_name``_axi_bresp = {``bus_name9``_axi_bresp, ``bus_name8``_axi_bresp, ``bus_name7``_axi_bresp, ``bus_name6``_axi_bresp, ``bus_name5``_axi_bresp, ``bus_name4``_axi_bresp, ``bus_name3``_axi_bresp, ``bus_name2``_axi_bresp, ``bus_name1``_axi_bresp, ``bus_name0``_axi_bresp}; \
    assign ``array_name``_axi_bvalid = {``bus_name9``_axi_bvalid, ``bus_name8``_axi_bvalid, ``bus_name7``_axi_bvalid, ``bus_name6``_axi_bvalid, ``bus_name5``_axi_bvalid, ``bus_name4``_axi_bvalid, ``bus_name3``_axi_bvalid, ``bus_name2``_axi_bvalid, ``bus_name1``_axi_bvalid, ``bus_name0``_axi_bvalid}; \
    assign ``array_name``_axi_arready = {``bus_name9``_axi_arready, ``bus_name8``_axi_arready, ``bus_name7``_axi_arready, ``bus_name6``_axi_arready, ``bus_name5``_axi_arready, ``bus_name4``_axi_arready, ``bus_name3``_axi_arready, ``bus_name2``_axi_arready, ``bus_name1``_axi_arready, ``bus_name0``_axi_arready}; \
    assign ``array_name``_axi_rid = {``bus_name9``_axi_rid, ``bus_name8``_axi_rid, ``bus_name7``_axi_rid, ``bus_name6``_axi_rid, ``bus_name5``_axi_rid, ``bus_name4``_axi_rid, ``bus_name3``_axi_rid, ``bus_name2``_axi_rid, ``bus_name1``_axi_rid, ``bus_name0``_axi_rid}; \
    assign ``array_name``_axi_rdata = {``bus_name9``_axi_rdata, ``bus_name8``_axi_rdata, ``bus_name7``_axi_rdata, ``bus_name6``_axi_rdata, ``bus_name5``_axi_rdata, ``bus_name4``_axi_rdata, ``bus_name3``_axi_rdata, ``bus_name2``_axi_rdata, ``bus_name1``_axi_rdata, ``bus_name0``_axi_rdata}; \
    assign ``array_name``_axi_rresp = {``bus_name9``_axi_rresp, ``bus_name8``_axi_rresp, ``bus_name7``_axi_rresp, ``bus_name6``_axi_rresp, ``bus_name5``_axi_rresp, ``bus_name4``_axi_rresp, ``bus_name3``_axi_rresp, ``bus_name2``_axi_rresp, ``bus_name1``_axi_rresp, ``bus_name0``_axi_rresp}; \
    assign ``array_name``_axi_rlast = {``bus_name9``_axi_rlast, ``bus_name8``_axi_rlast, ``bus_name7``_axi_rlast, ``bus_name6``_axi_rlast, ``bus_name5``_axi_rlast, ``bus_name4``_axi_rlast, ``bus_name3``_axi_rlast, ``bus_name2``_axi_rlast, ``bus_name1``_axi_rlast, ``bus_name0``_axi_rlast}; \
    assign ``array_name``_axi_rvalid = {``bus_name9``_axi_rvalid, ``bus_name8``_axi_rvalid, ``bus_name7``_axi_rvalid, ``bus_name6``_axi_rvalid, ``bus_name5``_axi_rvalid, ``bus_name4``_axi_rvalid, ``bus_name3``_axi_rvalid, ``bus_name2``_axi_rvalid, ``bus_name1``_axi_rvalid, ``bus_name0``_axi_rvalid};

// Concatenate 12 slave buses
`define CONCAT_AXI_SLAVES_ARRAY12(array_name, bus_name11, bus_name10, bus_name9, bus_name8, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
    assign {``bus_name11``_axi_awid    , ``bus_name10``_axi_awid    , ``bus_name9``_axi_awid    , ``bus_name8``_axi_awid    , \
            ``bus_name7``_axi_awid     , ``bus_name6``_axi_awid     , ``bus_name5``_axi_awid    , ``bus_name4``_axi_awid    , \
            ``bus_name3``_axi_awid     , ``bus_name2``_axi_awid     , ``bus_name1``_axi_awid    , ``bus_name0``_axi_awid    } = ``array_name``_axi_awid; \
    assign {``bus_name11``_axi_awaddr  , ``bus_name10``_axi_awaddr  , ``bus_name9``_axi_awaddr  , ``bus_name8``_axi_awaddr  , \
            ``bus_name7``_axi_awaddr   , ``bus_name6``_axi_awaddr   , ``bus_name5``_axi_awaddr  , ``bus_name4``_axi_awaddr  , \
            ``bus_name3``_axi_awaddr   , ``bus_name2``_axi_awaddr   , ``bus_name1``_axi_awaddr  , ``bus_name0``_axi_awaddr  } = ``array_name``_axi_awaddr; \
    assign {``bus_name11``_axi_awlen   , ``bus_name10``_axi_awlen   , ``bus_name9``_axi_awlen   , ``bus_name8``_axi_awlen   , \
            ``bus_name7``_axi_awlen    , ``bus_name6``_axi_awlen    , ``bus_name5``_axi_awlen   , ``bus_name4``_axi_awlen   , \
            ``bus_name3``_axi_awlen    , ``bus_name2``_axi_awlen    , ``bus_name1``_axi_awlen   , ``bus_name0``_axi_awlen   } = ``array_name``_axi_awlen; \
    assign {``bus_name11``_axi_awsize  , ``bus_name10``_axi_awsize  , ``bus_name9``_axi_awsize  , ``bus_name8``_axi_awsize  , \
            ``bus_name7``_axi_awsize   , ``bus_name6``_axi_awsize   , ``bus_name5``_axi_awsize  , ``bus_name4``_axi_awsize  , \
            ``bus_name3``_axi_awsize   , ``bus_name2``_axi_awsize   , ``bus_name1``_axi_awsize  , ``bus_name0``_axi_awsize  } = ``array_name``_axi_awsize; \
    assign {``bus_name11``_axi_awburst , ``bus_name10``_axi_awburst , ``bus_name9``_axi_awburst , ``bus_name8``_axi_awburst , \
            ``bus_name7``_axi_awburst  , ``bus_name6``_axi_awburst  , ``bus_name5``_axi_awburst , ``bus_name4``_axi_awburst , \
            ``bus_name3``_axi_awburst  , ``bus_name2``_axi_awburst  , ``bus_name1``_axi_awburst , ``bus_name0``_axi_awburst } = ``array_name``_axi_awburst; \
    assign {``bus_name11``_axi_awlock  , ``bus_name10``_axi_awlock  , ``bus_name9``_axi_awlock  , ``bus_name8``_axi_awlock  , \
            ``bus_name7``_axi_awlock   , ``bus_name6``_axi_awlock   , ``bus_name5``_axi_awlock  , ``bus_name4``_axi_awlock  , \
            ``bus_name3``_axi_awlock   , ``bus_name2``_axi_awlock   , ``bus_name1``_axi_awlock  , ``bus_name0``_axi_awlock  } = ``array_name``_axi_awlock; \
    assign {``bus_name11``_axi_awcache , ``bus_name10``_axi_awcache , ``bus_name9``_axi_awcache , ``bus_name8``_axi_awcache , \
            ``bus_name7``_axi_awcache  , ``bus_name6``_axi_awcache  , ``bus_name5``_axi_awcache , ``bus_name4``_axi_awcache , \
            ``bus_name3``_axi_awcache  , ``bus_name2``_axi_awcache  , ``bus_name1``_axi_awcache , ``bus_name0``_axi_awcache } = ``array_name``_axi_awcache; \
    assign {``bus_name11``_axi_awprot  , ``bus_name10``_axi_awprot  , ``bus_name9``_axi_awprot  , ``bus_name8``_axi_awprot  , \
            ``bus_name7``_axi_awprot   , ``bus_name6``_axi_awprot   , ``bus_name5``_axi_awprot  , ``bus_name4``_axi_awprot  , \
            ``bus_name3``_axi_awprot   , ``bus_name2``_axi_awprot   , ``bus_name1``_axi_awprot  , ``bus_name0``_axi_awprot  } = ``array_name``_axi_awprot; \
    assign {``bus_name11``_axi_awqos   , ``bus_name10``_axi_awqos   , ``bus_name9``_axi_awqos   , ``bus_name8``_axi_awqos   , \
            ``bus_name7``_axi_awqos    , ``bus_name6``_axi_awqos    , ``bus_name5``_axi_awqos   , ``bus_name4``_axi_awqos   , \
            ``bus_name3``_axi_awqos    , ``bus_name2``_axi_awqos    , ``bus_name1``_axi_awqos   , ``bus_name0``_axi_awqos   } = ``array_name``_axi_awqos; \
    assign {``bus_name11``_axi_awvalid , ``bus_name10``_axi_awvalid , ``bus_name9``_axi_awvalid , ``bus_name8``_axi_awvalid , \
            ``bus_name7``_axi_awvalid  , ``bus_name6``_axi_awvalid  , ``bus_name5``_axi_awvalid , ``bus_name4``_axi_awvalid , \
            ``bus_name3``_axi_awvalid  , ``bus_name2``_axi_awvalid  , ``bus_name1``_axi_awvalid , ``bus_name0``_axi_awvalid } = ``array_name``_axi_awvalid; \
    assign {``bus_name11``_axi_awregion, ``bus_name10``_axi_awregion, ``bus_name9``_axi_awregion, ``bus_name8``_axi_awregion, \
            ``bus_name7``_axi_awregion , ``bus_name6``_axi_awregion , ``bus_name5``_axi_awregion, ``bus_name4``_axi_awregion, \
            ``bus_name3``_axi_awregion , ``bus_name2``_axi_awregion , ``bus_name1``_axi_awregion, ``bus_name0``_axi_awregion} = ``array_name``_axi_awregion; \
    assign {``bus_name11``_axi_wdata   , ``bus_name10``_axi_wdata   , ``bus_name9``_axi_wdata   , ``bus_name8``_axi_wdata   , \
            ``bus_name7``_axi_wdata    , ``bus_name6``_axi_wdata    , ``bus_name5``_axi_wdata   , ``bus_name4``_axi_wdata   , \
            ``bus_name3``_axi_wdata    , ``bus_name2``_axi_wdata    , ``bus_name1``_axi_wdata   , ``bus_name0``_axi_wdata   } = ``array_name``_axi_wdata; \
    assign {``bus_name11``_axi_wstrb   , ``bus_name10``_axi_wstrb   , ``bus_name9``_axi_wstrb   , ``bus_name8``_axi_wstrb   , \
            ``bus_name7``_axi_wstrb    , ``bus_name6``_axi_wstrb    , ``bus_name5``_axi_wstrb   , ``bus_name4``_axi_wstrb   , \
            ``bus_name3``_axi_wstrb    , ``bus_name2``_axi_wstrb    , ``bus_name1``_axi_wstrb   , ``bus_name0``_axi_wstrb   } = ``array_name``_axi_wstrb; \
    assign {``bus_name11``_axi_wlast   , ``bus_name10``_axi_wlast   , ``bus_name9``_axi_wlast   , ``bus_name8``_axi_wlast   , \
            ``bus_name7``_axi_wlast    , ``bus_name6``_axi_wlast    , ``bus_name5``_axi_wlast   , ``bus_name4``_axi_wlast   , \
            ``bus_name3``_axi_wlast    , ``bus_name2``_axi_wlast    , ``bus_name1``_axi_wlast   , ``bus_name0``_axi_wlast   } = ``array_name``_axi_wlast; \
    assign {``bus_name11``_axi_wvalid  , ``bus_name10``_axi_wvalid  , ``bus_name9``_axi_wvalid  , ``bus_name8``_axi_wvalid  , \
            ``bus_name7``_axi_wvalid   , ``bus_name6``_axi_wvalid   , ``bus_name5``_axi_wvalid  , ``bus_name4``_axi_wvalid  , \
            ``bus_name3``_axi_wvalid   , ``bus_name2``_axi_wvalid   , ``bus_name1``_axi_wvalid  , ``bus_name0``_axi_wvalid  } = ``array_name``_axi_wvalid; \
    assign {``bus_name11``_axi_bready  , ``bus_name10``_axi_bready  , ``bus_name9``_axi_bready  , ``bus_name8``_axi_bready  , \
            ``bus_name7``_axi_bready   , ``bus_name6``_axi_bready   , ``bus_name5``_axi_bready  , ``bus_name4``_axi_bready  , \
            ``bus_name3``_axi_bready   , ``bus_name2``_axi_bready   , ``bus_name1``_axi_bready  , ``bus_name0``_axi_bready  } = ``array_name``_axi_bready; \
    assign {``bus_name11``_axi_araddr  , ``bus_name10``_axi_araddr  , ``bus_name9``_axi_araddr  , ``bus_name8``_axi_araddr  , \
            ``bus_name7``_axi_araddr   , ``bus_name6``_axi_araddr   , ``bus_name5``_axi_araddr  , ``bus_name4``_axi_araddr  , \
            ``bus_name3``_axi_araddr   , ``bus_name2``_axi_araddr   , ``bus_name1``_axi_araddr  , ``bus_name0``_axi_araddr  } = ``array_name``_axi_araddr; \
    assign {``bus_name11``_axi_arlen   , ``bus_name10``_axi_arlen   , ``bus_name9``_axi_arlen   , ``bus_name8``_axi_arlen   , \
            ``bus_name7``_axi_arlen    , ``bus_name6``_axi_arlen    , ``bus_name5``_axi_arlen   , ``bus_name4``_axi_arlen   , \
            ``bus_name3``_axi_arlen    , ``bus_name2``_axi_arlen    , ``bus_name1``_axi_arlen   , ``bus_name0``_axi_arlen   } = ``array_name``_axi_arlen; \
    assign {``bus_name11``_axi_arsize  , ``bus_name10``_axi_arsize  , ``bus_name9``_axi_arsize  , ``bus_name8``_axi_arsize  , \
            ``bus_name7``_axi_arsize   , ``bus_name6``_axi_arsize   , ``bus_name5``_axi_arsize  , ``bus_name4``_axi_arsize  , \
            ``bus_name3``_axi_arsize   , ``bus_name2``_axi_arsize   , ``bus_name1``_axi_arsize  , ``bus_name0``_axi_arsize  } = ``array_name``_axi_arsize; \
    assign {``bus_name11``_axi_arburst , ``bus_name10``_axi_arburst , ``bus_name9``_axi_arburst , ``bus_name8``_axi_arburst , \
            ``bus_name7``_axi_arburst  , ``bus_name6``_axi_arburst  , ``bus_name5``_axi_arburst , ``bus_name4``_axi_arburst , \
            ``bus_name3``_axi_arburst  , ``bus_name2``_axi_arburst  , ``bus_name1``_axi_arburst , ``bus_name0``_axi_arburst } = ``array_name``_axi_arburst; \
    assign {``bus_name11``_axi_arlock  , ``bus_name10``_axi_arlock  , ``bus_name9``_axi_arlock  , ``bus_name8``_axi_arlock  , \
            ``bus_name7``_axi_arlock   , ``bus_name6``_axi_arlock   , ``bus_name5``_axi_arlock  , ``bus_name4``_axi_arlock  , \
            ``bus_name3``_axi_arlock   , ``bus_name2``_axi_arlock   , ``bus_name1``_axi_arlock  , ``bus_name0``_axi_arlock  } = ``array_name``_axi_arlock; \
    assign {``bus_name11``_axi_arcache , ``bus_name10``_axi_arcache , ``bus_name9``_axi_arcache , ``bus_name8``_axi_arcache , \
            ``bus_name7``_axi_arcache  , ``bus_name6``_axi_arcache  , ``bus_name5``_axi_arcache , ``bus_name4``_axi_arcache , \
            ``bus_name3``_axi_arcache  , ``bus_name2``_axi_arcache  , ``bus_name1``_axi_arcache , ``bus_name0``_axi_arcache } = ``array_name``_axi_arcache; \
    assign {``bus_name11``_axi_arprot  , ``bus_name10``_axi_arprot  , ``bus_name9``_axi_arprot  , ``bus_name8``_axi_arprot  , \
            ``bus_name7``_axi_arprot   , ``bus_name6``_axi_arprot   , ``bus_name5``_axi_arprot  , ``bus_name4``_axi_arprot  , \
            ``bus_name3``_axi_arprot   , ``bus_name2``_axi_arprot   , ``bus_name1``_axi_arprot  , ``bus_name0``_axi_arprot  } = ``array_name``_axi_arprot; \
    assign {``bus_name11``_axi_arqos   , ``bus_name10``_axi_arqos   , ``bus_name9``_axi_arqos   , ``bus_name8``_axi_arqos   , \
            ``bus_name7``_axi_arqos    , ``bus_name6``_axi_arqos    , ``bus_name5``_axi_arqos   , ``bus_name4``_axi_arqos   , \
            ``bus_name3``_axi_arqos    , ``bus_name2``_axi_arqos    , ``bus_name1``_axi_arqos   , ``bus_name0``_axi_arqos   } = ``array_name``_axi_arqos; \
    assign {``bus_name11``_axi_arvalid , ``bus_name10``_axi_arvalid , ``bus_name9``_axi_arvalid , ``bus_name8``_axi_arvalid , \
            ``bus_name7``_axi_arvalid  , ``bus_name6``_axi_arvalid  , ``bus_name5``_axi_arvalid , ``bus_name4``_axi_arvalid , \
            ``bus_name3``_axi_arvalid  , ``bus_name2``_axi_arvalid  , ``bus_name1``_axi_arvalid , ``bus_name0``_axi_arvalid } = ``array_name``_axi_arvalid; \
    assign {``bus_name11``_axi_arid    , ``bus_name10``_axi_arid    , ``bus_name9``_axi_arid    , ``bus_name8``_axi_arid    , \
            ``bus_name7``_axi_arid     , ``bus_name6``_axi_arid     , ``bus_name5``_axi_arid    , ``bus_name4``_axi_arid    , \
            ``bus_name3``_axi_arid     , ``bus_name2``_axi_arid     , ``bus_name1``_axi_arid    , ``bus_name0``_axi_arid    } = ``array_name``_axi_arid; \
    assign {``bus_name11``_axi_arregion, ``bus_name10``_axi_arregion, ``bus_name9``_axi_arregion, ``bus_name8``_axi_arregion, \
            ``bus_name7``_axi_arregion , ``bus_name6``_axi_arregion , ``bus_name5``_axi_arregion, ``bus_name4``_axi_arregion, \
            ``bus_name3``_axi_arregion , ``bus_name2``_axi_arregion , ``bus_name1``_axi_arregion, ``bus_name0``_axi_arregion} = ``array_name``_axi_arregion; \
    assign {``bus_name11``_axi_rready  , ``bus_name10``_axi_rready  , ``bus_name9``_axi_rready  , ``bus_name8``_axi_rready  , \
            ``bus_name7``_axi_rready   , ``bus_name6``_axi_rready   , ``bus_name5``_axi_rready  , ``bus_name4``_axi_rready  , \
            ``bus_name3``_axi_rready   , ``bus_name2``_axi_rready   , ``bus_name1``_axi_rready  , ``bus_name0``_axi_rready  } = ``array_name``_axi_rready; \
    assign ``array_name``_axi_awready = {``bus_name11``_axi_awready , ``bus_name10``_axi_awready , ``bus_name9``_axi_awready , ``bus_name8``_axi_awready , \
                                         ``bus_name7``_axi_awready  , ``bus_name6``_axi_awready  , ``bus_name5``_axi_awready , ``bus_name4``_axi_awready , \
                                         ``bus_name3``_axi_awready  , ``bus_name2``_axi_awready  , ``bus_name1``_axi_awready , ``bus_name0``_axi_awready }; \
    assign ``array_name``_axi_wready  = {``bus_name11``_axi_wready  , ``bus_name10``_axi_wready  , ``bus_name9``_axi_wready  , ``bus_name8``_axi_wready  , \
                                         ``bus_name7``_axi_wready   , ``bus_name6``_axi_wready   , ``bus_name5``_axi_wready  , ``bus_name4``_axi_wready  , \
                                         ``bus_name3``_axi_wready   , ``bus_name2``_axi_wready   , ``bus_name1``_axi_wready  , ``bus_name0``_axi_wready  }; \
    assign ``array_name``_axi_bid     = {``bus_name11``_axi_bid     , ``bus_name10``_axi_bid     , ``bus_name9``_axi_bid     , ``bus_name8``_axi_bid     , \
                                         ``bus_name7``_axi_bid      , ``bus_name6``_axi_bid      , ``bus_name5``_axi_bid     , ``bus_name4``_axi_bid     , \
                                         ``bus_name3``_axi_bid      , ``bus_name2``_axi_bid      , ``bus_name1``_axi_bid     , ``bus_name0``_axi_bid     }; \
    assign ``array_name``_axi_bresp   = {``bus_name11``_axi_bresp   , ``bus_name10``_axi_bresp   , ``bus_name9``_axi_bresp   , ``bus_name8``_axi_bresp   , \
                                         ``bus_name7``_axi_bresp    , ``bus_name6``_axi_bresp    , ``bus_name5``_axi_bresp   , ``bus_name4``_axi_bresp   , \
                                         ``bus_name3``_axi_bresp    , ``bus_name2``_axi_bresp    , ``bus_name1``_axi_bresp   , ``bus_name0``_axi_bresp   }; \
    assign ``array_name``_axi_bvalid  = {``bus_name11``_axi_bvalid  , ``bus_name10``_axi_bvalid  , ``bus_name9``_axi_bvalid  , ``bus_name8``_axi_bvalid  , \
                                         ``bus_name7``_axi_bvalid   , ``bus_name6``_axi_bvalid   , ``bus_name5``_axi_bvalid  , ``bus_name4``_axi_bvalid  , \
                                         ``bus_name3``_axi_bvalid   , ``bus_name2``_axi_bvalid   , ``bus_name1``_axi_bvalid  , ``bus_name0``_axi_bvalid  }; \
    assign ``array_name``_axi_arready = {``bus_name11``_axi_arready , ``bus_name10``_axi_arready , ``bus_name9``_axi_arready , ``bus_name8``_axi_arready , \
                                         ``bus_name7``_axi_arready  , ``bus_name6``_axi_arready  , ``bus_name5``_axi_arready , ``bus_name4``_axi_arready , \
                                         ``bus_name3``_axi_arready  , ``bus_name2``_axi_arready  , ``bus_name1``_axi_arready , ``bus_name0``_axi_arready }; \
    assign ``array_name``_axi_rid     = {``bus_name11``_axi_rid     , ``bus_name10``_axi_rid     , ``bus_name9``_axi_rid     , ``bus_name8``_axi_rid     , \
                                         ``bus_name7``_axi_rid      , ``bus_name6``_axi_rid      , ``bus_name5``_axi_rid     , ``bus_name4``_axi_rid     , \
                                         ``bus_name3``_axi_rid      , ``bus_name2``_axi_rid      , ``bus_name1``_axi_rid     , ``bus_name0``_axi_rid     }; \
    assign ``array_name``_axi_rdata   = {``bus_name11``_axi_rdata   , ``bus_name10``_axi_rdata   , ``bus_name9``_axi_rdata   , ``bus_name8``_axi_rdata   , \
                                         ``bus_name7``_axi_rdata    , ``bus_name6``_axi_rdata    , ``bus_name5``_axi_rdata   , ``bus_name4``_axi_rdata   , \
                                         ``bus_name3``_axi_rdata    , ``bus_name2``_axi_rdata    , ``bus_name1``_axi_rdata   , ``bus_name0``_axi_rdata   }; \
    assign ``array_name``_axi_rresp   = {``bus_name11``_axi_rresp   , ``bus_name10``_axi_rresp   , ``bus_name9``_axi_rresp   , ``bus_name8``_axi_rresp   , \
                                         ``bus_name7``_axi_rresp    , ``bus_name6``_axi_rresp    , ``bus_name5``_axi_rresp   , ``bus_name4``_axi_rresp   , \
                                         ``bus_name3``_axi_rresp    , ``bus_name2``_axi_rresp    , ``bus_name1``_axi_rresp   , ``bus_name0``_axi_rresp   }; \
    assign ``array_name``_axi_rlast   = {``bus_name11``_axi_rlast   , ``bus_name10``_axi_rlast   , ``bus_name9``_axi_rlast   , ``bus_name8``_axi_rlast   , \
                                         ``bus_name7``_axi_rlast    , ``bus_name6``_axi_rlast    , ``bus_name5``_axi_rlast   , ``bus_name4``_axi_rlast   , \
                                         ``bus_name3``_axi_rlast    , ``bus_name2``_axi_rlast    , ``bus_name1``_axi_rlast   , ``bus_name0``_axi_rlast   }; \
    assign ``array_name``_axi_rvalid  = {``bus_name11``_axi_rvalid  , ``bus_name10``_axi_rvalid  , ``bus_name9``_axi_rvalid  , ``bus_name8``_axi_rvalid  , \
                                         ``bus_name7``_axi_rvalid   , ``bus_name6``_axi_rvalid   , ``bus_name5``_axi_rvalid  , ``bus_name4``_axi_rvalid  , \
                                         ``bus_name3``_axi_rvalid   , ``bus_name2``_axi_rvalid   , ``bus_name1``_axi_rvalid  , ``bus_name0``_axi_rvalid  };

// Concatenate 12 master buses
`define CONCAT_AXI_MASTERS_ARRAY12(array_name, bus_name11, bus_name10, bus_name9, bus_name8, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
    assign ``array_name``_axi_awid     = {``bus_name11``_axi_awid      , ``bus_name10``_axi_awid      , ``bus_name9``_axi_awid      , ``bus_name8``_axi_awid      , ``bus_name7``_axi_awid      , ``bus_name6``_axi_awid      , ``bus_name5``_axi_awid      , ``bus_name4``_axi_awid      , ``bus_name3``_axi_awid      , ``bus_name2``_axi_awid      , ``bus_name1``_axi_awid      , ``bus_name0``_axi_awid     }; \
    assign ``array_name``_axi_awaddr   = {``bus_name11``_axi_awaddr    , ``bus_name10``_axi_awaddr    , ``bus_name9``_axi_awaddr    , ``bus_name8``_axi_awaddr    , ``bus_name7``_axi_awaddr    , ``bus_name6``_axi_awaddr    , ``bus_name5``_axi_awaddr    , ``bus_name4``_axi_awaddr    , ``bus_name3``_axi_awaddr    , ``bus_name2``_axi_awaddr    , ``bus_name1``_axi_awaddr    , ``bus_name0``_axi_awaddr   }; \
    assign ``array_name``_axi_awlen    = {``bus_name11``_axi_awlen     , ``bus_name10``_axi_awlen     , ``bus_name9``_axi_awlen     , ``bus_name8``_axi_awlen     , ``bus_name7``_axi_awlen     , ``bus_name6``_axi_awlen     , ``bus_name5``_axi_awlen     , ``bus_name4``_axi_awlen     , ``bus_name3``_axi_awlen     , ``bus_name2``_axi_awlen     , ``bus_name1``_axi_awlen     , ``bus_name0``_axi_awlen    }; \
    assign ``array_name``_axi_awsize   = {``bus_name11``_axi_awsize    , ``bus_name10``_axi_awsize    , ``bus_name9``_axi_awsize    , ``bus_name8``_axi_awsize    , ``bus_name7``_axi_awsize    , ``bus_name6``_axi_awsize    , ``bus_name5``_axi_awsize    , ``bus_name4``_axi_awsize    , ``bus_name3``_axi_awsize    , ``bus_name2``_axi_awsize    , ``bus_name1``_axi_awsize    , ``bus_name0``_axi_awsize   }; \
    assign ``array_name``_axi_awburst  = {``bus_name11``_axi_awburst   , ``bus_name10``_axi_awburst   , ``bus_name9``_axi_awburst   , ``bus_name8``_axi_awburst   , ``bus_name7``_axi_awburst   , ``bus_name6``_axi_awburst   , ``bus_name5``_axi_awburst   , ``bus_name4``_axi_awburst   , ``bus_name3``_axi_awburst   , ``bus_name2``_axi_awburst   , ``bus_name1``_axi_awburst   , ``bus_name0``_axi_awburst  }; \
    assign ``array_name``_axi_awlock   = {``bus_name11``_axi_awlock    , ``bus_name10``_axi_awlock    , ``bus_name9``_axi_awlock    , ``bus_name8``_axi_awlock    , ``bus_name7``_axi_awlock    , ``bus_name6``_axi_awlock    , ``bus_name5``_axi_awlock    , ``bus_name4``_axi_awlock    , ``bus_name3``_axi_awlock    , ``bus_name2``_axi_awlock    , ``bus_name1``_axi_awlock    , ``bus_name0``_axi_awlock   }; \
    assign ``array_name``_axi_awcache  = {``bus_name11``_axi_awcache   , ``bus_name10``_axi_awcache   , ``bus_name9``_axi_awcache   , ``bus_name8``_axi_awcache   , ``bus_name7``_axi_awcache   , ``bus_name6``_axi_awcache   , ``bus_name5``_axi_awcache   , ``bus_name4``_axi_awcache   , ``bus_name3``_axi_awcache   , ``bus_name2``_axi_awcache   , ``bus_name1``_axi_awcache   , ``bus_name0``_axi_awcache  }; \
    assign ``array_name``_axi_awprot   = {``bus_name11``_axi_awprot    , ``bus_name10``_axi_awprot    , ``bus_name9``_axi_awprot    , ``bus_name8``_axi_awprot    , ``bus_name7``_axi_awprot    , ``bus_name6``_axi_awprot    , ``bus_name5``_axi_awprot    , ``bus_name4``_axi_awprot    , ``bus_name3``_axi_awprot    , ``bus_name2``_axi_awprot    , ``bus_name1``_axi_awprot    , ``bus_name0``_axi_awprot   }; \
    assign ``array_name``_axi_awqos    = {``bus_name11``_axi_awqos     , ``bus_name10``_axi_awqos     , ``bus_name9``_axi_awqos     , ``bus_name8``_axi_awqos     , ``bus_name7``_axi_awqos     , ``bus_name6``_axi_awqos     , ``bus_name5``_axi_awqos     , ``bus_name4``_axi_awqos     , ``bus_name3``_axi_awqos     , ``bus_name2``_axi_awqos     , ``bus_name1``_axi_awqos     , ``bus_name0``_axi_awqos    }; \
    assign ``array_name``_axi_awvalid  = {``bus_name11``_axi_awvalid   , ``bus_name10``_axi_awvalid   , ``bus_name9``_axi_awvalid   , ``bus_name8``_axi_awvalid   , ``bus_name7``_axi_awvalid   , ``bus_name6``_axi_awvalid   , ``bus_name5``_axi_awvalid   , ``bus_name4``_axi_awvalid   , ``bus_name3``_axi_awvalid   , ``bus_name2``_axi_awvalid   , ``bus_name1``_axi_awvalid   , ``bus_name0``_axi_awvalid  }; \
    assign ``array_name``_axi_awregion = {``bus_name11``_axi_awregion  , ``bus_name10``_axi_awregion  , ``bus_name9``_axi_awregion  , ``bus_name8``_axi_awregion  , ``bus_name7``_axi_awregion  , ``bus_name6``_axi_awregion  , ``bus_name5``_axi_awregion  , ``bus_name4``_axi_awregion  , ``bus_name3``_axi_awregion  , ``bus_name2``_axi_awregion  , ``bus_name1``_axi_awregion  , ``bus_name0``_axi_awregion }; \
    assign ``array_name``_axi_wdata    = {``bus_name11``_axi_wdata     , ``bus_name10``_axi_wdata     , ``bus_name9``_axi_wdata     , ``bus_name8``_axi_wdata     , ``bus_name7``_axi_wdata     , ``bus_name6``_axi_wdata     , ``bus_name5``_axi_wdata     , ``bus_name4``_axi_wdata     , ``bus_name3``_axi_wdata     , ``bus_name2``_axi_wdata     , ``bus_name1``_axi_wdata     , ``bus_name0``_axi_wdata    }; \
    assign ``array_name``_axi_wstrb    = {``bus_name11``_axi_wstrb     , ``bus_name10``_axi_wstrb     , ``bus_name9``_axi_wstrb     , ``bus_name8``_axi_wstrb     , ``bus_name7``_axi_wstrb     , ``bus_name6``_axi_wstrb     , ``bus_name5``_axi_wstrb     , ``bus_name4``_axi_wstrb     , ``bus_name3``_axi_wstrb     , ``bus_name2``_axi_wstrb     , ``bus_name1``_axi_wstrb     , ``bus_name0``_axi_wstrb    }; \
    assign ``array_name``_axi_wlast    = {``bus_name11``_axi_wlast     , ``bus_name10``_axi_wlast     , ``bus_name9``_axi_wlast     , ``bus_name8``_axi_wlast     , ``bus_name7``_axi_wlast     , ``bus_name6``_axi_wlast     , ``bus_name5``_axi_wlast     , ``bus_name4``_axi_wlast     , ``bus_name3``_axi_wlast     , ``bus_name2``_axi_wlast     , ``bus_name1``_axi_wlast     , ``bus_name0``_axi_wlast    }; \
    assign ``array_name``_axi_wvalid   = {``bus_name11``_axi_wvalid    , ``bus_name10``_axi_wvalid    , ``bus_name9``_axi_wvalid    , ``bus_name8``_axi_wvalid    , ``bus_name7``_axi_wvalid    , ``bus_name6``_axi_wvalid    , ``bus_name5``_axi_wvalid    , ``bus_name4``_axi_wvalid    , ``bus_name3``_axi_wvalid    , ``bus_name2``_axi_wvalid    , ``bus_name1``_axi_wvalid    , ``bus_name0``_axi_wvalid   }; \
    assign ``array_name``_axi_bready   = {``bus_name11``_axi_bready    , ``bus_name10``_axi_bready    , ``bus_name9``_axi_bready    , ``bus_name8``_axi_bready    , ``bus_name7``_axi_bready    , ``bus_name6``_axi_bready    , ``bus_name5``_axi_bready    , ``bus_name4``_axi_bready    , ``bus_name3``_axi_bready    , ``bus_name2``_axi_bready    , ``bus_name1``_axi_bready    , ``bus_name0``_axi_bready   }; \
    assign ``array_name``_axi_araddr   = {``bus_name11``_axi_araddr    , ``bus_name10``_axi_araddr    , ``bus_name9``_axi_araddr    , ``bus_name8``_axi_araddr    , ``bus_name7``_axi_araddr    , ``bus_name6``_axi_araddr    , ``bus_name5``_axi_araddr    , ``bus_name4``_axi_araddr    , ``bus_name3``_axi_araddr    , ``bus_name2``_axi_araddr    , ``bus_name1``_axi_araddr    , ``bus_name0``_axi_araddr   }; \
    assign ``array_name``_axi_arlen    = {``bus_name11``_axi_arlen     , ``bus_name10``_axi_arlen     , ``bus_name9``_axi_arlen     , ``bus_name8``_axi_arlen     , ``bus_name7``_axi_arlen     , ``bus_name6``_axi_arlen     , ``bus_name5``_axi_arlen     , ``bus_name4``_axi_arlen     , ``bus_name3``_axi_arlen     , ``bus_name2``_axi_arlen     , ``bus_name1``_axi_arlen     , ``bus_name0``_axi_arlen    }; \
    assign ``array_name``_axi_arsize   = {``bus_name11``_axi_arsize    , ``bus_name10``_axi_arsize    , ``bus_name9``_axi_arsize    , ``bus_name8``_axi_arsize    , ``bus_name7``_axi_arsize    , ``bus_name6``_axi_arsize    , ``bus_name5``_axi_arsize    , ``bus_name4``_axi_arsize    , ``bus_name3``_axi_arsize    , ``bus_name2``_axi_arsize    , ``bus_name1``_axi_arsize    , ``bus_name0``_axi_arsize   }; \
    assign ``array_name``_axi_arburst  = {``bus_name11``_axi_arburst   , ``bus_name10``_axi_arburst   , ``bus_name9``_axi_arburst   , ``bus_name8``_axi_arburst   , ``bus_name7``_axi_arburst   , ``bus_name6``_axi_arburst   , ``bus_name5``_axi_arburst   , ``bus_name4``_axi_arburst   , ``bus_name3``_axi_arburst   , ``bus_name2``_axi_arburst   , ``bus_name1``_axi_arburst   , ``bus_name0``_axi_arburst  }; \
    assign ``array_name``_axi_arlock   = {``bus_name11``_axi_arlock    , ``bus_name10``_axi_arlock    , ``bus_name9``_axi_arlock    , ``bus_name8``_axi_arlock    , ``bus_name7``_axi_arlock    , ``bus_name6``_axi_arlock    , ``bus_name5``_axi_arlock    , ``bus_name4``_axi_arlock    , ``bus_name3``_axi_arlock    , ``bus_name2``_axi_arlock    , ``bus_name1``_axi_arlock    , ``bus_name0``_axi_arlock   }; \
    assign ``array_name``_axi_arcache  = {``bus_name11``_axi_arcache   , ``bus_name10``_axi_arcache   , ``bus_name9``_axi_arcache   , ``bus_name8``_axi_arcache   , ``bus_name7``_axi_arcache   , ``bus_name6``_axi_arcache   , ``bus_name5``_axi_arcache   , ``bus_name4``_axi_arcache   , ``bus_name3``_axi_arcache   , ``bus_name2``_axi_arcache   , ``bus_name1``_axi_arcache   , ``bus_name0``_axi_arcache  }; \
    assign ``array_name``_axi_arprot   = {``bus_name11``_axi_arprot    , ``bus_name10``_axi_arprot    , ``bus_name9``_axi_arprot    , ``bus_name8``_axi_arprot    , ``bus_name7``_axi_arprot    , ``bus_name6``_axi_arprot    , ``bus_name5``_axi_arprot    , ``bus_name4``_axi_arprot    , ``bus_name3``_axi_arprot    , ``bus_name2``_axi_arprot    , ``bus_name1``_axi_arprot    , ``bus_name0``_axi_arprot   }; \
    assign ``array_name``_axi_arqos    = {``bus_name11``_axi_arqos     , ``bus_name10``_axi_arqos     , ``bus_name9``_axi_arqos     , ``bus_name8``_axi_arqos     , ``bus_name7``_axi_arqos     , ``bus_name6``_axi_arqos     , ``bus_name5``_axi_arqos     , ``bus_name4``_axi_arqos     , ``bus_name3``_axi_arqos     , ``bus_name2``_axi_arqos     , ``bus_name1``_axi_arqos     , ``bus_name0``_axi_arqos    }; \
    assign ``array_name``_axi_arvalid  = {``bus_name11``_axi_arvalid   , ``bus_name10``_axi_arvalid   , ``bus_name9``_axi_arvalid   , ``bus_name8``_axi_arvalid   , ``bus_name7``_axi_arvalid   , ``bus_name6``_axi_arvalid   , ``bus_name5``_axi_arvalid   , ``bus_name4``_axi_arvalid   , ``bus_name3``_axi_arvalid   , ``bus_name2``_axi_arvalid   , ``bus_name1``_axi_arvalid   , ``bus_name0``_axi_arvalid  }; \
    assign ``array_name``_axi_arid     = {``bus_name11``_axi_arid      , ``bus_name10``_axi_arid      , ``bus_name9``_axi_arid      , ``bus_name8``_axi_arid      , ``bus_name7``_axi_arid      , ``bus_name6``_axi_arid      , ``bus_name5``_axi_arid      , ``bus_name4``_axi_arid      , ``bus_name3``_axi_arid      , ``bus_name2``_axi_arid      , ``bus_name1``_axi_arid      , ``bus_name0``_axi_arid     }; \
    assign ``array_name``_axi_arregion = {``bus_name11``_axi_arregion  , ``bus_name10``_axi_arregion  , ``bus_name9``_axi_arregion  , ``bus_name8``_axi_arregion  , ``bus_name7``_axi_arregion  , ``bus_name6``_axi_arregion  , ``bus_name5``_axi_arregion  , ``bus_name4``_axi_arregion  , ``bus_name3``_axi_arregion  , ``bus_name2``_axi_arregion  , ``bus_name1``_axi_arregion  , ``bus_name0``_axi_arregion }; \
    assign ``array_name``_axi_rready   = {``bus_name11``_axi_rready    , ``bus_name10``_axi_rready    , ``bus_name9``_axi_rready    , ``bus_name8``_axi_rready    , ``bus_name7``_axi_rready    , ``bus_name6``_axi_rready    , ``bus_name5``_axi_rready    , ``bus_name4``_axi_rready    , ``bus_name3``_axi_rready    , ``bus_name2``_axi_rready    , ``bus_name1``_axi_rready    , ``bus_name0``_axi_rready   }; \
    assign {``bus_name11``_axi_awready    , ``bus_name10``_axi_awready    , ``bus_name9``_axi_awready    , ``bus_name8``_axi_awready    , ``bus_name7``_axi_awready    , ``bus_name6``_axi_awready   , ``bus_name5``_axi_awready   , ``bus_name4``_axi_awready   , ``bus_name3``_axi_awready   , ``bus_name2``_axi_awready   , ``bus_name1``_axi_awready   , ``bus_name0``_axi_awready  } = ``array_name``_axi_awready ; \
    assign {``bus_name11``_axi_wready     , ``bus_name10``_axi_wready     , ``bus_name9``_axi_wready     , ``bus_name8``_axi_wready     , ``bus_name7``_axi_wready     , ``bus_name6``_axi_wready    , ``bus_name5``_axi_wready    , ``bus_name4``_axi_wready    , ``bus_name3``_axi_wready    , ``bus_name2``_axi_wready    , ``bus_name1``_axi_wready    , ``bus_name0``_axi_wready   } = ``array_name``_axi_wready  ; \
    assign {``bus_name11``_axi_bid        , ``bus_name10``_axi_bid        , ``bus_name9``_axi_bid        , ``bus_name8``_axi_bid        , ``bus_name7``_axi_bid        , ``bus_name6``_axi_bid       , ``bus_name5``_axi_bid       , ``bus_name4``_axi_bid       , ``bus_name3``_axi_bid       , ``bus_name2``_axi_bid       , ``bus_name1``_axi_bid       , ``bus_name0``_axi_bid      } = ``array_name``_axi_bid     ; \
    assign {``bus_name11``_axi_bresp      , ``bus_name10``_axi_bresp      , ``bus_name9``_axi_bresp      , ``bus_name8``_axi_bresp      , ``bus_name7``_axi_bresp      , ``bus_name6``_axi_bresp     , ``bus_name5``_axi_bresp     , ``bus_name4``_axi_bresp     , ``bus_name3``_axi_bresp     , ``bus_name2``_axi_bresp     , ``bus_name1``_axi_bresp     , ``bus_name0``_axi_bresp    } = ``array_name``_axi_bresp   ; \
    assign {``bus_name11``_axi_bvalid     , ``bus_name10``_axi_bvalid     , ``bus_name9``_axi_bvalid     , ``bus_name8``_axi_bvalid     , ``bus_name7``_axi_bvalid     , ``bus_name6``_axi_bvalid    , ``bus_name5``_axi_bvalid    , ``bus_name4``_axi_bvalid    , ``bus_name3``_axi_bvalid    , ``bus_name2``_axi_bvalid    , ``bus_name1``_axi_bvalid    , ``bus_name0``_axi_bvalid   } = ``array_name``_axi_bvalid  ; \
    assign {``bus_name11``_axi_arready    , ``bus_name10``_axi_arready    , ``bus_name9``_axi_arready    , ``bus_name8``_axi_arready    , ``bus_name7``_axi_arready    , ``bus_name6``_axi_arready   , ``bus_name5``_axi_arready   , ``bus_name4``_axi_arready   , ``bus_name3``_axi_arready   , ``bus_name2``_axi_arready   , ``bus_name1``_axi_arready   , ``bus_name0``_axi_arready  } = ``array_name``_axi_arready ; \
    assign {``bus_name11``_axi_rid        , ``bus_name10``_axi_rid        , ``bus_name9``_axi_rid        , ``bus_name8``_axi_rid        , ``bus_name7``_axi_rid        , ``bus_name6``_axi_rid       , ``bus_name5``_axi_rid       , ``bus_name4``_axi_rid       , ``bus_name3``_axi_rid       , ``bus_name2``_axi_rid       , ``bus_name1``_axi_rid       , ``bus_name0``_axi_rid      } = ``array_name``_axi_rid     ; \
    assign {``bus_name11``_axi_rdata      , ``bus_name10``_axi_rdata      , ``bus_name9``_axi_rdata      , ``bus_name8``_axi_rdata      , ``bus_name7``_axi_rdata      , ``bus_name6``_axi_rdata     , ``bus_name5``_axi_rdata     , ``bus_name4``_axi_rdata     , ``bus_name3``_axi_rdata     , ``bus_name2``_axi_rdata     , ``bus_name1``_axi_rdata     , ``bus_name0``_axi_rdata    } = ``array_name``_axi_rdata   ; \
    assign {``bus_name11``_axi_rresp      , ``bus_name10``_axi_rresp      , ``bus_name9``_axi_rresp      , ``bus_name8``_axi_rresp      , ``bus_name7``_axi_rresp      , ``bus_name6``_axi_rresp     , ``bus_name5``_axi_rresp     , ``bus_name4``_axi_rresp     , ``bus_name3``_axi_rresp     , ``bus_name2``_axi_rresp     , ``bus_name1``_axi_rresp     , ``bus_name0``_axi_rresp    } = ``array_name``_axi_rresp   ; \
    assign {``bus_name11``_axi_rlast      , ``bus_name10``_axi_rlast      , ``bus_name9``_axi_rlast      , ``bus_name8``_axi_rlast      , ``bus_name7``_axi_rlast      , ``bus_name6``_axi_rlast     , ``bus_name5``_axi_rlast     , ``bus_name4``_axi_rlast     , ``bus_name3``_axi_rlast     , ``bus_name2``_axi_rlast     , ``bus_name1``_axi_rlast     , ``bus_name0``_axi_rlast    } = ``array_name``_axi_rlast   ; \
    assign {``bus_name11``_axi_rvalid     , ``bus_name10``_axi_rvalid     , ``bus_name9``_axi_rvalid     , ``bus_name8``_axi_rvalid     , ``bus_name7``_axi_rvalid     , ``bus_name6``_axi_rvalid    , ``bus_name5``_axi_rvalid    , ``bus_name4``_axi_rvalid    , ``bus_name3``_axi_rvalid    , ``bus_name2``_axi_rvalid    , ``bus_name1``_axi_rvalid    , ``bus_name0``_axi_rvalid   } = ``array_name``_axi_rvalid  ;

// `define CONCAT_AXI_MASTERS_ARRAY14(array_name, bus_name13, bus_name12, bus_name11, bus_name10, bus_name9, bus_name8, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
//         assign ``array_name``_axi_awid     = {``bus_name13``_axi_awid      , ``bus_name12``_axi_awid      , ``bus_name11``_axi_awid      , ``bus_name10``_axi_awid      , ``bus_name9``_axi_awid      , ``bus_name8``_axi_awid      , ``bus_name7``_axi_awid      , ``bus_name6``_axi_awid      , ``bus_name5``_axi_awid      , ``bus_name4``_axi_awid      , ``bus_name3``_axi_awid      , ``bus_name2``_axi_awid      , ``bus_name1``_axi_awid      , ``bus_name0``_axi_awid     }; \
//         assign ``array_name``_axi_awaddr   = {``bus_name13``_axi_awaddr    , ``bus_name12``_axi_awaddr    , ``bus_name11``_axi_awaddr    , ``bus_name10``_axi_awaddr    , ``bus_name9``_axi_awaddr    , ``bus_name8``_axi_awaddr    , ``bus_name7``_axi_awaddr    , ``bus_name6``_axi_awaddr    , ``bus_name5``_axi_awaddr    , ``bus_name4``_axi_awaddr    , ``bus_name3``_axi_awaddr    , ``bus_name2``_axi_awaddr    , ``bus_name1``_axi_awaddr    , ``bus_name0``_axi_awaddr   }; \
//         assign ``array_name``_axi_awlen    = {``bus_name13``_axi_awlen     , ``bus_name12``_axi_awlen     , ``bus_name11``_axi_awlen     , ``bus_name10``_axi_awlen     , ``bus_name9``_axi_awlen     , ``bus_name8``_axi_awlen     , ``bus_name7``_axi_awlen     , ``bus_name6``_axi_awlen     , ``bus_name5``_axi_awlen     , ``bus_name4``_axi_awlen     , ``bus_name3``_axi_awlen     , ``bus_name2``_axi_awlen     , ``bus_name1``_axi_awlen     , ``bus_name0``_axi_awlen    }; \
//         assign ``array_name``_axi_awsize   = {``bus_name13``_axi_awsize    , ``bus_name12``_axi_awsize    , ``bus_name11``_axi_awsize    , ``bus_name10``_axi_awsize    , ``bus_name9``_axi_awsize    , ``bus_name8``_axi_awsize    , ``bus_name7``_axi_awsize    , ``bus_name6``_axi_awsize    , ``bus_name5``_axi_awsize    , ``bus_name4``_axi_awsize    , ``bus_name3``_axi_awsize    , ``bus_name2``_axi_awsize    , ``bus_name1``_axi_awsize    , ``bus_name0``_axi_awsize   }; \
//         assign ``array_name``_axi_awburst  = {``bus_name13``_axi_awburst   , ``bus_name12``_axi_awburst   , ``bus_name11``_axi_awburst   , ``bus_name10``_axi_awburst   , ``bus_name9``_axi_awburst   , ``bus_name8``_axi_awburst   , ``bus_name7``_axi_awburst   , ``bus_name6``_axi_awburst   , ``bus_name5``_axi_awburst   , ``bus_name4``_axi_awburst   , ``bus_name3``_axi_awburst   , ``bus_name2``_axi_awburst   , ``bus_name1``_axi_awburst   , ``bus_name0``_axi_awburst  }; \
//         assign ``array_name``_axi_awlock   = {``bus_name13``_axi_awlock    , ``bus_name12``_axi_awlock    , ``bus_name11``_axi_awlock    , ``bus_name10``_axi_awlock    , ``bus_name9``_axi_awlock    , ``bus_name8``_axi_awlock    , ``bus_name7``_axi_awlock    , ``bus_name6``_axi_awlock    , ``bus_name5``_axi_awlock    , ``bus_name4``_axi_awlock    , ``bus_name3``_axi_awlock    , ``bus_name2``_axi_awlock    , ``bus_name1``_axi_awlock    , ``bus_name0``_axi_awlock   }; \
//         assign ``array_name``_axi_awcache  = {``bus_name13``_axi_awcache   , ``bus_name12``_axi_awcache   , ``bus_name11``_axi_awcache   , ``bus_name10``_axi_awcache   , ``bus_name9``_axi_awcache   , ``bus_name8``_axi_awcache   , ``bus_name7``_axi_awcache   , ``bus_name6``_axi_awcache   , ``bus_name5``_axi_awcache   , ``bus_name4``_axi_awcache   , ``bus_name3``_axi_awcache   , ``bus_name2``_axi_awcache   , ``bus_name1``_axi_awcache   , ``bus_name0``_axi_awcache  }; \
//         assign ``array_name``_axi_awprot   = {``bus_name13``_axi_awprot    , ``bus_name12``_axi_awprot    , ``bus_name11``_axi_awprot    , ``bus_name10``_axi_awprot    , ``bus_name9``_axi_awprot    , ``bus_name8``_axi_awprot    , ``bus_name7``_axi_awprot    , ``bus_name6``_axi_awprot    , ``bus_name5``_axi_awprot    , ``bus_name4``_axi_awprot    , ``bus_name3``_axi_awprot    , ``bus_name2``_axi_awprot    , ``bus_name1``_axi_awprot    , ``bus_name0``_axi_awprot   }; \
//         assign ``array_name``_axi_awqos    = {``bus_name13``_axi_awqos     , ``bus_name12``_axi_awqos     , ``bus_name11``_axi_awqos     , ``bus_name10``_axi_awqos     , ``bus_name9``_axi_awqos     , ``bus_name8``_axi_awqos     , ``bus_name7``_axi_awqos     , ``bus_name6``_axi_awqos     , ``bus_name5``_axi_awqos     , ``bus_name4``_axi_awqos     , ``bus_name3``_axi_awqos     , ``bus_name2``_axi_awqos     , ``bus_name1``_axi_awqos     , ``bus_name0``_axi_awqos    }; \
//         assign ``array_name``_axi_awvalid  = {``bus_name13``_axi_awvalid   , ``bus_name12``_axi_awvalid   , ``bus_name11``_axi_awvalid   , ``bus_name10``_axi_awvalid   , ``bus_name9``_axi_awvalid   , ``bus_name8``_axi_awvalid   , ``bus_name7``_axi_awvalid   , ``bus_name6``_axi_awvalid   , ``bus_name5``_axi_awvalid   , ``bus_name4``_axi_awvalid   , ``bus_name3``_axi_awvalid   , ``bus_name2``_axi_awvalid   , ``bus_name1``_axi_awvalid   , ``bus_name0``_axi_awvalid  }; \
//         assign ``array_name``_axi_awregion = {``bus_name13``_axi_awregion  , ``bus_name12``_axi_awregion  , ``bus_name11``_axi_awregion  , ``bus_name10``_axi_awregion  , ``bus_name9``_axi_awregion  , ``bus_name8``_axi_awregion  , ``bus_name7``_axi_awregion  , ``bus_name6``_axi_awregion  , ``bus_name5``_axi_awregion  , ``bus_name4``_axi_awregion  , ``bus_name3``_axi_awregion  , ``bus_name2``_axi_awregion  , ``bus_name1``_axi_awregion  , ``bus_name0``_axi_awregion }; \
//         assign ``array_name``_axi_wdata    = {``bus_name13``_axi_wdata     , ``bus_name12``_axi_wdata     , ``bus_name11``_axi_wdata     , ``bus_name10``_axi_wdata     , ``bus_name9``_axi_wdata     , ``bus_name8``_axi_wdata     , ``bus_name7``_axi_wdata     , ``bus_name6``_axi_wdata     , ``bus_name5``_axi_wdata     , ``bus_name4``_axi_wdata     , ``bus_name3``_axi_wdata     , ``bus_name2``_axi_wdata     , ``bus_name1``_axi_wdata     , ``bus_name0``_axi_wdata    }; \
//         assign ``array_name``_axi_wstrb    = {``bus_name13``_axi_wstrb     , ``bus_name12``_axi_wstrb     , ``bus_name11``_axi_wstrb     , ``bus_name10``_axi_wstrb     , ``bus_name9``_axi_wstrb     , ``bus_name8``_axi_wstrb     , ``bus_name7``_axi_wstrb     , ``bus_name6``_axi_wstrb     , ``bus_name5``_axi_wstrb     , ``bus_name4``_axi_wstrb     , ``bus_name3``_axi_wstrb     , ``bus_name2``_axi_wstrb     , ``bus_name1``_axi_wstrb     , ``bus_name0``_axi_wstrb    }; \
//         assign ``array_name``_axi_wlast    = {``bus_name13``_axi_wlast     , ``bus_name12``_axi_wlast     , ``bus_name11``_axi_wlast     , ``bus_name10``_axi_wlast     , ``bus_name9``_axi_wlast     , ``bus_name8``_axi_wlast     , ``bus_name7``_axi_wlast     , ``bus_name6``_axi_wlast     , ``bus_name5``_axi_wlast     , ``bus_name4``_axi_wlast     , ``bus_name3``_axi_wlast     , ``bus_name2``_axi_wlast     , ``bus_name1``_axi_wlast     , ``bus_name0``_axi_wlast    }; \
//         assign ``array_name``_axi_wvalid   = {``bus_name13``_axi_wvalid    , ``bus_name12``_axi_wvalid    , ``bus_name11``_axi_wvalid    , ``bus_name10``_axi_wvalid    , ``bus_name9``_axi_wvalid    , ``bus_name8``_axi_wvalid    , ``bus_name7``_axi_wvalid    , ``bus_name6``_axi_wvalid    , ``bus_name5``_axi_wvalid    , ``bus_name4``_axi_wvalid    , ``bus_name3``_axi_wvalid    , ``bus_name2``_axi_wvalid    , ``bus_name1``_axi_wvalid    , ``bus_name0``_axi_wvalid   }; \
//         assign ``array_name``_axi_bready   = {``bus_name13``_axi_bready    , ``bus_name12``_axi_bready    , ``bus_name11``_axi_bready    , ``bus_name10``_axi_bready    , ``bus_name9``_axi_bready    , ``bus_name8``_axi_bready    , ``bus_name7``_axi_bready    , ``bus_name6``_axi_bready    , ``bus_name5``_axi_bready    , ``bus_name4``_axi_bready    , ``bus_name3``_axi_bready    , ``bus_name2``_axi_bready    , ``bus_name1``_axi_bready    , ``bus_name0``_axi_bready   }; \
//         assign ``array_name``_axi_araddr   = {``bus_name13``_axi_araddr    , ``bus_name12``_axi_araddr    , ``bus_name11``_axi_araddr    , ``bus_name10``_axi_araddr    , ``bus_name9``_axi_araddr    , ``bus_name8``_axi_araddr    , ``bus_name7``_axi_araddr    , ``bus_name6``_axi_araddr    , ``bus_name5``_axi_araddr    , ``bus_name4``_axi_araddr    , ``bus_name3``_axi_araddr    , ``bus_name2``_axi_araddr    , ``bus_name1``_axi_araddr    , ``bus_name0``_axi_araddr   }; \
//         assign ``array_name``_axi_arlen    = {``bus_name13``_axi_arlen     , ``bus_name12``_axi_arlen     , ``bus_name11``_axi_arlen     , ``bus_name10``_axi_arlen     , ``bus_name9``_axi_arlen     , ``bus_name8``_axi_arlen     , ``bus_name7``_axi_arlen     , ``bus_name6``_axi_arlen     , ``bus_name5``_axi_arlen     , ``bus_name4``_axi_arlen     , ``bus_name3``_axi_arlen     , ``bus_name2``_axi_arlen     , ``bus_name1``_axi_arlen     , ``bus_name0``_axi_arlen    }; \
//         assign ``array_name``_axi_arsize   = {``bus_name13``_axi_arsize    , ``bus_name12``_axi_arsize    , ``bus_name11``_axi_arsize    , ``bus_name10``_axi_arsize    , ``bus_name9``_axi_arsize    , ``bus_name8``_axi_arsize    , ``bus_name7``_axi_arsize    , ``bus_name6``_axi_arsize    , ``bus_name5``_axi_arsize    , ``bus_name4``_axi_arsize    , ``bus_name3``_axi_arsize    , ``bus_name2``_axi_arsize    , ``bus_name1``_axi_arsize    , ``bus_name0``_axi_arsize   }; \
//         assign ``array_name``_axi_arburst  = {``bus_name13``_axi_arburst   , ``bus_name12``_axi_arburst   , ``bus_name11``_axi_arburst   , ``bus_name10``_axi_arburst   , ``bus_name9``_axi_arburst   , ``bus_name8``_axi_arburst   , ``bus_name7``_axi_arburst   , ``bus_name6``_axi_arburst   , ``bus_name5``_axi_arburst   , ``bus_name4``_axi_arburst   , ``bus_name3``_axi_arburst   , ``bus_name2``_axi_arburst   , ``bus_name1``_axi_arburst   , ``bus_name0``_axi_arburst  }; \
//         assign ``array_name``_axi_arlock   = {``bus_name13``_axi_arlock    , ``bus_name12``_axi_arlock    , ``bus_name11``_axi_arlock    , ``bus_name10``_axi_arlock    , ``bus_name9``_axi_arlock    , ``bus_name8``_axi_arlock    , ``bus_name7``_axi_arlock    , ``bus_name6``_axi_arlock    , ``bus_name5``_axi_arlock    , ``bus_name4``_axi_arlock    , ``bus_name3``_axi_arlock    , ``bus_name2``_axi_arlock    , ``bus_name1``_axi_arlock    , ``bus_name0``_axi_arlock   }; \
//         assign ``array_name``_axi_arcache  = {``bus_name13``_axi_arcache   , ``bus_name12``_axi_arcache   , ``bus_name11``_axi_arcache   , ``bus_name10``_axi_arcache   , ``bus_name9``_axi_arcache   , ``bus_name8``_axi_arcache   , ``bus_name7``_axi_arcache   , ``bus_name6``_axi_arcache   , ``bus_name5``_axi_arcache   , ``bus_name4``_axi_arcache   , ``bus_name3``_axi_arcache   , ``bus_name2``_axi_arcache   , ``bus_name1``_axi_arcache   , ``bus_name0``_axi_arcache  }; \
//         assign ``array_name``_axi_arprot   = {``bus_name13``_axi_arprot    , ``bus_name12``_axi_arprot    , ``bus_name11``_axi_arprot    , ``bus_name10``_axi_arprot    , ``bus_name9``_axi_arprot    , ``bus_name8``_axi_arprot    , ``bus_name7``_axi_arprot    , ``bus_name6``_axi_arprot    , ``bus_name5``_axi_arprot    , ``bus_name4``_axi_arprot    , ``bus_name3``_axi_arprot    , ``bus_name2``_axi_arprot    , ``bus_name1``_axi_arprot    , ``bus_name0``_axi_arprot   }; \
//         assign ``array_name``_axi_arqos    = {``bus_name13``_axi_arqos     , ``bus_name12``_axi_arqos     , ``bus_name11``_axi_arqos     , ``bus_name10``_axi_arqos     , ``bus_name9``_axi_arqos     , ``bus_name8``_axi_arqos     , ``bus_name7``_axi_arqos     , ``bus_name6``_axi_arqos     , ``bus_name5``_axi_arqos     , ``bus_name4``_axi_arqos     , ``bus_name3``_axi_arqos     , ``bus_name2``_axi_arqos     , ``bus_name1``_axi_arqos     , ``bus_name0``_axi_arqos    }; \
//         assign ``array_name``_axi_arvalid  = {``bus_name13``_axi_arvalid   , ``bus_name12``_axi_arvalid   , ``bus_name11``_axi_arvalid   , ``bus_name10``_axi_arvalid   , ``bus_name9``_axi_arvalid   , ``bus_name8``_axi_arvalid   , ``bus_name7``_axi_arvalid   , ``bus_name6``_axi_arvalid   , ``bus_name5``_axi_arvalid   , ``bus_name4``_axi_arvalid   , ``bus_name3``_axi_arvalid   , ``bus_name2``_axi_arvalid   , ``bus_name1``_axi_arvalid   , ``bus_name0``_axi_arvalid  }; \
//         assign ``array_name``_axi_arid     = {``bus_name13``_axi_arid      , ``bus_name12``_axi_arid      , ``bus_name11``_axi_arid      , ``bus_name10``_axi_arid      , ``bus_name9``_axi_arid      , ``bus_name8``_axi_arid      , ``bus_name7``_axi_arid      , ``bus_name6``_axi_arid      , ``bus_name5``_axi_arid      , ``bus_name4``_axi_arid      , ``bus_name3``_axi_arid      , ``bus_name2``_axi_arid      , ``bus_name1``_axi_arid      , ``bus_name0``_axi_arid     }; \
//         assign ``array_name``_axi_arregion = {``bus_name13``_axi_arregion  , ``bus_name12``_axi_arregion  , ``bus_name11``_axi_arregion  , ``bus_name10``_axi_arregion  , ``bus_name9``_axi_arregion  , ``bus_name8``_axi_arregion  , ``bus_name7``_axi_arregion  , ``bus_name6``_axi_arregion  , ``bus_name5``_axi_arregion  , ``bus_name4``_axi_arregion  , ``bus_name3``_axi_arregion  , ``bus_name2``_axi_arregion  , ``bus_name1``_axi_arregion  , ``bus_name0``_axi_arregion }; \
//         assign ``array_name``_axi_rready   = {``bus_name13``_axi_rready    , ``bus_name12``_axi_rready    , ``bus_name11``_axi_rready    , ``bus_name10``_axi_rready    , ``bus_name9``_axi_rready    , ``bus_name8``_axi_rready    , ``bus_name7``_axi_rready    , ``bus_name6``_axi_rready    , ``bus_name5``_axi_rready    , ``bus_name4``_axi_rready    , ``bus_name3``_axi_rready    , ``bus_name2``_axi_rready    , ``bus_name1``_axi_rready    , ``bus_name0``_axi_rready   }; \
//         assign {``bus_name13``_axi_awready    , ``bus_name12``_axi_awready    , ``bus_name11``_axi_awready    , ``bus_name10``_axi_awready    , ``bus_name9``_axi_awready    , ``bus_name8``_axi_awready   , ``bus_name7``_axi_awready   , ``bus_name6``_axi_awready   , ``bus_name5``_axi_awready   , ``bus_name4``_axi_awready   , ``bus_name3``_axi_awready   , ``bus_name2``_axi_awready   , ``bus_name1``_axi_awready   , ``bus_name0``_axi_awready  } = ``array_name``_axi_awready ; \
//         assign {``bus_name13``_axi_wready     , ``bus_name12``_axi_wready     , ``bus_name11``_axi_wready     , ``bus_name10``_axi_wready     , ``bus_name9``_axi_wready     , ``bus_name8``_axi_wready    , ``bus_name7``_axi_wready    , ``bus_name6``_axi_wready    , ``bus_name5``_axi_wready    , ``bus_name4``_axi_wready    , ``bus_name3``_axi_wready    , ``bus_name2``_axi_wready    , ``bus_name1``_axi_wready    , ``bus_name0``_axi_wready   } = ``array_name``_axi_wready  ; \
//         assign {``bus_name13``_axi_bid        , ``bus_name12``_axi_bid        , ``bus_name11``_axi_bid        , ``bus_name10``_axi_bid        , ``bus_name9``_axi_bid        , ``bus_name8``_axi_bid       , ``bus_name7``_axi_bid       , ``bus_name6``_axi_bid       , ``bus_name5``_axi_bid       , ``bus_name4``_axi_bid       , ``bus_name3``_axi_bid       , ``bus_name2``_axi_bid       , ``bus_name1``_axi_bid       , ``bus_name0``_axi_bid      } = ``array_name``_axi_bid     ; \
//         assign {``bus_name13``_axi_bresp      , ``bus_name12``_axi_bresp      , ``bus_name11``_axi_bresp      , ``bus_name10``_axi_bresp      , ``bus_name9``_axi_bresp      , ``bus_name8``_axi_bresp     , ``bus_name7``_axi_bresp     , ``bus_name6``_axi_bresp     , ``bus_name5``_axi_bresp     , ``bus_name4``_axi_bresp     , ``bus_name3``_axi_bresp     , ``bus_name2``_axi_bresp     , ``bus_name1``_axi_bresp     , ``bus_name0``_axi_bresp    } = ``array_name``_axi_bresp   ; \
//         assign {``bus_name13``_axi_bvalid     , ``bus_name12``_axi_bvalid     , ``bus_name11``_axi_bvalid     , ``bus_name10``_axi_bvalid     , ``bus_name9``_axi_bvalid     , ``bus_name8``_axi_bvalid    , ``bus_name7``_axi_bvalid    , ``bus_name6``_axi_bvalid    , ``bus_name5``_axi_bvalid    , ``bus_name4``_axi_bvalid    , ``bus_name3``_axi_bvalid    , ``bus_name2``_axi_bvalid    , ``bus_name1``_axi_bvalid    , ``bus_name0``_axi_bvalid   } = ``array_name``_axi_bvalid  ; \
//         assign {``bus_name13``_axi_arready    , ``bus_name12``_axi_arready    , ``bus_name11``_axi_arready    , ``bus_name10``_axi_arready    , ``bus_name9``_axi_arready    , ``bus_name8``_axi_arready   , ``bus_name7``_axi_arready   , ``bus_name6``_axi_arready   , ``bus_name5``_axi_arready   , ``bus_name4``_axi_arready   , ``bus_name3``_axi_arready   , ``bus_name2``_axi_arready   , ``bus_name1``_axi_arready   , ``bus_name0``_axi_arready  } = ``array_name``_axi_arready ; \
//         assign {``bus_name13``_axi_rid        , ``bus_name12``_axi_rid        , ``bus_name11``_axi_rid        , ``bus_name10``_axi_rid        , ``bus_name9``_axi_rid        , ``bus_name8``_axi_rid       , ``bus_name7``_axi_rid       , ``bus_name6``_axi_rid       , ``bus_name5``_axi_rid       , ``bus_name4``_axi_rid       , ``bus_name3``_axi_rid       , ``bus_name2``_axi_rid       , ``bus_name1``_axi_rid       , ``bus_name0``_axi_rid      } = ``array_name``_axi_rid     ; \
//         assign {``bus_name13``_axi_rdata      , ``bus_name12``_axi_rdata      , ``bus_name11``_axi_rdata      , ``bus_name10``_axi_rdata      , ``bus_name9``_axi_rdata      , ``bus_name8``_axi_rdata     , ``bus_name7``_axi_rdata     , ``bus_name6``_axi_rdata     , ``bus_name5``_axi_rdata     , ``bus_name4``_axi_rdata     , ``bus_name3``_axi_rdata     , ``bus_name2``_axi_rdata     , ``bus_name1``_axi_rdata     , ``bus_name0``_axi_rdata    } = ``array_name``_axi_rdata   ; \
//         assign {``bus_name13``_axi_rresp      , ``bus_name12``_axi_rresp      , ``bus_name11``_axi_rresp      , ``bus_name10``_axi_rresp      , ``bus_name9``_axi_rresp      , ``bus_name8``_axi_rresp     , ``bus_name7``_axi_rresp     , ``bus_name6``_axi_rresp     , ``bus_name5``_axi_rresp     , ``bus_name4``_axi_rresp     , ``bus_name3``_axi_rresp     , ``bus_name2``_axi_rresp     , ``bus_name1``_axi_rresp     , ``bus_name0``_axi_rresp    } = ``array_name``_axi_rresp   ; \
//         assign {``bus_name13``_axi_rlast      , ``bus_name12``_axi_rlast      , ``bus_name11``_axi_rlast      , ``bus_name10``_axi_rlast      , ``bus_name9``_axi_rlast      , ``bus_name8``_axi_rlast     , ``bus_name7``_axi_rlast     , ``bus_name6``_axi_rlast     , ``bus_name5``_axi_rlast     , ``bus_name4``_axi_rlast     , ``bus_name3``_axi_rlast     , ``bus_name2``_axi_rlast     , ``bus_name1``_axi_rlast     , ``bus_name0``_axi_rlast    } = ``array_name``_axi_rlast   ; \
//         assign {``bus_name13``_axi_rvalid     , ``bus_name12``_axi_rvalid     , ``bus_name11``_axi_rvalid     , ``bus_name10``_axi_rvalid     , ``bus_name9``_axi_rvalid     , ``bus_name8``_axi_rvalid    , ``bus_name7``_axi_rvalid    , ``bus_name6``_axi_rvalid    , ``bus_name5``_axi_rvalid    , ``bus_name4``_axi_rvalid    , ``bus_name3``_axi_rvalid    , ``bus_name2``_axi_rvalid    , ``bus_name1``_axi_rvalid    , ``bus_name0``_axi_rvalid   } = ``array_name``_axi_rvalid  ;

// // Concatenate 14 slave buses
`define CONCAT_AXI_SLAVES_ARRAY14(array_name, bus_name13, bus_name12, bus_name11, bus_name10, bus_name9, bus_name8, bus_name7, bus_name6, bus_name5, bus_name4, bus_name3, bus_name2, bus_name1, bus_name0) \
        assign {``bus_name13``_axi_awid, ``bus_name12``_axi_awid, ``bus_name11``_axi_awid, ``bus_name10``_axi_awid, ``bus_name9``_axi_awid, ``bus_name8``_axi_awid, ``bus_name7``_axi_awid, ``bus_name6``_axi_awid, ``bus_name5``_axi_awid, ``bus_name4``_axi_awid, ``bus_name3``_axi_awid, ``bus_name2``_axi_awid, ``bus_name1``_axi_awid, ``bus_name0``_axi_awid} = ``array_name``_axi_awid; \
        assign {``bus_name13``_axi_awaddr, ``bus_name12``_axi_awaddr, ``bus_name11``_axi_awaddr, ``bus_name10``_axi_awaddr, ``bus_name9``_axi_awaddr, ``bus_name8``_axi_awaddr, ``bus_name7``_axi_awaddr, ``bus_name6``_axi_awaddr, ``bus_name5``_axi_awaddr, ``bus_name4``_axi_awaddr, ``bus_name3``_axi_awaddr, ``bus_name2``_axi_awaddr, ``bus_name1``_axi_awaddr, ``bus_name0``_axi_awaddr} = ``array_name``_axi_awaddr; \
        assign {``bus_name13``_axi_awlen, ``bus_name12``_axi_awlen, ``bus_name11``_axi_awlen, ``bus_name10``_axi_awlen, ``bus_name9``_axi_awlen, ``bus_name8``_axi_awlen, ``bus_name7``_axi_awlen, ``bus_name6``_axi_awlen, ``bus_name5``_axi_awlen, ``bus_name4``_axi_awlen, ``bus_name3``_axi_awlen, ``bus_name2``_axi_awlen, ``bus_name1``_axi_awlen, ``bus_name0``_axi_awlen} = ``array_name``_axi_awlen; \
        assign {``bus_name13``_axi_awsize, ``bus_name12``_axi_awsize, ``bus_name11``_axi_awsize, ``bus_name10``_axi_awsize, ``bus_name9``_axi_awsize, ``bus_name8``_axi_awsize, ``bus_name7``_axi_awsize, ``bus_name6``_axi_awsize, ``bus_name5``_axi_awsize, ``bus_name4``_axi_awsize, ``bus_name3``_axi_awsize, ``bus_name2``_axi_awsize, ``bus_name1``_axi_awsize, ``bus_name0``_axi_awsize} = ``array_name``_axi_awsize; \
        assign {``bus_name13``_axi_awburst, ``bus_name12``_axi_awburst, ``bus_name11``_axi_awburst, ``bus_name10``_axi_awburst, ``bus_name9``_axi_awburst, ``bus_name8``_axi_awburst, ``bus_name7``_axi_awburst, ``bus_name6``_axi_awburst, ``bus_name5``_axi_awburst, ``bus_name4``_axi_awburst, ``bus_name3``_axi_awburst, ``bus_name2``_axi_awburst, ``bus_name1``_axi_awburst, ``bus_name0``_axi_awburst} = ``array_name``_axi_awburst; \
        assign {``bus_name13``_axi_awlock, ``bus_name12``_axi_awlock, ``bus_name11``_axi_awlock, ``bus_name10``_axi_awlock, ``bus_name9``_axi_awlock, ``bus_name8``_axi_awlock, ``bus_name7``_axi_awlock, ``bus_name6``_axi_awlock, ``bus_name5``_axi_awlock, ``bus_name4``_axi_awlock, ``bus_name3``_axi_awlock, ``bus_name2``_axi_awlock, ``bus_name1``_axi_awlock, ``bus_name0``_axi_awlock} = ``array_name``_axi_awlock; \
        assign {``bus_name13``_axi_awcache, ``bus_name12``_axi_awcache, ``bus_name11``_axi_awcache, ``bus_name10``_axi_awcache, ``bus_name9``_axi_awcache, ``bus_name8``_axi_awcache, ``bus_name7``_axi_awcache, ``bus_name6``_axi_awcache, ``bus_name5``_axi_awcache, ``bus_name4``_axi_awcache, ``bus_name3``_axi_awcache, ``bus_name2``_axi_awcache, ``bus_name1``_axi_awcache, ``bus_name0``_axi_awcache} = ``array_name``_axi_awcache; \
        assign {``bus_name13``_axi_awprot, ``bus_name12``_axi_awprot, ``bus_name11``_axi_awprot, ``bus_name10``_axi_awprot, ``bus_name9``_axi_awprot, ``bus_name8``_axi_awprot, ``bus_name7``_axi_awprot, ``bus_name6``_axi_awprot, ``bus_name5``_axi_awprot, ``bus_name4``_axi_awprot, ``bus_name3``_axi_awprot, ``bus_name2``_axi_awprot, ``bus_name1``_axi_awprot, ``bus_name0``_axi_awprot} = ``array_name``_axi_awprot; \
        assign {``bus_name13``_axi_awqos, ``bus_name12``_axi_awqos, ``bus_name11``_axi_awqos, ``bus_name10``_axi_awqos, ``bus_name9``_axi_awqos, ``bus_name8``_axi_awqos, ``bus_name7``_axi_awqos, ``bus_name6``_axi_awqos, ``bus_name5``_axi_awqos, ``bus_name4``_axi_awqos, ``bus_name3``_axi_awqos, ``bus_name2``_axi_awqos, ``bus_name1``_axi_awqos, ``bus_name0``_axi_awqos} = ``array_name``_axi_awqos; \
        assign {``bus_name13``_axi_awvalid, ``bus_name12``_axi_awvalid, ``bus_name11``_axi_awvalid, ``bus_name10``_axi_awvalid, ``bus_name9``_axi_awvalid, ``bus_name8``_axi_awvalid, ``bus_name7``_axi_awvalid, ``bus_name6``_axi_awvalid, ``bus_name5``_axi_awvalid, ``bus_name4``_axi_awvalid, ``bus_name3``_axi_awvalid, ``bus_name2``_axi_awvalid, ``bus_name1``_axi_awvalid, ``bus_name0``_axi_awvalid} = ``array_name``_axi_awvalid; \
        assign {``bus_name13``_axi_awregion, ``bus_name12``_axi_awregion, ``bus_name11``_axi_awregion, ``bus_name10``_axi_awregion, ``bus_name9``_axi_awregion, ``bus_name8``_axi_awregion, ``bus_name7``_axi_awregion, ``bus_name6``_axi_awregion, ``bus_name5``_axi_awregion, ``bus_name4``_axi_awregion, ``bus_name3``_axi_awregion, ``bus_name2``_axi_awregion, ``bus_name1``_axi_awregion, ``bus_name0``_axi_awregion} = ``array_name``_axi_awregion; \
        assign {``bus_name13``_axi_wdata, ``bus_name12``_axi_wdata, ``bus_name11``_axi_wdata, ``bus_name10``_axi_wdata, ``bus_name9``_axi_wdata, ``bus_name8``_axi_wdata, ``bus_name7``_axi_wdata, ``bus_name6``_axi_wdata, ``bus_name5``_axi_wdata, ``bus_name4``_axi_wdata, ``bus_name3``_axi_wdata, ``bus_name2``_axi_wdata, ``bus_name1``_axi_wdata, ``bus_name0``_axi_wdata} = ``array_name``_axi_wdata; \
        assign {``bus_name13``_axi_wstrb, ``bus_name12``_axi_wstrb, ``bus_name11``_axi_wstrb, ``bus_name10``_axi_wstrb, ``bus_name9``_axi_wstrb, ``bus_name8``_axi_wstrb, ``bus_name7``_axi_wstrb, ``bus_name6``_axi_wstrb, ``bus_name5``_axi_wstrb, ``bus_name4``_axi_wstrb, ``bus_name3``_axi_wstrb, ``bus_name2``_axi_wstrb, ``bus_name1``_axi_wstrb, ``bus_name0``_axi_wstrb} = ``array_name``_axi_wstrb; \
        assign {``bus_name13``_axi_wlast, ``bus_name12``_axi_wlast, ``bus_name11``_axi_wlast, ``bus_name10``_axi_wlast, ``bus_name9``_axi_wlast, ``bus_name8``_axi_wlast, ``bus_name7``_axi_wlast, ``bus_name6``_axi_wlast, ``bus_name5``_axi_wlast, ``bus_name4``_axi_wlast, ``bus_name3``_axi_wlast, ``bus_name2``_axi_wlast, ``bus_name1``_axi_wlast, ``bus_name0``_axi_wlast} = ``array_name``_axi_wlast; \
        assign {``bus_name13``_axi_wvalid, ``bus_name12``_axi_wvalid, ``bus_name11``_axi_wvalid, ``bus_name10``_axi_wvalid, ``bus_name9``_axi_wvalid, ``bus_name8``_axi_wvalid, ``bus_name7``_axi_wvalid, ``bus_name6``_axi_wvalid, ``bus_name5``_axi_wvalid, ``bus_name4``_axi_wvalid, ``bus_name3``_axi_wvalid, ``bus_name2``_axi_wvalid, ``bus_name1``_axi_wvalid, ``bus_name0``_axi_wvalid} = ``array_name``_axi_wvalid; \
        assign {``bus_name13``_axi_bready, ``bus_name12``_axi_bready, ``bus_name11``_axi_bready, ``bus_name10``_axi_bready, ``bus_name9``_axi_bready, ``bus_name8``_axi_bready, ``bus_name7``_axi_bready, ``bus_name6``_axi_bready, ``bus_name5``_axi_bready, ``bus_name4``_axi_bready, ``bus_name3``_axi_bready, ``bus_name2``_axi_bready, ``bus_name1``_axi_bready, ``bus_name0``_axi_bready} = ``array_name``_axi_bready; \
        assign {``bus_name13``_axi_araddr, ``bus_name12``_axi_araddr, ``bus_name11``_axi_araddr, ``bus_name10``_axi_araddr, ``bus_name9``_axi_araddr, ``bus_name8``_axi_araddr, ``bus_name7``_axi_araddr, ``bus_name6``_axi_araddr, ``bus_name5``_axi_araddr, ``bus_name4``_axi_araddr, ``bus_name3``_axi_araddr, ``bus_name2``_axi_araddr, ``bus_name1``_axi_araddr, ``bus_name0``_axi_araddr} = ``array_name``_axi_araddr; \
        assign {``bus_name13``_axi_arlen, ``bus_name12``_axi_arlen, ``bus_name11``_axi_arlen, ``bus_name10``_axi_arlen, ``bus_name9``_axi_arlen, ``bus_name8``_axi_arlen, ``bus_name7``_axi_arlen, ``bus_name6``_axi_arlen, ``bus_name5``_axi_arlen, ``bus_name4``_axi_arlen, ``bus_name3``_axi_arlen, ``bus_name2``_axi_arlen, ``bus_name1``_axi_arlen, ``bus_name0``_axi_arlen} = ``array_name``_axi_arlen; \
        assign {``bus_name13``_axi_arsize, ``bus_name12``_axi_arsize, ``bus_name11``_axi_arsize, ``bus_name10``_axi_arsize, ``bus_name9``_axi_arsize, ``bus_name8``_axi_arsize, ``bus_name7``_axi_arsize, ``bus_name6``_axi_arsize, ``bus_name5``_axi_arsize, ``bus_name4``_axi_arsize, ``bus_name3``_axi_arsize, ``bus_name2``_axi_arsize, ``bus_name1``_axi_arsize, ``bus_name0``_axi_arsize} = ``array_name``_axi_arsize; \
        assign {``bus_name13``_axi_arburst, ``bus_name12``_axi_arburst, ``bus_name11``_axi_arburst, ``bus_name10``_axi_arburst, ``bus_name9``_axi_arburst, ``bus_name8``_axi_arburst, ``bus_name7``_axi_arburst, ``bus_name6``_axi_arburst, ``bus_name5``_axi_arburst, ``bus_name4``_axi_arburst, ``bus_name3``_axi_arburst, ``bus_name2``_axi_arburst, ``bus_name1``_axi_arburst, ``bus_name0``_axi_arburst} = ``array_name``_axi_arburst; \
        assign {``bus_name13``_axi_arlock, ``bus_name12``_axi_arlock, ``bus_name11``_axi_arlock, ``bus_name10``_axi_arlock, ``bus_name9``_axi_arlock, ``bus_name8``_axi_arlock, ``bus_name7``_axi_arlock, ``bus_name6``_axi_arlock, ``bus_name5``_axi_arlock, ``bus_name4``_axi_arlock, ``bus_name3``_axi_arlock, ``bus_name2``_axi_arlock, ``bus_name1``_axi_arlock, ``bus_name0``_axi_arlock} = ``array_name``_axi_arlock; \
        assign {``bus_name13``_axi_arcache, ``bus_name12``_axi_arcache, ``bus_name11``_axi_arcache, ``bus_name10``_axi_arcache, ``bus_name9``_axi_arcache, ``bus_name8``_axi_arcache, ``bus_name7``_axi_arcache, ``bus_name6``_axi_arcache, ``bus_name5``_axi_arcache, ``bus_name4``_axi_arcache, ``bus_name3``_axi_arcache, ``bus_name2``_axi_arcache, ``bus_name1``_axi_arcache, ``bus_name0``_axi_arcache} = ``array_name``_axi_arcache; \
        assign {``bus_name13``_axi_arprot, ``bus_name12``_axi_arprot, ``bus_name11``_axi_arprot, ``bus_name10``_axi_arprot, ``bus_name9``_axi_arprot, ``bus_name8``_axi_arprot, ``bus_name7``_axi_arprot, ``bus_name6``_axi_arprot, ``bus_name5``_axi_arprot, ``bus_name4``_axi_arprot, ``bus_name3``_axi_arprot, ``bus_name2``_axi_arprot, ``bus_name1``_axi_arprot, ``bus_name0``_axi_arprot} = ``array_name``_axi_arprot; \
        assign {``bus_name13``_axi_arqos, ``bus_name12``_axi_arqos, ``bus_name11``_axi_arqos, ``bus_name10``_axi_arqos, ``bus_name9``_axi_arqos, ``bus_name8``_axi_arqos, ``bus_name7``_axi_arqos, ``bus_name6``_axi_arqos, ``bus_name5``_axi_arqos, ``bus_name4``_axi_arqos, ``bus_name3``_axi_arqos, ``bus_name2``_axi_arqos, ``bus_name1``_axi_arqos, ``bus_name0``_axi_arqos} = ``array_name``_axi_arqos; \
        assign {``bus_name13``_axi_arvalid, ``bus_name12``_axi_arvalid, ``bus_name11``_axi_arvalid, ``bus_name10``_axi_arvalid, ``bus_name9``_axi_arvalid, ``bus_name8``_axi_arvalid, ``bus_name7``_axi_arvalid, ``bus_name6``_axi_arvalid, ``bus_name5``_axi_arvalid, ``bus_name4``_axi_arvalid, ``bus_name3``_axi_arvalid, ``bus_name2``_axi_arvalid, ``bus_name1``_axi_arvalid, ``bus_name0``_axi_arvalid} = ``array_name``_axi_arvalid; \
        assign {``bus_name13``_axi_arid, ``bus_name12``_axi_arid, ``bus_name11``_axi_arid, ``bus_name10``_axi_arid, ``bus_name9``_axi_arid, ``bus_name8``_axi_arid, ``bus_name7``_axi_arid, ``bus_name6``_axi_arid, ``bus_name5``_axi_arid, ``bus_name4``_axi_arid, ``bus_name3``_axi_arid, ``bus_name2``_axi_arid, ``bus_name1``_axi_arid, ``bus_name0``_axi_arid} = ``array_name``_axi_arid; \
        assign {``bus_name13``_axi_arregion, ``bus_name12``_axi_arregion, ``bus_name11``_axi_arregion, ``bus_name10``_axi_arregion, ``bus_name9``_axi_arregion, ``bus_name8``_axi_arregion, ``bus_name7``_axi_arregion, ``bus_name6``_axi_arregion, ``bus_name5``_axi_arregion, ``bus_name4``_axi_arregion, ``bus_name3``_axi_arregion, ``bus_name2``_axi_arregion, ``bus_name1``_axi_arregion, ``bus_name0``_axi_arregion} = ``array_name``_axi_arregion; \
        assign {``bus_name13``_axi_rready, ``bus_name12``_axi_rready, ``bus_name11``_axi_rready, ``bus_name10``_axi_rready, ``bus_name9``_axi_rready, ``bus_name8``_axi_rready, ``bus_name7``_axi_rready, ``bus_name6``_axi_rready, ``bus_name5``_axi_rready, ``bus_name4``_axi_rready, ``bus_name3``_axi_rready, ``bus_name2``_axi_rready, ``bus_name1``_axi_rready, ``bus_name0``_axi_rready} = ``array_name``_axi_rready; \
        assign ``array_name``_axi_awready = {``bus_name13``_axi_awready, ``bus_name12``_axi_awready, ``bus_name11``_axi_awready, ``bus_name10``_axi_awready, ``bus_name9``_axi_awready, ``bus_name8``_axi_awready, ``bus_name7``_axi_awready, ``bus_name6``_axi_awready, ``bus_name5``_axi_awready, ``bus_name4``_axi_awready, ``bus_name3``_axi_awready, ``bus_name2``_axi_awready, ``bus_name1``_axi_awready, ``bus_name0``_axi_awready}; \
        assign ``array_name``_axi_wready = {``bus_name13``_axi_wready, ``bus_name12``_axi_wready, ``bus_name11``_axi_wready, ``bus_name10``_axi_wready, ``bus_name9``_axi_wready, ``bus_name8``_axi_wready, ``bus_name7``_axi_wready, ``bus_name6``_axi_wready, ``bus_name5``_axi_wready, ``bus_name4``_axi_wready, ``bus_name3``_axi_wready, ``bus_name2``_axi_wready, ``bus_name1``_axi_wready, ``bus_name0``_axi_wready}; \
        assign ``array_name``_axi_bid = {``bus_name13``_axi_bid, ``bus_name12``_axi_bid, ``bus_name11``_axi_bid, ``bus_name10``_axi_bid, ``bus_name9``_axi_bid, ``bus_name8``_axi_bid, ``bus_name7``_axi_bid, ``bus_name6``_axi_bid, ``bus_name5``_axi_bid, ``bus_name4``_axi_bid, ``bus_name3``_axi_bid, ``bus_name2``_axi_bid, ``bus_name1``_axi_bid, ``bus_name0``_axi_bid}; \
        assign ``array_name``_axi_bresp = {``bus_name13``_axi_bresp, ``bus_name12``_axi_bresp, ``bus_name11``_axi_bresp, ``bus_name10``_axi_bresp, ``bus_name9``_axi_bresp, ``bus_name8``_axi_bresp, ``bus_name7``_axi_bresp, ``bus_name6``_axi_bresp, ``bus_name5``_axi_bresp, ``bus_name4``_axi_bresp, ``bus_name3``_axi_bresp, ``bus_name2``_axi_bresp, ``bus_name1``_axi_bresp, ``bus_name0``_axi_bresp}; \
        assign ``array_name``_axi_bvalid = {``bus_name13``_axi_bvalid, ``bus_name12``_axi_bvalid, ``bus_name11``_axi_bvalid, ``bus_name10``_axi_bvalid, ``bus_name9``_axi_bvalid, ``bus_name8``_axi_bvalid, ``bus_name7``_axi_bvalid, ``bus_name6``_axi_bvalid, ``bus_name5``_axi_bvalid, ``bus_name4``_axi_bvalid, ``bus_name3``_axi_bvalid, ``bus_name2``_axi_bvalid, ``bus_name1``_axi_bvalid, ``bus_name0``_axi_bvalid}; \
        assign ``array_name``_axi_arready = {``bus_name13``_axi_arready, ``bus_name12``_axi_arready, ``bus_name11``_axi_arready, ``bus_name10``_axi_arready, ``bus_name9``_axi_arready, ``bus_name8``_axi_arready, ``bus_name7``_axi_arready, ``bus_name6``_axi_arready, ``bus_name5``_axi_arready, ``bus_name4``_axi_arready, ``bus_name3``_axi_arready, ``bus_name2``_axi_arready, ``bus_name1``_axi_arready, ``bus_name0``_axi_arready}; \
        assign ``array_name``_axi_rid = {``bus_name13``_axi_rid, ``bus_name12``_axi_rid, ``bus_name11``_axi_rid, ``bus_name10``_axi_rid, ``bus_name9``_axi_rid, ``bus_name8``_axi_rid, ``bus_name7``_axi_rid, ``bus_name6``_axi_rid, ``bus_name5``_axi_rid, ``bus_name4``_axi_rid, ``bus_name3``_axi_rid, ``bus_name2``_axi_rid, ``bus_name1``_axi_rid, ``bus_name0``_axi_rid}; \
        assign ``array_name``_axi_rdata = {``bus_name13``_axi_rdata, ``bus_name12``_axi_rdata, ``bus_name11``_axi_rdata, ``bus_name10``_axi_rdata, ``bus_name9``_axi_rdata, ``bus_name8``_axi_rdata, ``bus_name7``_axi_rdata, ``bus_name6``_axi_rdata, ``bus_name5``_axi_rdata, ``bus_name4``_axi_rdata, ``bus_name3``_axi_rdata, ``bus_name2``_axi_rdata, ``bus_name1``_axi_rdata, ``bus_name0``_axi_rdata}; \
        assign ``array_name``_axi_rresp = {``bus_name13``_axi_rresp, ``bus_name12``_axi_rresp, ``bus_name11``_axi_rresp, ``bus_name10``_axi_rresp, ``bus_name9``_axi_rresp, ``bus_name8``_axi_rresp, ``bus_name7``_axi_rresp, ``bus_name6``_axi_rresp, ``bus_name5``_axi_rresp, ``bus_name4``_axi_rresp, ``bus_name3``_axi_rresp, ``bus_name2``_axi_rresp, ``bus_name1``_axi_rresp, ``bus_name0``_axi_rresp}; \
        assign ``array_name``_axi_rlast = {``bus_name13``_axi_rlast, ``bus_name12``_axi_rlast, ``bus_name11``_axi_rlast, ``bus_name10``_axi_rlast, ``bus_name9``_axi_rlast, ``bus_name8``_axi_rlast, ``bus_name7``_axi_rlast, ``bus_name6``_axi_rlast, ``bus_name5``_axi_rlast, ``bus_name4``_axi_rlast, ``bus_name3``_axi_rlast, ``bus_name2``_axi_rlast, ``bus_name1``_axi_rlast, ``bus_name0``_axi_rlast}; \
        assign ``array_name``_axi_rvalid = {``bus_name13``_axi_rvalid, ``bus_name12``_axi_rvalid, ``bus_name11``_axi_rvalid, ``bus_name10``_axi_rvalid, ``bus_name9``_axi_rvalid, ``bus_name8``_axi_rvalid, ``bus_name7``_axi_rvalid, ``bus_name6``_axi_rvalid, ``bus_name5``_axi_rvalid, ``bus_name4``_axi_rvalid, ``bus_name3``_axi_rvalid, ``bus_name2``_axi_rvalid, ``bus_name1``_axi_rvalid, ``bus_name0``_axi_rvalid};

`ifdef HPC
    `include "uninasoc_pcie.svh"
    `include "uninasoc_ddr4.svh"
`endif

///////////////////////
// Module definition //
///////////////////////

module uninasoc (

    `ifdef EMBEDDED
        // Clock and reset
        input logic sys_clock_i,
        input logic sys_reset_i,

        // UART interface
        input  logic                        uart_rx_i,
        output logic                        uart_tx_o,

        // GPIOs
        input  logic [GPIO_IN_WIDTH  -1 : 0]  gpio_in_i,
        output logic [GPIO_OUT_WIDTH -1 : 0]  gpio_out_o
    `elsif HPC
        // DDR4 Channel 0 differential clock
        input logic clk_300mhz_0_p_i,
        input logic clk_300mhz_0_n_i,
        // DDR4 Channel 0 interface
        `DEFINE_DDR4_PORTS(0),

        // DDR4 Channel 1 differential clock
        input logic clk_300mhz_1_p_i,
        input logic clk_300mhz_1_n_i,
        // DDR4 Channel 1 interface
        `DEFINE_DDR4_PORTS(1),

        // // DDR4 Channel 2 differential clock
        // input logic clk_300mhz_2_p_i,
        // input logic clk_300mhz_2_n_i,
        // // DDR4 Channel 2 interface
        // `DEFINE_DDR4_PORTS(2),

        // PCIe clock and reset
        input logic pcie_refclk_p_i,
        input logic pcie_refclk_n_i,
        input logic pcie_resetn_i,

        // PCIe interface
        `DEFINE_PCIE_PORTS
    `endif

);

    /////////////////////
    // Local variables //
    /////////////////////

    localparam peripherals_interrupts_num = 4;
    localparam HBUS_AXI_DATAWIDTH = 512;

    ///////////////////
    // Local Signals //
    //////////////////

    // CLOCKS
    logic main_clk;
    logic clk_10MHz;
    logic clk_20MHz;
    logic clk_50MHz;
    logic clk_100MHz;
    logic clk_250MHz;      // HPC ONLY

    // RESETS
    logic main_rstn;
    logic rstn_10MHz;
    logic rstn_20MHz;
    logic rstn_50MHz;
    logic rstn_100MHz;
    logic rstn_250MHz;     // HPC ONLY

    // VIO Signals
    logic vio_resetn;

    // Socket interrupts
    logic [31:0] rv_socket_interrupt_line;

    // Peripheral bus interrupts
    logic [peripherals_interrupts_num-1:0] pbus_int_line;

    /////////////////////////////////////////
    // Buses declaration and concatenation //
    /////////////////////////////////////////
    `include "mbus_buses.svinc"

    ///////////////////////
    // Clock assignments //
    ///////////////////////
    `include "uninasoc_clk_assignments.svinc"

    ///////////////////////
    // Local assignments //
    ///////////////////////

    /////////////
    // Modules //
    /////////////

    // Virtual I/O

    xlnx_vio vio_inst (
      .clk        ( main_clk        ),
      .probe_out0 ( vio_resetn      ),
      .probe_out1 (                 ),
      .probe_in0  (                 )
    );

    // Axi Crossbar
    xlnx_main_crossbar main_xbar_u (
        .aclk           ( main_clk                  ), // input
        .aresetn        ( main_rstn                 ), // input
        .s_axi_awid     ( MBUS_masters_axi_awid     ), // input
        .s_axi_awaddr   ( MBUS_masters_axi_awaddr   ), // input
        .s_axi_awlen    ( MBUS_masters_axi_awlen    ), // input
        .s_axi_awsize   ( MBUS_masters_axi_awsize   ), // input
        .s_axi_awburst  ( MBUS_masters_axi_awburst  ), // input
        .s_axi_awlock   ( MBUS_masters_axi_awlock   ), // input
        .s_axi_awcache  ( MBUS_masters_axi_awcache  ), // input
        .s_axi_awprot   ( MBUS_masters_axi_awprot   ), // input
        .s_axi_awqos    ( MBUS_masters_axi_awqos    ), // input
        .s_axi_awvalid  ( MBUS_masters_axi_awvalid  ), // input
        .s_axi_awready  ( MBUS_masters_axi_awready  ), // output
        .s_axi_wdata    ( MBUS_masters_axi_wdata    ), // input
        .s_axi_wstrb    ( MBUS_masters_axi_wstrb    ), // input
        .s_axi_wlast    ( MBUS_masters_axi_wlast    ), // input
        .s_axi_wvalid   ( MBUS_masters_axi_wvalid   ), // input
        .s_axi_wready   ( MBUS_masters_axi_wready   ), // output
        .s_axi_bid      ( MBUS_masters_axi_bid      ), // output
        .s_axi_bresp    ( MBUS_masters_axi_bresp    ), // output
        .s_axi_bvalid   ( MBUS_masters_axi_bvalid   ), // output
        .s_axi_bready   ( MBUS_masters_axi_bready   ), // input
        .s_axi_arid     ( MBUS_masters_axi_arid     ), // output
        .s_axi_araddr   ( MBUS_masters_axi_araddr   ), // input
        .s_axi_arlen    ( MBUS_masters_axi_arlen    ), // input
        .s_axi_arsize   ( MBUS_masters_axi_arsize   ), // input
        .s_axi_arburst  ( MBUS_masters_axi_arburst  ), // input
        .s_axi_arlock   ( MBUS_masters_axi_arlock   ), // input
        .s_axi_arcache  ( MBUS_masters_axi_arcache  ), // input
        .s_axi_arprot   ( MBUS_masters_axi_arprot   ), // input
        .s_axi_arqos    ( MBUS_masters_axi_arqos    ), // input
        .s_axi_arvalid  ( MBUS_masters_axi_arvalid  ), // input
        .s_axi_arready  ( MBUS_masters_axi_arready  ), // output
        .s_axi_rid      ( MBUS_masters_axi_rid      ), // output
        .s_axi_rdata    ( MBUS_masters_axi_rdata    ), // output
        .s_axi_rresp    ( MBUS_masters_axi_rresp    ), // output
        .s_axi_rlast    ( MBUS_masters_axi_rlast    ), // output
        .s_axi_rvalid   ( MBUS_masters_axi_rvalid   ), // output
        .s_axi_rready   ( MBUS_masters_axi_rready   ), // input
        .m_axi_awid     ( MBUS_slaves_axi_awid      ), // output
        .m_axi_awaddr   ( MBUS_slaves_axi_awaddr    ), // output
        .m_axi_awlen    ( MBUS_slaves_axi_awlen     ), // output
        .m_axi_awsize   ( MBUS_slaves_axi_awsize    ), // output
        .m_axi_awburst  ( MBUS_slaves_axi_awburst   ), // output
        .m_axi_awlock   ( MBUS_slaves_axi_awlock    ), // output
        .m_axi_awcache  ( MBUS_slaves_axi_awcache   ), // output
        .m_axi_awprot   ( MBUS_slaves_axi_awprot    ), // output
        .m_axi_awregion ( MBUS_slaves_axi_awregion  ), // output
        .m_axi_awqos    ( MBUS_slaves_axi_awqos     ), // output
        .m_axi_awvalid  ( MBUS_slaves_axi_awvalid   ), // output
        .m_axi_awready  ( MBUS_slaves_axi_awready   ), // input
        .m_axi_wdata    ( MBUS_slaves_axi_wdata     ), // output
        .m_axi_wstrb    ( MBUS_slaves_axi_wstrb     ), // output
        .m_axi_wlast    ( MBUS_slaves_axi_wlast     ), // output
        .m_axi_wvalid   ( MBUS_slaves_axi_wvalid    ), // output
        .m_axi_wready   ( MBUS_slaves_axi_wready    ), // input
        .m_axi_bid      ( MBUS_slaves_axi_bid       ), // input
        .m_axi_bresp    ( MBUS_slaves_axi_bresp     ), // input
        .m_axi_bvalid   ( MBUS_slaves_axi_bvalid    ), // input
        .m_axi_bready   ( MBUS_slaves_axi_bready    ), // output
        .m_axi_arid     ( MBUS_slaves_axi_arid      ), // output
        .m_axi_araddr   ( MBUS_slaves_axi_araddr    ), // output
        .m_axi_arlen    ( MBUS_slaves_axi_arlen     ), // output
        .m_axi_arsize   ( MBUS_slaves_axi_arsize    ), // output
        .m_axi_arburst  ( MBUS_slaves_axi_arburst   ), // output
        .m_axi_arlock   ( MBUS_slaves_axi_arlock    ), // output
        .m_axi_arcache  ( MBUS_slaves_axi_arcache   ), // output
        .m_axi_arprot   ( MBUS_slaves_axi_arprot    ), // output
        .m_axi_arregion ( MBUS_slaves_axi_arregion  ), // output
        .m_axi_arqos    ( MBUS_slaves_axi_arqos     ), // output
        .m_axi_arvalid  ( MBUS_slaves_axi_arvalid   ), // output
        .m_axi_arready  ( MBUS_slaves_axi_arready   ), // input
        .m_axi_rid      ( MBUS_slaves_axi_rid       ), // input
        .m_axi_rdata    ( MBUS_slaves_axi_rdata     ), // input
        .m_axi_rresp    ( MBUS_slaves_axi_rresp     ), // input
        .m_axi_rlast    ( MBUS_slaves_axi_rlast     ), // input
        .m_axi_rvalid   ( MBUS_slaves_axi_rvalid    ), // input
        .m_axi_rready   ( MBUS_slaves_axi_rready    )  // output
    );

    /////////////////
    // AXI masters //
    /////////////////

    sys_master # (
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) sys_master_u (

        // EMBEDDED ONLY
        .sys_clock_i(sys_clock_i),
        .sys_reset_i(sys_reset_i),

        // HPC ONLY
        .pcie_refclk_p_i(pcie_refclk_p_i),
        .pcie_refclk_n_i(pcie_refclk_n_i),
        .pcie_resetn_i(pcie_resetn_i),
        // PCI interface
        .pci_exp_rxn_i(pci_exp_rxn_i),
        .pci_exp_rxp_i(pci_exp_rxp_i),
        .pci_exp_txn_o(pci_exp_txn_o),
        .pci_exp_txp_o(pci_exp_txp_o),

        // Output clocks
        .clk_10MHz_o(clk_10MHz),
        .clk_20MHz_o(clk_20MHz),
        .clk_50MHz_o(clk_50MHz),
        .clk_100MHz_o(clk_100MHz),
        .clk_250MHz_o(clk_250MHz),      // HPC ONLY

        // Output resets
        .rstn_10MHz_o(rstn_10MHz),
        .rstn_20MHz_o(rstn_20MHz),
        .rstn_50MHz_o(rstn_50MHz),
        .rstn_100MHz_o(rstn_100MHz),
        .rstn_250MHz_o(rstn_250MHz),      // HPC ONLY

        // AXI Master
        .m_axi_awid     ( SYS_MASTER_to_MBUS_axi_awid     ),
        .m_axi_awaddr   ( SYS_MASTER_to_MBUS_axi_awaddr   ),
        .m_axi_awlen    ( SYS_MASTER_to_MBUS_axi_awlen    ),
        .m_axi_awsize   ( SYS_MASTER_to_MBUS_axi_awsize   ),
        .m_axi_awburst  ( SYS_MASTER_to_MBUS_axi_awburst  ),
        .m_axi_awlock   ( SYS_MASTER_to_MBUS_axi_awlock   ),
        .m_axi_awcache  ( SYS_MASTER_to_MBUS_axi_awcache  ),
        .m_axi_awprot   ( SYS_MASTER_to_MBUS_axi_awprot   ),
        .m_axi_awqos    ( SYS_MASTER_to_MBUS_axi_awqos    ),
        .m_axi_awvalid  ( SYS_MASTER_to_MBUS_axi_awvalid  ),
        .m_axi_awready  ( SYS_MASTER_to_MBUS_axi_awready  ),
        .m_axi_awregion ( SYS_MASTER_to_MBUS_axi_awregion ),
        .m_axi_wdata    ( SYS_MASTER_to_MBUS_axi_wdata    ),
        .m_axi_wstrb    ( SYS_MASTER_to_MBUS_axi_wstrb    ),
        .m_axi_wlast    ( SYS_MASTER_to_MBUS_axi_wlast    ),
        .m_axi_wvalid   ( SYS_MASTER_to_MBUS_axi_wvalid   ),
        .m_axi_wready   ( SYS_MASTER_to_MBUS_axi_wready   ),
        .m_axi_bid      ( SYS_MASTER_to_MBUS_axi_bid      ),
        .m_axi_bresp    ( SYS_MASTER_to_MBUS_axi_bresp    ),
        .m_axi_bvalid   ( SYS_MASTER_to_MBUS_axi_bvalid   ),
        .m_axi_bready   ( SYS_MASTER_to_MBUS_axi_bready   ),
        .m_axi_arid     ( SYS_MASTER_to_MBUS_axi_arid     ),
        .m_axi_araddr   ( SYS_MASTER_to_MBUS_axi_araddr   ),
        .m_axi_arlen    ( SYS_MASTER_to_MBUS_axi_arlen    ),
        .m_axi_arsize   ( SYS_MASTER_to_MBUS_axi_arsize   ),
        .m_axi_arburst  ( SYS_MASTER_to_MBUS_axi_arburst  ),
        .m_axi_arlock   ( SYS_MASTER_to_MBUS_axi_arlock   ),
        .m_axi_arcache  ( SYS_MASTER_to_MBUS_axi_arcache  ),
        .m_axi_arprot   ( SYS_MASTER_to_MBUS_axi_arprot   ),
        .m_axi_arqos    ( SYS_MASTER_to_MBUS_axi_arqos    ),
        .m_axi_arvalid  ( SYS_MASTER_to_MBUS_axi_arvalid  ),
        .m_axi_arready  ( SYS_MASTER_to_MBUS_axi_arready  ),
        .m_axi_arregion ( SYS_MASTER_to_MBUS_axi_arregion ),
        .m_axi_rid      ( SYS_MASTER_to_MBUS_axi_rid      ),
        .m_axi_rdata    ( SYS_MASTER_to_MBUS_axi_rdata    ),
        .m_axi_rresp    ( SYS_MASTER_to_MBUS_axi_rresp    ),
        .m_axi_rlast    ( SYS_MASTER_to_MBUS_axi_rlast    ),
        .m_axi_rvalid   ( SYS_MASTER_to_MBUS_axi_rvalid   ),
        .m_axi_rready   ( SYS_MASTER_to_MBUS_axi_rready   )
    );

    // RV Socket
    localparam NUM_CPU = 1;
    rv_socket # (
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH    ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH    ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH      ),
        .CORE_SELECTOR      ( CORE_SELECTOR      ),
        .NUM_CPU            ( NUM_CPU            )
    ) rv_socket_u (
        .clk_i          ( main_clk   ),
        .rst_ni         ( main_rstn  ),
        .core_resetn_i  ( vio_resetn ),
        .bootaddr_i     ( '0         ),
        .irq_i          ( rv_socket_interrupt_line ),

        // Instruction/Data AXI Port
        `ASSIGN_AXI_PORT(rv_socket_instr0, RV_SOCKET_INSTR0_to_MBUS),
        `ASSIGN_AXI_PORT( rv_socket_data0,  RV_SOCKET_DATA0_to_MBUS),
        `ASSIGN_AXI_PORT(rv_socket_instr1, RV_SOCKET_INSTR1_to_MBUS),
        `ASSIGN_AXI_PORT( rv_socket_data1,  RV_SOCKET_DATA1_to_MBUS),
        `ASSIGN_AXI_PORT(rv_socket_instr2, RV_SOCKET_INSTR2_to_MBUS),
        `ASSIGN_AXI_PORT( rv_socket_data2,  RV_SOCKET_DATA2_to_MBUS),
        `ASSIGN_AXI_PORT(rv_socket_instr3, RV_SOCKET_INSTR3_to_MBUS),
        `ASSIGN_AXI_PORT( rv_socket_data3,  RV_SOCKET_DATA3_to_MBUS),
        `ASSIGN_AXI_PORT(rv_socket_instr4, RV_SOCKET_INSTR4_to_MBUS),
        `ASSIGN_AXI_PORT( rv_socket_data4,  RV_SOCKET_DATA4_to_MBUS),
        `ASSIGN_AXI_PORT(rv_socket_instr5, RV_SOCKET_INSTR5_to_MBUS),
        `ASSIGN_AXI_PORT( rv_socket_data5,  RV_SOCKET_DATA5_to_MBUS),

        // Debug AXI master
        `ASSIGN_AXI_PORT(rv_socket_dbg_master, DBG_MASTER_to_MBUS),
        // Debug AXI slave
        `ASSIGN_AXI_PORT(rv_socket_dbg_slave, MBUS_to_DM_mem)
    );

    ////////////////
    // AXI slaves //
    ////////////////

    // Main memory
    xlnx_blk_mem_gen_0 bram_u (
        .rsta_busy      ( /* open */                ), // output wire rsta_busy
        .rstb_busy      ( /* open */                ), // output wire rstb_busy
        .s_aclk         ( BRAM_clk                  ), // input wire s_aclk
        .s_aresetn      ( BRAM_rstn                 ), // input wire s_aresetn
        .s_axi_awid     ( MBUS_to_BRAM_axi_awid     ), // input wire [3 : 0] s_axi_awid
        .s_axi_awaddr   ( MBUS_to_BRAM_axi_awaddr   ), // input wire [31 : 0] s_axi_awaddr
        .s_axi_awlen    ( MBUS_to_BRAM_axi_awlen    ), // input wire [7 : 0] s_axi_awlen
        .s_axi_awsize   ( MBUS_to_BRAM_axi_awsize   ), // input wire [2 : 0] s_axi_awsize
        .s_axi_awburst  ( MBUS_to_BRAM_axi_awburst  ), // input wire [1 : 0] s_axi_awburst
        .s_axi_awvalid  ( MBUS_to_BRAM_axi_awvalid  ), // input wire s_axi_awvalid
        .s_axi_awready  ( MBUS_to_BRAM_axi_awready  ), // output wire s_axi_awready
        .s_axi_wdata    ( MBUS_to_BRAM_axi_wdata    ), // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb    ( MBUS_to_BRAM_axi_wstrb    ), // input wire [3 : 0] s_axi_wstrb
        .s_axi_wlast    ( MBUS_to_BRAM_axi_wlast    ), // input wire s_axi_wlast
        .s_axi_wvalid   ( MBUS_to_BRAM_axi_wvalid   ), // input wire s_axi_wvalid
        .s_axi_wready   ( MBUS_to_BRAM_axi_wready   ), // output wire s_axi_wready
        .s_axi_bid      ( MBUS_to_BRAM_axi_bid      ), // output wire [3 : 0] s_axi_bid
        .s_axi_bresp    ( MBUS_to_BRAM_axi_bresp    ), // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid   ( MBUS_to_BRAM_axi_bvalid   ), // output wire s_axi_bvalid
        .s_axi_bready   ( MBUS_to_BRAM_axi_bready   ), // input wire s_axi_bready
        .s_axi_arid     ( MBUS_to_BRAM_axi_arid     ), // input wire [3 : 0] s_axi_arid
        .s_axi_araddr   ( MBUS_to_BRAM_axi_araddr   ), // input wire [31 : 0] s_axi_araddr
        .s_axi_arlen    ( MBUS_to_BRAM_axi_arlen    ), // input wire [7 : 0] s_axi_arlen
        .s_axi_arsize   ( MBUS_to_BRAM_axi_arsize   ), // input wire [2 : 0] s_axi_arsize
        .s_axi_arburst  ( MBUS_to_BRAM_axi_arburst  ), // input wire [1 : 0] s_axi_arburst
        .s_axi_arvalid  ( MBUS_to_BRAM_axi_arvalid  ), // input wire s_axi_arvalid
        .s_axi_arready  ( MBUS_to_BRAM_axi_arready  ), // output wire s_axi_arready
        .s_axi_rid      ( MBUS_to_BRAM_axi_rid      ), // output wire [3 : 0] s_axi_rid
        .s_axi_rdata    ( MBUS_to_BRAM_axi_rdata    ), // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp    ( MBUS_to_BRAM_axi_rresp    ), // output wire [1 : 0] s_axi_rresp
        .s_axi_rlast    ( MBUS_to_BRAM_axi_rlast    ), // output wire s_axi_rlast
        .s_axi_rvalid   ( MBUS_to_BRAM_axi_rvalid   ), // output wire s_axi_rvalid
        .s_axi_rready   ( MBUS_to_BRAM_axi_rready   )  // input wire s_axi_rready
    );

    // Platform-Level Interrupt Controller (PLIC)
    logic [31:0] plic_int_line;
    logic plic_int_irq_o;
    // TODO154: generate by config
    localparam NUM_HLS_CORES = 4;
    logic [NUM_HLS_CORES -1 : 0 ] hls_interrupt_to_plic;

    always_comb begin : system_interrupts

        // Default non-assigned lines
        plic_int_line = '0;
        rv_socket_interrupt_line = '0;

        // Mapping PLIC input interrupts (only from pbus at the moment)
        // Mapping is static (refer to uninasoc_pkg.sv)
        // TODO154: generate by config
        plic_int_line[PLIC_RESERVED_INTERRUPT]  = 1'b0;
        // PBUS lines
        plic_int_line[PLIC_GPIOIN_INTERRUPT]    = pbus_int_line[PBUS_GPIOIN_INTERRUPT];
        plic_int_line[PLIC_TIM0_INTERRUPT]      = pbus_int_line[PBUS_TIM0_INTERRUPT];
        plic_int_line[PLIC_TIM1_INTERRUPT]      = pbus_int_line[PBUS_TIM1_INTERRUPT];
        plic_int_line[PLIC_UART_INTERRUPT]      = pbus_int_line[PBUS_UART_INTERRUPT];
        // HLS cores
        plic_int_line[PLIC_HLS_INTERRUPT +: NUM_HLS_CORES] = hls_interrupt_to_plic;

        // Map system-interrupts pins to socket interrupts
        rv_socket_interrupt_line[CORE_EXT_INTERRUPT] = plic_int_irq_o;

    end : system_interrupts

    plic_wrapper #(
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) plic_wrapper_u (
        .clk_i          ( main_clk                      ), // input wire s_axi_aclk
        .rst_ni         ( main_rstn                     ), // input wire s_axi_aresetn
        // AXI4 slave port (from xbar)
        .intr_src_i     ( plic_int_line                 ), // Input interrupt lines (Sources)
        .irq_o          ( plic_int_irq_o                ), // Output Interrupts (Targets -> Socket)
        .s_axi_awid     ( MBUS_to_PLIC_axi_awid         ), // input wire [1 : 0] s_axi_awid
        .s_axi_awaddr   ( MBUS_to_PLIC_axi_awaddr       ), // input wire [25 : 0] s_axi_awaddr
        .s_axi_awlen    ( MBUS_to_PLIC_axi_awlen        ), // input wire [7 : 0] s_axi_awlen
        .s_axi_awsize   ( MBUS_to_PLIC_axi_awsize       ), // input wire [2 : 0] s_axi_awsize
        .s_axi_awburst  ( MBUS_to_PLIC_axi_awburst      ), // input wire [1 : 0] s_axi_awburst
        .s_axi_awlock   ( MBUS_to_PLIC_axi_awlock       ), // input wire [0 : 0] s_axi_awlock
        .s_axi_awcache  ( MBUS_to_PLIC_axi_awcache      ), // input wire [3 : 0] s_axi_awcache
        .s_axi_awprot   ( MBUS_to_PLIC_axi_awprot       ), // input wire [2 : 0] s_axi_awprot
        .s_axi_awregion ( MBUS_to_PLIC_axi_awregion     ), // input wire [3 : 0] s_axi_awregion
        .s_axi_awqos    ( MBUS_to_PLIC_axi_awqos        ), // input wire [3 : 0] s_axi_awqos
        .s_axi_awvalid  ( MBUS_to_PLIC_axi_awvalid      ), // input wire s_axi_awvalid
        .s_axi_awready  ( MBUS_to_PLIC_axi_awready      ), // output wire s_axi_awready
        .s_axi_wdata    ( MBUS_to_PLIC_axi_wdata        ), // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb    ( MBUS_to_PLIC_axi_wstrb        ), // input wire [3 : 0] s_axi_wstrb
        .s_axi_wlast    ( MBUS_to_PLIC_axi_wlast        ), // input wire s_axi_wlast
        .s_axi_wvalid   ( MBUS_to_PLIC_axi_wvalid       ), // input wire s_axi_wvalid
        .s_axi_wready   ( MBUS_to_PLIC_axi_wready       ), // output wire s_axi_wready
        .s_axi_bid      ( MBUS_to_PLIC_axi_bid          ), // output wire [1 : 0] s_axi_bid
        .s_axi_bresp    ( MBUS_to_PLIC_axi_bresp        ), // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid   ( MBUS_to_PLIC_axi_bvalid       ), // output wire s_axi_bvalid
        .s_axi_bready   ( MBUS_to_PLIC_axi_bready       ), // input wire s_axi_bready
        .s_axi_arid     ( MBUS_to_PLIC_axi_arid         ), // input wire [1 : 0] s_axi_arid
        .s_axi_araddr   ( MBUS_to_PLIC_axi_araddr       ), // input wire [25 : 0] s_axi_araddr
        .s_axi_arlen    ( MBUS_to_PLIC_axi_arlen        ), // input wire [7 : 0] s_axi_arlen
        .s_axi_arsize   ( MBUS_to_PLIC_axi_arsize       ), // input wire [2 : 0] s_axi_arsize
        .s_axi_arburst  ( MBUS_to_PLIC_axi_arburst      ), // input wire [1 : 0] s_axi_arburst
        .s_axi_arlock   ( MBUS_to_PLIC_axi_arlock       ), // input wire [0 : 0] s_axi_arlock
        .s_axi_arcache  ( MBUS_to_PLIC_axi_arcache      ), // input wire [3 : 0] s_axi_arcache
        .s_axi_arprot   ( MBUS_to_PLIC_axi_arprot       ), // input wire [2 : 0] s_axi_arprot
        .s_axi_arregion ( MBUS_to_PLIC_axi_arregion     ), // input wire [3 : 0] s_axi_arregion
        .s_axi_arqos    ( MBUS_to_PLIC_axi_arqos        ), // input wire [3 : 0] s_axi_arqos
        .s_axi_arvalid  ( MBUS_to_PLIC_axi_arvalid      ), // input wire s_axi_arvalid
        .s_axi_arready  ( MBUS_to_PLIC_axi_arready      ), // output wire s_axi_arready
        .s_axi_rid      ( MBUS_to_PLIC_axi_rid          ), // output wire [1 : 0] s_axi_rid
        .s_axi_rdata    ( MBUS_to_PLIC_axi_rdata        ), // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp    ( MBUS_to_PLIC_axi_rresp        ), // output wire [1 : 0] s_axi_rresp
        .s_axi_rlast    ( MBUS_to_PLIC_axi_rlast        ), // output wire s_axi_rlast
        .s_axi_rvalid   ( MBUS_to_PLIC_axi_rvalid       ), // output wire s_axi_rvalid
        .s_axi_rready   ( MBUS_to_PLIC_axi_rready       )
    );

    ////////////////////
    // PERIPHERAL BUS //
    ////////////////////

    peripheral_bus # (

        .LOCAL_DATA_WIDTH   ( PBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( PBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( PBUS_ID_WIDTH   )

        ) peripheral_bus_u (

        .main_clock_i   ( main_clk    ),
        .main_reset_ni  ( main_rstn   ),
        .PBUS_clock_i   ( PBUS_clk    ),
        .PBUS_reset_ni  ( PBUS_rstn   ),

        // EMBEDDED ONLY
        .uart_rx_i      ( uart_rx_i      ),
        .uart_tx_o      ( uart_tx_o      ),
        .gpio_out_o     ( gpio_out_o     ),
        .gpio_in_i      ( gpio_in_i      ),

        .int_o          ( pbus_int_line  ),

        .s_axi_awid     ( MBUS_to_PBUS_axi_awid     ),
        .s_axi_awaddr   ( MBUS_to_PBUS_axi_awaddr   ),
        .s_axi_awlen    ( MBUS_to_PBUS_axi_awlen    ),
        .s_axi_awsize   ( MBUS_to_PBUS_axi_awsize   ),
        .s_axi_awburst  ( MBUS_to_PBUS_axi_awburst  ),
        .s_axi_awlock   ( MBUS_to_PBUS_axi_awlock   ),
        .s_axi_awcache  ( MBUS_to_PBUS_axi_awcache  ),
        .s_axi_awprot   ( MBUS_to_PBUS_axi_awprot   ),
        .s_axi_awregion ( MBUS_to_PBUS_axi_awregion ),
        .s_axi_awqos    ( MBUS_to_PBUS_axi_awqos    ),
        .s_axi_awvalid  ( MBUS_to_PBUS_axi_awvalid  ),
        .s_axi_awready  ( MBUS_to_PBUS_axi_awready  ),
        .s_axi_wdata    ( MBUS_to_PBUS_axi_wdata    ),
        .s_axi_wstrb    ( MBUS_to_PBUS_axi_wstrb    ),
        .s_axi_wlast    ( MBUS_to_PBUS_axi_wlast    ),
        .s_axi_wvalid   ( MBUS_to_PBUS_axi_wvalid   ),
        .s_axi_wready   ( MBUS_to_PBUS_axi_wready   ),
        .s_axi_bid      ( MBUS_to_PBUS_axi_bid      ),
        .s_axi_bresp    ( MBUS_to_PBUS_axi_bresp    ),
        .s_axi_bvalid   ( MBUS_to_PBUS_axi_bvalid   ),
        .s_axi_bready   ( MBUS_to_PBUS_axi_bready   ),
        .s_axi_arid     ( MBUS_to_PBUS_axi_arid     ),
        .s_axi_araddr   ( MBUS_to_PBUS_axi_araddr   ),
        .s_axi_arlen    ( MBUS_to_PBUS_axi_arlen    ),
        .s_axi_arsize   ( MBUS_to_PBUS_axi_arsize   ),
        .s_axi_arburst  ( MBUS_to_PBUS_axi_arburst  ),
        .s_axi_arlock   ( MBUS_to_PBUS_axi_arlock   ),
        .s_axi_arcache  ( MBUS_to_PBUS_axi_arcache  ),
        .s_axi_arprot   ( MBUS_to_PBUS_axi_arprot   ),
        .s_axi_arregion ( MBUS_to_PBUS_axi_arregion ),
        .s_axi_arqos    ( MBUS_to_PBUS_axi_arqos    ),
        .s_axi_arvalid  ( MBUS_to_PBUS_axi_arvalid  ),
        .s_axi_arready  ( MBUS_to_PBUS_axi_arready  ),
        .s_axi_rid      ( MBUS_to_PBUS_axi_rid      ),
        .s_axi_rdata    ( MBUS_to_PBUS_axi_rdata    ),
        .s_axi_rresp    ( MBUS_to_PBUS_axi_rresp    ),
        .s_axi_rlast    ( MBUS_to_PBUS_axi_rlast    ),
        .s_axi_rvalid   ( MBUS_to_PBUS_axi_rvalid   ),
        .s_axi_rready   ( MBUS_to_PBUS_axi_rready   )
    );

    ///////////////////
    // HLS Subsystem //
    ///////////////////

    // HLS CONV2D -> MBUS/HBUS
    // `define HLS_TARGET_BUS HBUS
    // localparam HLS_MASTER_DATA_WIDTH = HBUS_DATA_WIDTH;
    // localparam HLS_MASTER_ADDR_WIDTH = HBUS_ADDR_WIDTH;
    // localparam HLS_MASTER_ID_WIDTH   = HBUS_ID_WIDTH;
    // TODO: else if HLS on MBUS
    `define HLS_TARGET_BUS HBUS
    localparam HLS_MASTER_DATA_WIDTH = HBUS_DATA_WIDTH;
    localparam HLS_MASTER_ADDR_WIDTH = HBUS_ADDR_WIDTH;
    localparam HLS_MASTER_ID_WIDTH   = MBUS_ID_WIDTH;

    // Instance
    hls_subsystem # (
        // MBUS parameters, for HLS_CTRL
        .MBUS_ADDR_WIDTH       ( MBUS_ADDR_WIDTH       ),
        .MBUS_DATA_WIDTH       ( MBUS_DATA_WIDTH       ),
        .MBUS_ID_WIDTH         ( MBUS_ID_WIDTH         ),
        // HBUS parameters
        .AXI_MASTER_DATA_WIDTH ( HLS_MASTER_DATA_WIDTH ),
        .AXI_MASTER_ADDR_WIDTH ( HLS_MASTER_DATA_WIDTH ),
        .AXI_MASTER_ID_WIDTH   ( HLS_MASTER_DATA_WIDTH ),
        // Number of instances
        .NUM_HLS_CORES         ( NUM_HLS_CORES         ) // Supported values are 1, 2, 4, 8
    ) hls_subsystem_u (
        // MBUS clock and reset (for CDC)
        .main_clk_i             ( main_clk  ),
        .main_rstn_i            ( main_rstn ),
        // HLS IP(s) clock and reset, assume all in the same domain, wlog HLS_CTRL0
        .HLS_CTRL_clk_i          ( HLS_CTRL0_clk ),
        .HLS_CTRL_rstn_i         ( HLS_CTRL0_rstn ),
        // Slave(s) for control
        `ASSIGN_AXI_PORT(s_HLS_CTRL0, MBUS_to_HLS_CTRL0),
        `ASSIGN_AXI_PORT(s_HLS_CTRL1, MBUS_to_HLS_CTRL1),
        `ASSIGN_AXI_PORT(s_HLS_CTRL2, MBUS_to_HLS_CTRL2),
        `ASSIGN_AXI_PORT(s_HLS_CTRL3, MBUS_to_HLS_CTRL3),
        `ASSIGN_AXI_PORT(s_HLS_CTRL4, MBUS_to_HLS_CTRL4),
        `ASSIGN_AXI_PORT(s_HLS_CTRL5, MBUS_to_HLS_CTRL5),
        `ASSIGN_AXI_PORT(s_HLS_CTRL6, MBUS_to_HLS_CTRL6),
        `ASSIGN_AXI_PORT(s_HLS_CTRL7, MBUS_to_HLS_CTRL7),
        // Master(s) to MBUS / HBUS
        `ASSIGN_AXI_PORT(m0, HLS_MASTER0_to_`HLS_TARGET_BUS),
        `ASSIGN_AXI_PORT(m1, HLS_MASTER1_to_`HLS_TARGET_BUS),
        `ASSIGN_AXI_PORT(m2, HLS_MASTER2_to_`HLS_TARGET_BUS),
        `ASSIGN_AXI_PORT(m3, HLS_MASTER3_to_`HLS_TARGET_BUS),
        `ASSIGN_AXI_PORT(m4, HLS_MASTER4_to_`HLS_TARGET_BUS),
        `ASSIGN_AXI_PORT(m5, HLS_MASTER5_to_`HLS_TARGET_BUS),
        `ASSIGN_AXI_PORT(m6, HLS_MASTER6_to_`HLS_TARGET_BUS),
        `ASSIGN_AXI_PORT(m7, HLS_MASTER7_to_`HLS_TARGET_BUS),
        // Interrupt line(s)
        .hls_interrupt_o ( hls_interrupt_to_plic )
    );


// In HPC profile
`ifdef HPC

    ////////////////////
    // DDR4 Channel 1 //
    ////////////////////

    // TODO127: export these to config
    logic ddr4ch1_clk300MHz;
    logic ddr4ch1_rst300MHz;

    // DDR channel 1 on MBUS
    ddr4_channel_wrapper # (
        .ENABLE_CACHE       ( 1               ), // Always enabled for DDR4CH1
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) ddr4_channel_1_wrapper_u (
        .clock_i              ( main_clk          ),
        .reset_ni             ( main_rstn         ),
        // DDR4 differential clock
        .clk_300mhz_x_p_i     ( clk_300mhz_1_p_i  ),
        .clk_300mhz_x_n_i     ( clk_300mhz_1_n_i  ),

        // Output clock and reset
        .ddr_clk_o            ( ddr4ch1_clk300MHz ),
        .ddr_rst_o            ( ddr4ch1_rst300MHz ),

        // Connect DDR4 channel 1
        .cx_ddr4_adr          ( c1_ddr4_adr       ),
        .cx_ddr4_ba           ( c1_ddr4_ba        ),
        .cx_ddr4_cke          ( c1_ddr4_cke       ),
        .cx_ddr4_cs_n         ( c1_ddr4_cs_n      ),
        .cx_ddr4_dq           ( c1_ddr4_dq        ),
        .cx_ddr4_dqs_t        ( c1_ddr4_dqs_t     ),
        .cx_ddr4_dqs_c        ( c1_ddr4_dqs_c     ),
        .cx_ddr4_odt          ( c1_ddr4_odt       ),
        .cx_ddr4_parity       ( c1_ddr4_parity    ),
        .cx_ddr4_bg           ( c1_ddr4_bg        ),
        .cx_ddr4_act_n        ( c1_ddr4_act_n     ),
        .cx_ddr4_reset_n      ( c1_ddr4_reset_n   ),
        .cx_ddr4_ck_t         ( c1_ddr4_ck_t      ),
        .cx_ddr4_ck_c         ( c1_ddr4_ck_c      ),

        // AXILITE interface - for ECC status and control - not connected
        .s_ctrl_axilite_awvalid  ( 1'b0  ),
        .s_ctrl_axilite_awready  (       ),
        .s_ctrl_axilite_awaddr   ( 32'd0 ),
        .s_ctrl_axilite_wvalid   ( 1'b0  ),
        .s_ctrl_axilite_wready   (       ),
        .s_ctrl_axilite_wdata    ( 32'd0 ),
        .s_ctrl_axilite_bvalid   (       ),
        .s_ctrl_axilite_bready   ( 1'b1  ),
        .s_ctrl_axilite_bresp    (       ),
        .s_ctrl_axilite_arvalid  ( 1'b0  ),
        .s_ctrl_axilite_arready  (       ),
        .s_ctrl_axilite_araddr   ( 31'd0 ),
        .s_ctrl_axilite_rvalid   (       ),
        .s_ctrl_axilite_rready   ( 1'b1  ),
        .s_ctrl_axilite_rdata    (       ),
        .s_ctrl_axilite_rresp    (       ),

        // Slave interface
        .s_axi_awid           ( MBUS_to_DDR4CH1_axi_awid     ),
        .s_axi_awaddr         ( MBUS_to_DDR4CH1_axi_awaddr   ),
        .s_axi_awlen          ( MBUS_to_DDR4CH1_axi_awlen    ),
        .s_axi_awsize         ( MBUS_to_DDR4CH1_axi_awsize   ),
        .s_axi_awburst        ( MBUS_to_DDR4CH1_axi_awburst  ),
        .s_axi_awlock         ( MBUS_to_DDR4CH1_axi_awlock   ),
        .s_axi_awcache        ( MBUS_to_DDR4CH1_axi_awcache  ),
        .s_axi_awprot         ( MBUS_to_DDR4CH1_axi_awprot   ),
        .s_axi_awregion       ( MBUS_to_DDR4CH1_axi_awregion ),
        .s_axi_awqos          ( MBUS_to_DDR4CH1_axi_awqos    ),
        .s_axi_awvalid        ( MBUS_to_DDR4CH1_axi_awvalid  ),
        .s_axi_awready        ( MBUS_to_DDR4CH1_axi_awready  ),
        .s_axi_wdata          ( MBUS_to_DDR4CH1_axi_wdata    ),
        .s_axi_wstrb          ( MBUS_to_DDR4CH1_axi_wstrb    ),
        .s_axi_wlast          ( MBUS_to_DDR4CH1_axi_wlast    ),
        .s_axi_wvalid         ( MBUS_to_DDR4CH1_axi_wvalid   ),
        .s_axi_wready         ( MBUS_to_DDR4CH1_axi_wready   ),
        .s_axi_bid            ( MBUS_to_DDR4CH1_axi_bid      ),
        .s_axi_bresp          ( MBUS_to_DDR4CH1_axi_bresp    ),
        .s_axi_bvalid         ( MBUS_to_DDR4CH1_axi_bvalid   ),
        .s_axi_bready         ( MBUS_to_DDR4CH1_axi_bready   ),
        .s_axi_arid           ( MBUS_to_DDR4CH1_axi_arid     ),
        .s_axi_araddr         ( MBUS_to_DDR4CH1_axi_araddr   ),
        .s_axi_arlen          ( MBUS_to_DDR4CH1_axi_arlen    ),
        .s_axi_arsize         ( MBUS_to_DDR4CH1_axi_arsize   ),
        .s_axi_arburst        ( MBUS_to_DDR4CH1_axi_arburst  ),
        .s_axi_arlock         ( MBUS_to_DDR4CH1_axi_arlock   ),
        .s_axi_arcache        ( MBUS_to_DDR4CH1_axi_arcache  ),
        .s_axi_arprot         ( MBUS_to_DDR4CH1_axi_arprot   ),
        .s_axi_arregion       ( MBUS_to_DDR4CH1_axi_arregion ),
        .s_axi_arqos          ( MBUS_to_DDR4CH1_axi_arqos    ),
        .s_axi_arvalid        ( MBUS_to_DDR4CH1_axi_arvalid  ),
        .s_axi_arready        ( MBUS_to_DDR4CH1_axi_arready  ),
        .s_axi_rid            ( MBUS_to_DDR4CH1_axi_rid      ),
        .s_axi_rdata          ( MBUS_to_DDR4CH1_axi_rdata    ),
        .s_axi_rresp          ( MBUS_to_DDR4CH1_axi_rresp    ),
        .s_axi_rlast          ( MBUS_to_DDR4CH1_axi_rlast    ),
        .s_axi_rvalid         ( MBUS_to_DDR4CH1_axi_rvalid   ),
        .s_axi_rready         ( MBUS_to_DDR4CH1_axi_rready   )
    );

    //////////
    // HBUS //
    //////////

    highperformance_bus # (
        .HBUS_DATA_WIDTH  ( HBUS_DATA_WIDTH ),
        .HBUS_ADDR_WIDTH  ( HBUS_ADDR_WIDTH ),
        .HBUS_ID_WIDTH    ( HBUS_ID_WIDTH   ),
        .MBUS_DATA_WIDTH  ( MBUS_DATA_WIDTH ),
        .MBUS_ADDR_WIDTH  ( MBUS_ADDR_WIDTH ),
        .MBUS_ID_WIDTH    ( MBUS_ID_WIDTH   ),
        // Number of accelerator ports
        .NUM_ACC_MASTERS  ( NUM_HLS_CORES   ),
        // TODO: these are fixed for now
        .NUM_DDR_CHANNELS ( 1 ),
        .NUM_HBM_CHANNELS ( 0 )
    ) highperformance_bus_u (
        // MBUS domain clock and reset
        .main_clock_i        ( main_clk  ),
        .main_reset_ni       ( main_rstn ),
        // From MBUS
        .s_MBUS_axi_awid     ( MBUS_to_HBUS_axi_awid     ),
        .s_MBUS_axi_awaddr   ( MBUS_to_HBUS_axi_awaddr   ),
        .s_MBUS_axi_awlen    ( MBUS_to_HBUS_axi_awlen    ),
        .s_MBUS_axi_awsize   ( MBUS_to_HBUS_axi_awsize   ),
        .s_MBUS_axi_awburst  ( MBUS_to_HBUS_axi_awburst  ),
        .s_MBUS_axi_awlock   ( MBUS_to_HBUS_axi_awlock   ),
        .s_MBUS_axi_awcache  ( MBUS_to_HBUS_axi_awcache  ),
        .s_MBUS_axi_awprot   ( MBUS_to_HBUS_axi_awprot   ),
        .s_MBUS_axi_awregion ( MBUS_to_HBUS_axi_awregion ),
        .s_MBUS_axi_awqos    ( MBUS_to_HBUS_axi_awqos    ),
        .s_MBUS_axi_awvalid  ( MBUS_to_HBUS_axi_awvalid  ),
        .s_MBUS_axi_awready  ( MBUS_to_HBUS_axi_awready  ),
        .s_MBUS_axi_wdata    ( MBUS_to_HBUS_axi_wdata    ),
        .s_MBUS_axi_wstrb    ( MBUS_to_HBUS_axi_wstrb    ),
        .s_MBUS_axi_wlast    ( MBUS_to_HBUS_axi_wlast    ),
        .s_MBUS_axi_wvalid   ( MBUS_to_HBUS_axi_wvalid   ),
        .s_MBUS_axi_wready   ( MBUS_to_HBUS_axi_wready   ),
        .s_MBUS_axi_bid      ( MBUS_to_HBUS_axi_bid      ),
        .s_MBUS_axi_bresp    ( MBUS_to_HBUS_axi_bresp    ),
        .s_MBUS_axi_bvalid   ( MBUS_to_HBUS_axi_bvalid   ),
        .s_MBUS_axi_bready   ( MBUS_to_HBUS_axi_bready   ),
        .s_MBUS_axi_arid     ( MBUS_to_HBUS_axi_arid     ),
        .s_MBUS_axi_araddr   ( MBUS_to_HBUS_axi_araddr   ),
        .s_MBUS_axi_arlen    ( MBUS_to_HBUS_axi_arlen    ),
        .s_MBUS_axi_arsize   ( MBUS_to_HBUS_axi_arsize   ),
        .s_MBUS_axi_arburst  ( MBUS_to_HBUS_axi_arburst  ),
        .s_MBUS_axi_arlock   ( MBUS_to_HBUS_axi_arlock   ),
        .s_MBUS_axi_arcache  ( MBUS_to_HBUS_axi_arcache  ),
        .s_MBUS_axi_arprot   ( MBUS_to_HBUS_axi_arprot   ),
        .s_MBUS_axi_arregion ( MBUS_to_HBUS_axi_arregion ),
        .s_MBUS_axi_arqos    ( MBUS_to_HBUS_axi_arqos    ),
        .s_MBUS_axi_arvalid  ( MBUS_to_HBUS_axi_arvalid  ),
        .s_MBUS_axi_arready  ( MBUS_to_HBUS_axi_arready  ),
        .s_MBUS_axi_rid      ( MBUS_to_HBUS_axi_rid      ),
        .s_MBUS_axi_rdata    ( MBUS_to_HBUS_axi_rdata    ),
        .s_MBUS_axi_rresp    ( MBUS_to_HBUS_axi_rresp    ),
        .s_MBUS_axi_rlast    ( MBUS_to_HBUS_axi_rlast    ),
        .s_MBUS_axi_rvalid   ( MBUS_to_HBUS_axi_rvalid   ),
        .s_MBUS_axi_rready   ( MBUS_to_HBUS_axi_rready   ),
        // To MBUS
        .m_MBUS_axi_awid     ( HBUS_to_MBUS_axi_awid     ),
        .m_MBUS_axi_awaddr   ( HBUS_to_MBUS_axi_awaddr   ),
        .m_MBUS_axi_awlen    ( HBUS_to_MBUS_axi_awlen    ),
        .m_MBUS_axi_awsize   ( HBUS_to_MBUS_axi_awsize   ),
        .m_MBUS_axi_awburst  ( HBUS_to_MBUS_axi_awburst  ),
        .m_MBUS_axi_awlock   ( HBUS_to_MBUS_axi_awlock   ),
        .m_MBUS_axi_awcache  ( HBUS_to_MBUS_axi_awcache  ),
        .m_MBUS_axi_awprot   ( HBUS_to_MBUS_axi_awprot   ),
        .m_MBUS_axi_awregion ( HBUS_to_MBUS_axi_awregion ),
        .m_MBUS_axi_awqos    ( HBUS_to_MBUS_axi_awqos    ),
        .m_MBUS_axi_awvalid  ( HBUS_to_MBUS_axi_awvalid  ),
        .m_MBUS_axi_awready  ( HBUS_to_MBUS_axi_awready  ),
        .m_MBUS_axi_wdata    ( HBUS_to_MBUS_axi_wdata    ),
        .m_MBUS_axi_wstrb    ( HBUS_to_MBUS_axi_wstrb    ),
        .m_MBUS_axi_wlast    ( HBUS_to_MBUS_axi_wlast    ),
        .m_MBUS_axi_wvalid   ( HBUS_to_MBUS_axi_wvalid   ),
        .m_MBUS_axi_wready   ( HBUS_to_MBUS_axi_wready   ),
        .m_MBUS_axi_bid      ( HBUS_to_MBUS_axi_bid      ),
        .m_MBUS_axi_bresp    ( HBUS_to_MBUS_axi_bresp    ),
        .m_MBUS_axi_bvalid   ( HBUS_to_MBUS_axi_bvalid   ),
        .m_MBUS_axi_bready   ( HBUS_to_MBUS_axi_bready   ),
        .m_MBUS_axi_arid     ( HBUS_to_MBUS_axi_arid     ),
        .m_MBUS_axi_araddr   ( HBUS_to_MBUS_axi_araddr   ),
        .m_MBUS_axi_arlen    ( HBUS_to_MBUS_axi_arlen    ),
        .m_MBUS_axi_arsize   ( HBUS_to_MBUS_axi_arsize   ),
        .m_MBUS_axi_arburst  ( HBUS_to_MBUS_axi_arburst  ),
        .m_MBUS_axi_arlock   ( HBUS_to_MBUS_axi_arlock   ),
        .m_MBUS_axi_arcache  ( HBUS_to_MBUS_axi_arcache  ),
        .m_MBUS_axi_arprot   ( HBUS_to_MBUS_axi_arprot   ),
        .m_MBUS_axi_arregion ( HBUS_to_MBUS_axi_arregion ),
        .m_MBUS_axi_arqos    ( HBUS_to_MBUS_axi_arqos    ),
        .m_MBUS_axi_arvalid  ( HBUS_to_MBUS_axi_arvalid  ),
        .m_MBUS_axi_arready  ( HBUS_to_MBUS_axi_arready  ),
        .m_MBUS_axi_rid      ( HBUS_to_MBUS_axi_rid      ),
        .m_MBUS_axi_rdata    ( HBUS_to_MBUS_axi_rdata    ),
        .m_MBUS_axi_rresp    ( HBUS_to_MBUS_axi_rresp    ),
        .m_MBUS_axi_rlast    ( HBUS_to_MBUS_axi_rlast    ),
        .m_MBUS_axi_rvalid   ( HBUS_to_MBUS_axi_rvalid   ),
        .m_MBUS_axi_rready   ( HBUS_to_MBUS_axi_rready   ),
        // From Accelerator(s)
        // TODO: add a CONCAT to support multiple ports
        `ASSIGN_AXI_PORT(s_acc0, HLS_MASTER0_to_HBUS),
        `ASSIGN_AXI_PORT(s_acc1, HLS_MASTER1_to_HBUS),
        `ASSIGN_AXI_PORT(s_acc2, HLS_MASTER2_to_HBUS),
        `ASSIGN_AXI_PORT(s_acc3, HLS_MASTER3_to_HBUS),
        `ASSIGN_AXI_PORT(s_acc4, HLS_MASTER4_to_HBUS),
        `ASSIGN_AXI_PORT(s_acc5, HLS_MASTER5_to_HBUS),
        `ASSIGN_AXI_PORT(s_acc6, HLS_MASTER6_to_HBUS),
        `ASSIGN_AXI_PORT(s_acc7, HLS_MASTER7_to_HBUS),

        // DDR channel 0 on MBUS
        // DDR4 differential clock
        .clk_300mhz_x_p_i     ( clk_300mhz_0_p_i  ),
        .clk_300mhz_x_n_i     ( clk_300mhz_0_n_i  ),
        // DDR4 user clock and reset
        .clk_300MHz_o         ( clk_300MHz        ),
        .rstn_300MHz_o        ( rstn_300MHz       ),
        // Connect DDR4 channel 0
        .cx_ddr4_adr          ( c0_ddr4_adr       ),
        .cx_ddr4_ba           ( c0_ddr4_ba        ),
        .cx_ddr4_cke          ( c0_ddr4_cke       ),
        .cx_ddr4_cs_n         ( c0_ddr4_cs_n      ),
        .cx_ddr4_dq           ( c0_ddr4_dq        ),
        .cx_ddr4_dqs_t        ( c0_ddr4_dqs_t     ),
        .cx_ddr4_dqs_c        ( c0_ddr4_dqs_c     ),
        .cx_ddr4_odt          ( c0_ddr4_odt       ),
        .cx_ddr4_parity       ( c0_ddr4_parity    ),
        .cx_ddr4_bg           ( c0_ddr4_bg        ),
        .cx_ddr4_act_n        ( c0_ddr4_act_n     ),
        .cx_ddr4_reset_n      ( c0_ddr4_reset_n   ),
        .cx_ddr4_ck_t         ( c0_ddr4_ck_t      ),
        .cx_ddr4_ck_c         ( c0_ddr4_ck_c      ),

        // AXILITE interface - for ECC status and control - not connected
        .s_ctrl_axilite_awvalid  ( 1'b0  ),
        .s_ctrl_axilite_awready  (       ),
        .s_ctrl_axilite_awaddr   ( '0    ),
        .s_ctrl_axilite_wvalid   ( 1'b0  ),
        .s_ctrl_axilite_wready   (       ),
        .s_ctrl_axilite_wdata    ( '0    ),
        .s_ctrl_axilite_bvalid   (       ),
        .s_ctrl_axilite_bready   ( 1'b1  ),
        .s_ctrl_axilite_bresp    (       ),
        .s_ctrl_axilite_arvalid  ( 1'b0  ),
        .s_ctrl_axilite_arready  (       ),
        .s_ctrl_axilite_araddr   ( '0    ),
        .s_ctrl_axilite_rvalid   (       ),
        .s_ctrl_axilite_rready   ( 1'b1  ),
        .s_ctrl_axilite_rdata    (       ),
        .s_ctrl_axilite_rresp    (       ),
        .s_ctrl_axilite_arprot   ( '0    ),
        .s_ctrl_axilite_wstrb    ( '0    ),
        .s_ctrl_axilite_awprot   ( '0    )
    );

`endif // HPC


endmodule : uninasoc
