# CI runner setup

This guide describes how to prepare a machine to run the CI workflow
(`.github/workflows/arty-a7-ci.yml`). It is a one-time configuration step, to
be done together with the installation of the GitHub Actions runner itself and
before the first CI run. The workflow does not install any of the tools listed
here.

## 1. GitHub Actions runner

- Install a self-hosted runner for the repository (*Settings → Actions →
  Runners → New self-hosted runner*) and follow the instructions shown there.
- The jobs use `runs-on: [self-hosted, arty-a7-wsl]`: give the runner the
  `arty-a7-wsl` label when configuring it.
- Use runner version 2.327.1 or newer, required by the Node 24 actions used in
  the workflow. The runner used so far is 2.337.0.
- Keep the runner running (`./run.sh`, or install it as a service).

## 2. Operating system

Ubuntu. If the machine runs Windows, run the runner inside WSL (Ubuntu) with
Vivado installed on the Windows side, following [WSL_SETUP.md](WSL_SETUP.md).

## 3. Required tools

| Tool | Used by | Instructions |
|---|---|---|
| `git`, `make`, `python3`, `curl`, `tar` | configuration, fetching the sources | standard Ubuntu packages |
| Vivado, with the board files of the target board | build job (IPs, bitstream), HIL job (programming) | [BOARDS_INSTALLATION.md](../hw/xilinx/doc/BOARDS_INSTALLATION.md) |
| RISC-V GCC (`riscv32-unknown-elf-*`) | build job (software) | [GCC_INSTALLATION.md](../sw/doc/GCC_INSTALLATION.md) |
| OpenOCD with FTDI support | HIL job | [OPENOCD_INSTALLATION.md](../sw/doc/OPENOCD_INSTALLATION.md) |

Notes:

- `vivado` must be in the `PATH` of the user running the runner. On WSL this is
  the wrapper script `scripts/wsl/vivado`, see [WSL_SETUP.md](WSL_SETUP.md).
- The HIL script currently checks that OpenOCD is the xPack build, and stops
  otherwise.
- Bender does not need to be installed: each unit downloads its own copy.
- On native Linux, Vivado needs the cable drivers, see
  [INSTALL_CABLE_DRIVERS.md](../hw/xilinx/doc/INSTALL_CABLE_DRIVERS.md).

## 4. PATH

The shell of the runner does not read `.bashrc`, so the workflow sets the
`PATH` itself in the step *Add local tools to PATH*:

- `build` job: `$HOME/bin`
- `hil_test` job: `$HOME/bin` and `$HOME/xpack-openocd-0.12.0-7/bin`

In our setup `$HOME/bin` contains the `vivado` wrapper and the
`riscv32-unknown-elf-*` commands. If the tools are installed elsewhere, update
that step.

## 5. Board for the HIL job

- The target board must be connected to the machine running the runner.
- On WSL, the USB device is shared with WSL by `usbipd-win` (see
  [WSL_SETUP.md](WSL_SETUP.md)), and `usbipd.exe` must be in the `PATH`. The
  HIL script binds and attaches the board itself; `usbipd bind` needs an
  elevated session the first time.
- The HIL script uses USB bus ID `1-4` by default. `usbipd list` shows the
  bus ID of your board: if it differs, pass it as the argument of the script.
- The runner user needs read and write access to the serial port
  (`/dev/ttyUSB*`): add the user to the `dialout` group.

## 6. Disk space and resources

Vivado builds are heavy. On WSL the virtual disk is stored on the Windows
drive: if that drive is full, WSL can turn read-only. Keep enough free space,
and give WSL enough memory and swap, see [WSL_SETUP.md](WSL_SETUP.md).

## 7. Checklist

If a job fails, check these first:

```bash
command -v vivado riscv32-unknown-elf-gcc openocd
openocd --version | head -1     # the HIL script expects the xPack build
command -v usbipd.exe           # WSL only
groups | grep dialout
```
