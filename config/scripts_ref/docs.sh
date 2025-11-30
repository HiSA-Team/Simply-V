#!/usr/bin/env bash
set -euo pipefail

# Simple script: generate class diagrams for each package and a global one.
# Uses pyreverse, discards everything except the desired class PNG files.

if ! command -v pyreverse >/dev/null 2>&1; then
  echo "Error: pyreverse not found." >&2
  exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"

DOCS_DIR="docs"
mkdir -p "$DOCS_DIR"

# Find python packages
mapfile -t PACKAGES < <(
  find . -maxdepth 3 -type f -name "__init__.py" -printf '%h\n' \
    | sed 's|^\./||' \
    | sort -u
)

# Generate class diagram for each package
for pkg in "${PACKAGES[@]}"; do
  pkg_name="$(basename "$pkg")"
  echo "Generating class diagram for package: $pkg"

  pyreverse -AS -o png -p "$pkg_name" "$pkg" >/dev/null 2>&1

  mv -f "classes_${pkg_name}.png" "$DOCS_DIR/${pkg_name}.png" 2>/dev/null || \
    echo "No class diagram produced for $pkg_name"
  
  rm -f "packages_${pkg_name}.png"
done

# Global diagram
GLOBAL="simply_v"
echo "Generating global class diagram"

pyreverse -AS -o png -p "$GLOBAL" . >/dev/null 2>&1

mv -f "classes_${GLOBAL}.png" "$DOCS_DIR/${GLOBAL}_classes.png" 2>/dev/null || \
  echo "No global class diagram produced"

rm -f "packages_${GLOBAL}.png"

echo "Done. Outputs in $DOCS_DIR"

