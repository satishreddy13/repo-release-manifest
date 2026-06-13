# Handoff Document — Release Manifest Prototype

**Date:** 2026-06-13  
**Status:** Prototype complete, sprint-12 demo fully working  
**GitHub org:** satishreddy13

---

## What This Is

A prototype release management system for a 5-team polyrepo environment with
bi-weekly sprint deliveries. CM owns a central "release manifest" repository
that acts as the single source of truth for every build — recording which
teams are included, their commit SHA or artifact version, environment
deployment status, and cross-team dependencies.

Two delivery models are supported:
- **Git teams** — branch + commit SHA + git tags (`sit/`, `uat/`, `release/`)
- **SharePoint teams** — folder URL + artifact version (e.g. `v1.3`) recorded in manifest; no git operations

---

## Repositories on GitHub (satishreddy13)

| Repo | Branch state | Notes |
|------|-------------|-------|
| `repo-release-manifest` | `master` | CM hub — all scripts, manifests, docs |
| `repo-interfaces` | `main` + `sprint/sprint-12` | Git team; depends on func_config |
| `repo-workflow-config` | `main` + `sprint/sprint-12` | Git team; ELM-1220 deferred this sprint |
| `repo-func-config` | `main` + `sprint/sprint-12` | Git team |
| `repo-conversion` | `main` + `sprint/sprint-12` | SharePoint team (git repo exists but SharePoint is the delivery mechanism) |

---

## Repository Layout (repo-release-manifest)

```
releases/
  sprint-12/
    manifest.xlsx         ← sprint-12 build definition (populated with demo data)
    RELEASE-NOTES.xlsx    ← generated report (3 sheets: Summary, Teams, COTS)
    cots-sprint-12.md     ← COTS 2.4.0 record

scripts/
  cut-sprint.sh                ← Phase 1 (sprint start)
  create_manifest_xlsx.py      ← called by cut-sprint.sh (Python)
  create_manifest_xlsx.js      ← called by cut-sprint.sh (Node.js fallback)
  generate-report.sh           ← Phase 4 (build day)
  generate-report.py           ← Python engine → writes RELEASE-NOTES.xlsx
  generate-report.js           ← Node.js engine → writes RELEASE-NOTES.xlsx
  read-manifest.js             ← Node.js manifest reader for bash scripts
  tag-environments.sh          ← Phases 5 & 7 (SIT / UAT tagging)
  close-sprint.sh              ← Phase 8 (UAT passed, merge to main)
  populate_sprint12.py         ← one-off: seeds sprint-12 demo data

docs/
  sprint-12-demo-guide.md      ← full end-to-end demo walkthrough
  dependency-management-options.md  ← options doc (Options 1-5)
  management-overview.pptx     ← 8-slide senior management deck
  sprint-12-demo.pptx          ← 12-slide technical demo deck

templates/
  cots.md.template             ← COTS record template

package.json / node_modules/   ← exceljs dependency (Node.js engine)
```

---

## manifest.xlsx — Sheet Structure

### Sheet 1: Build Info (key-value)
`release`, `sprint_dates`, `build_date`, `built_by`, `elm_sprint_url`

### Sheet 2: Teams (table, one row per team)

| Column | Purpose |
|--------|---------|
| `team_key` | Short identifier used in scripts (e.g. `func_config`) |
| `team_name` | Display name |
| `source_control` | `git` or `sharepoint` — controls all script behaviour |
| `repo_or_sharepoint_url` | GitHub repo path or SharePoint folder URL |
| `branch` | Sprint branch (git); `N/A` for SharePoint |
| `commit_or_artifact_version` | Commit SHA (git) or artifact version e.g. `v1.3` (SharePoint) |
| `included` | `TRUE` / `FALSE` |
| `elm_work_items` | Space-separated ELM item numbers |
| `summary` | One-line delivery summary |
| `notes` | Free-text |
| `depends_on` | **New.** Comma-separated `team_key` values this team depends on |
| `reason_if_deferred` | Required when `included = FALSE` |

### Sheet 3: COTS (key-value)
`product`, `version`, `previous_version`, `hotfixes_included`, `included`, `notes`, `release_notes_file`

### Sheet 4: Environments (table)
`environment`, `status`, `deployed_by`, `deployed_date`, `passed_date`, `notes`  
Rows: `sit`, `uat`

---

## Sprint-12 Demo Data (current state)

| Team | Source | Included | Commit / Version | depends_on |
|------|--------|----------|-----------------|------------|
| Conversion | SharePoint | ✅ | `v1.3` | — |
| Interfaces | Git | ✅ | `b2c3d4e5` | `func_config` |
| Workflow Config | Git | ❌ Deferred | — | — |
| Func Config | Git | ✅ | `c3d4e5f6` | — |

- COTS: Acme ETL Platform 2.3.8 → 2.4.0 (HF-2024-011, HF-2024-012)
- SIT: deployed (2026-06-20 14:30 by john.smith)
- UAT: pending

**Dependency demo:** `interfaces.depends_on = func_config`. If you set
`func_config.included = FALSE` in the manifest and re-run `generate-report.sh`,
the terminal and RELEASE-NOTES.xlsx will show a red dependency warning.

---

## Script Runtime

Scripts try **Python + openpyxl** first, fall back to **Node.js + exceljs**:

```bash
# Python path
pip3 install openpyxl

# Node.js path (already installed)
# node_modules/exceljs already present in repo root
```

The bash scripts (`tag-environments.sh`, `close-sprint.sh`) contain a
`read_manifest_teams()` helper function that auto-detects and uses whichever
runtime is available. `generate-report.sh` does the same.

---

## CM Lifecycle — Quick Command Reference

```bash
cd /Volumes/projects/claudeCode/claudeProjects/release-manifest

# Sprint start
./scripts/cut-sprint.sh sprint-13

# Build day — after filling in manifest.xlsx
./scripts/generate-report.sh sprint-12

# After SIT deployment
./scripts/tag-environments.sh sprint-12 sit

# After SIT passes
./scripts/tag-environments.sh sprint-12 uat

# After UAT passes
./scripts/close-sprint.sh sprint-12

# Mid-SIT team removal
cp -r releases/sprint-12 releases/sprint-12-patch1
# edit manifest.xlsx in patch1
./scripts/generate-report.sh sprint-12-patch1
./scripts/tag-environments.sh sprint-12-patch1 sit
```

---

## Key Design Decisions (and why)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Repo structure | Polyrepo | Teams deploy independently; no cross-team merge conflicts |
| Manifest format | Excel (.xlsx) | CM-friendly; non-technical stakeholders can open it; structured enough for scripts to parse |
| SharePoint support | `source_control` field per team | Conversion team doesn't use Git; both delivery models are first-class |
| Dependency tracking | `depends_on` column, team-level | Covers the common case with low CM overhead; Options 3-5 documented for future escalation |
| Report format | Excel (.xlsx) with styled sheets | Matches manifest format; colour-coded; easier to share than markdown |
| Script runtime | Python primary, Node.js fallback | No single runtime lock-in; auto-detected |
| Environment tracking | Git tags (`sit/`, `uat/`, `release/`) | Immutable record of exact deployed commit; survives branch deletions |

---

## Open Questions / Potential Next Steps

These were not implemented but came up during design:

1. **Dependency tracking depth** — current `depends_on` is team-level (Option 2).
   If cross-team dependencies become item-level, consider Option 3 (`depends_on_elm_items`)
   or Option 4 (ELM API integration). See `docs/dependency-management-options.md`.

2. **close-sprint.sh end-to-end test** — the script logic is correct but hasn't been
   run against real repos in a UAT-passed scenario. The demo stops at SIT deployed.

3. **GitHub Actions integration** — `generate-report.sh` could be triggered
   automatically on a PR to `releases/sprint-NN/manifest.xlsx` changing.

4. **Sprint history / dashboard** — currently each sprint is a standalone folder.
   A script that aggregates environment status across all sprints would give a
   bird's-eye view of what's deployed where.

5. **ELM API integration** — `generate-report.py` could call the ELM REST API
   to pull work item status/dependency links directly, removing manual entry of
   `elm_work_items` and `depends_on`.

6. **management-overview.pptx** — generated and opened; content not reviewed
   with stakeholders yet.

---

## Commit History

```
31ddc5c  Update README and demo guide for depends_on column
e269d99  Add depends_on column and cross-team dependency warnings
7bce102  Switch release notes to Excel and add Node.js alternative to Python scripts
14f2366  Add SharePoint delivery model, Excel manifest, and management overview deck
f2b4b02  Add sprint-12 demo guide and PowerPoint deck
9b06a87  Update repo paths and org references to satishreddy13
352b1d9  Replace bash YAML parser with Python generate-report.py
b5c1b12  Initial skeleton: release manifest repo
```

---

## How to Resume

1. Clone or open `repo-release-manifest` at `/Volumes/projects/claudeCode/claudeProjects/release-manifest`
2. Read `README.md` for the full CM runbook
3. Read `docs/sprint-12-demo-guide.md` to walk through the demo
4. The sprint-12 manifest and report are already populated — open
   `releases/sprint-12/manifest.xlsx` and `releases/sprint-12/RELEASE-NOTES.xlsx`
   to see the current state
5. To demonstrate the dependency warning: set `func_config.included = FALSE` in
   `manifest.xlsx`, run `./scripts/generate-report.sh sprint-12`, observe the warning,
   then restore `func_config.included = TRUE`
