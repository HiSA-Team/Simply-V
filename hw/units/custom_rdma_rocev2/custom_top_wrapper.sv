// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: Top level wrapper for RDMA RoCEv2 stack.


module custom_top_wrapper #(

 //////////////////////////////////////
 // Add here IP-related parameters //
 //////////////////////////////////////

 parameter int unsigned MAC_DATA_WIDTH = 1024,
 parameter int unsigned STACK_DATA_WIDTH = 1024,
 parameter int unsigned FIFO_REGS = 4,
 parameter logic [7:0] ENABLE_PFC = 8'h0,
 parameter int unsigned DEBUG = 0

) (

 ///////////////////////////////////
 // Add here IP-related signals //
 ///////////////////////////////////

 // Clock and reset (MAC vs stack domains)
 input logic clk_mac,
 input logic rst_mac,
 input logic clk_stack,
 input logic rst_stack,

 // Flow control (stack clock domain)
 input logic flow_ctrl_pause,

 ////////////////////////////
 // Ethernet AXI-Stream //
 ////////////////////////////

 // TX toward MAC
 output logic [MAC_DATA_WIDTH-1:0] m_eth_tx_axis_tdata,
 output logic [MAC_DATA_WIDTH/8-1:0] m_eth_tx_axis_tkeep,
 output logic m_eth_tx_axis_tvalid,
 input logic m_eth_tx_axis_tready,
 output logic m_eth_tx_axis_tlast,
 output logic m_eth_tx_axis_tuser,

 // RX from MAC
 input logic [MAC_DATA_WIDTH-1:0] s_eth_rx_axis_tdata,
 input logic [MAC_DATA_WIDTH/8-1:0] s_eth_rx_axis_tkeep,
 input logic s_eth_rx_axis_tvalid,
 output logic s_eth_rx_axis_tready,
 input logic s_eth_rx_axis_tlast,
 input logic s_eth_rx_axis_tuser,

 // Pause (IEEE 802.3 PFC path when ENABLE_PFC != 0)
 input logic [7:0] pfc_pause_req,
 output logic [7:0] pfc_pause_ack,

 ////////////////////
 // QP state spy //
 ////////////////////

 input logic m_qp_context_spy,
 input logic [23:0] m_qp_local_qpn_spy,
 output logic s_qp_spy_context_valid,
 output logic [2:0] s_qp_spy_state,
 output logic [23:0] s_qp_spy_rem_qpn,
 output logic [23:0] s_qp_spy_loc_qpn,
 output logic [23:0] s_qp_spy_rem_psn,
 output logic [23:0] s_qp_spy_rem_acked_psn,
 output logic [23:0] s_qp_spy_loc_psn,
 output logic [31:0] s_qp_spy_r_key,
 output logic [63:0] s_qp_spy_rem_addr,
 output logic [31:0] s_qp_spy_rem_ip_addr,
 output logic [7:0] s_qp_spy_syndrome,

 /////////////////////////
 // Control registers //
 /////////////////////////

 input logic [47:0] ctrl_local_mac_address,
 input logic [31:0] ctrl_local_ip,
 input logic ctrl_clear_arp_cache,
 input logic [2:0] ctrl_pmtu,
 input logic [15:0] ctrl_RoCE_udp_port,
 input logic [2:0] ctrl_priority_tag,

 //////////////////////
 // Status / debug //
 //////////////////////

 output logic stat_test,

 /////////////////////
 // Perf monitor //
 /////////////////////

 input logic [3:0] cfg_latency_avg_po2,
 input logic [4:0] cfg_throughput_avg_po2,
 input logic [23:0] monitor_loc_qpn,
 output logic [31:0] transfer_time_avg,
 output logic [31:0] transfer_time_moving_avg,
 output logic [31:0] transfer_time_inst,
 output logic [31:0] latency_avg,
 output logic [31:0] latency_moving_avg,
 output logic [31:0] latency_inst
);

 network_wrapper_roce_generic #(
 .MAC_DATA_WIDTH ( MAC_DATA_WIDTH ),
 .STACK_DATA_WIDTH ( STACK_DATA_WIDTH ),
 .FIFO_REGS ( FIFO_REGS ),
 .ENABLE_PFC ( ENABLE_PFC ),
 .DEBUG ( DEBUG )
 ) u_net (
 // Clock and reset
 .clk_mac ( clk_mac ),
 .rst_mac ( rst_mac ),
 .clk_stack ( clk_stack ),
 .rst_stack ( rst_stack ),
 .flow_ctrl_pause ( flow_ctrl_pause ),

 // Ethernet AXI-Stream
 .m_network_tx_axis_tdata ( m_eth_tx_axis_tdata ),
 .m_network_tx_axis_tkeep ( m_eth_tx_axis_tkeep ),
 .m_network_tx_axis_tvalid ( m_eth_tx_axis_tvalid ),
 .m_network_tx_axis_tready ( m_eth_tx_axis_tready ),
 .m_network_tx_axis_tlast ( m_eth_tx_axis_tlast ),
 .m_network_tx_axis_tuser ( m_eth_tx_axis_tuser ),

 .s_network_rx_axis_tdata ( s_eth_rx_axis_tdata ),
 .s_network_rx_axis_tkeep ( s_eth_rx_axis_tkeep ),
 .s_network_rx_axis_tvalid ( s_eth_rx_axis_tvalid ),
 .s_network_rx_axis_tready ( s_eth_rx_axis_tready ),
 .s_network_rx_axis_tlast ( s_eth_rx_axis_tlast ),
 .s_network_rx_axis_tuser ( s_eth_rx_axis_tuser ),

 // Pause
 .pfc_pause_req ( pfc_pause_req ),
 .pfc_pause_ack ( pfc_pause_ack ),

 // QP spy
 .m_qp_context_spy ( m_qp_context_spy ),
 .m_qp_local_qpn_spy ( m_qp_local_qpn_spy ),
 .s_qp_spy_context_valid ( s_qp_spy_context_valid ),
 .s_qp_spy_state ( s_qp_spy_state ),
 .s_qp_spy_rem_qpn ( s_qp_spy_rem_qpn ),
 .s_qp_spy_loc_qpn ( s_qp_spy_loc_qpn ),
 .s_qp_spy_rem_psn ( s_qp_spy_rem_psn ),
 .s_qp_spy_rem_acked_psn ( s_qp_spy_rem_acked_psn ),
 .s_qp_spy_loc_psn ( s_qp_spy_loc_psn ),
 .s_qp_spy_r_key ( s_qp_spy_r_key ),
 .s_qp_spy_rem_addr ( s_qp_spy_rem_addr ),
 .s_qp_spy_rem_ip_addr ( s_qp_spy_rem_ip_addr ),
 .s_qp_spy_syndrome ( s_qp_spy_syndrome ),

 // Control
 .ctrl_local_mac_address ( ctrl_local_mac_address ),
 .ctrl_local_ip ( ctrl_local_ip ),
 .ctrl_clear_arp_cache ( ctrl_clear_arp_cache ),
 .ctrl_pmtu ( ctrl_pmtu ),
 .ctrl_RoCE_udp_port ( ctrl_RoCE_udp_port ),
 .ctrl_priority_tag ( ctrl_priority_tag ),

 // Status / perf
 .stat_test ( stat_test ),
 .cfg_latency_avg_po2 ( cfg_latency_avg_po2 ),
 .cfg_throughput_avg_po2 ( cfg_throughput_avg_po2 ),
 .monitor_loc_qpn ( monitor_loc_qpn ),
 .transfer_time_avg ( transfer_time_avg ),
 .transfer_time_moving_avg ( transfer_time_moving_avg ),
 .transfer_time_inst ( transfer_time_inst ),
 .latency_avg ( latency_avg ),
 .latency_moving_avg ( latency_moving_avg ),
 .latency_inst ( latency_inst )
);

endmodule : custom_top_wrapper