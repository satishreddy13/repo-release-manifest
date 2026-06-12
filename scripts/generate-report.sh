#!/usr/bin/env bash
# =============================================================================
# generate-report.sh
# CM runs this on BUILD DAY after finalising manifest.xlsx.
# Delegates to generate-report.py (requires Python 3 + openpyxl).
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

# Check Python + openpyxl
if ! python3 -c "import openpyxl" &>/dev/null; then
  echo "Error: openpyxl not found. Install with:  pip3 install openpyxl"
  exit 1
fi

python3 "$SCRIPT_DIR/generate-report.py" "$SPRINT"
