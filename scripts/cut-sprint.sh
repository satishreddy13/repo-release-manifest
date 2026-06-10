#!/usr/bin/env bash
# =============================================================================
# cut-sprint.sh
# CM runs this at the START of each sprint.
#
# What it does:
#   1. Creates sprint/sprint-NN branch from main in each team repo
#   2. Scaffolds releases/sprint-NN/manifest.yml from the template
#   3. Scaffolds releases/sprint-NN/cots-sprint-NN.md from the template
#
# Usage:
#   ./scripts/cut-sprint.sh sprint-13
#
# Prerequisites:
#   - TEAM_REPOS must be set to the local paths of each team repo clone
#   - You must have write access to each repo
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
TEAM_REPOS=(
  "/Volumes/projects/claudeCode/claudeProjects/repo-conversion"
  "/Volumes/projects/claudeCode/claudeProjects/repo-interfaces"
  "/Volumes/projects/claudeCode/claudeProjects/repo-workflow-config"
  "/Volumes/projects/claudeCode/claudeProjects/repo-func-config"
)
TEAM_NAMES=(
  "conversion"
  "interfaces"
  "workflow_config"
  "func_config"
)
# ─────────────────────────────────────────────────────────────────────────────

BRANCH="sprint/$SPRINT"
RELEASE_DIR="$MANIFEST_ROOT/releases/$SPRINT"

echo "=== Cutting sprint: $SPRINT ==="
echo ""

# 1. Create sprint branches in each team repo
for i in "${!TEAM_REPOS[@]}"; do
  REPO="${TEAM_REPOS[$i]}"
  NAME="${TEAM_NAMES[$i]}"

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

echo ""

# 2. Scaffold manifest directory
if [[ -d "$RELEASE_DIR" ]]; then
  echo "  [WARN] $RELEASE_DIR already exists — not overwriting"
else
  mkdir -p "$RELEASE_DIR"

  # Copy and replace NN placeholder in manifest template
  sed "s/sprint-NN/$SPRINT/g" "$MANIFEST_ROOT/templates/manifest.yml.template" \
    > "$RELEASE_DIR/manifest.yml"

  # Copy and replace NN placeholder in COTS template
  sed "s/sprint-NN/$SPRINT/g" "$MANIFEST_ROOT/templates/cots.md.template" \
    > "$RELEASE_DIR/cots-$SPRINT.md"

  # Create empty RELEASE-NOTES placeholder
  echo "# Release Notes — $SPRINT" > "$RELEASE_DIR/RELEASE-NOTES.md"
  echo "" >> "$RELEASE_DIR/RELEASE-NOTES.md"
  echo "> Run \`./scripts/generate-report.sh $SPRINT\` to populate this file." \
    >> "$RELEASE_DIR/RELEASE-NOTES.md"

  echo "  Scaffolded $RELEASE_DIR/"
  echo "    manifest.yml"
  echo "    cots-$SPRINT.md"
  echo "    RELEASE-NOTES.md"
fi

echo ""
echo "=== Done. Next steps for CM: ==="
echo "  1. Fill in COTS details: releases/$SPRINT/cots-$SPRINT.md"
echo "  2. Share sprint branch name with all teams: $BRANCH"
echo "  3. Teams create feature/ELM-XXXX-* branches off $BRANCH"
