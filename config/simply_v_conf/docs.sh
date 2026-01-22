#!/usr/bin/env bash

# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This script uses "pyreverse" to automatically generate class diagrams
# of all the Python classes in the configuration flow, a more structured and precise
# documentation is in the {CONFIG_ROOT}/doc folder, but since that documentation need to
# be manually kept up to date when changing the code, this script can be used to have updated
# class diagrams in a immediate manner.

set -euo pipefail

# pyreverse need to see the root folder in PYTHONPATH to work correctly
export PYTHONPATH="${PWD}"

# Simple script: generate class diagrams for each package and a global one.
# Uses pyreverse, discards everything except the desired class PNG files.

if ! command -v pyreverse >/dev/null 2>&1; then
  echo "Error: pyreverse not found." >&2
  exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"

DOCS_DIR="doc_gen"
mkdir -p "$DOCS_DIR"

# Find python packages
mapfile -t PACKAGES < <(
  find . -maxdepth 3 -type f -name "__init__.py" -printf '%h\n' \
    | sed 's|^\./||' \
    | sort -u
)

# Generate class diagram for each package
for pkg in "${PACKAGES[@]}"; do
  if [ "$pkg" = "." ]; then
    pkg_name="simply_v"
  else
    pkg_name="$(basename "$pkg")"
  fi

  echo "Generating class diagram for package: $pkg_name"

  pyreverse -AS -o png -p "$pkg_name" "$pkg" >/dev/null 2>&1

  mv -f "classes_${pkg_name}.png" "$DOCS_DIR/${pkg_name}.png" 2>/dev/null || \
    echo "No class diagram produced for $pkg_name"

  rm -f "packages_${pkg_name}.png"
done
