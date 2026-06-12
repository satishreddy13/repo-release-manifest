# Sprint-12 Release Management — End-to-End Demo Guide

> **Purpose:** Walk through the full CM lifecycle for sprint-12, from sprint cut to UAT close,
> using the five GitHub repositories created for this prototype.
>
> **Audience:** CM team, Release Managers, stakeholders reviewing the branching strategy.

---

## Repositories in Play

| Repo | Description | GitHub |
|------|-------------|--------|
| `repo-release-manifest` | CM hub — manifests, scripts, runbook | satishreddy13/repo-release-manifest |
| `repo-conversion` | Pentaho ETL — **SharePoint delivery** | satishreddy13/repo-conversion |
| `repo-interfaces` | REST integrations, Pentaho jobs | satishreddy13/repo-interfaces |
| `repo-workflow-config` | Workflow rules, approval chains | satishreddy13/repo-workflow-config |
| `repo-func-config` | Region codes, product hierarchy | satishreddy13/repo-func-config |

> **Note:** Conversion delivers via SharePoint, not Git. CM records their artifact version
> in the manifest; no git branch or tag operations apply to that team.

---

## Phase 1 — Sprint Start: Cut the Sprint Branches

**Who:** CM  
**When:** Day 1 of sprint-12  
**What:** Create `sprint/sprint-12` in all Git team repos; scaffold the manifest

### Command

```bash
cd /Volumes/projects/claudeCode/claudeProjects/release-manifest
./scripts/cut-sprint.sh sprint-12
```

### What happens

1. Each **Git** team repo gets a `sprint/sprint-12` branch created from `main` and pushed to GitHub.
2. **SharePoint** team (Conversion) is skipped — script prints the expected SharePoint folder URL and a reminder to notify the team.
3. `releases/sprint-12/` directory is scaffolded with:
   - `manifest.xlsx` — 4-sheet Excel file (Build Info, Teams, COTS, Environments) ready to fill in
   - `cots-sprint-12.md` — COTS version record template
   - `RELEASE-NOTES.xlsx` — placeholder, generated later

### What teams see

Git teams receive the sprint branch name: `sprint/sprint-12`.  
They create their own feature branches off it:

| Team | Delivery | Feature branches created |
|------|----------|--------------------------|
| Conversion | SharePoint | _(no branches — uploads to sprint folder)_ |
| Interfaces | Git | `feature/ELM-1210-v2-endpoints`, `feature/ELM-1215-retry-logic` |
| Workflow Config | Git | `feature/ELM-1221-account-closure`, `feature/ELM-1220-dynamic-approvals` |
| Func Config | Git | `feature/ELM-1230-region-expansion`, `feature/ELM-1231-med-mea-products` |

---

## Phase 2 — Development: Teams Work in Their Repos

**Who:** Each development team  
**When:** Throughout the sprint (sprint-12: 9 Jun → 20 Jun 2026)

Git teams commit on their feature branches with the ELM convention:

```
ELM-XXXX: Short description of what was done
```

When ready, they raise a PR from `feature/ELM-XXXX-*` → `sprint/sprint-12` for peer review and merge.

### Snapshot of what each team delivered

**Conversion Team** — SharePoint folder: `sites/ETL/Shared Documents/sprint-12`
- Artifact version: `v1.3`
- `ELM-1201` — Customer address mapping: suburb normalisation, PO Box detection
- `ELM-1202` — Account load: null guards on `customer_id` + empty `account_type` check
- `ELM-1208` — Audit column rename (required for COTS 2.4.0)

**Interfaces Team** — `repo-interfaces / sprint/sprint-12`
- `ELM-1210` — `rest_endpoints.properties`: all endpoints moved to `/v2`, timeout 30s → 60s
- `ELM-1215` — `retry_config.properties`: status-code retry on 408/503/504; circuit breaker added

> **Dependency note:** Interfaces depends on Func Config (`depends_on: func_config`).
> If Func Config is deferred, `generate-report.sh` will emit a dependency warning and
> highlight it in the release notes — CM must decide whether Interfaces can still ship.

**Workflow Config Team** — `repo-workflow-config / sprint/sprint-12`
- `ELM-1221` — `workflow_rules.xml` v1.2: account closure rule added ✅
- `ELM-1220` — Dynamic approval chains: **blocked** — pending business sign-off ⛔
  → Commit message explicitly warns: "Do not deploy to SIT without CM sign-off"

**Func Config Team** — `repo-func-config / sprint/sprint-12`
- `ELM-1230` — `region_codes.sql`: MED, MEA, NAC regions added
- `ELM-1231` — `product_hierarchy.sql`: MED/MEA product variants; balance thresholds updated

---

## Phase 3 — Build Day: Finalise the Manifest

**Who:** CM  
**When:** End of sprint (20 Jun 2026)

CM opens `releases/sprint-12/manifest.xlsx` and fills in the **Teams sheet**:

| Column | What to fill in |
|--------|----------------|
| `included` | TRUE or FALSE |
| `commit_or_artifact_version` | Git commit SHA (git teams) or artifact version e.g. `v1.3` (SharePoint) |
| `elm_work_items` | Space-separated ELM item numbers |
| `summary` | One-line description of what the team delivered |
| `depends_on` | Comma-separated `team_key` values this team needs in the build (leave blank if none) |
| `reason_if_deferred` | Required if `included = FALSE` — reason for deferral |

Also fills in the **Build Info sheet** (build date, built_by) and **COTS sheet** (version, hotfixes).

### The sprint-12 decision

| Team | Delivery | Included? | `depends_on` | Reason |
|------|----------|-----------|--------------|--------|
| Conversion | SharePoint | ✅ Yes | — | All three items complete; artifact `v1.3` uploaded |
| Interfaces | Git | ✅ Yes | `func_config` | v2 endpoints and retry logic ready; depends on func_config being in the build |
| Workflow Config | Git | ❌ **Deferred** | — | ELM-1220 not complete — business sign-off outstanding |
| Func Config | Git | ✅ Yes | — | Region and product data complete |

**COTS:** upgrading from 2.3.8 → 2.4.0. Includes hotfixes HF-2024-011 and HF-2024-012.

> **Demonstrating `depends_on`:** Because `interfaces.depends_on = func_config` and
> `func_config` is **included**, there are no warnings this sprint. To see the warning
> in action, temporarily set `func_config.included = FALSE` in the manifest — the
> next `generate-report.sh` run will flag it.

---

## Phase 4 — Generate the Release Notes

**Who:** CM  
**When:** Build day, after manifest is finalised

```bash
cd /Volumes/projects/claudeCode/claudeProjects/release-manifest
./scripts/generate-report.sh sprint-12
```

The script auto-detects Python + openpyxl (primary) or Node.js + exceljs (fallback).

### What it produces

`releases/sprint-12/RELEASE-NOTES.xlsx` — a styled Excel workbook with three sheets:

| Sheet | Contents |
|-------|----------|
| **Summary** | Build info, environment status, dependency warnings (red band if any) |
| **Teams** | All teams with colour-coded status — green=included, red=deferred; `Depends On` column highlighted amber (satisfied) or red (broken dependency) |
| **COTS** | Product version and hotfix details |

### Dependency warning output (example)

If `func_config` were deferred while `interfaces.depends_on = func_config`:

```
⚠️  DEPENDENCY WARNINGS:
   Interfaces depends on Functional Product Config — but Functional Product Config is DEFERRED
```

The same warning appears as a red band in the Summary sheet. CM must review and
decide whether to also defer Interfaces before the build goes out.

This report is committed to the `repo-release-manifest` repo and forms the
official build record for the CM team's PR review.

---

## Phase 5 — Deploy to SIT and Tag

**Who:** CM / DevOps  
**When:** After build artifact is deployed to SIT environment

Each included Git team's `sprint/sprint-12` branch tip is deployed (SharePoint artifact is already in place).

```bash
./scripts/tag-environments.sh sprint-12 sit
```

### What it does

1. Reads `manifest.xlsx` to find included teams and their source control type.
2. **Git teams:** creates `sit/sprint-12` tag on the recorded commit SHA in each included repo:
   - `repo-interfaces`  → tagged at ELM-1210/1215 commit (`b2c3d4e5`)
   - `repo-func-config` → tagged at ELM-1230/1231 commit (`c3d4e5f6`)
   - `repo-workflow-config` → **skipped** (included: false)
3. **SharePoint team (Conversion):** prints artifact version confirmation — no git tag needed.
4. Updates `manifest.xlsx` Environments sheet: `sit.status = deployed`.

### Result — git tags visible in each repo

```bash
git -C repo-interfaces tag -l "sit/*"
# sit/sprint-12

git -C repo-workflow-config tag -l "sit/*"
# (nothing — deferred team gets no SIT tag)
```

---

## Phase 6 — Mid-SIT Issue (Optional Scenario)

> This scenario demonstrates how to remove a team **after** a build has already gone to SIT.

**Scenario:** During SIT testing, a defect is found in Func Config's region data (hypothetical).
The team needs more time to fix it and must be removed from the SIT build without holding up
the other teams.

> **Dependency cascade to consider:** Interfaces has `depends_on = func_config`. Before
> creating the patch manifest, CM should check whether Interfaces can still function without
> Func Config's changes. If not, Interfaces should also be deferred in the patch manifest.

### Step 1 — Create a patch manifest

```bash
cp -r releases/sprint-12 releases/sprint-12-patch1
```

Open `releases/sprint-12-patch1/manifest.xlsx`:
- Set `func_config.included = FALSE` with a reason
- If needed, also set `interfaces.included = FALSE` (dependency cascade)

### Step 2 — Generate patch release notes

```bash
./scripts/generate-report.sh sprint-12-patch1
```

If `interfaces.depends_on = func_config` and func_config is now FALSE, the report
will show a dependency warning — confirming CM's decision to review Interfaces.

### Step 3 — Re-deploy to SIT with the patched build

Deploy only the included teams' artifacts.

### Step 4 — Tag the patched SIT

```bash
./scripts/tag-environments.sh sprint-12-patch1 sit
```

Now included repos have `sit/sprint-12-patch1` tags. The original `sit/sprint-12`
tags remain as an audit trail.

---

## Phase 7 — SIT Passes → Deploy to UAT

**Who:** CM  
**When:** After SIT sign-off

```bash
./scripts/tag-environments.sh sprint-12 uat
```

Same process as SIT tagging: creates `uat/sprint-12` tags on included Git team repos
and updates `manifest.xlsx` Environments sheet: `uat.status = deployed`.

---

## Phase 8 — UAT Passes → Close the Sprint

**Who:** CM  
**When:** After UAT sign-off from business

```bash
./scripts/close-sprint.sh sprint-12
```

### What it does

For each **included Git team**:
1. Merges `sprint/sprint-12` → `main` with `--no-ff` (preserves sprint branch history)
2. Tags `main` as `release/sprint-12` in that team's repo
3. Pushes to GitHub

For **SharePoint team (Conversion)**:
- Prints confirmation that artifact `v1.3` is the release record — no git operations needed.

For **deferred team (workflow_config)**:
- Branch `sprint/sprint-12` stays open — team continues work
- Script prints a reminder: "carry over to next sprint"

Updates `manifest.xlsx` Environments sheet: `uat.status = passed`.

### Result after close

```
repo-interfaces:  main  ← merged sprint/sprint-12 + tagged release/sprint-12
repo-func-config: main  ← merged sprint/sprint-12 + tagged release/sprint-12

repo-conversion:  SharePoint v1.3 is the release artifact (no git merge)

repo-workflow-config: sprint/sprint-12 still open  (ELM-1220 carries to sprint-13)
```

---

## Phase 9 — Sprint-13 Pickup for Deferred Team

**Who:** Workflow Config team + CM  
**When:** Sprint-13 starts

### Option A — Continue on same branch

If ELM-1220 is unblocked quickly, the team continues on `sprint/sprint-12` (still open).
Sprint-13 manifest includes `workflow_config` pointing to the same branch.

### Option B — Rebase onto fresh sprint-13 branch

If significant new work is also needed:

```bash
# CM creates sprint-13 branch in workflow-config repo
./scripts/cut-sprint.sh sprint-13

# Team rebases their ELM-1220 work
git -C repo-workflow-config rebase sprint/sprint-12 sprint/sprint-13
```

Sprint-13 manifest: set `workflow_config.included = TRUE`, `branch = sprint/sprint-13`.

---

## Key Design Decisions — Quick Reference

| Decision | Approach | Why |
|----------|----------|-----|
| Repo structure | Polyrepo (5 team repos + 1 manifest repo) | Teams are independent; no merge conflicts across teams |
| Build coordination | `manifest.xlsx` in release-manifest repo | Single source of truth; CM-owned; auditable via git history |
| Delivery models | Git (branch + SHA) or SharePoint (folder URL + artifact version) | Conversion team doesn't use git; both models are first-class |
| Deferred team handling | `included: FALSE` in manifest — no branch surgery | Safe; branch stays intact for next sprint; no rebasing drama |
| Cross-team dependencies | `depends_on` column — team-level; warning at report time | Surfaces silent dependency gaps before build goes to SIT |
| Mid-SIT removal | `sprint-12-patch1` manifest — copy + edit | Immutable audit trail; original sprint-12 record preserved |
| Environment tracking | Git tags (`sit/`, `uat/`, `release/`) on team repos | Pinpoints exact deployed commit; survives branch deletions |
| COTS tracking | Version + hotfix record in `cots-sprint-NN.md` | Proprietary binaries never in git; record is auditable |
| ELM traceability | `ELM-XXXX:` commit prefix + `elm_work_items` in manifest | Links every build to IBM ELM work items end-to-end |
| Script runtime | Python + openpyxl (primary); Node.js + exceljs (fallback) | No single runtime lock-in; auto-detected by shell scripts |

---

## File Reference

```
repo-release-manifest/
├── README.md                                  ← CM runbook (full lifecycle)
├── docs/
│   ├── sprint-12-demo-guide.md                ← This file
│   ├── dependency-management-options.md       ← Options considered for depends_on
│   ├── management-overview.pptx               ← Senior management overview deck
│   └── sprint-12-demo.pptx                    ← Technical demo slides
├── scripts/
│   ├── cut-sprint.sh                          ← Phase 1: cut sprint branches
│   ├── create_manifest_xlsx.py / .js          ← Called by cut-sprint.sh
│   ├── generate-report.sh                     ← Phase 4: generate RELEASE-NOTES.xlsx
│   ├── generate-report.py / .js               ← Python and Node.js report engines
│   ├── read-manifest.js                       ← Node.js manifest reader for bash scripts
│   ├── tag-environments.sh                    ← Phases 5 & 7: tag SIT / UAT
│   └── close-sprint.sh                        ← Phase 8: merge to main, tag release
├── releases/
│   └── sprint-12/
│       ├── manifest.xlsx                      ← Sprint-12 build manifest (4 sheets)
│       ├── cots-sprint-12.md                  ← COTS 2.4.0 record
│       └── RELEASE-NOTES.xlsx                 ← Generated build report (3 sheets)
└── templates/
    └── cots.md.template                       ← COTS record template
```

### manifest.xlsx — Teams sheet columns

| Column | Description |
|--------|-------------|
| `team_key` | Short identifier used in scripts (e.g. `func_config`) |
| `team_name` | Display name |
| `source_control` | `git` or `sharepoint` |
| `repo_or_sharepoint_url` | GitHub repo or SharePoint folder URL |
| `branch` | Sprint branch (git teams); `N/A` for SharePoint |
| `commit_or_artifact_version` | Commit SHA (git) or artifact version e.g. `v1.3` (SharePoint) |
| `included` | `TRUE` / `FALSE` |
| `elm_work_items` | Space-separated ELM item numbers |
| `summary` | One-line delivery summary |
| `notes` | Free-text notes |
| `depends_on` | Comma-separated `team_key` values this team depends on being in the build |
| `reason_if_deferred` | Required when `included = FALSE` |
