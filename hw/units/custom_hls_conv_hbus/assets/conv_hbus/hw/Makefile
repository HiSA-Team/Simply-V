# Author: Vincenzo Merola <vincenzo.merola2@unina.it>
# Description:
#   This Makefile uses Vitis compiler to simulate and synthesize HLS kernel

DIR = conv_hbus

VITIS_HLS = vitis-run --mode hls
VPP = v++
VFLAGS = -c --mode hls
CSIM = ${VITIS_HLS} --csim
COSIM = ${VITIS_HLS} --cosim
SYN = ${VPP} ${VFLAGS}
PACK = ${VITIS_HLS} --package
IP = ${DIR}_hls

CONFIG = --config src/hls_config.cfg
WORK_DIR = --work_dir ${DIR}


.PHONY: csim
csim:
	@echo "[INFO] C-Simulation starting..."
	${CSIM} ${CONFIG} ${WORK_DIR}
	@echo "[INFO] C-Simulation ended"


.PHONY: syn
syn:
	@echo "Synthesis starting..."
	${SYN} ${CONFIG} ${WORK_DIR}
	@echo "[INFO] Synthesis ended"


.PHONY: cosim
cosim:
	@echo "[INFO] Cosimulation starting ..."
	${COSIM} ${CONFIG} ${WORK_DIR}
	@echo "[INFO] Cosimulation ended"


.PHONY: package
package:
	@echo "[INFO] Packaging IP..."
	${PACK} ${CONFIG} ${WORK_DIR}
	@echo "[INFO] Packaging ended"


.PHONY: clean
clean:
	@echo "[INFO] Cleaning..."
	rm -f ${IP}.zip
	rm -fr ${DIR}
	rm -f xcd.log
	rm -fr .Xil