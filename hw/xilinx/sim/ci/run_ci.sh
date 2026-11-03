#!/usr/bin/env bash
# Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
# Description: local CI. Config flow unit tests, then the embedded SoC tests on Verilator:
#              every core with the Xilinx crossbar, ibex with the custom one too.
#              cv64a6_ara runs hello_world only, SIM_CI_FULL=1 runs its full suite.
#              The 64-bit cores skip xlnx_cdma_examples (RV32-only firmware) and
#              picorv32 skips interrupts (no standard interrupt CSRs).
set -euo pipefail

: "${SIMPLYV_ROOT_DIR:?source settings.sh first}"
cd "${SIMPLYV_ROOT_DIR}"
: "${PYTHON:?set PYTHON to the python of the config flow env}"
export PYTHON

echo "== [CI] config flow unit tests =="
(cd config/simply_config && "${PYTHON}" -m pytest -q tests)

all="hello_world echo interrupts xlnx_cdma_examples"
rv64="hello_world echo interrupts"
pico="hello_world echo xlnx_cdma_examples"
run() {
  echo "== [CI] CORE=$1 XBAR_IMPL=$2 TEST=$3 =="
  make sim CORE="$1" XBAR_IMPL="$2" TEST="$3"
}
for t in $all; do run ibex XILINX "$t"; done
for t in $all; do run ibex CUSTOM "$t"; done
for t in $all; do run cv32e40p XILINX "$t"; done
for t in $pico; do run picorv32 XILINX "$t"; done
for t in $rv64; do run cv64a6 XILINX "$t"; done
for t in $([ "${SIM_CI_FULL:-0}" = 1 ] && echo "$rv64" || echo hello_world); do run cv64a6_ara XILINX "$t"; done

echo "[CI] ALL PASS"
