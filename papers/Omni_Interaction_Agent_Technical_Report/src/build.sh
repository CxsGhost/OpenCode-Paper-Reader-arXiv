#!/usr/bin/env bash
# Build the paper to main.pdf with pdflatex + bibtex (via latexmk).
#   ./build.sh         build main.pdf
#   ./build.sh clean   remove all generated files
set -euo pipefail
cd "$(dirname "$0")"

# latexmk was installed to ~/.local/bin (no root); make sure it's reachable.
export PATH="$HOME/.local/bin:$PATH"

if ! command -v latexmk >/dev/null 2>&1; then
  echo "latexmk not found on PATH (expected in ~/.local/bin)." >&2
  exit 1
fi

if [[ "${1:-}" == "clean" ]]; then
  latexmk -C
  echo "Cleaned."
  exit 0
fi

latexmk -pdf -interaction=nonstopmode -bibtex main.tex
echo
echo "Built: $(pwd)/main.pdf"
