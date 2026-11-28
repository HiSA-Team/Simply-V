// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description: Single AXI memory slave that selects the channel wrapper for
//              the active build profile; unused DDR pins remain unconnected.
//              Add the DDR3 pin interface and channel wrapper when supported.

`include "simplyv_axi.svh"
`include "simplyv_ddr2.svh"
`include "simplyv_ddr4.svh"

module ddr_wrapper # (
    parameter string         DDR_TYPE         = "DDR4",
    parameter int unsigned   ENABLE_CACHE     = 0,
    parameter int unsigned   LOCAL_DATA_WIDTH = 32,
    parameter int unsigned   LOCAL_ADDR_WIDTH = 32,
    parameter int unsigned   LOCAL_ID_WIDTH   = 32
) (
    // SoC clock and reset
    input logic clock_i,
    input logic reset_ni,

    // DDR2 MIG clock and physical interface
    input logic sys_clk_i,
    input logic sys_reset_ni,
    `DEFINE_DDR2_PORTS,

    // DDR4 MIG differential clock and physical interface
    input logic clk_300mhz_x_p_i,
    input logic clk_300mhz_x_n_i,
    `DEFINE_DDR4_PORTS(x),

    // DDR user clock and reset
    output logic ddr_clk_o,
    output logic ddr_rst_o,

    // AXI4 memory slave interface
    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
);

`ifdef EMBEDDED
    generate
        if (DDR_TYPE == "DDR2") begin : gen_ddr2
            ddr2_channel_wrapper # (
                .LOCAL_DATA_WIDTH ( LOCAL_DATA_WIDTH ),
                .LOCAL_ADDR_WIDTH ( LOCAL_ADDR_WIDTH ),
                .LOCAL_ID_WIDTH   ( LOCAL_ID_WIDTH   )
            ) ddr2_channel_wrapper_u (
                .init_calib_complete_o (),
                .*
            );
        end else begin : gen_unsupported_ddr
            initial begin
                $error("Unsupported DDR_TYPE %s for EMBEDDED profile.", DDR_TYPE);
            end
        end
    endgenerate
`elsif HPC
    generate
        if (DDR_TYPE == "DDR4") begin : gen_ddr4
            ddr4_channel_wrapper # (
                .ENABLE_CACHE     ( ENABLE_CACHE     ),
                .LOCAL_DATA_WIDTH ( LOCAL_DATA_WIDTH ),
                .LOCAL_ADDR_WIDTH ( LOCAL_ADDR_WIDTH ),
                .LOCAL_ID_WIDTH   ( LOCAL_ID_WIDTH   )
            ) ddr4_channel_wrapper_u (
                // AXI-Lite ECC control is not used by this configuration.
                .s_ctrl_axilite_awaddr  ('0),
                .s_ctrl_axilite_awprot  ('0),
                .s_ctrl_axilite_awvalid (1'b0),
                .s_ctrl_axilite_awready (),
                .s_ctrl_axilite_wdata   ('0),
                .s_ctrl_axilite_wstrb   ('0),
                .s_ctrl_axilite_wvalid  (1'b0),
                .s_ctrl_axilite_wready  (),
                .s_ctrl_axilite_bresp   (),
                .s_ctrl_axilite_bvalid  (),
                .s_ctrl_axilite_bready  (1'b1),
                .s_ctrl_axilite_araddr  ('0),
                .s_ctrl_axilite_arprot  ('0),
                .s_ctrl_axilite_arvalid (1'b0),
                .s_ctrl_axilite_arready (),
                .s_ctrl_axilite_rdata   (),
                .s_ctrl_axilite_rresp   (),
                .s_ctrl_axilite_rvalid  (),
                .s_ctrl_axilite_rready  (1'b1),
                .*
            );
        end else begin : gen_unsupported_ddr
            initial begin
                $error("Unsupported DDR_TYPE %s for HPC profile.", DDR_TYPE);
            end
        end
    endgenerate
`else
    initial begin
        $error("ddr_wrapper requires the EMBEDDED or HPC build profile.");
    end
`endif

endmodule : ddr_wrapper
