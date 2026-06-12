#!/usr/bin/env bash
# =============================================================================
# tag-environments.sh
# CM runs this after deploying a build to SIT or UAT.
#
# What it does:
#   1. Reads manifest.xlsx to find included teams and their source_control type
#   2. For GIT teams: creates sit/sprint-NN or uat/sprint-NN tags on the
#      exact commit SHA recorded in the manifest
#   3. For SHAREPOINT teams: records the artifact version in the manifest
#      (no git tagging — version is the SharePoint folder/file version)
#   4. Updates environment status in manifest.xlsx
#
# Usage:
#   ./scripts/tag-environments.sh sprint-12 sit
#   ./scripts/tag-environments.sh sprint-12 uat
#   ./scripts/tag-environments.sh sprint-12-patch1 sit
# =============================================================================

set -euo pipefail

SPRINT=${1:-}
ENV=${2:-}

if [[ -z "$SPRINT" || -z "$ENV" ]]; then
  echo "Usage: $0 <sprint> <sit|uat>"
  echo "  e.g. $0 sprint-12 sit"
  exit 1
fi

if [[ "$ENV" != "sit" && "$ENV" != "uat" ]]; then
  echo "Error: environment must be 'sit' or 'uat'"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST="$MANIFEST_ROOT/releases/$SPRINT/manifest.xlsx"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: $MANIFEST not found"
  exit 1
fi

# ── Configure git team repo paths ─────────────────────────────────────────────
declare -A REPO_PATHS=(
  [interfaces]="/Volumes/projects/claudeCode/claudeProjects/repo-interfaces"
  [workflow_config]="/Volumes/projects/claudeCode/claudeProjects/repo-workflow-config"
  [func_config]="/Volumes/projects/claudeCode/claudeProjects/repo-func-config"
)
# ─────────────────────────────────────────────────────────────────────────────

TAG="$ENV/$SPRINT"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
DEPLOYER="${USER:-CM}"

echo "=== Tagging $ENV for $SPRINT ==="
echo ""

# Read manifest.xlsx — try Python first, then Node.js
# Format per team: TEAM_KEY|source_control|included|commit_or_version
read_manifest_teams() {
  local manifest="$1"
  if python3 -c "import openpyxl" &>/dev/null; then
    python3 - <<'PYEOF' -- "$manifest" 2>/dev/null
import sys, openpyxl
manifest = sys.argv[1] if len(sys.argv) > 1 else ""
wb = openpyxl.load_workbook(manifest, data_only=True)
ws = wb["Teams"]
headers = [str(c.value).strip().lower().replace(" ","_") if c.value else "" for c in ws[1]]
def col(row, name):
    try:
        idx = headers.index(name); val = row[idx].value
        return str(val).strip() if val is not None else ""
    except (ValueError, IndexError): return ""
for row in ws.iter_rows(min_row=2):
    key = col(row,"team_key"); sc = col(row,"source_control").lower()
    inc = col(row,"included").lower(); cv = col(row,"commit_or_artifact_version")
    if not key: continue
    included = "true" if inc in ("true","yes","1") else "false"
    print(f"{key}|{sc}|{included}|{cv}")
PYEOF
  elif node --version &>/dev/null && [[ -d "$(dirname "$SCRIPT_DIR")/node_modules/exceljs" ]]; then
    node "$SCRIPT_DIR/read-manifest.js" "$manifest" teams
  else
    echo "Error: No xlsx reader found. Install Python/openpyxl or run: npm install" >&2
    exit 1
  fi
}

TEAM_DATA=$(read_manifest_teams "$MANIFEST")

while IFS='|' read -r TEAM SC INCLUDED COMMIT_OR_VERSION; do
  if [[ "$INCLUDED" != "true" ]]; then
    echo "  [$TEAM] skipped (included: false)"
    continue
  fi

  if [[ "$SC" == "sharepoint" ]]; then
    # SharePoint team — record artifact version, no git tagging
    echo "  [$TEAM] SharePoint team — no git tag"
    if [[ -n "$COMMIT_OR_VERSION" ]]; then
      echo "  [$TEAM] Artifact version $COMMIT_OR_VERSION deployed to $ENV — record in manifest"
    else
      echo "  [$TEAM] [WARN] No artifact version recorded in manifest — update manifest.xlsx"
    fi
    continue
  fi

  # Git team — create tag
  REPO="${REPO_PATHS[$TEAM]:-}"
  if [[ -z "$REPO" ]]; then
    echo "  [$TEAM] [WARN] No repo path configured, skipping tag"
    continue
  fi

  if [[ -z "$COMMIT_OR_VERSION" ]]; then
    echo "  [$TEAM] [WARN] No commit SHA in manifest — update manifest.xlsx before tagging"
    continue
  fi

  if [[ ! -d "$REPO/.git" ]]; then
    echo "  [$TEAM] [WARN] Repo not found at $REPO, skipping tag"
    continue
  fi

  if git -C "$REPO" rev-parse "$TAG" &>/dev/null; then
    echo "  [$TEAM] Tag $TAG already exists — skipping (delete manually to re-tag)"
  else
    git -C "$REPO" tag "$TAG" "$COMMIT_OR_VERSION" \
      -m "Deployed to $ENV as part of $SPRINT on $TIMESTAMP by $DEPLOYER"
    git -C "$REPO" push origin "$TAG" --quiet
    echo "  [$TEAM] Tagged $COMMIT_OR_VERSION as $TAG"
  fi

done <<< "$TEAM_DATA"

# Update environment status in manifest.xlsx
python3 - <<PYEOF
import sys, openpyxl
from datetime import datetime

manifest = "$MANIFEST"
env      = "$ENV"
deployer = "$DEPLOYER"
ts       = "$TIMESTAMP"

wb = openpyxl.load_workbook(manifest)
ws = wb["Environments"]
headers = [str(c.value).strip().lower() if c.value else "" for c in ws[1]]

def cidx(name):
    return headers.index(name) + 1  # 1-based

for row in ws.iter_rows(min_row=2):
    env_cell = row[cidx("environment") - 1]
    if env_cell.value and str(env_cell.value).strip().lower() == env:
        row[cidx("status")       - 1].value = "deployed"
        row[cidx("deployed_by")  - 1].value = deployer
        row[cidx("deployed_date")- 1].value = ts
        break

wb.save(manifest)
print(f"  manifest.xlsx updated: environments.{env}.status = deployed")
PYEOF

echo ""
echo "=== Done ==="
echo "  Git tags pushed: $TAG on included git team repos"
echo "  SharePoint teams: artifact versions noted above — update manifest.xlsx if needed"
echo "  Manifest updated: environments.$ENV.status = deployed"
echo ""
if [[ "$ENV" == "sit" ]]; then
  echo "  When SIT passes: ./scripts/tag-environments.sh $SPRINT uat"
else
  echo "  When UAT passes: ./scripts/close-sprint.sh $SPRINT"
fi
