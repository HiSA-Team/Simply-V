// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description: Basic system variables for UninaSoC

package uninasoc_pkg;

    ///////////////////////
    // SoC-level defines //
    ///////////////////////

    // GPIO widths
    localparam int unsigned GPIO_IN_WIDTH  = 16;
    localparam int unsigned GPIO_OUT_WIDTH = 16;

    // MBUS widths
    localparam MBUS_DATA_WIDTH = `MBUS_DATA_WIDTH; // From SoC config
    localparam MBUS_ADDR_WIDTH = `MBUS_ADDR_WIDTH; // From SoC config
    localparam MBUS_ID_WIDTH   = `MBUS_ID_WIDTH;   // From MBUS config

    // PBUS widths
    localparam PBUS_DATA_WIDTH = 32; // Fixed 32-bits
    localparam PBUS_ADDR_WIDTH = 32; // Fixed 32-bits
    localparam PBUS_ID_WIDTH = `PBUS_ID_WIDTH; // From PBUS config

    // HBUS widths
    localparam int unsigned HBUS_DATA_WIDTH = 512; // Same as DRAM channels
    localparam int unsigned HBUS_ADDR_WIDTH = `MBUS_ADDR_WIDTH; // Same as MBUS
    localparam int unsigned HBUS_ID_WIDTH   = `HBUS_ID_WIDTH; // From HBUS config

    ///////////////////////
    // AXI main crossbar //
    ///////////////////////

    // Main Crosbar masters
    localparam int unsigned MBUS_NUM_SI = `MBUS_NUM_SI;
    // Main Crosbar slaves
    localparam int unsigned MBUS_NUM_MI = `MBUS_NUM_MI;

    /////////////////////////////
    // AXI Lite peripheral bus //
    /////////////////////////////

    // Always assume 1 master
    // Peripheral bus slaves
    localparam int unsigned PBUS_NUM_MI = `PBUS_NUM_MI;

    //////////////////////////
    // High-performance bus //
    //////////////////////////
    localparam int unsigned HBUS_NUM_SI = `HBUS_NUM_SI;
    localparam int unsigned HBUS_NUM_MI = `HBUS_NUM_MI;


    //////////////////////////
    // Supported Processors //
    //////////////////////////

    typedef enum int unsigned {
        // 32-bits Cores
        CORE_PICORV32,
        CORE_CV32E40P,
        CORE_IBEX,
        CORE_MICROBLAZEV_RV32,
        // 64-bits Cores
        CORE_MICROBLAZEV_RV64,
        CORE_CV64A6
    } core_selector_t;

    // Select core from macro
    localparam core_selector_t CORE_SELECTOR = `CORE_SELECTOR;

    ///////////////////////
    // System Interrupts //
    ///////////////////////

    // Masters and Buses (Slves) can generate interrupts, which are forwarded to the PLIC (Platform interrupts).
    // The PLIC forwards interrupts to the Masters (e.g. the Socket)

    // RISC-V cores standard interrupts
    localparam int unsigned CORE_SW_INTERRUPT = 3;      // Inter Processor Interrupts
    localparam int unsigned CORE_TIM_INTERRUPT = 7;     // Real-time Clock Timer
    localparam int unsigned CORE_EXT_INTERRUPT = 11;    // PLIC-to-hart interrupts

    // Peripheral Bus interrupts
    localparam int unsigned PBUS_GPIOIN_INTERRUPT = 0;      // GPIO In [embedded only]
    localparam int unsigned PBUS_TIM0_INTERRUPT = 1;        // Timer 0
    localparam int unsigned PBUS_TIM1_INTERRUPT = 2;        // Timer 1
    localparam int unsigned PBUS_UART_INTERRUPT = 3;        // UART

    // PLIC Interrupts mapping
    // We support 32 possible sources of platform interrupts, which are statically mapped
    // regardless of the configuration.
    // TODO154: this is static for now, must generate by config
    localparam int unsigned PLIC_RESERVED_INTERRUPT = 0;    // PLIC line 0 is reserved
    localparam int unsigned PLIC_GPIOIN_INTERRUPT = 1;      // GPIO In (From PBUS)[embedded only]
    localparam int unsigned PLIC_TIM0_INTERRUPT = 2;        // Timer 0 (From PBUS)
    localparam int unsigned PLIC_TIM1_INTERRUPT = 3;        // Timer 1 (From PBUS)
    localparam int unsigned PLIC_UART_INTERRUPT = 4;        // UART    (From PBUS)
    localparam int unsigned PLIC_HLS_INTERRUPT = 5;         // HLS     (From HLS core) [HPC only]

    ///////////////
    // Functions //
    ///////////////

    // This function is used to turn a core_selector id into the corresponding core name string
    function string core_selector_to_string(input int core_sel);
        case (core_sel)
            CORE_PICORV32:     return "CORE_PICORV32";
            CORE_CV32E40P:     return "CORE_CV32E40P";
            CORE_IBEX:         return "CORE_IBEX";
            CORE_MICROBLAZEV_RV32:  return "CORE_MICROBLAZEV_RV32";
            CORE_MICROBLAZEV_RV64:  return "CORE_MICROBLAZEV_RV64";
            default:           return $sformatf("UNKNOWN_CORE_%0d", core_sel);
        endcase
    endfunction

endpackage : uninasoc_pkg
