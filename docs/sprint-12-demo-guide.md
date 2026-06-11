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
| `repo-conversion` | Pentaho ETL — customer data pipelines | satishreddy13/repo-conversion |
| `repo-interfaces` | REST integrations, Pentaho jobs | satishreddy13/repo-interfaces |
| `repo-workflow-config` | Workflow rules, approval chains | satishreddy13/repo-workflow-config |
| `repo-func-config` | Region codes, product hierarchy | satishreddy13/repo-func-config |

---

## Phase 1 — Sprint Start: Cut the Sprint Branches

**Who:** CM  
**When:** Day 1 of sprint-12  
**What:** Create `sprint/sprint-12` in all team repos; scaffold the manifest

### Command

```bash
cd /Volumes/projects/claudeCode/claudeProjects/release-manifest
./scripts/cut-sprint.sh sprint-12
```

### What happens

1. Each team repo gets a `sprint/sprint-12` branch created from `main` and pushed to GitHub.
2. `releases/sprint-12/` directory is scaffolded with:
   - `manifest.yml` — from template, placeholders ready to fill
   - `cots-sprint-12.md` — COTS version record template
   - `RELEASE-NOTES.md` — placeholder, generated later

### What teams see

All four teams receive the sprint branch name: `sprint/sprint-12`.  
They create their own feature branches off it:

| Team | Feature branches created |
|------|--------------------------|
| Conversion | `feature/ELM-1201-address-normalisation`, `feature/ELM-1202-null-guards`, `feature/ELM-1208-audit-user-rename` |
| Interfaces | `feature/ELM-1210-v2-endpoints`, `feature/ELM-1215-retry-logic` |
| Workflow Config | `feature/ELM-1221-account-closure`, `feature/ELM-1220-dynamic-approvals` |
| Func Config | `feature/ELM-1230-region-expansion`, `feature/ELM-1231-med-mea-products` |

---

## Phase 2 — Development: Teams Work in Their Repos

**Who:** Each development team  
**When:** Throughout the sprint (sprint-12: 9 Jun → 20 Jun 2026)

Teams commit on their feature branches with the ELM convention:

```
ELM-XXXX: Short description of what was done
```

When ready, they raise a PR from `feature/ELM-XXXX-*` → `sprint/sprint-12` for peer review and merge.

### Snapshot of what each team delivered

**Conversion Team** — `repo-conversion / sprint/sprint-12`  
- `ELM-1201` — `customer_address_mapping.ktr` v1.2: suburb normalisation, PO Box detection  
- `ELM-1202` — `account_load.sql`: null guards on `customer_id` + empty `account_type` check  
- `ELM-1208` — `sql/migrations/rename_audit_column.sql`: idempotent PostgreSQL migration, `created_by → audit_user` (required for COTS 2.4.0)

```bash
# View the sprint-12 diff
git -C repo-conversion log main..sprint/sprint-12 --oneline
```

**Interfaces Team** — `repo-interfaces / sprint/sprint-12`  
- `ELM-1210` — `rest_endpoints.properties`: all endpoints moved to `/v2`, timeout 30s → 60s  
- `ELM-1215` — `retry_config.properties`: status-code retry on 408/503/504; circuit breaker added

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

CM opens `releases/sprint-12/manifest.yml` and fills in:

1. Build metadata (date, built_by, ELM sprint URL)
2. For each team: `included: true/false`, `commit` SHA, `elm_work_items`, `summary`
3. COTS version details

### The sprint-12 decision

| Team | Included? | Reason |
|------|-----------|--------|
| Conversion | ✅ Yes | All three ELM items complete and tested |
| Interfaces | ✅ Yes | v2 endpoints and retry logic ready |
| Workflow Config | ❌ **Deferred** | ELM-1220 not complete — business sign-off outstanding. Risk too high to include partial work |
| Func Config | ✅ Yes | Region and product data complete |

**COTS:** upgrading from 2.3.8 → 2.4.0. Includes hotfixes HF-2024-011 and HF-2024-012. The `rename_audit_column.sql` migration (ELM-1208 from Conversion) is required to support this upgrade.

### Viewing the filled manifest

```bash
cat releases/sprint-12/manifest.yml
```

Key fields to highlight:
```yaml
  workflow_config:
    included: false
    reason: "ELM-1220 blocked pending sign-off from business — deferred to sprint-13"
```

---

## Phase 4 — Generate the Release Notes

**Who:** CM  
**When:** Build day, after manifest is finalised

```bash
cd /Volumes/projects/claudeCode/claudeProjects/release-manifest
./scripts/generate-report.sh sprint-12
```

### What it produces

`releases/sprint-12/RELEASE-NOTES.md` — a fully formatted markdown report with:

- Build metadata table (dates, builder, ELM sprint link)
- **Teams Included** section: branch, commit SHA, ELM items, summary per team
- **Teams Deferred** section: reason logged for audit trail
- **COTS** section: version, previous version, hotfixes
- **Environment Status** table: SIT/UAT status

```bash
# Preview the output
cat releases/sprint-12/RELEASE-NOTES.md
```

This document is committed to the `repo-release-manifest` repo and forms the official build record for the CM team's PR review.

---

## Phase 5 — Deploy to SIT and Tag

**Who:** CM / DevOps  
**When:** After build artifact is deployed to SIT environment

Each included team's `sprint/sprint-12` branch tip is deployed. After successful deployment:

```bash
./scripts/tag-environments.sh sprint-12 sit
```

### What it does

1. Reads `manifest.yml` to find included teams and their commit SHAs
2. Creates `sit/sprint-12` tag on that exact commit in each included team repo:
   - `repo-conversion`  → tagged at ELM-1201/1202/1208 commit
   - `repo-interfaces`  → tagged at ELM-1210/1215 commit
   - `repo-func-config` → tagged at ELM-1230/1231 commit
   - `repo-workflow-config` → **skipped** (included: false)
3. Pushes tags to GitHub
4. Updates `manifest.yml`: `environments.sit.status = deployed`

### Result — git tag visible in each repo

```bash
git -C repo-conversion tag -l "sit/*"
# sit/sprint-12

git -C repo-workflow-config tag -l "sit/*"
# (nothing — deferred team gets no SIT tag)
```

---

## Phase 6 — Mid-SIT Issue (Optional Scenario)

> This scenario demonstrates how to remove a team **after** a build has already gone to SIT.

**Scenario:** During SIT testing, a defect is found in Func Config's region data (hypothetical). The team needs more time to fix it. It must be removed from the SIT build without holding up the other teams.

### Step 1 — Create a patch manifest

```bash
mkdir -p releases/sprint-12-patch1
cp releases/sprint-12/manifest.yml releases/sprint-12-patch1/manifest.yml
```

Edit `sprint-12-patch1/manifest.yml`: set `func_config.included: false` with a reason.

### Step 2 — Generate patch release notes

```bash
./scripts/generate-report.sh sprint-12-patch1
```

### Step 3 — Re-deploy to SIT with the patched build

Deploy only the included teams' artifacts.

### Step 4 — Tag the patched SIT

```bash
./scripts/tag-environments.sh sprint-12-patch1 sit
```

Now `repo-conversion` and `repo-interfaces` have `sit/sprint-12-patch1` tags. The original `sit/sprint-12` tags remain as an audit trail.

---

## Phase 7 — SIT Passes → Deploy to UAT

**Who:** CM  
**When:** After SIT sign-off

```bash
./scripts/tag-environments.sh sprint-12 uat
```

Same process as SIT tagging: creates `uat/sprint-12` tags on included team repos and updates the manifest environment status.

```yaml
environments:
  uat:
    status: deployed
    deployed_date: "2026-06-25 10:00"
```

---

## Phase 8 — UAT Passes → Close the Sprint

**Who:** CM  
**When:** After UAT sign-off from business

```bash
./scripts/close-sprint.sh sprint-12
```

### What it does

For each **included** team:
1. Merges `sprint/sprint-12` → `main` with `--no-ff` (preserves sprint branch history)
2. Tags `main` as `release/sprint-12` in that team's repo
3. Pushes to GitHub

For **deferred** team (workflow_config):
- Branch `sprint/sprint-12` stays open — team continues work
- Script prints a reminder: "carry over to next sprint"

Updates manifest: `environments.uat.status = passed`

### Result after close

```
repo-conversion:  main  ← merged sprint/sprint-12 + tagged release/sprint-12
repo-interfaces:  main  ← merged sprint/sprint-12 + tagged release/sprint-12
repo-func-config: main  ← merged sprint/sprint-12 + tagged release/sprint-12

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

Sprint-13 `manifest.yml` sets:
```yaml
workflow_config:
  branch: sprint/sprint-13
  included: true
```

---

## Key Design Decisions — Quick Reference

| Decision | Approach | Why |
|----------|----------|-----|
| Repo structure | Polyrepo (5 team repos + 1 manifest repo) | Teams are independent; no merge conflicts across teams |
| Build coordination | `manifest.yml` in release-manifest repo | Single source of truth; CM-owned; auditable via git history |
| Deferred team handling | `included: false` in manifest — no branch surgery | Safe; branch stays intact for next sprint; no rebasing drama |
| Mid-SIT removal | `sprint-12-patch1` manifest — copy + edit | Immutable audit trail; original sprint-12 record preserved |
| Environment tracking | Git tags (`sit/`, `uat/`, `release/`) on team repos | Pinpoints exact deployed commit; survives branch deletions |
| COTS tracking | Version + hotfix record in `cots-sprint-NN.md` | Proprietary binaries never in git; record is auditable |
| ELM traceability | `ELM-XXXX:` commit prefix + `elm_work_items` in manifest | Links every build to IBM ELM work items end-to-end |

---

## File Reference

```
repo-release-manifest/
├── README.md                          ← CM runbook (full lifecycle)
├── templates/
│   ├── manifest.yml.template          ← Sprint manifest template
│   └── cots.md.template               ← COTS version record template
├── scripts/
│   ├── cut-sprint.sh                  ← Phase 1: cut sprint branches
│   ├── generate-report.sh             ← Phase 4: generate RELEASE-NOTES.md
│   ├── generate-report.py             ← (called by generate-report.sh)
│   ├── tag-environments.sh            ← Phases 5 & 7: tag SIT / UAT
│   └── close-sprint.sh                ← Phase 8: merge to main, tag release
├── releases/
│   └── sprint-12/
│       ├── manifest.yml               ← Sprint-12 build manifest
│       ├── cots-sprint-12.md          ← COTS 2.4.0 record
│       └── RELEASE-NOTES.md           ← Generated build report
└── .github/
    ├── CODEOWNERS                     ← CM team owns all PRs
    └── ISSUE_TEMPLATE/
        └── remove-team-mid-sit.md     ← Checklist for mid-SIT removal
```
