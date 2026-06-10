---
name: Remove team mid-SIT
about: Track removal of a team's work after a build has been deployed to SIT
title: "[PATCH] Remove <team> from <sprint>"
labels: patch-release
assignees: ''
---

## Sprint
<!-- e.g. sprint-12 -->

## Team being removed
<!-- e.g. Interfaces Team -->

## ELM work items affected
<!-- list ELM-XXXX IDs that will not be in this build -->

## Reason
<!-- What issue was found in SIT? Link to defect in ELM if raised -->

## Action plan
- [ ] Create `releases/<sprint>-patch1/manifest.yml` with team set to `included: false`
- [ ] Run `./scripts/generate-report.sh <sprint>-patch1`
- [ ] Deploy patched build to SIT
- [ ] Run `./scripts/tag-environments.sh <sprint>-patch1 sit`
- [ ] Notify stakeholders with updated RELEASE-NOTES.md
- [ ] Log deferred ELM items for next sprint planning
