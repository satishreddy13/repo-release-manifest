#!/usr/bin/env bash
# =============================================================================
# tag-environments.sh
# CM runs this after deploying a build to SIT or UAT.
#
# What it does:
#   1. Reads the manifest to find which teams were included and their commit SHAs
#   2. Creates git tags (sit/sprint-NN or uat/sprint-NN) on those commits
#      in each team repo
#   3. Updates the environment status in manifest.yml
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
MANIFEST="$MANIFEST_ROOT/releases/$SPRINT/manifest.yml"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: $MANIFEST not found"
  exit 1
fi

# ── Configure team repo paths ─────────────────────────────────────────────────
declare -A REPO_PATHS=(
  [conversion]="/Volumes/projects/claudeCode/claudeProjects/repo-conversion"
  [interfaces]="/Volumes/projects/claudeCode/claudeProjects/repo-interfaces"
  [workflow_config]="/Volumes/projects/claudeCode/claudeProjects/repo-workflow-config"
  [func_config]="/Volumes/projects/claudeCode/claudeProjects/repo-func-config"
)
# ─────────────────────────────────────────────────────────────────────────────

yaml_team_get() {
  local team="$1" key="$2"
  awk "/^  $team:/{found=1} found && /^    $key:/{print; found=0}" "$MANIFEST" \
    | sed 's/^[^:]*: *//' | tr -d '"'
}

TAG="$ENV/$SPRINT"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
DEPLOYER="${USER:-CM}"

echo "=== Tagging $ENV for $SPRINT ==="
echo ""

for TEAM in conversion interfaces workflow_config func_config; do
  INCLUDED=$(yaml_team_get "$TEAM" "included")
  COMMIT=$(yaml_team_get "$TEAM" "commit")
  REPO="${REPO_PATHS[$TEAM]}"

  if [[ "$INCLUDED" != "true" ]]; then
    echo "  [$TEAM] skipped (included: false)"
    continue
  fi

  if [[ -z "$COMMIT" ]]; then
    echo "  [$TEAM] WARNING — commit SHA not recorded in manifest, skipping tag"
    continue
  fi

  if [[ ! -d "$REPO/.git" ]]; then
    echo "  [$TEAM] WARNING — repo not found at $REPO, skipping tag"
    continue
  fi

  if git -C "$REPO" rev-parse "$TAG" &>/dev/null; then
    echo "  [$TEAM] Tag $TAG already exists — skipping (delete manually to re-tag)"
  else
    git -C "$REPO" tag "$TAG" "$COMMIT" \
      -m "Deployed to $ENV as part of $SPRINT on $TIMESTAMP by $DEPLOYER"
    git -C "$REPO" push origin "$TAG" --quiet
    echo "  [$TEAM] Tagged $COMMIT as $TAG"
  fi
done

# Update manifest.yml environment status in-place
DATE_KEY="${ENV}:"
sed -i.bak \
  "/^  $ENV:/,/^  [a-z]/{
    s/status: pending/status: deployed/
    s/status: failed/status: deployed/
  }" "$MANIFEST"
sed -i.bak \
  "/^  $ENV:/,/^  [a-z]/{
    s|deployed_by: .*|deployed_by: $DEPLOYER|
    s|deployed_date: .*|deployed_date: $TIMESTAMP|
  }" "$MANIFEST"
rm -f "$MANIFEST.bak"

echo ""
echo "=== Done ==="
echo "  Tags pushed: $TAG on all included team repos"
echo "  Manifest updated: environments.$ENV.status = deployed"
echo ""
echo "Next:"
if [[ "$ENV" == "sit" ]]; then
  echo "  When SIT passes: ./scripts/tag-environments.sh $SPRINT uat"
else
  echo "  When UAT passes: ./scripts/close-sprint.sh $SPRINT"
fi
