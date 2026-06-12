#!/usr/bin/env bash
# =============================================================================
# cut-sprint.sh
# CM runs this at the START of each sprint.
#
# What it does:
#   1. Creates sprint/sprint-NN branch from main in each GIT team repo
#      (SharePoint teams are noted but skipped — no branch to create)
#   2. Scaffolds releases/sprint-NN/manifest.xlsx from the template
#   3. Scaffolds releases/sprint-NN/cots-sprint-NN.md from the template
#
# Usage:
#   ./scripts/cut-sprint.sh sprint-13
#
# Prerequisites:
#   - GIT_TEAM_REPOS / GIT_TEAM_NAMES: local clones of git-based team repos
#   - SHAREPOINT_TEAMS: team names whose work lives in SharePoint (no git ops)
#   - You must have write access to each git repo
# =============================================================================

set -euo pipefail

SPRINT=${1:-}
if [[ -z "$SPRINT" ]]; then
  echo "Usage: $0 <sprint-name>   e.g. $0 sprint-13"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Configure these paths for your environment ────────────────────────────────

# Git-based team repos — branches will be created here
GIT_TEAM_REPOS=(
  "/Volumes/projects/claudeCode/claudeProjects/repo-interfaces"
  "/Volumes/projects/claudeCode/claudeProjects/repo-workflow-config"
  "/Volumes/projects/claudeCode/claudeProjects/repo-func-config"
)
GIT_TEAM_NAMES=(
  "interfaces"
  "workflow_config"
  "func_config"
)

# SharePoint-based teams — no git operations; CM notifies them manually
SHAREPOINT_TEAMS=(
  "conversion"
)
SHAREPOINT_URLS=(
  "https://company.sharepoint.com/sites/ETL/Shared Documents/$SPRINT"
)

# ─────────────────────────────────────────────────────────────────────────────

BRANCH="sprint/$SPRINT"
RELEASE_DIR="$MANIFEST_ROOT/releases/$SPRINT"

echo "=== Cutting sprint: $SPRINT ==="
echo ""

# 1a. Create sprint branches in each git team repo
echo "--- Git teams ---"
for i in "${!GIT_TEAM_REPOS[@]}"; do
  REPO="${GIT_TEAM_REPOS[$i]}"
  NAME="${GIT_TEAM_NAMES[$i]}"

  if [[ ! -d "$REPO/.git" ]]; then
    echo "  [WARN] $NAME — repo not found at $REPO, skipping"
    continue
  fi

  echo "  [$NAME] Creating $BRANCH from main..."
  git -C "$REPO" fetch origin --quiet
  git -C "$REPO" checkout main --quiet
  git -C "$REPO" pull origin main --quiet

  if git -C "$REPO" rev-parse --verify "$BRANCH" &>/dev/null; then
    echo "  [$NAME] Branch $BRANCH already exists — skipping"
  else
    git -C "$REPO" checkout -b "$BRANCH" --quiet
    git -C "$REPO" push origin "$BRANCH" --quiet
    echo "  [$NAME] Created and pushed $BRANCH"
  fi
done

# 1b. Notify SharePoint teams — no git operations needed
echo ""
echo "--- SharePoint teams ---"
for i in "${!SHAREPOINT_TEAMS[@]}"; do
  NAME="${SHAREPOINT_TEAMS[$i]}"
  URL="${SHAREPOINT_URLS[$i]}"
  echo "  [$NAME] SharePoint team — no branch to create"
  echo "  [$NAME] Action required: create sprint folder at:"
  echo "          $URL"
  echo "  [$NAME] Notify team to upload their sprint-$SPRINT deliverables there"
done

echo ""

# 2. Scaffold manifest directory
if [[ -d "$RELEASE_DIR" ]]; then
  echo "  [WARN] $RELEASE_DIR already exists — not overwriting"
else
  mkdir -p "$RELEASE_DIR"

  # Generate manifest.xlsx from template script
  if python3 -c "import openpyxl" 2>/dev/null; then
    python3 "$SCRIPT_DIR/create_manifest_xlsx.py" "$SPRINT"
  else
    echo "  [WARN] openpyxl not found — skipping manifest.xlsx creation"
    echo "         Install with: pip3 install openpyxl"
  fi

  # Copy and replace NN placeholder in COTS template
  sed "s/sprint-NN/$SPRINT/g" "$MANIFEST_ROOT/templates/cots.md.template" \
    > "$RELEASE_DIR/cots-$SPRINT.md"

  # Create empty RELEASE-NOTES placeholder
  echo "# Release Notes — $SPRINT" > "$RELEASE_DIR/RELEASE-NOTES.md"
  echo "" >> "$RELEASE_DIR/RELEASE-NOTES.md"
  echo "> Run \`./scripts/generate-report.sh $SPRINT\` to populate this file." \
    >> "$RELEASE_DIR/RELEASE-NOTES.md"

  echo "  Scaffolded $RELEASE_DIR/"
  echo "    manifest.xlsx"
  echo "    cots-$SPRINT.md"
  echo "    RELEASE-NOTES.md"
fi

echo ""
echo "=== Done. Next steps for CM: ==="
echo "  1. Open releases/$SPRINT/manifest.xlsx and fill in team details"
echo "  2. Fill in COTS details: releases/$SPRINT/cots-$SPRINT.md"
echo "  3. Notify Git teams — sprint branch: $BRANCH"
echo "  4. Notify SharePoint teams — upload deliverables to their sprint folder"
