# Running Simply-V from WSL (Windows Subsystem for Linux)

This document describes the extra configuration needed to build and run
Simply-V when `make` runs inside WSL (Ubuntu) but Vivado is only installed
on the Windows side. It complements the standard Linux setup: the steps below
assume you already have a working WSL/Ubuntu distribution, with the RISC-V
toolchain and OpenOCD installed as described in [`sw/doc`](../sw/doc).

## 1. Vivado bridge (WSL → Windows)

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

## 2. WSL resources

Vivado is memory hungry. Increase the resources given to WSL in the
`.wslconfig` file in your Windows user folder (`%UserProfile%\.wslconfig`),
namely the processors, the memory and the swap space. A swap of around 10 GB
is standard for Vivado on Linux, and it applies here as well:

```ini
[wsl2]
memory=<N>GB
processors=<N>
swap=10GB
```

Then run `wsl --shutdown` from PowerShell and restart WSL to apply it.

## 3. Programming the board and OpenOCD/JTAG access

`make program_bitstream` (Vivado/hw_server, which runs on Windows) and
`openocd_run` (OpenOCD, which runs inside WSL) both need the USB JTAG
interface of the board. [usbipd-win](https://github.com/dorssel/usbipd-win)
shares a Windows USB device with the WSL2 kernel, so OpenOCD running inside
WSL can access it as a native Linux USB device.

```powershell
# One-time setup (elevated PowerShell):
winget install usbipd
usbipd list                     # find the BUSID of the board
usbipd bind --busid <BUSID>     # one-time, persists across reboots

# Every session:
usbipd attach --wsl --busid <BUSID>
```

Inside WSL, confirm the device is visible: `lsusb` should list an FTDI device
(for example `0403:6010`).

**Caveat:** while a device is attached to WSL via `usbipd`, Windows (and
therefore Vivado/hw_server) cannot see it. Before programming the board with
Vivado, detach it first:

```powershell
usbipd detach --busid <BUSID>
```

If Vivado still cannot see the board, release it completely with
`usbipd unbind --busid <BUSID>` (elevated PowerShell), and run `usbipd bind`
again before the next attach. Then re-attach the device
(`usbipd attach --wsl --busid <BUSID>`) before using OpenOCD again.

## 4. Typical workflow

```bash
source settings.sh embedded <board_config>
make hw MAX_VIVADO_INSTANCES=<N>
make -C hw/xilinx program_bitstream   # the board must be visible to Windows (see §3)
```

`make hw` runs the units and IP flows and then builds the bitstream.
`MAX_VIVADO_INSTANCES` limits the number of parallel Vivado instances: choose
a value adequate to the CPUs and memory given to WSL (not 1).

To run software, follow [`hw/xilinx/doc/PROGRAM_LOADING.md`](../hw/xilinx/doc/PROGRAM_LOADING.md).
With the board attached to WSL (see §3), in one terminal:

```bash
make -C hw/xilinx openocd_run
```

and in another terminal:

```bash
make -C hw/xilinx gdb_run EXAMPLE=hello_world
```
