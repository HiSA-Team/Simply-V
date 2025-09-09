`include "uninasoc_axi.svh"

module packet_transmitter (
    input   logic        clock_i,
    input   logic        reset_ni,

    /* Custom interface from the rule-match engine */
    `DEFINE_MATCH_SLAVE_PORT(s),

    /* AXI4 Slave port from the core (unused for now to do) */
    `DEFINE_AXI4_SLAVE_PORT(s),

    /* AXI Stream master interface to the network */
    `DEFINE_AXIS_MASTER_PORT(m)
);


/* Simply sync the AXI4 slave interface from the core */
assign s_axi_awready = 1;
assign s_axi_wready  = 1;
assign s_axi_bid     = 0;
assign s_axi_bresp   = 2'b00;
assign s_axi_bvalid  = 1;
assign s_axi_arready = 1;
assign s_axi_rid     = 0;
assign s_axi_rdata   = 0;
assign s_axi_rresp   = 2'b00;
assign s_axi_rlast   = 1;
assign s_axi_rvalid  = 1;


localparam S_IDLE = 1'b0;
localparam S_BUSY = 1'b1;  /* Serving a match */


logic current_state;
logic next_state;

logic [15:0] seg_tx_cnt; /* 64 bytes segment transmitted */
logic [7:0]  match_addr_buffer;
logic [15:0] match_pkt_len_buffer;

logic [7:0]  rd_addr_ram;
logic [AXIS_DATA_WIDTH-1:0] data_out_ram;


always_ff @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        current_state <= S_IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

always_comb begin
    next_state = current_state;

    case (current_state)

        S_IDLE : begin
            if ( s_match_valid == 1'b1 && s_match_ready == 1'b1 ) begin
                next_state = S_BUSY;
            end
            else begin
                next_state = current_state;
            end
        end

        S_BUSY : begin
            if ( seg_tx_cnt == match_pkt_len_buffer ) begin
                next_state = S_IDLE;
            end
            else begin
                next_state = current_state;
            end
        end
    endcase
end

always_ff @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        match_addr_buffer      <= 'b0;
        match_pkt_len_buffer   <= 'b0;
        s_match_ready          <= 1'b0;
    end
    else begin
        if ( current_state == S_IDLE && s_match_valid == 1'b1 && !s_match_ready) begin
            s_match_ready <= 1'b1;
        end
        else if ( current_state == S_IDLE && s_match_valid == 1'b1 && s_match_ready == 1'b1) begin
            match_addr_buffer      <= s_match_addr;
            match_pkt_len_buffer   <= s_match_pkt_len;
            s_match_ready <= 1'b0;
        end
        else begin
            match_addr_buffer      <= match_addr_buffer;
            match_pkt_len_buffer   <= match_pkt_len_buffer;
            s_match_ready          <= 1'b0;
        end
    end
end

always_ff @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        seg_tx_cnt <= 'b0;
    end
    else begin
        if ( current_state == S_BUSY ) begin
            seg_tx_cnt <= seg_tx_cnt + 1'b1;
        end
        else if (current_state == S_IDLE) begin
            seg_tx_cnt <= 'b0;
        end
        else begin
            seg_tx_cnt <= 'b0;
        end
    end
end

always_ff @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        rd_addr_ram <= 'b0;
    end
    else begin
        if ( current_state == S_IDLE && s_match_valid == 1'b1 &&  s_match_ready == 1'b1) begin
            rd_addr_ram <= s_match_addr;
        end
        else if ( current_state == S_BUSY /*&& m_axis_tready*/ ) begin
            rd_addr_ram <= rd_addr_ram + 1;
        end
        else if (current_state == S_IDLE) begin
            rd_addr_ram <= 'b0;
        end
        else begin
            rd_addr_ram <= 'b0;
        end
    end
end

/* We are not considering the m_axis_tready signal, but we are the only one that talk to the CMAC, tready is assumed always up... this is just a PoC */
always_ff @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        m_axis_tvalid <= 1'b0;
        m_axis_tdata  <= 'b0;
        m_axis_tkeep  <= 'b0;
        m_axis_tlast  <= 1'b0;
    end
    else begin
        if ( current_state == S_BUSY ) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= data_out_ram;
            m_axis_tkeep  <= { AXIS_KEEP_WIDTH { 1'b1 } };
            m_axis_tlast  <= 1'b0;
        end
        else if ( current_state == S_BUSY && seg_tx_cnt == match_pkt_len_buffer ) begin
            m_axis_tvalid <= 1'b1;
            m_axis_tdata  <= data_out_ram;
            m_axis_tkeep  <= { AXIS_KEEP_WIDTH { 1'b1 } };
            m_axis_tlast  <= 1'b1;
        end
        else if ( current_state == S_IDLE )  begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 'b0;
            m_axis_tkeep  <= { AXIS_KEEP_WIDTH { 1'b0 } };
            m_axis_tlast  <= 1'b0;
        end
    end
end

/* TO DO */
reg [7:0] ram_wr_addr;
reg [AXIS_DATA_WIDTH-1:0] ram_data_in;
reg ram_wr_en;

always_ff @ (posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        ram_wr_en   <= 'b1;
        ram_wr_addr <= 'b0;
        ram_data_in <= 512'h9921400a9a210a08010100007eff00021880e0547408d90a65a7f4c4401f0100007f0100007f3acf06400040316c8a0100450008000000000000000000000000;
    end
    else begin
        ram_wr_addr <= ram_wr_addr + 1'b1;
        ram_wr_en   <= 1'b1;
        ram_data_in <= 512'h9921400a9a210a08010100007eff00021880e0547408d90a65a7f4c4401f0100007f0100007f3acf06400040316c8a0100450008000000000000000000000000/*ram_data_in + { {AXIS_DATA_WIDTH/2{1'b1}} , {AXIS_DATA_WIDTH/2{1'b0}} }*/ ;
    end
end

lut_ram #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .ADDR_WIDTH(8)
) packet_memory (
    .data_in(ram_data_in),
    .read_addr(rd_addr_ram),
    .write_addr(ram_wr_addr),
    .wr_en(ram_wr_en),
    .clk(clock_i),
    .data_out(data_out_ram)
);

endmodule