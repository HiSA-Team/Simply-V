/*
 * This file contains RISCV SBI bindings according the SBI 3.0 specification.
 *
 * This is meant to be used by bare-metal supervisor to interact with firmware services.
 *
 * Content of this file has been adapted from the Linux kernel
 * - arch/riscv/kernel/sbi_ecall.c
 * - arch/riscv/asm/sbi.h
 *
 * Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

#ifndef __SIMPLYV_SBI
#define __SIMPLYV_SBI

struct sbiret {
    long error;
    long value;
};

/* All SBI extensions */
enum sbi_ext_id {
    SBI_EXT_BASE = 0x10,
    SBI_EXT_TIME = 0x54494D45,
    SBI_EXT_IPI = 0x735049,
    SBI_EXT_RFENCE = 0x52464E43,
    SBI_EXT_HSM = 0x48534D,
    SBI_EXT_SRST = 0x53525354,
    SBI_EXT_SUSP = 0x53555350,
    SBI_EXT_PMU = 0x504D55,
    SBI_EXT_DBCN = 0x4442434E,
    SBI_EXT_STA = 0x535441,
    SBI_EXT_NACL = 0x4E41434C,
    SBI_EXT_FWFT = 0x46574654,
    /* Experimentals extensions must lie within this range */
    SBI_EXT_EXPERIMENTAL_START = 0x08000000,
    SBI_EXT_EXPERIMENTAL_END = 0x08FFFFFF,
    /* Vendor extensions must lie within this range */
    SBI_EXT_VENDOR_START = 0x09000000,
    SBI_EXT_VENDOR_END = 0x09FFFFFF,
};

/* Base extension */
enum sbi_ext_base_fid {
    SBI_EXT_BASE_GET_SPEC_VERSION = 0,
    SBI_EXT_BASE_GET_IMP_ID,
    SBI_EXT_BASE_GET_IMP_VERSION,
    SBI_EXT_BASE_PROBE_EXT,
    SBI_EXT_BASE_GET_MVENDORID,
    SBI_EXT_BASE_GET_MARCHID,
    SBI_EXT_BASE_GET_MIMPID,
};

long sbi_get_spec_version(void);
long sbi_get_firmware_id(void);
long sbi_get_firmware_version(void);
long sbi_get_mvendorid(void);
long sbi_get_marchid(void);
long sbi_get_mimpid(void);

/* Debug console */
enum sbi_ext_dbcn_fid {
    SBI_EXT_DBCN_CONSOLE_WRITE = 0,
    SBI_EXT_DBCN_CONSOLE_READ = 1,
    SBI_EXT_DBCN_CONSOLE_WRITE_BYTE = 2,
};
int sbi_console_write(const char *str, size_t num_bytes);
int sbi_console_write_byte(char ch);

/* SBI spec version fields */
#define SBI_SPEC_VERSION_DEFAULT	0x1
#define SBI_SPEC_VERSION_MAJOR_SHIFT	24
#define SBI_SPEC_VERSION_MAJOR_MASK	0x7f
#define SBI_SPEC_VERSION_MINOR_MASK	0xffffff

/* SBI return error codes */
#define SBI_SUCCESS		0
#define SBI_ERR_FAILURE		-1
#define SBI_ERR_NOT_SUPPORTED	-2
#define SBI_ERR_INVALID_PARAM	-3
#define SBI_ERR_DENIED		-4
#define SBI_ERR_INVALID_ADDRESS	-5
#define SBI_ERR_ALREADY_AVAILABLE -6
#define SBI_ERR_ALREADY_STARTED -7
#define SBI_ERR_ALREADY_STOPPED -8
#define SBI_ERR_NO_SHMEM	-9
#define SBI_ERR_INVALID_STATE	-10
#define SBI_ERR_BAD_RANGE	-11
#define SBI_ERR_TIMEOUT		-12
#define SBI_ERR_IO		-13
#define SBI_ERR_DENIED_LOCKED	-14

static inline struct sbiret sbi_ecall(
    unsigned long arg0, unsigned long arg1,
    unsigned long arg2, unsigned long arg3,
    unsigned long arg4, unsigned long arg5,
    int ext,  int fid
) {

    struct sbiret ret;
    register unsigned long a0 asm("a0") = arg0;
    register unsigned long a1 asm("a1") = arg1;
    register unsigned long a2 asm("a2") = arg2;
    register unsigned long a3 asm("a3") = arg3;
    register unsigned long a4 asm("a4") = arg4;
    register unsigned long a5 asm("a5") = arg5;
    register unsigned long a6 asm("a6") = fid;
    register unsigned long a7 asm("a7") = ext;

    asm volatile (
	"ecall"
	/* a0,a1 are outputs (a0=err, a1=val) */
	: "+r"(a0), "+r"(a1)
	: "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(a6), "r"(a7)
	: "memory"
	);

    ret.error = a0;
    ret.value = a1;

    return ret;
}

/* SBI spec version fields */
#define SBI_SPEC_VERSION_DEFAULT	0x1
#define SBI_SPEC_VERSION_MAJOR_SHIFT	24
#define SBI_SPEC_VERSION_MAJOR_MASK	0x7f
#define SBI_SPEC_VERSION_MINOR_MASK	0xffffff

/* Get the major version of SBI */
static inline unsigned long sbi_major_version(unsigned long ver) {
    return (ver >> SBI_SPEC_VERSION_MAJOR_SHIFT) &
      SBI_SPEC_VERSION_MAJOR_MASK;
}

/* Get the minor version of SBI */
static inline unsigned long sbi_minor_version(unsigned long ver) {
    return ver & SBI_SPEC_VERSION_MINOR_MASK;
}

static const char *sbi_impl_names[] = {
    "BBL",
    "OpenSBI",
    "Xvisor",
    "KVM",
    "RustSBI",
    "Diosix",
    "Coffer",
    "Xen Projects",
    "PolarFire Hart Software Services",
    "coreboot",
    "oreboot",
    "bhyve",
    NULL,
};

#endif /* __SIMPLYV_SBI */
