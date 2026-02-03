// Author: Manuel Maddaluno     <manuel.maddaluno@unina.it>
// Description: Utility variables and macros for APB interconnections
// Note: The main rationale behind this macro is to avoid the usage of structs and
//       macros for the widest possible syntax compatibility.
//       For now, the APB protocol is only used for accessing the APB interface of the HBM IP

`ifndef UNINASOC_APB_SVH__
`define UNINASOC_APB_SVH__

////////////////////////////////////////
//    __  __   _   ___ ___  ___       //
//   |  \/  | /_\ / __| _ \/ _ \ ___  //
//   | |\/| |/ _ \ (__|   / (_) (_-<  //
//   |_|  |_/_/ \_\___|_|_\\___//__/  //
//                                    //
////////////////////////////////////////

////////////////////////
//  Bus Declaration   //
////////////////////////

// Declare APB bus specifying ADDR_WIDTH, DATA_WIDTH and NUM_SLAVES
`define DECLARE_APB_BUS(bus_name, DATA_WIDTH, ADDR_WIDTH, NUM_SLAVES) \
    logic [ADDR_WIDTH-1 : 0]     ``bus_name``_apb_paddr;              \
    logic [DATA_WIDTH-1 : 0]     ``bus_name``_apb_pwdata;             \
    logic [DATA_WIDTH-1 : 0]     ``bus_name``_apb_prdata;             \
    logic                        ``bus_name``_apb_penable;            \
    logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_psel;               \
    logic                        ``bus_name``_apb_pwrite;             \
    logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_pready;             \
    logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_pslverr;


//////////////////////
// Ports Declaration //
//////////////////////

// APB master ports
`define DEFINE_APB_MASTER_PORTS(bus_name, DATA_WIDTH, ADDR_WIDTH, NUM_SLAVES) \
    output logic [ADDR_WIDTH-1 : 0]     ``bus_name``_apb_paddr,               \
    output logic [DATA_WIDTH-1 : 0]     ``bus_name``_apb_pwdata,              \
    input  logic [DATA_WIDTH-1 : 0]     ``bus_name``_apb_prdata,              \
    output logic                        ``bus_name``_apb_penable,             \
    output logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_psel,                \
    output logic                        ``bus_name``_apb_pwrite,              \
    input  logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_pready,              \
    input  logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_pslverr

// APB slave ports
`define DEFINE_APB_SLAVE_PORTS(bus_name, DATA_WIDTH, ADDR_WIDTH, NUM_SLAVES)  \
    input  logic [ADDR_WIDTH-1 : 0]     ``bus_name``_apb_paddr,               \
    input  logic [DATA_WIDTH-1 : 0]     ``bus_name``_apb_pwdata,              \
    output logic [DATA_WIDTH-1 : 0]     ``bus_name``_apb_prdata,              \
    input  logic                        ``bus_name``_apb_penable,             \
    input  logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_psel,                \
    input  logic                        ``bus_name``_apb_pwrite,              \
    output logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_pready,              \
    output logic [NUM_SLAVES-1 : 0]     ``bus_name``_apb_pslverr


`endif // UNINASOC_APB_SVH__