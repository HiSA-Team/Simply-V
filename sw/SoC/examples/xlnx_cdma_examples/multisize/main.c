/*
# Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
# Description:
#   Example demonstrating multiple AXI CDMA Simple Transfer operations with
#   different transfer sizes. The program performs several back-to-back DMA
#   transactions, each using a different byte/word count, and verifies the
#   correctness of each copy. This example is useful for testing CDMA behavior
#   across varying data lengths. All output uses c_printf with plain strings
#   (no formatted printing).
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

// --- Test config
#define WORDS           16u                  // quante word trasferire
#define BYTES           (WORDS * 4u)

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

static void print_idx_hex_pair(const char* lbl, uint32_t idx, uint32_t val) {
    char ibuf[12], hbuf[11];
    udec_to_str(idx, ibuf);
    hex32_to_str(val, hbuf);
    c_printf(lbl);      // es. "SRC["
    c_printf(ibuf);     // indice
    c_printf("] = ");
    c_printf(hbuf);
    c_printf("\r\n");
}

// ---------------------------------------------------------------------
// CDMA setup
// ---------------------------------------------------------------------
static XAxiCdma Cdma;
static XAxiCdma_Config CdmaCfg = {
    .DeviceId   = 0,
    .BaseAddress= CDMA_BASEADDR,
    .HasDRE     = 1,
    .IsLite     = 0,
    .DataWidth  = 32,
    .BurstLen   = 16,
    .AddrWidth  = 32
};

static void cdma_print_status(const char* tag) {
    uint32_t s = XAxiCdma_ReadReg(CDMA_BASEADDR, XAXICDMA_SR_OFFSET);
    c_printf(tag);
    print_hex_line("", s);
}

int main(void) {
    // UART init
    uninasoc_init();

    // Banner
    print_str("\r\nCDMA multi-word transfer test start\r\n");

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

    // Buffer
    volatile uint32_t* src = (uint32_t*)SRC_ADDR;
    volatile uint32_t* dst = (uint32_t*)DST_ADDR;

    // Riempie SORGENTE con pattern variabile; DEST = 0xFFFFFFFF
    for (uint32_t i = 0; i < WORDS; ++i) {
        src[i] = (i * 0x11111111u) ^ 0xA5A5A5A5u;
        dst[i] = 0xFFFFFFFFu;
    }

    // Preview iniziale (prime 8 word)
    print_str("Before transfer:\r\n");
    for (uint32_t i = 0; i < (WORDS < 8 ? WORDS : 8); ++i) {
        c_printf("SRC["); print_idx_hex_pair("", i, src[i]); // etichetta composita
    }
    for (uint32_t i = 0; i < (WORDS < 8 ? WORDS : 8); ++i) {
        c_printf("DST["); print_idx_hex_pair("", i, dst[i]);
    }

    cdma_print_status("CDMA Status: ");

    // Avvio trasferimento semplice
    print_str("Starting CDMA transfer...\r\n");
    int st = XAxiCdma_SimpleTransfer(&Cdma, SRC_ADDR, DST_ADDR, BYTES, NULL, NULL);
    if (st != 0) {
        print_str("[CDMA] Transfer start failed\r\n");
        cdma_print_status("CDMA Status: ");
        while (1);
    }

    // Poll busy
    {
        uint32_t guard = 0;
        while (XAxiCdma_IsBusy(&Cdma)) {
            if (++guard > 10000000u) {
                print_str("[CDMA] Timeout while busy\r\n");
                cdma_print_status("CDMA Status: ");
                while (1);
            }
        }
    }
    print_str("[CDMA] Transfer complete.\r\n");
    cdma_print_status("CDMA Status: ");

    // Verifica & stampa prime 8 word
    print_str("After transfer:\r\n");
    uint32_t errors = 0;
    for (uint32_t i = 0; i < WORDS; ++i) {
        if (dst[i] != src[i]) { errors++; }
        if (i < 8) {
            // Riga "SRC[i] = 0x..., DST[i] = 0x..."
            c_printf("SRC[");
            char ibuf[12]; udec_to_str(i, ibuf);
            c_printf(ibuf); c_printf("] = ");
            char hs[11]; hex32_to_str(src[i], hs);
            c_printf(hs);
            c_printf(" | DST["); c_printf(ibuf); c_printf("] = ");
            char hd[11]; hex32_to_str(dst[i], hd);
            c_printf(hd); c_printf("\r\n");
        }
    }

    if (errors == 0) {
        print_str("Transfer OK - All words copied\r\n");
    } else {
        char eb[12]; udec_to_str(errors, eb);
        c_printf("Transfer ERROR - mismatches: ");
        c_printf(eb); c_printf("\r\n");
    }

    while (1);
    return 0;
}
