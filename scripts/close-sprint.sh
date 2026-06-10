#!/usr/bin/env bash
# =============================================================================
# close-sprint.sh
# CM runs this after UAT passes.
#
# What it does:
#   1. Merges each included team's sprint branch into main
#   2. Tags main as release/sprint-NN in each team repo
#   3. Marks manifest environments.uat.status = passed
#   4. Prints a summary of what to do next sprint for deferred teams
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
MANIFEST="$MANIFEST_ROOT/releases/$SPRINT/manifest.yml"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: $MANIFEST not found"
  exit 1
fi

declare -A REPO_PATHS=(
  [conversion]="/Volumes/projects/claudeCode/claudeProjects/repo-conversion"
  [interfaces]="/Volumes/projects/claudeCode/claudeProjects/repo-interfaces"
  [workflow_config]="/Volumes/projects/claudeCode/claudeProjects/repo-workflow-config"
  [func_config]="/Volumes/projects/claudeCode/claudeProjects/repo-func-config"
)

yaml_team_get() {
  local team="$1" key="$2"
  awk "/^  $team:/{found=1} found && /^    $key:/{print; found=0}" "$MANIFEST" \
    | sed 's/^[^:]*: *//' | tr -d '"'
}

TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
RELEASE_TAG="release/$SPRINT"

echo "=== Closing sprint: $SPRINT ==="
echo ""
echo "  This will merge included sprint branches into main."
read -rp "  Are you sure? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""

DEFERRED_TEAMS=()

for TEAM in conversion interfaces workflow_config func_config; do
  INCLUDED=$(yaml_team_get "$TEAM" "included")
  BRANCH=$(yaml_team_get "$TEAM" "branch")
  REPO="${REPO_PATHS[$TEAM]}"

  if [[ "$INCLUDED" != "true" ]]; then
    echo "  [$TEAM] skipped (deferred) — will need re-inclusion in next sprint"
    DEFERRED_TEAMS+=("$TEAM")
    continue
  fi

  if [[ ! -d "$REPO/.git" ]]; then
    echo "  [$TEAM] WARNING — repo not found at $REPO, skipping"
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
done

# Mark manifest UAT as passed
sed -i.bak \
  "/^  uat:/,/^  [a-z]/{
    s/status: deployed/status: passed/
    s|passed_date: .*|passed_date: $TIMESTAMP|
  }" "$MANIFEST"
rm -f "$MANIFEST.bak"

echo ""
echo "=== Sprint $SPRINT closed ==="
echo ""

if [[ ${#DEFERRED_TEAMS[@]} -gt 0 ]]; then
  echo "  Deferred teams (carry over to next sprint):"
  for T in "${DEFERRED_TEAMS[@]}"; do
    echo "    - $T  (branch still open: sprint/$SPRINT)"
    echo "      Action: continue work on sprint/$SPRINT or rebase onto next sprint branch"
  done
  echo ""
fi

echo "  Commit and push the manifest update:"
echo "    cd $(dirname "$SCRIPT_DIR")"
echo "    git add releases/$SPRINT/manifest.yml"
echo "    git commit -m 'Close $SPRINT: UAT passed, main updated'"
echo "    git push origin main"
