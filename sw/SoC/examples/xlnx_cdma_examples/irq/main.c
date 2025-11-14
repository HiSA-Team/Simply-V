/*
# Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
# Description:
#   Example demonstrating the use of the AXI CDMA in Simple Transfer mode
#   using interrupt handling. The program configures the CDMA engine,
#   enables interrupts, registers the interrupt callback, and manages
#   transfer completion via the IRQ handler. Includes buffer verification
#   and diagnostic prints without formatted strings.
*/

#include "uninasoc.h"
#include "xaxicdma.h"
#include "xaxicdma_hw.h"
#include "plic.h"
#include <stdint.h>
#include <stdio.h>

/* ====== Parametri ====== */
extern const volatile uint32_t _peripheral_AXI_CDMA_start;
#define CDMA_BASEADDR ((uintptr_t)&_peripheral_AXI_CDMA_start)

#define WORDS  16u
#define BYTES  (WORDS * 4u)
#define CDMA_IRQ_ID  6   /* aggiorna se il pending mostra un altro bit */

/* ====== Buffer DMA in sezione dedicata ====== */
__attribute__((section(".dma"), aligned(64)))
static uint32_t S_buf[WORDS];

__attribute__((section(".dma"), aligned(64)))
static uint32_t D_buf[WORDS];

/* ====== Stato globale ====== */
static XAxiCdma Cdma;
static XAxiCdma_Config CdmaCfg = {
    .DeviceId    = 0,
    .BaseAddress = 0,
    .HasDRE      = 1,
    .IsLite      = 0,
    .DataWidth   = 32,
    .BurstLen    = 16,
    .AddrWidth   = 32
};
static volatile int cdma_done = 0;

/* ====== PLIC base ====== */
#ifndef PLIC_BASEADDR
extern const volatile uint32_t _peripheral_PLIC_start;
#define PLIC_BASEADDR ((uintptr_t)&_peripheral_PLIC_start)
#endif

#define PLIC_PRIO_SRC(n)      (PLIC_BASEADDR + 4u * (n))
#define PLIC_PENDING_BASE     (PLIC_BASEADDR + 0x1000u)
#define PLIC_ENABLE_CTX0      (PLIC_BASEADDR + 0x2000u)
#define PLIC_THRESHOLD_CTX0   (PLIC_BASEADDR + 0x200000u)
/* PLIC_CLAIM_CTX0 / COMPLETE_CTX0 sono in plic.h */

static inline void write32(uintptr_t a, uint32_t v){ *(volatile uint32_t*)a = v; }
static inline uint32_t read32(uintptr_t a){ return *(volatile uint32_t*)a; }

/* ====== Utils ====== */
static void dump_cdma_regs(const char* tag){
    uint32_t cr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_CR_OFFSET);
    uint32_t sr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET);
    printf("%s CR=0x%08x SR=0x%08x\n", tag, (unsigned)cr, (unsigned)sr);
}
static void dump_preview(const char* tag, volatile uint32_t* src, volatile uint32_t* dst){
    printf("%s\n", tag);
    for (uint32_t i=0;i<(WORDS<8?WORDS:8);++i)
        printf("SRC[%u]=0x%08x | DST[%u]=0x%08x\n",
               i, (unsigned)src[i], i, (unsigned)dst[i]);
}
static void dump_plic_state(void){
    uint32_t prio = read32(PLIC_PRIO_SRC(CDMA_IRQ_ID));
    uint32_t en   = read32(PLIC_ENABLE_CTX0);
    uint32_t pen0 = read32(PLIC_PENDING_BASE + 0);
    printf("[PLIC] prio[%u]=0x%08x  enable[ctx0]=0x%08x  pending0=0x%08x\n",
           CDMA_IRQ_ID, (unsigned)prio, (unsigned)en, (unsigned)pen0);
}
static void dump_cpu_irq_bits(void){
    uint32_t mstatus, mie;
    __asm__ volatile ("csrr %0, mstatus" : "=r"(mstatus));
    __asm__ volatile ("csrr %0, mie"     : "=r"(mie));
    printf("[CPU ] mstatus=0x%08x mie=0x%08x\n", (unsigned)mstatus, (unsigned)mie);
}
static inline void enable_global_meie(void) {
    uint32_t mstatus;
    __asm__ volatile ("csrr %0, mstatus" : "=r"(mstatus));
    mstatus |= (1u << 3);
    __asm__ volatile ("csrw mstatus, %0" :: "r"(mstatus));
    uint32_t mie;
    __asm__ volatile ("csrr %0, mie" : "=r"(mie));
    mie |= (1u << 11);
    __asm__ volatile ("csrw mie, %0" :: "r"(mie));
}

/* ====== Soft reset PLIC (robusto ai warm-boot) ====== */
static void plic_soft_reset(void){
    /* soglia a 0 per ctx0 */
    write32(PLIC_THRESHOLD_CTX0, 0u);
    /* disabilita tutte le sorgenti 0..31 e azzera priorità */
    write32(PLIC_ENABLE_CTX0, 0x00000000u);
    for (unsigned id = 1; id <= 31; ++id)
        write32(PLIC_PRIO_SRC(id), 0u);
    /* drena qualunque pending (claim finché !=0) */
    while (1) {
        uint32_t id = read32(PLIC_CLAIM_CTX0);
        if (id == 0) break;
        write32(PLIC_COMPLETE_CTX0, id);
    }
}

/* ====== ISR ====== */
void _ext_handler(void) __attribute__((interrupt("machine")));
void _ext_handler(void) {
    uint32_t id = read32(PLIC_CLAIM_CTX0);
    if (id == CDMA_IRQ_ID) {
        uint32_t sr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET);
        if (sr & XAXICDMA_XR_IRQ_IOC_MASK) cdma_done = 1;
        if (sr & XAXICDMA_XR_IRQ_ERROR_MASK)
            printf("[ISR] CDMA ERROR SR=0x%08x\n", (unsigned)sr);
        XAxiCdma_WriteReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET, XAXICDMA_XR_IRQ_ALL_MASK);
        write32(PLIC_COMPLETE_CTX0, id);
        return;
    }
    write32(PLIC_COMPLETE_CTX0, id);
}

/* ====== ctz helper ====== */
static unsigned ctz32(uint32_t v) {
    unsigned c = 0;
    if (v == 0) return 32;
    while ((v & 1u) == 0u) { v >>= 1; c++; }
    return c;
}

/* ====== MAIN ====== */
int main(void) {
    uninasoc_init();

    /* mtvec → evita salti a 0x0 */
    extern void _ext_handler(void);
    __asm__ volatile ("csrw mtvec, %0" :: "r"(&_ext_handler));

    printf("\n=== CDMA Interrupt Test (spin puro, sonde attive) ===\n");

    /* 🔧 STAMPA indirizzi buffer: DEVONO stare in AXI (NON 0x0000xxxx) */
    printf("[ADDR] &S_buf=0x%08x  &D_buf=0x%08x\n",
           (unsigned)(uintptr_t)S_buf, (unsigned)(uintptr_t)D_buf);

    /* Warm-boot hygiene */
    plic_soft_reset();

    /* Reset CDMA lato SW (serve anche post warm-boot) */
    Cdma.BaseAddr = CDMA_BASEADDR;
    XAxiCdma_Reset(&Cdma);
    while (!XAxiCdma_ResetIsDone(&Cdma)) __asm__ volatile("nop");

    /* Init driver */
    if (XAxiCdma_CfgInitialize(&Cdma, &CdmaCfg, CDMA_BASEADDR) != 0) {
        printf("[CDMA] CfgInitialize failed\n"); while(1);
    }
    XAxiCdma_IntrEnable(&Cdma, XAXICDMA_XR_IRQ_IOC_MASK | XAXICDMA_XR_IRQ_ERROR_MASK);

    /* PLIC: abilitazione della sola sorgente CDMA */
    write32(PLIC_PRIO_SRC(CDMA_IRQ_ID), 2u);
    uint32_t en = read32(PLIC_ENABLE_CTX0);
    en |= (1u << CDMA_IRQ_ID);
    write32(PLIC_ENABLE_CTX0, en);
    write32(PLIC_THRESHOLD_CTX0, 0u);

    enable_global_meie();

    /* Prepara dati */
    for (uint32_t i=0;i<WORDS;++i){ S_buf[i] = 0xDEC0DE1Cu; D_buf[i] = 0xDEC0DE1Cu; }
    dump_preview("Before transfer:", S_buf, D_buf);

    printf("[CDMA] Reset...\n");
    XAxiCdma_Reset(&Cdma);
    while (!XAxiCdma_ResetIsDone(&Cdma)) __asm__ volatile("nop");
    printf("[CDMA] Reset complete\n");

    dump_cdma_regs("[DBG ]");
    dump_plic_state();
    dump_cpu_irq_bits();

    /* Avvio transfer su indirizzi FISICI dei buffer */
    cdma_done = 0;
    printf("Starting CDMA transfer...\n");
    int st = XAxiCdma_SimpleTransfer(&Cdma,
                                     (uintptr_t)S_buf, (uintptr_t)D_buf,
                                     BYTES, NULL, NULL);
    if (st != 0) {
        uint32_t cr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_CR_OFFSET);
        uint32_t sr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET);
        printf("[CDMA] SimpleTransfer failed (%d)  CR=0x%08x SR=0x%08x\n", st, cr, sr);
        while(1);
    }

    /* Attendere IRQ o fallback su IOC */
    uint32_t guard = 0;
    while (!cdma_done && guard++ < 1000000u) {
        uint32_t sr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET);
        if ((sr & XAXICDMA_XR_IRQ_IOC_MASK) != 0u) {
            printf("[WARN] IOC set in SR, ma ISR non eseguita (verifica PLIC/CPU)\n");
            break;
        }
        __asm__ volatile("nop");
    }

    /* Debug PLIC pending */
    uint32_t sr_dbg  = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET);
    uint32_t pen_dbg = read32(PLIC_PENDING_BASE);
    printf("[DEBUG] SR=0x%08x  PLIC.pending0=0x%08x\n", sr_dbg, pen_dbg);
    if (pen_dbg) {
        unsigned bit = ctz32(pen_dbg);
        unsigned actual_id = bit + 1;
        printf("[DEBUG] PLIC says pending ID=%u (bit=%u)\n", actual_id, bit);
        uint32_t claimed = read32(PLIC_CLAIM_CTX0);
        printf("[DEBUG] plic_claim() -> %u\n", claimed);
        if (claimed) {
            write32(PLIC_COMPLETE_CTX0, claimed);
            printf("[DEBUG] plic_complete(%u) done\n", claimed);
        }
    }

    /* Verifica dati */
    uint32_t errors = 0;
    for (uint32_t i=0;i<WORDS;++i)
        if (D_buf[i] != S_buf[i]) errors++;
    dump_preview("After transfer:", S_buf, D_buf);

    if (errors == 0)
        printf("Transfer OK — all %u words match\n", (unsigned)WORDS);
    else
        printf("Transfer ERROR — mismatches=%u\n", (unsigned)errors);

    while (1);
    return 0;
}

