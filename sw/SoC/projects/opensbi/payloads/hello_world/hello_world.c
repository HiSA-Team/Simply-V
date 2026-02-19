/*
 * Basic S-mode hello-world kernel. The program has a simple printf implementation and prints
 * platform and firmware information using OpenSBI interface.
 *
 * Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

#include <stdio.h>
#include "sbi.h"

int main(void) {
    const char str[] = "Hello from SIMPLY-V Supervisor";
    unsigned long sbi_version = sbi_get_spec_version();
    long fwid = sbi_get_firmware_id();
    long fwver= sbi_get_firmware_version();

    printf("%s\n", str);
    printf("Spec version: %ld.%ld\n", sbi_major_version(sbi_version), sbi_minor_version(sbi_version));
    printf("Firmware: %s v%ld.%ld\n", sbi_impl_names[fwid], (fwver >> 16) &0xFFFF, (fwver & 0XFFFF));
    printf("Vendor id: %ld\n", sbi_get_mvendorid());
    printf("Machine architecture id: %ld\n", sbi_get_marchid());
    printf("Machine implementation id: %ld\n", sbi_get_mimpid());

    return 0;
}
