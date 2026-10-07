#!/bin/bash
# =============================================================================
# Simply-V — HIL test on the Arty-A7 from WSL
#
# Programs the board, releases the core from reset (VIO), attaches the board
# to WSL with usbipd, starts OpenOCD, loads and runs hello_world through GDB,
# and checks that the expected string shows up on the UART.
#
# Usage (from the repository root, after `source settings.sh ...` and
# `make config`, with the bitstream and hello_world.elf already built):
#   bash hw/xilinx/scripts/utils/wsl/hil_hello_world_wsl.sh [BUSID]        # BUSID default: 1-4
#
# Works the same way from the terminal and from the CI, so it can be tested
# by hand with the board connected. Prerequisites: usbipd-win, xPack OpenOCD
# and read/write permission on the serial port.
# =============================================================================
set -u
set -o pipefail

BUSID="${1:-1-4}"
EXPECTED="${EXPECTED:-Hello World}"
OPENOCD_LOG=/tmp/hil_openocd.log
UART_LOG=/tmp/hil_uart.log
VIO_LOG=/tmp/hil_vio.log
OPENOCD_PID=""
UART_PID=""

cleanup() {
    [ -n "$UART_PID" ] && kill "$UART_PID" 2>/dev/null
    [ -n "$OPENOCD_PID" ] && kill "$OPENOCD_PID" 2>/dev/null
    # Give the board back to Windows so Vivado can use it again.
    # (`unbind` needs an elevated session; if it fails the device stays
    # "Shared" and Vivado will not see it until it is unbound by hand.)
    usbipd.exe detach --busid "$BUSID" >/dev/null 2>&1
    usbipd.exe unbind --busid "$BUSID" >/dev/null 2>&1
}
trap cleanup EXIT

fail() { echo "[HIL] FAIL: $*"; exit 1; }

command -v usbipd.exe >/dev/null || fail "usbipd.exe not found in PATH"
command -v vivado >/dev/null     || fail "vivado wrapper not found in PATH (see scripts/wsl/vivado)"
openocd --version 2>&1 | grep -qi xpack \
    || fail "OpenOCD is not the xPack build (the Ubuntu package has no telnet support)"
: > "$OPENOCD_LOG"; : > "$UART_LOG"; : > "$VIO_LOG"

echo "[HIL] 1/6 Program the bitstream (the board must be visible to Windows/Vivado)"
usbipd.exe detach --busid "$BUSID" >/dev/null 2>&1
usbipd.exe unbind --busid "$BUSID" >/dev/null 2>&1
( cd hw/xilinx && make program_bitstream ) || fail "make program_bitstream"

echo "[HIL] 2/6 Release the core from reset (VIO)"
vivado -mode batch \
    -source hw/xilinx/scripts/utils/open_hw_manager.tcl \
    -source hw/xilinx/scripts/utils/vio_reset.tcl \
    -tclargs vio_resetn 2>&1 | tee "$VIO_LOG" | tail -3
grep -q "Setting probe vio_resetn to 1" "$VIO_LOG" || fail "VIO reset (see $VIO_LOG)"

echo "[HIL] 3/6 Attach the board to WSL (usbipd)"
usbipd.exe bind --busid "$BUSID" >/dev/null 2>&1   # needs an elevated session; no-op if already bound
usbipd.exe attach --wsl --busid "$BUSID" \
    || fail "usbipd attach (device not bound? 'usbipd bind' needs an elevated session)"
for _ in $(seq 1 15); do ls /dev/ttyUSB* >/dev/null 2>&1 && break; sleep 1; done
PORT="$(ls /dev/ttyUSB* 2>/dev/null | tail -n1)"
[ -n "$PORT" ] || fail "no /dev/ttyUSB* after attach"
if [ ! -r "$PORT" ] || [ ! -w "$PORT" ]; then
    sudo -n chmod a+rw "$PORT" 2>/dev/null \
        || fail "no permission on $PORT (add the user to the dialout group)"
fi
echo "[HIL]     serial port: $PORT"

echo "[HIL] 4/6 Start OpenOCD"
( cd hw/xilinx && exec openocd -f scripts/load_binary/openocd.cfg ) > "$OPENOCD_LOG" 2>&1 &
OPENOCD_PID=$!
for _ in $(seq 1 20); do grep -q "Listening on port 3004" "$OPENOCD_LOG" && break; sleep 1; done
if ! grep -q "Examination succeed" "$OPENOCD_LOG"; then
    cat "$OPENOCD_LOG"
    fail "OpenOCD could not examine the core (dtmcontrol is 0? repeat the VIO reset)"
fi

echo "[HIL] 5/6 Listen on $PORT (9600 8N1)"
stty -F "$PORT" 9600 cs8 -cstopb -parenb raw -echo || fail "stty $PORT"
cat "$PORT" > "$UART_LOG" &
UART_PID=$!

echo "[HIL] 6/6 Load and run hello_world through GDB"
( cd hw/xilinx && timeout 120 make gdb_run EXAMPLE=hello_world ) < /dev/null 2>&1 | cat \
    || fail "make gdb_run"
sleep 3

echo "----- UART output -----"
cat "$UART_LOG"
echo "-----------------------"
grep -q "$EXPECTED" "$UART_LOG" || fail "'$EXPECTED' not found on the UART"
echo "[HIL] PASS"
