#!/usr/bin/env bash
# =============================================================================
# generate-report.sh
# CM runs this on BUILD DAY after finalising manifest.xlsx.
# Writes releases/<sprint>/RELEASE-NOTES.xlsx
#
# Uses Python 3 + openpyxl if available, falls back to Node.js + exceljs.
#
# Usage:
#   ./scripts/generate-report.sh sprint-12
#   ./scripts/generate-report.sh sprint-12-patch1
# =============================================================================

set -euo pipefail

SPRINT=${1:-}
if [[ -z "$SPRINT" ]]; then
  echo "Usage: $0 <sprint>   e.g. $0 sprint-12"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Prefer Python; fall back to Node.js ───────────────────────────────────────
if python3 -c "import openpyxl" &>/dev/null; then
  python3 "$SCRIPT_DIR/generate-report.py" "$SPRINT"
elif node --version &>/dev/null && [[ -f "$SCRIPT_DIR/../node_modules/.bin/exceljs" || \
      -d "$SCRIPT_DIR/../node_modules/exceljs" ]]; then
  node "$SCRIPT_DIR/generate-report.js" "$SPRINT"
else
  echo "Error: No report engine found."
  echo ""
  echo "  Option A (Python):  pip3 install openpyxl"
  echo "  Option B (Node.js): cd $(dirname "$SCRIPT_DIR") && npm install"
  exit 1
fi
