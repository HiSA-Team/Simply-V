// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description: Baremetal host code for conv_hbus HLS IP core.

#include "uninasoc.h"
#include "xlnx/xlnx.h"
#include "krnl_conv_hbus.h"
#include "utils.h"

void dump_conv_hbus_csrs () {
    // Read in order
    uint32_t AP_CTRL     = Xil_In32(Xkrnl_Control   );
    uint32_t GIE         = Xil_In32(Xkrnl_GIE       );
    uint32_t IER         = Xil_In32(Xkrnl_IER       );
    uint32_t ISR         = Xil_In32(Xkrnl_ISR       );
    uint32_t AXI_I_ADDR  = Xil_In32(Xkrnl_AXI_ADDR_I);
    uint32_t AXI_W_ADDR  = Xil_In32(Xkrnl_AXI_ADDR_W);
    uint32_t AXI_O_ADDR  = Xil_In32(Xkrnl_AXI_ADDR_O);
    uint32_t AXI_N       = Xil_In32(Xkrnl_N         );
    uint32_t AXI_C       = Xil_In32(Xkrnl_C         );
    uint32_t AXI_K       = Xil_In32(Xkrnl_K         );

    // Print
    printf( "CSR DUMP:\n\r");
    // Use formatting, e.g.
    //    AP_CTRL     = 0x0000       AXI_I_ADDR  = 0x0000
    //    GIE         = 0x0000       AXI_W_ADDR  = 0x0000
    //    IER         = 0x0000       AXI_O_ADDR  = 0x0000
    //    ISR         = 0x0000       AXI_N       = 0x0000
    //                               AXI_C       = 0x0000
    //                               AXI_K       = 0x0000
    printf( "   AP_CTRL     = 0x%04x    ", AP_CTRL    );
    printf( "   AXI_I_ADDR  = 0x%04x\n\r", AXI_I_ADDR );
    printf( "   GIE         = 0x%04x    ", GIE        );
    printf( "   AXI_W_ADDR  = 0x%04x\n\r", AXI_W_ADDR );
    printf( "   IER         = 0x%04x    ", IER        );
    printf( "   AXI_O_ADDR  = 0x%04x\n\r", AXI_O_ADDR );
    printf( "   ISR         = 0x%04x    ", ISR        );
    printf( "   AXI_N       = 0x%04x\n\r", AXI_N      );
    printf( "                              AXI_C       = 0x%04x\n\r", AXI_C );
    printf( "                              AXI_K       = 0x%04x\n\r", AXI_K );
}

// Print each field of a control CSR word
void print_control_csr ( uint32_t csr_read_in ) {
    // Print fields
    printf("AP_CTRL = 0x%04x\n\r", csr_read_in);
    printf("    START       =  0x%x    ", ( csr_read_in & AP_START    ) >> (AP_START_BIT    ));
    printf("    DONE        =  0x%x\n\r", ( csr_read_in & AP_DONE     ) >> (AP_DONE_BIT     ));
    printf("    IDLE        =  0x%x    ", ( csr_read_in & AP_IDLE     ) >> (AP_IDLE_BIT     ));
    printf("    READY       =  0x%x\n\r", ( csr_read_in & AP_READY    ) >> (AP_READY_BIT    ));
    printf("    CONTINUE    =  0x%x    ", ( csr_read_in & AP_CONTINUE ) >> (AP_CONTINUE_BIT ));
    printf("    AUTORESTART =  0x%x\n\r", ( csr_read_in & AP_AUTORESTART) >> (AP_AUTORESTART_BIT));
    printf("    INTERRUPT   =  0x%x\n\r", ( csr_read_in & AP_INTERRUPT) >> (AP_INTERRUPT_BIT));
}

#define PRINT_LEAP 10

int main() {

    // Control CSR
    uint32_t csr_read;
    uint32_t cnt;

    // Init platform
    uninasoc_init();

    // Pre-allocate tensors, aligned to power of two
    #define ALIGN_I 2048
    #define ALIGN_W 1024
    #define ALIGN_O 1024
    target_type_t I       [N][C][ Y][ X]__attribute__((aligned(ALIGN_I)));
    target_type_t W       [K][C][ R][ S]__attribute__((aligned(ALIGN_W)));
    target_type_t O       [N][K][Y1][X1]__attribute__((aligned(ALIGN_O)));
    target_type_t expected[N][K][Y1][X1] = {0};

    printf("\n\r");
    printf("------------------\n\r");
    printf("- HLS CONV HBUS  -\n\r");
    printf("------------------\n\r");
    printf("\n\r");

    // Debug
    printf("Convolution parameters:\n\r");
    printf("    I = 0x%p\n\r", (uintptr_t)I);
    printf("    W = 0x%p\n\r", (uintptr_t)W);
    printf("    O = 0x%p\n\r", (uintptr_t)O);
    printf("    N = %hhu\n\r", (uint8_t)N);
    printf("    C = %hhu\n\r", (uint8_t)C);
    printf("    K = %hhu\n\r", (uint8_t)K);
    printf("    Y = %hhu\n\r", (uint8_t)  Y);
    printf("    X = %hhu\n\r", (uint8_t)  X);
    printf("    R = %hhu\n\r", (uint8_t)  R);
    printf("    S = %hhu\n\r", (uint8_t)  S);
    printf("   Y1 = %hhu\n\r", (uint8_t) Y1);
    printf("   X1 = %hhu\n\r", (uint8_t) X1);

    // Initializing input/output data
    init_data(I, W, O);

    // Compute expected
    printf("[INFO] Compute expected\n\r");
    compute_expected(I, W, expected);

    printf("[INFO] Waiting for idle...\n\r");
    // Reset counter
    cnt = 0;
    do {
        // Increment counter
        cnt++;
        if ( cnt == PRINT_LEAP ) {
            // Reset counter
            cnt = 0;
            // Read
            csr_read = -1;
            csr_read = Xil_In32(Xkrnl_Control);
            // Print
            print_control_csr(csr_read);
        }
    } while ( XKrnl_IsIdle() );

    ///////////////////////
    // Enable interrupts //
    ///////////////////////
    // Global Interrupts Enable
    XKrnl_InterruptGlobalEnable();
    // Enable done and ready interrupts
    XKrnl_InterruptEnable_ap_done();
    // XKrnl_InterruptEnable_ap_ready();

    /////////////////////////
    // Starting the kernel //
    /////////////////////////

    // Writing input/output addresses
    Xil_Out32(Xkrnl_AXI_ADDR_I, (uintptr_t)I);
    Xil_Out32(Xkrnl_AXI_ADDR_W, (uintptr_t)W);
    Xil_Out32(Xkrnl_AXI_ADDR_O, (uintptr_t)O);
    Xil_Out32(Xkrnl_N, (uint8_t)N);
    Xil_Out32(Xkrnl_C, (uint8_t)C);
    Xil_Out32(Xkrnl_K, (uint8_t)K);

    // Enable auto-restart
    XKrnl_EnableAutoRestart();
    // Raising ap_start to start the kernel
    XKrnl_Start();

    // Waiting for the kernel to finish (polling the ap_done control bit)
    printf("[INFO] Waiting for done...\n\r");
    // Reset counter
    cnt = 0;
    do {
        // Increment counter
        cnt++;
        if ( cnt == PRINT_LEAP ) {
            // Reset counter
            cnt = 0;
            // Read
            csr_read = -1;
            csr_read = Xil_In32(Xkrnl_Control);
            // Print
            print_control_csr(csr_read);
        }
    } while ( XKrnl_IsDone() );

    // Read pending interrupts
    printf( "   ISR     = 0x%04x\n\r", XKrnl_InterruptGetStatus() );
    // Clear interrupts
    XKrnl_InterruptClear_ap_done();
    // XKrnl_InterruptClear_ap_ready();
    // Read pending interrupts
    printf( "   ISR     = 0x%04x\n\r", XKrnl_InterruptGetStatus() );

    // // Write continue
    // XKrnl_Continue();

    // Checking results
    printf("[INFO] Checking results...\n\r");
    bool result = check_values(O, expected);
    if ( !result ) {
        printf("[ERROR] Check failed!\n\r");
        return 1;
    }
    else {
        printf("[INFO] Check successful!\n\r");
    }

    return 0;

}