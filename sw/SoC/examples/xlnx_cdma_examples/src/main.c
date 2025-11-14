/*
# Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
# Description:
#   Example demonstrating the use of the AXI CDMA in Simple Transfer mode.
#   The program performs multiple consecutive transfer rounds, preparing
#   the source/destination buffers, starting the CDMA transfer in polling
#   mode, and verifying data integrity after each round.
*/




#include "uninasoc.h"
#include <stdint.h>
#include "xaxicdma.h"
#include "xaxicdma_hw.h"
#include "tinyIO.h"

// --- Niente % nelle stringhe: usiamo c_printf solo con stringhe "plain"
#define print_str(S)    c_printf(S)

// --- Indirizzi dal linker
extern const volatile uint32_t _peripheral_AXI_CDMA_start;
#define CDMA_BASEADDR   ((uintptr_t)&_peripheral_AXI_CDMA_start)

// --- BRAM mappa semplice (adatta ai tuoi indirizzi)
#define MEM_BASEADDR    0x00000000u
#define SRC_ADDR        (MEM_BASEADDR + 0x0000u)
#define DST_ADDR        (MEM_BASEADDR + 0x1000u)

// ---------------------------------------------------------------------
// Parametri test multi-round
// ---------------------------------------------------------------------
#define ROUNDS          3u          // quante volte ripetere il test
static const uint32_t WORDS_ROUND[ROUNDS] = {
    8u,    // Round 0:  8 word  (32 byte)
    16u,   // Round 1: 16 word  (64 byte)
    32u    // Round 2: 32 word (128 byte)
};

// ---------------------------------------------------------------------
// Helpers di stampa (NO %):
// ---------------------------------------------------------------------
static void hex32_to_str(uint32_t v, char out[11]) {
    static const char H[] = "0123456789ABCDEF";
    out[0] = '0'; out[1] = 'x';
    for (int i = 0; i < 8; ++i) {
        int shift = (7 - i) * 4;
        out[2 + i] = H[(v >> shift) & 0xF];
    }
    out[10] = '\0';
}

static void udec_to_str(uint32_t v, char out[12]) {
    char tmp[12];
    int n = 0;
    if (v == 0) { out[0] = '0'; out[1] = '\0'; return; }
    while (v && n < 11) { tmp[n++] = (char)('0' + (v % 10)); v /= 10; }
    for (int i = 0; i < n; ++i) out[i] = tmp[n - 1 - i];
    out[n] = '\0';
}

static void print_hex_line(const char* prefix, uint32_t val) {
    char buf[11];
    hex32_to_str(val, buf);
    c_printf(prefix);
    c_printf(buf);
    c_printf("\r\n");
}

static void print_idx_hex_pair(uint32_t idx, uint32_t val_src, uint32_t val_dst) {
    char ibuf[12], hs[11], hd[11];
    udec_to_str(idx, ibuf);
    hex32_to_str(val_src, hs);
    hex32_to_str(val_dst, hd);

    c_printf("SRC["); c_printf(ibuf); c_printf("] = ");
    c_printf(hs);
    c_printf(" | DST["); c_printf(ibuf); c_printf("] = ");
    c_printf(hd);
    c_printf("\r\n");
}

// ---------------------------------------------------------------------
// CDMA setup
// ---------------------------------------------------------------------
static XAxiCdma Cdma;
static XAxiCdma_Config CdmaCfg = {
    .DeviceId    = 0,
    .BaseAddress = CDMA_BASEADDR,
    .HasDRE      = 1,
    .IsLite      = 0,
    .DataWidth   = 32,
    .BurstLen    = 16,
    .AddrWidth   = 32
};

static void cdma_print_status(const char* tag) {
    uint32_t s = XAxiCdma_ReadReg(CDMA_BASEADDR, XAXICDMA_SR_OFFSET);
    c_printf(tag);
    print_hex_line("", s);
}

// ---------------------------------------------------------------------
// Esegue un round: prepara buffer, trasferisce, verifica e stampa
// ---------------------------------------------------------------------
static int do_one_round(uint32_t round_idx, uint32_t words) {
    volatile uint32_t* src = (uint32_t*)SRC_ADDR;
    volatile uint32_t* dst = (uint32_t*)DST_ADDR;
    const uint32_t bytes = words * 4u;

    // Banner round
    c_printf("\r\n=== Round ");
    char rbuf[12]; udec_to_str(round_idx, rbuf);
    c_printf(rbuf);
    c_printf(" — words ");
    char wbuf[12]; udec_to_str(words, wbuf);
    c_printf(wbuf);
    c_printf(" ===\r\n");

    // Riempie SORGENTE con pattern variabile dipendente dal round; DEST = 0xFFFFFFFF
    // Pattern: src[i] = (round_idx << 28) ^ (i * 0x11111111) ^ 0xA5A5A5A5
    for (uint32_t i = 0; i < words; ++i) {
        src[i] = ((round_idx & 0xFu) << 28) ^ (i * 0x11111111u) ^ 0xA5A5A5A5u;
        dst[i] = 0xFFFFFFFFu;
    }

    // Preview iniziale (prime 8 word)
    c_printf("Before transfer:\r\n");
    uint32_t preview = (words < 8u) ? words : 8u;
    for (uint32_t i = 0; i < preview; ++i) {
        print_idx_hex_pair(i, src[i], dst[i]);
    }

    cdma_print_status("CDMA Status: ");

    // Avvio trasferimento semplice
    c_printf("Starting CDMA transfer...\r\n");
    int st = XAxiCdma_SimpleTransfer(&Cdma, SRC_ADDR, DST_ADDR, (int)bytes, NULL, NULL);
    if (st != 0) {
        c_printf("[CDMA] Transfer start failed\r\n");
        cdma_print_status("CDMA Status: ");
        return -1;
    }

    // Poll busy con guard
    {
        uint32_t guard = 0;
        while (XAxiCdma_IsBusy(&Cdma)) {
            if (++guard > 10000000u) {
                c_printf("[CDMA] Timeout while busy\r\n");
                cdma_print_status("CDMA Status: ");
                return -2;
            }
        }
    }
    c_printf("[CDMA] Transfer complete.\r\n");
    cdma_print_status("CDMA Status: ");

    // Verifica & stampa prime 8 word
    c_printf("After transfer:\r\n");
    uint32_t errors = 0;
    for (uint32_t i = 0; i < words; ++i) {
        if (dst[i] != src[i]) { errors++; }
        if (i < preview) {
            print_idx_hex_pair(i, src[i], dst[i]);
        }
    }

    if (errors == 0) {
        c_printf("Round OK - All words copied\r\n");
        return 0;
    } else {
        char eb[12]; udec_to_str(errors, eb);
        c_printf("Round ERROR - mismatches: ");
        c_printf(eb); c_printf("\r\n");
        return (int)errors;
    }
}

int main(void) {
    // UART init
    uninasoc_init();

    // Banner
    print_str("\r\nCDMA multi-round transfer test start\r\n");

    // Init CDMA
    if (XAxiCdma_CfgInitialize(&Cdma, &CdmaCfg, CDMA_BASEADDR) != 0) {
        print_str("[CDMA] Init failed\r\n");
        while (1);
    }

    // Reset sicuro
    print_str("Resetting CDMA...\r\n");
    XAxiCdma_Reset(&Cdma);
    for (volatile uint32_t t = 0; t < 50000; ++t) { __asm__ __volatile__(""); }
    print_str("[CDMA] Reset complete\r\n");
    cdma_print_status("CDMA Status: ");

    // Esegui più trasferimenti consecutivi
    for (uint32_t r = 0; r < ROUNDS; ++r) {
        int res = do_one_round(r, WORDS_ROUND[r]);

	XAxiCdma_Reset(&Cdma);
        for (volatile int i = 0; i < 50000; ++i) { __asm__ __volatile__(""); }
        Cdma.SimpleNotDone = 0;
        if (res != 0) {
            c_printf("Stopping due to error in round ");
            char rb[12]; udec_to_str(r, rb);
            c_printf(rb); c_printf("\r\n");
            break;
        }
    }

    c_printf("\r\nAll rounds done\r\n");
    while (1);
    return 0;
}
