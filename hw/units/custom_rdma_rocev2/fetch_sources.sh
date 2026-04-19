#!/bin/bash
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description:
# This script downloads RDMA_RoCEv2_standalone_accelerator sources and flattens them into the rtl directory

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
IP_NAME=$( basename $(dirname $( realpath ${BASH_SOURCE[0]} ) ))

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

GIT_URL=https://github.com/DOTTORM5/RDMA_RoCEv2_standalone_accelerator.git
GIT_BRANCH=main
GIT_COMMIT=60ac6a634f16211c21d94f0227f2d95a42475acd
CLONE_DIR=rdma_rocev2_accelerator
RTL_DIR="$PWD/rtl"

printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Cloning source repository${NC}\n"
rm -rf "${RTL_DIR}" "${CLONE_DIR}"
mkdir -p "${RTL_DIR}"

git clone "${GIT_URL}" -b "${GIT_BRANCH}" "${CLONE_DIR}"
( cd "${CLONE_DIR}" && git checkout "${GIT_COMMIT}" )

printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Flatten RTL into rtl${NC}\n"
while IFS= read -r -d '' f; do
	base=$(basename "$f")
	dst="${RTL_DIR}/${base}"
	if [ -e "$dst" ]; then
		printf "${RED}[FETCH_SOURCES $IP_NAME] Error: duplicate basename ${base} (flatten collision)${NC}\n"
		exit 1
	fi
	cp "$f" "$dst"
done < <(find "${CLONE_DIR}" -type f \( -name '*.sv' -o -name '*.v' -o -name '*.vh' -o -name '*.svh' \) ! -path '*/.git/*' -print0)

printf "${YELLOW}[FETCH_SOURCES $IP_NAME] Removing temporary clone${NC}\n"
rm -rf "${CLONE_DIR}"

printf "${GREEN}[FETCH_SOURCES $IP_NAME] Completed${NC}\n"
