# Building RISC-V GCC Toolchain from Sources
To build SoC software, we require [RISC-V GCC](https://github.com/riscv/riscv-gnu-toolchain.git) to be installed on the developement host.

> [!WARNING]
> We use 2024.03.01 version as a reference and Ubuntu 22.04 as building host.
Refer to the documentation for different Linux distribution support.
RISC-V GCC release 2026.02.13 has been verified with host GCC 11.4.0. Newer or older releases might require a different host GCC version.

First, download prerequisites (for Debian and Debian-derived distro):
``` bash
sudo apt-get install -y autoconf automake autotools-dev curl python3 python3-pip \
    libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf \
    libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev
```

Clone sources:
``` bash
git clone https://github.com/riscv/riscv-gnu-toolchain.git --depth 1 -b 2026.02.13
cd riscv-gnu-toolchain
```

Configure the build:
> NOTE: it is recommended to separate 32-bit and 64-bit toolchains with two different `INSTALL_DIR`, in case both are needed

``` bash
mkdir build
cd build
# For RV32
../configure --prefix=$INSTALL_DIR --with-arch=rv32gcv
# For RV64 (multilib enables the building for 32-bit architecture)
../configure --prefix=$INSTALL_DIR --enable-multilib
```

We show how to build 2 types of toolchains:

- **newlib**: suitable for bare metal code;
- **gnu**: suitable for high-level code that assumes to have a working LIBC implemenation, e.g. GNU glibc.

Build and install in `--prefix`:

- newlib toolchain, i.e. `riscv${XLEN}-unknown-elf-`:

```sh
make -j$(nproc)
````

- glibc support, i.e. `riscv${XLEN}-unknown-linux-gnu`:

```sh
make -j$(nproc) linux
```
