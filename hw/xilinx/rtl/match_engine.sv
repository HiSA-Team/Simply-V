// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Author: Rocco Marotta <roc.marotta@studenti.unina.it>
// Description: This is a rule-match engine coupled with the network interface (CMAC).
//              Each packet arrives at this module that checks every bytes against its internal rules,
//              if there is a match a signal is asserted.
//              This logic relizes the lowest latency path from the arrival of any network packets


`include "uninasoc_axi.svh"


    localparam int unsigned NUM_RULES = 16;
    localparam int unsigned PACKET_MAX_SIZE = 4096;
    localparam int unsigned MAX_SOP_TERMS = 4;


    typedef enum bit [2:0] {
        EQ = 3'b000,
        GT = 3'b001,
        LT = 3'b010,
        GE = 3'b011,
        LE = 3'b100
    } compare_symbol_e;

    typedef struct packed {
        logic [11:0] addr;
        logic [7:0]  value;
        compare_symbol_e symbol;
        // logic [31:0] packet_tx_addr;
        logic [7:0] packet_tx_addr;      // Reduce this address to fit 32 bits rules
        logic        enable;
    } rule_entry_t;


module match_engine #(
    parameter PKT_DATA_WIDTH = AXIS_TDATA_WIDTH,
    parameter PKT_KSTRB_WIDTH = AXIS_TKEEP_WIDTH

) (
    // Clock and reset
    input logic clock_i,
    input logic reset_ni,

    // Rules clock and reset for AXI Lite interface (rules management)
    input logic rules_clock_i,
    input logic rules_reset_ni,

    // AXIS rx interface from the CMAC
    `DEFINE_AXIS_SLAVE_PORTS(s),

    // AXILite interface to let the processor update the rules dynamically
    `DEFINE_AXILITE_SLAVE_PORTS(s_rules, 32, 32, 3),


    // Nuove uscite per match multipli
    output logic [NUM_RULES-1:0]           tx_match_valid_out,      // Vettore di validità: tx_match_valid_out[i] è alto se rules_in[i] ha matchato
    output logic [NUM_RULES-1:0][31:0]     tx_packet_addr_list_out, // Array degli indirizzi delle regole
    output logic [$clog2(NUM_RULES+1)-1:0] tx_num_matches_out,      // Contatore del numero di match trovati


    // =====================================================================
    // NUOVI INPUT PER LA LOGICA BOOELANA DELLE REGOLE
    // =====================================================================

    input logic [NUM_RULES-1:0]                 rule_logic_mask_and_in,    // Maschera per le regole che devono essere combinate in AND
    input logic [NUM_RULES-1:0]                 rule_logic_mask_or_in,     // Maschera per le regole che devono essere combinate in OR
    input logic                                 final_match_logic_enable_in, // Abilita/disabilita la logica booleana finale
    output logic                                res_mask_and,               // se alto la maschera di regole in and ha avuto successo
    output logic [NUM_RULES-1:0]                res_mask_or,                 // viene specificate quale regole in or matcha nel pacchetto

    // Input per la logica SOP
    input logic [MAX_SOP_TERMS-1:0][NUM_RULES-1:0] sop_term_masks_in, // Matrice di maschere: sop_term_masks_in[j] definisce il j-esimo termine AND
    input logic [MAX_SOP_TERMS-1:0] sop_term_enable_in, // Abilita/disabilita ogni termine AND
    input logic sop_logic_enable_in, // Abilita/disabilita l'intera logica SOP
    output logic final_sop_match_out // Risultato finale della logica SOP
);


    // Rules management (AXI-Lite interface to let the core acccess them)
    (* keep = "TRUE" *) rule_entry_t rules_in [NUM_RULES-1:0];


    // AXI Lite write channel
    assign s_rules_axilite_bresp = 2'b00;
    always_ff @(posedge rules_clock_i or negedge rules_reset_ni) begin
        if (rules_reset_ni == 1'b0) begin
            s_rules_axilite_awready <= 1'b0;
            s_rules_axilite_wready  <= 1'b0;
            s_rules_axilite_bvalid  <= 1'b0;

            for (int i = 0; i < NUM_RULES; i++) begin
                rules_in [i] <= '0;
            end
        end

        else begin
            // Address handshake
            if (!s_rules_axilite_awready && s_rules_axilite_awvalid) begin
                s_rules_axilite_awready <= 1'b1;
            end else begin
                s_rules_axilite_awready <= 1'b0;
            end

            // Data handshake
            if (!s_rules_axilite_wready && s_rules_axilite_wvalid) begin
                s_rules_axilite_wready <= 1'b1;
            end else begin
                s_rules_axilite_wready <= 1'b0;
            end

            // Perform write
            if (s_rules_axilite_awvalid && s_rules_axilite_awready &&
                s_rules_axilite_wvalid  && s_rules_axilite_wready) begin

                for (int b = 0; b < 4; b++) begin
                    if (s_rules_axilite_wstrb[b])
                        rules_in[s_rules_axilite_awaddr[5:2]][b*8 +: 8] <= s_rules_axilite_wdata[b*8 +: 8];
                end
            end

            // Response
            if (s_rules_axilite_awvalid && s_rules_axilite_awready && s_rules_axilite_wvalid  && s_rules_axilite_wready) begin
                s_rules_axilite_bvalid <= 1'b1;
            end else if (s_rules_axilite_bready) begin
                s_rules_axilite_bvalid <= 1'b0;
            end
        end
    end

    // AXI Lite read channel
    assign s_rules_axilite_rresp   = 2'b00;

    always_ff @(posedge rules_clock_i or negedge rules_reset_ni) begin
        if ( rules_reset_ni == 1'b0 ) begin
            s_rules_axilite_arready <= 1'b0;
            s_rules_axilite_rvalid  <= 1'b0;
            s_rules_axilite_rdata   <= 32'd0;
        end
        else begin
            if (!s_rules_axilite_arready && s_rules_axilite_arvalid) begin
                s_rules_axilite_arready <= 1'b1;
            end else begin
                s_rules_axilite_arready <= 1'b0;
            end

            if (s_rules_axilite_arvalid && s_rules_axilite_arready) begin
                s_rules_axilite_rdata <= rules_in[s_rules_axilite_araddr[5:2]];
                s_rules_axilite_rvalid <= 1'b1;

            end else if (s_rules_axilite_rready) begin
                s_rules_axilite_rvalid <= 1'b0;
            end
        end
    end



    // Local params
    localparam int IDX_WIDTH = $clog2(NUM_RULES + 1); // Larghezza necessaria per contare fino a NUM_RULES match


    // FSM states
    typedef enum logic [1:0] {
        STATE_IDLE,          // Packet waiting
        STATE_PROCESSING,    // Packet processing
        STATE_WAIT_ACC,      // Aggiornamento registri di accumulo beat finale
        STATE_REPORT_MATCH   // Segnalazione dei match finali dopo l'elaborazione completa del pacchetto
    } fsm_state_e;

    // FSM
    fsm_state_e current_state, next_state;

    logic [PKT_DATA_WIDTH-1:0]  r_pkt_data;
    logic [PKT_KSTRB_WIDTH-1:0] r_pkt_kstrb;
    logic                       r_pkt_last;


    // L'offset del primo byte del beat corrente all'interno del pacchetto
    logic [$clog2(PACKET_MAX_SIZE)-1:0] current_beat_start_byte_offset;


    // Registri per accumulare i match trovati su tutti i beat del pacchetto
    logic [NUM_RULES-1:0]       accum_match_valid_reg;
    logic [NUM_RULES-1:0][31:0] accum_packet_addr_list_reg;


    // Registri per gli output finali (validi solo in STATE_REPORT_MATCH)
    logic [NUM_RULES-1:0]       tx_match_valid_reg;
    logic [NUM_RULES-1:0][31:0] tx_packet_addr_list_reg;
    logic [IDX_WIDTH-1:0]       tx_num_matches_reg;


    // SEGNALI INTERNI COMBINATORI (Asincroni)
    logic [NUM_RULES-1:0]       match_found_per_rule_comb;
    logic [NUM_RULES-1:0][31:0] matched_tx_addr_per_rule_comb;



    // Nuovi segnali per la logica booleana finale
    logic matched_and_group_comb; // Risultato AND delle regole selezionate
    logic [NUM_RULES-1:0] matched_or_group_comb;  // Risultato OR delle regole selezionate


    // Segnali interni combinatori
    logic [MAX_SOP_TERMS-1:0] individual_sop_term_results_comb; // Risultato di ogni singolo termine AND
    logic sop_final_result_comb; // Risultato OR finale di tutti i termini AND


    // =====================================================================

    // REGISTRI SINCRONI E AGGIORNAMENTO OFFSET

    // =====================================================================

    always_ff @(posedge clock_i or negedge reset_ni) begin

        if (!reset_ni) begin // Reset asincrono attivo basso

            current_state <= STATE_IDLE;

            r_pkt_data <= '0;

            r_pkt_kstrb <= '0;

            r_pkt_last <= 1'b0;

            current_beat_start_byte_offset <= '0;



            accum_match_valid_reg <= '0;

            accum_packet_addr_list_reg <= '0;



            tx_match_valid_reg <= '0;

            tx_packet_addr_list_reg <= '0;

            tx_num_matches_reg <= '0;





            res_mask_and <= '0;

            res_mask_or <= '0;

            final_sop_match_out <= '0;



        end else begin

            current_state <= next_state; // Aggiornamento dello stato FSM



            // Cattura i dati in ingresso solo se il beat è stato accettato (handshake)

            if ((s_axis_tvalid && s_axis_tready) || s_axis_tlast) begin
                r_pkt_data  <= s_axis_tdata;
                r_pkt_kstrb <= s_axis_tkeep;
                r_pkt_last  <= s_axis_tlast; // Ensure r_pkt_last captures the last beat's status


                // Aggiorna i registri di accumulo dei match se siamo in STATE_PROCESSING

                if (current_state == STATE_PROCESSING) begin

                    accum_match_valid_reg <= accum_match_valid_reg | match_found_per_rule_comb;



                    for (int j = 0; j < NUM_RULES; j++) begin

                        // Solo se la regola ha matchato ora E non aveva matchato prima

                        if (match_found_per_rule_comb[j]) begin

                            accum_packet_addr_list_reg[j] <= matched_tx_addr_per_rule_comb[j];

                        end

                    end

                    // Aggiornamento dell'offset del beat corrente per il prossimo beat

                    current_beat_start_byte_offset <= current_beat_start_byte_offset + PKT_KSTRB_WIDTH;

                end

            end



            // Logica per il caricamento degli output finali (tx_*)

            if (next_state == STATE_REPORT_MATCH) begin

                tx_match_valid_reg       <= accum_match_valid_reg;

                tx_packet_addr_list_reg <= accum_packet_addr_list_reg;

                tx_num_matches_reg       <= $countones(accum_match_valid_reg);



                // Aggiorna gli output finali per la logica booleana

                res_mask_and <=  matched_and_group_comb;

                res_mask_or <=  matched_or_group_comb;

                final_sop_match_out <= sop_final_result_comb;





            end else begin

                // In tutti gli altri stati, o se non si transita in REPORT_MATCH, resettiamo gli output finali

                tx_match_valid_reg       <= '0;

                tx_packet_addr_list_reg <= '0;

                tx_num_matches_reg       <= '0;



                res_mask_and <= '0;

                res_mask_or <= '0;

                final_sop_match_out <= '0;

            end



            // Reset degli accumuli e dell'offset all'inizio di un nuovo pacchetto

            // Questo reset deve avvenire quando si *entra* in PROCESSING dallo stato IDLE

            if (current_state == STATE_IDLE && next_state == STATE_PROCESSING) begin

                accum_match_valid_reg <= '0;

                accum_packet_addr_list_reg <= '0;

                current_beat_start_byte_offset <= '0;

            end

        end

    end



    // =====================================================================

    // MACCHINA A STATI (FSM) E LOGICA DI MATCHING COMBINATORIA PER IL BEAT CORRENTE

    // =====================================================================

    always_comb begin

        next_state = current_state;

        s_axis_tready = 1'b0; // Default a non pronto



        // Reset combinatorio delle variabili di match per il beat corrente

        match_found_per_rule_comb = '0;

        matched_tx_addr_per_rule_comb = '0;



        // Reset combinatorio per la logica booleana (default)

        matched_and_group_comb = 1'b1; // Inizializza a 1 per l'AND

        matched_or_group_comb = 1'b0;  // Inizializza a 0 per l'OR



        case (current_state)

            STATE_IDLE: begin

                s_axis_tready = 1'b1; // Sempre pronto a ricevere il primo beat del pacchetto

                if (s_axis_tvalid) begin

                    next_state = STATE_PROCESSING; // Inizia a processare il pacchetto

                end

            end



            STATE_PROCESSING: begin

                s_axis_tready = 1'b1; // Sempre pronto a ricevere il prossimo beat



                // Loop attraverso tutte le regole definite per il BEAT CORRENTE

                for (int i = 0; i < NUM_RULES; i++) begin

                    if (rules_in[i].enable) begin // Solo se la regola è abilitata

                        automatic logic [$clog2(PACKET_MAX_SIZE)-1:0] rule_absolute_addr = rules_in[i].addr;

                        automatic logic [$clog2(PACKET_MAX_SIZE)-1:0] current_beat_end_byte_offset = current_beat_start_byte_offset + PKT_KSTRB_WIDTH - 1;



                        if ((rule_absolute_addr >= current_beat_start_byte_offset) &&

                            (rule_absolute_addr <= current_beat_end_byte_offset) &&

                            (!accum_match_valid_reg[i])) begin // Aggiunta questa condizione per evitare ricalcoli di match già trovati



                            automatic logic [$clog2(PKT_KSTRB_WIDTH)-1:0] relative_byte_addr = rule_absolute_addr - current_beat_start_byte_offset;



                            if (r_pkt_kstrb[relative_byte_addr]) begin

                                automatic logic [7:0] packet_byte = r_pkt_data[(relative_byte_addr * 8) +: 8];



                                automatic logic current_rule_matches;



                                case (rules_in[i].symbol)

                                    EQ: current_rule_matches = (packet_byte == rules_in[i].value);

                                    GT: current_rule_matches = (packet_byte > rules_in[i].value);

                                    LT: current_rule_matches = (packet_byte < rules_in[i].value);

                                    GE: current_rule_matches = (packet_byte >= rules_in[i].value);

                                    LE: current_rule_matches = (packet_byte <= rules_in[i].value);

                                    default: current_rule_matches = 1'b0;

                                endcase



                                if (current_rule_matches) begin

                                    match_found_per_rule_comb[i] = 1'b1;

                                    matched_tx_addr_per_rule_comb[i] = rules_in[i].packet_tx_addr;

                                end

                            end

                        end

                    end

                end



                // Logica di transizione

                if (s_axis_tready && r_pkt_last) begin

                    next_state = STATE_WAIT_ACC;

                end else begin

                    next_state = STATE_PROCESSING;

                end

            end // STATE_PROCESSING



            STATE_WAIT_ACC: begin

                next_state = STATE_REPORT_MATCH;

            end



            STATE_REPORT_MATCH: begin

                next_state = STATE_IDLE;

                s_axis_tready = 1'b1;

            end



            default: next_state = STATE_IDLE;

        endcase



        // =====================================================================

        // LOGICA BOOLEANA FINALE (CALCOLATA COMBINATORIAMENTE SULL'ACCUMULO FINALE)

        // Questa logica viene calcolata in tutti gli stati, ma è significativa

        // solo nello stato STATE_REPORT_MATCH quando gli accum_match_valid_reg

        // contengono i risultati finali per il pacchetto.

        // =====================================================================

        if (final_match_logic_enable_in) begin

            // Calcolo del gruppo AND: tutte le regole nella maschera AND devono aver matchato

            matched_and_group_comb = (rule_logic_mask_and_in & accum_match_valid_reg) == rule_logic_mask_and_in;





            // Calcolo del gruppo OR: almeno una delle regole nella maschera OR deve aver matchato

            matched_or_group_comb = rule_logic_mask_or_in & accum_match_valid_reg;



        end



        // Inizializzazione per la logica SOP

    sop_final_result_comb = 1'b0; // Default a falso per l'OR finale



    if (sop_logic_enable_in) begin

        // Calcola il risultato di ogni termine AND

        for (int j = 0; j < MAX_SOP_TERMS; j++) begin

            if (sop_term_enable_in[j]) begin

                // Un termine AND è vero se tutte le regole specificate nella sua maschera hanno matchato

                individual_sop_term_results_comb[j] =

                    (sop_term_masks_in[j] & accum_match_valid_reg) == sop_term_masks_in[j];

            end else begin

                individual_sop_term_results_comb[j] = 1'b0; // Termine disabilitato non contribuisce all'OR

            end

        end

        // Esegui l'OR logico di tutti i risultati dei termini AND

        sop_final_result_comb = |individual_sop_term_results_comb; // Riduzione OR bit-a-bit

    end else begin

        sop_final_result_comb = 1'b0; // Se la logica SOP è disabilitata, il risultato è falso

    end

        end



    // =====================================================================

    // ASSEGNAZIONI DEGLI OUTPUT FINALI

    // I valori registrati vengono assegnati direttamente alle porte di output.

    // =====================================================================

    assign tx_match_valid_out = tx_match_valid_reg;

    assign tx_packet_addr_list_out = tx_packet_addr_list_reg;

    assign tx_num_matches_out = tx_num_matches_reg;



endmodule