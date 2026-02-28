/*
 * This file contains the implementation of basic SBI wrapper according SBI 3.0 specification.
 * For now, the following extensions are supported:
 *
 * - SBI_EXT_BASE: retrieve information about the firmware (eg: OpenSBI)
 * - SBI_EXT_DBCN: use the console device for debug purposes (Debug Console)
 *
 * Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

#include <stddef.h>
#include "sbi.h"


/* Utility to get values out of the base extension */
static long sbi_base_ecall(int fid) {

    struct sbiret ret;

    ret = sbi_ecall(0, 0, 0, 0, 0, 0, SBI_EXT_BASE, fid);

    if (!ret.error)
      return ret.value;
    else
      return ret.error;
}

/* Base Information */
long sbi_get_spec_version(void) {
    return sbi_base_ecall(SBI_EXT_BASE_GET_SPEC_VERSION);
}

long sbi_get_firmware_id(void) {
    return sbi_base_ecall(SBI_EXT_BASE_GET_IMP_ID);
}

long sbi_get_firmware_version(void) {
    return sbi_base_ecall(SBI_EXT_BASE_GET_IMP_VERSION);
}

long sbi_get_mvendorid(void) {
    return sbi_base_ecall(SBI_EXT_BASE_GET_MVENDORID);
}

long sbi_get_marchid(void) {
    return sbi_base_ecall(SBI_EXT_BASE_GET_MARCHID);
}

long sbi_get_mimpid(void) {
    return sbi_base_ecall(SBI_EXT_BASE_GET_MIMPID);
}

/* Debug console */
int sbi_console_write_byte(char ch) {
    struct sbiret ret;

    ret = sbi_ecall(ch, 0, 0, 0, 0, 0, 
        SBI_EXT_DBCN, SBI_EXT_DBCN_CONSOLE_WRITE_BYTE);

    return ret.error;
}

int sbi_console_write(const char *str, size_t num_bytes) {
    struct sbiret ret;

    ret = sbi_ecall(num_bytes, (unsigned long) str, 0, 0, 0, 0,
        SBI_EXT_DBCN, SBI_EXT_DBCN_CONSOLE_WRITE);

    return ret.error;
}
