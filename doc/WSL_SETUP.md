# Running Simply-V from WSL (Windows Subsystem for Linux)

This document describes the extra configuration needed to build and run
Simply-V on the Arty-A7 board when `make` runs inside WSL (Ubuntu) but
Vivado is only installed on the Windows side. It complements the standard
Linux setup — the steps below assume you already have a working WSL/Ubuntu
distribution.

## 1. Bender

The version of Bender that gets installed automatically by the fetch
scripts (`bender-init`, via the fallback for unrecognized platforms) is
**0.31.0** on Ubuntu 24.04/26.04. This version has a real bug: `bender
script flist` (and `flist-plus`) silently returns an empty file list
instead of erroring out, which makes RTL fetch for some units (`custom_clint`,
`custom_rv32_dbg_bscane`, `custom_rv64_dbg_bscane`, `custom_rv_plic`, and
others) appear to succeed while actually producing an empty `rtl/`
directory.

**Fix:** install Bender 0.32.1 explicitly, which does not have this bug:

```bash
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/pulp-platform/bender/releases/download/v0.32.1/bender-installer.sh | sh
source ~/.bashrc
bender --version   # should print 0.32.1
```

Some `fetch_sources.sh` scripts (and, for `custom_rv_plic`, a nested
Makefile inside the externally-cloned `opentitan_peripherals` repo) try to
re-download their own copy of Bender via a `curl ... | bash` one-liner,
which fails outright on this Ubuntu version. Where this caused a real,
silent fetch failure, the download step was patched in-repo to copy the
already-installed Bender binary instead (see `hw/units/custom_clint`,
`custom_rv32_dbg_bscane`, `custom_rv64_dbg_bscane`, `custom_rv_plic` —
look for `cp $(which bender) ./bender` in their `fetch_sources.sh`).
The CI workflow additionally patches any remaining occurrence automatically
before running `make units` (see `.github/workflows/arty-a7-ci.yml`).

## 2. RISC-V toolchain

Install via apt (the packaged toolchain uses the `riscv64-unknown-elf-`
prefix, while the project's build scripts expect `riscv32-unknown-elf-`):

```bash
sudo apt install -y gcc-riscv64-unknown-elf gdb-multiarch
```

Create shims so the expected command names resolve to the installed tools:

```bash
mkdir -p ~/bin
cat > ~/bin/riscv32-unknown-elf-gdb << 'EOF'
#!/bin/bash
exec gdb-multiarch "$@"
EOF
chmod +x ~/bin/riscv32-unknown-elf-gdb

for tool in gcc g++ ar as objcopy objdump nm ranlib strip; do
    cat > ~/bin/riscv32-unknown-elf-${tool} << EOF
#!/bin/bash
exec riscv64-unknown-elf-${tool} "\$@"
EOF
    chmod +x ~/bin/riscv32-unknown-elf-${tool}
done
```

**Important:** `riscv64-unknown-elf-ld` defaults to 64-bit ELF emulation.
When linking 32-bit object files (as this project's `embedded` profile
does), it must be told explicitly to use the 32-bit emulation, or linking
fails with `ABI is incompatible with that of the selected emulation`:

```bash
cat > ~/bin/riscv32-unknown-elf-ld << 'EOF'
#!/bin/bash
exec riscv64-unknown-elf-ld -m elf32lriscv "$@"
EOF
chmod +x ~/bin/riscv32-unknown-elf-ld
```

Add `~/bin` to `PATH` (`echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc`)
and run `hash -r` after creating/editing any shim, since bash caches
resolved command paths.

## 3. OpenOCD

The OpenOCD package from Ubuntu's own repositories
(`sudo apt install openocd`) is built **without Telnet support**, and this
project's `openocd.cfg` uses the `telnet port disabled` command, which
does not exist in that build — OpenOCD exits immediately with `invalid
command name "telnet"`.

**Fix:** install the xPack OpenOCD build instead (same one used on
Windows), which does include Telnet support:

```bash
cd ~
curl -LO https://github.com/xpack-dev-tools/openocd-xpack/releases/download/v0.12.0-7/xpack-openocd-0.12.0-7-linux-x64.tar.gz
tar xzf xpack-openocd-0.12.0-7-linux-x64.tar.gz
echo 'export PATH="$HOME/xpack-openocd-0.12.0-7/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
openocd --version   # should print the xPack build, not the distro one
```

## 4. Vivado bridge (WSL → Windows)

Vivado only runs on Windows. `make` (running in WSL) invokes `vivado`
directly, so a wrapper script named `vivado` must exist in your WSL
`$PATH` that forwards the call to the real Windows executable via
`cmd.exe`. A ready-to-adapt version is provided at
[`scripts/wsl/vivado`](../scripts/wsl/vivado) in this repository — copy it
to `~/bin/vivado`, `chmod +x` it, and edit the three variables at the top
(`PROJROOT`, `VIVADO_WIN_PATH`, `WIN_DRIVE`) for your machine.

This wrapper solves three separate problems:

- **Environment variables**: `make` passes several environment variables
  with Linux paths (`IP_DIR`, `XILINX_ROOT`, `IP_LIST_XCI`, etc.) that
  Vivado, running on Windows, cannot resolve. The wrapper translates them
  to Windows-style paths before invoking Vivado, and forwards them across
  the WSL/Windows boundary via the `WSLENV` variable.
- **Path length limit**: Windows enforces a 260-character path limit.
  A WSL UNC path (`\\wsl.localhost\Ubuntu\home\user\Simply-V\...`) is
  already long on its own, and combined with the subdirectories Vivado
  creates during a build, it exceeds the limit. Mapping the project folder
  to a short drive letter avoids this:
  ```bash
  cmd.exe /c "subst X: \\\\wsl.localhost\\Ubuntu\\home\\YOUR_USERNAME\\Simply-V"
  ```
  (`subst` is not persistent across reboots; re-run it if `X:` stops
  resolving.)
- **Separator style**: pass translated paths with forward slashes
  (`X:/hw/xilinx/...`), not backslashes, in the exported environment
  variables. Vivado's internal Tcl/IP-catalog handling can silently strip
  backslashes from environment-variable-sourced paths, producing corrupted
  paths. Backslashes are only needed for the `pushd` call used to set the
  working directory for `cmd.exe` itself.

## 5. Symbolic links

Some `fetch_sources.sh` scripts create symbolic links (e.g.
`hw/xilinx/ips/common/*/config.tcl -> ../tcl/custom_config.tcl`,
`hw/units/custom_cv64a6/rtl/cv64a6_config_pkg.sv -> ../../assets/...`).
These resolve fine within WSL itself, but Vivado (running on Windows,
accessing the files through the WSL↔Windows bridge) cannot follow them
and fails with `couldn't read file ... no such file or directory`.

Resolve all symlinks into real file copies before running `make ips`:

```bash
find . -type l | while read -r link; do
    target=$(readlink -f "$link")
    if [ -f "$target" ]; then
        rm "$link"
        cp "$target" "$link"
    fi
done
```

The CI workflow runs this automatically as a dedicated step. Note that
running `git checkout -- <path>` afterwards will restore the symlinks
(and can make `make` think the corresponding IPs need to be rebuilt from
scratch) — avoid discarding changes under `hw/` this way once you've
resolved the links for a WSL-based build.

## 6. Programming the board and OpenOCD/JTAG access

`make program_bitstream` (via Vivado/hw_server) and `openocd_run` both
need exclusive access to the same USB JTAG interface on the board, but
they require *different* Windows USB drivers:

- Vivado/hw_server needs the standard Digilent driver.
- OpenOCD needs a libusb-compatible driver (WinUSB), normally installed
  by switching the driver for "Interface 0" of the board's USB device
  with [Zadig](https://zadig.akeo.ie/).

Two approaches, both requiring a manual switch between the two drivers:

**Option A — Zadig (driver swap on the Windows side).**
Use Zadig to set Interface 0's driver to WinUSB before running
`openocd_run`, and switch it back to the default Digilent driver (e.g. by
disabling/re-enabling the device in Device Manager, or reinstalling the
driver) before using Vivado/hw_server again.

**Option B — usbipd-win (attach the USB device to WSL directly).**
[usbipd-win](https://github.com/dorssel/usbipd-win) shares a Windows USB
device with the WSL2 kernel, so OpenOCD running inside WSL can access it
as a native Linux USB device — no Zadig/WinUSB juggling needed for the
WSL side.

```powershell
# One-time setup (elevated PowerShell):
winget install usbipd
usbipd list                     # find the BUSID for the Digilent device
usbipd bind --busid <BUSID>     # one-time, persists across reboots

# Every session:
usbipd attach --wsl --busid <BUSID>
```

Inside WSL, confirm the device is visible: `lsusb` should list an FTDI
device (`0403:6010`).

**Caveat:** while a device is attached to WSL via `usbipd`, Windows
(and therefore Vivado/hw_server) cannot see it. Before programming the
board with Vivado, detach it first:

```powershell
usbipd detach --busid <BUSID>
```

then re-attach it (`usbipd attach --wsl --busid <BUSID>`) before using
OpenOCD again. In practice this still means alternating between the two
tools, similar to Option A, but without needing to touch Zadig each time.

## 7. Typical workflow

```bash
source settings.sh embedded arty_a7_100t
make config
cd hw/units && make -j1 units   # -j1 avoids a Windows/WSL race condition
                                 # seen with the default parallel build
cd ../xilinx && make ips
make bitstream
make program_bitstream          # requires the Digilent driver (see §6)
# switch USB access to OpenOCD (§6), then in one terminal:
openocd -f scripts/load_binary/openocd.cfg
# and in another:
make gdb_run EXAMPLE=hello_world
```

## 8. Running the HIL test (board connected to the runner machine)

`ci/hil_hello_world_wsl.sh` programs the board, releases the core from reset,
attaches the USB device to WSL, runs hello_world through OpenOCD/GDB and
checks the UART. The CI `hil_test` job simply calls it, and it can be run by
hand from the repository root (after `source settings.sh ...`, `make config`
and with the bitstream and `hello_world.elf` already built):

```bash
bash ci/hil_hello_world_wsl.sh        # optional argument: usbipd BUSID, default 1-4
```

Prerequisites on the machine that runs it:

- **usbipd-win** installed, with the right BUSID (`usbipd list`).
  `usbipd bind` / `unbind` need an **elevated** session. The script calls
  them, but from a non-elevated runner they fail: in that case bind the
  device by hand once (`usbipd bind --busid 1-4`, elevated PowerShell) and
  unbind it by hand before using Vivado again.
- **xPack OpenOCD** first in `PATH` (section 3). The script refuses to run
  with the Ubuntu package.
- **Serial port access without sudo**: `sudo usermod -aG dialout $USER`, then
  `wsl --shutdown` from PowerShell and restart WSL (and the runner).
- The board must not be attached to WSL when Vivado programs it: the script
  detaches it first, and again in its cleanup step.
