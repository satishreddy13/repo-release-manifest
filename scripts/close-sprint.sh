#!/usr/bin/env bash
# =============================================================================
# close-sprint.sh
# CM runs this after UAT passes.
#
# What it does:
#   For GIT teams that were included:
#     1. Merges sprint/sprint-NN → main with --no-ff
#     2. Tags main as release/sprint-NN
#   For SHAREPOINT teams that were included:
#     1. Prints confirmation that their artifact version is the release record
#     2. No git operations needed
#   For deferred teams:
#     Prints carry-over reminder for next sprint planning
#
# Usage:
#   ./scripts/close-sprint.sh sprint-12
# =============================================================================

set -euo pipefail

SPRINT=${1:-}
if [[ -z "$SPRINT" ]]; then
  echo "Usage: $0 <sprint>   e.g. $0 sprint-12"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST="$MANIFEST_ROOT/releases/$SPRINT/manifest.xlsx"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: $MANIFEST not found"
  exit 1
fi

declare -A REPO_PATHS=(
  [interfaces]="/Volumes/projects/claudeCode/claudeProjects/repo-interfaces"
  [workflow_config]="/Volumes/projects/claudeCode/claudeProjects/repo-workflow-config"
  [func_config]="/Volumes/projects/claudeCode/claudeProjects/repo-func-config"
)

TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
RELEASE_TAG="release/$SPRINT"

echo "=== Closing sprint: $SPRINT ==="
echo ""
echo "  This will merge included git branches into main and tag releases."
read -rp "  Are you sure? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""

# Read manifest.xlsx
TEAM_DATA=$(python3 - <<'PYEOF'
import sys, os, openpyxl

manifest = sys.argv[1] if len(sys.argv) > 1 else ""
wb = openpyxl.load_workbook(manifest, data_only=True)
ws = wb["Teams"]
headers = [str(c.value).strip().lower().replace(" ","_") if c.value else "" for c in ws[1]]

def col(row, name):
    try:
        idx = headers.index(name)
        val = row[idx].value
        return str(val).strip() if val is not None else ""
    except (ValueError, IndexError):
        return ""

for row in ws.iter_rows(min_row=2):
    key    = col(row, "team_key")
    sc     = col(row, "source_control").lower()
    inc    = col(row, "included").lower()
    branch = col(row, "branch")
    cv     = col(row, "commit_or_artifact_version")
    if not key:
        continue
    included = "true" if inc in ("true", "yes", "1") else "false"
    print(f"{key}|{sc}|{included}|{branch}|{cv}")
PYEOF
-- "$MANIFEST" 2>/dev/null)

DEFERRED_TEAMS=()

while IFS='|' read -r TEAM SC INCLUDED BRANCH COMMIT_OR_VERSION; do
  if [[ "$INCLUDED" != "true" ]]; then
    DEFERRED_TEAMS+=("$TEAM ($SC)")
    echo "  [$TEAM] skipped (deferred) — carry over to next sprint"
    continue
  fi

  if [[ "$SC" == "sharepoint" ]]; then
    echo "  [$TEAM] SharePoint team — no merge needed"
    echo "  [$TEAM] Release artifact: version $COMMIT_OR_VERSION — recorded in manifest.xlsx"
    echo "  [$TEAM] Done"
    continue
  fi

  # Git team — merge and tag
  REPO="${REPO_PATHS[$TEAM]:-}"
  if [[ -z "$REPO" || ! -d "$REPO/.git" ]]; then
    echo "  [$TEAM] [WARN] Repo not found at ${REPO:-<unconfigured>}, skipping"
    continue
  fi

  echo "  [$TEAM] Merging $BRANCH → main..."
  git -C "$REPO" fetch origin --quiet
  git -C "$REPO" checkout main --quiet
  git -C "$REPO" pull origin main --quiet
  git -C "$REPO" merge "origin/$BRANCH" \
    --no-ff \
    -m "Release $SPRINT: merge $BRANCH into main" \
    --quiet
  git -C "$REPO" push origin main --quiet

  echo "  [$TEAM] Tagging main as $RELEASE_TAG..."
  git -C "$REPO" tag "$RELEASE_TAG" \
    -m "Release $SPRINT — merged to main on $TIMESTAMP"
  git -C "$REPO" push origin "$RELEASE_TAG" --quiet
  echo "  [$TEAM] Done"

done <<< "$TEAM_DATA"

# Mark manifest UAT as passed
python3 - <<PYEOF
import openpyxl

manifest = "$MANIFEST"
ts = "$TIMESTAMP"

wb = openpyxl.load_workbook(manifest)
ws = wb["Environments"]
headers = [str(c.value).strip().lower() if c.value else "" for c in ws[1]]

def cidx(name):
    return headers.index(name) + 1

for row in ws.iter_rows(min_row=2):
    env_cell = row[cidx("environment") - 1]
    if env_cell.value and str(env_cell.value).strip().lower() == "uat":
        row[cidx("status")     - 1].value = "passed"
        row[cidx("passed_date")- 1].value = ts
        break

wb.save(manifest)
print("  manifest.xlsx updated: environments.uat.status = passed")
PYEOF

echo ""
echo "=== Sprint $SPRINT closed ==="
echo ""

if [[ ${#DEFERRED_TEAMS[@]} -gt 0 ]]; then
  echo "  Deferred teams (carry over to next sprint):"
  for T in "${DEFERRED_TEAMS[@]}"; do
    echo "    - $T"
  done
  echo ""
fi

echo "  Commit and push the manifest update:"
echo "    cd $MANIFEST_ROOT"
echo "    git add releases/$SPRINT/"
echo "    git commit -m 'Close $SPRINT: UAT passed, manifest updated'"
echo "    git push origin master"
