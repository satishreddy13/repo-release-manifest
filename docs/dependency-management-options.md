# Cross-Team Dependency Management — Options

This document records the options evaluated for handling cross-team dependencies
in the release manifest. It exists so CM and the team can revisit the decision
if the current implementation proves insufficient.

**Current implementation: Option 2 — `depends_on` column.**

---

## The Problem

The manifest tracks each team independently. If Team A is included in a build
but depends on work from Team B, and Team B gets deferred, the build goes out
with a silent gap. The dependency is only discovered at SIT or UAT when
integration failures surface.

The manifest has no built-in mechanism to detect or warn about this situation.

---

## Option 1 — Free-text `notes` convention *(no change)*

CM manually enters a dependency note in the `notes` column of the dependent team:

```
interfaces | notes: "requires func_config ELM-1231 in build"
```

**How it works:** Purely manual. CM has to know about the dependency and remember
to check it when a team is deferred. No script enforcement.

**Pros:**
- Zero changes to schema or scripts.
- Works today.

**Cons:**
- Entirely dependent on CM awareness and discipline.
- Easy to miss under sprint pressure.
- Gives no automated warning at report generation time.
- Does not scale as team count grows.

**Best for:** Rare, one-off dependencies where the CM team is small and
communication is tight.

---

## Option 2 — `depends_on` column *(current implementation)*

A structured `depends_on` column in the Teams sheet lists team keys the team
depends on (comma-separated). The report generator reads it and emits a warning
if any listed team is deferred.

```
interfaces | depends_on: "func_config"
```

At report generation time:

```
⚠  DEPENDENCY WARNING:
   Interfaces depends on Functional Product Config — but Functional Product Config is DEFERRED
```

The warning appears:
- In the terminal output of `generate-report.sh`
- As a red warning band in the `RELEASE-NOTES.xlsx` Summary sheet
- As a red highlighted cell in the Teams sheet `Depends On` column

**Schema change:** Add `depends_on` column (column 11) to the Teams sheet,
between `notes` and `reason_if_deferred`. Value is a comma-separated list of
`team_key` values (e.g. `func_config` or `func_config,workflow_config`).

**Pros:**
- Low implementation effort.
- CM-visible directly in `manifest.xlsx`.
- Automated warning surfaces at report generation — CM sees it before the build
  goes out, not after SIT fails.
- Handles multiple dependencies per team (comma-separated).

**Cons:**
- Team-level granularity only — doesn't say *which* work items drive the
  dependency.
- CM must know about and manually record the dependency when filling in the
  manifest. If developers don't communicate cross-team dependencies to CM,
  they won't appear here.
- Dependency record is in the manifest (sprint-scoped), not in the authoritative
  source (ELM). Must be re-entered each sprint.

**Best for:** Most teams, most of the time. Covers the common case where a team
lead tells CM "we need func_config's changes to be in before we can go."

---

## Option 3 — ELM work item level dependency (`depends_on_elm_items`)

Instead of team-level, track the specific ELM work items the team depends on:

```
interfaces | depends_on_elm_items: "ELM-1231"
```

The report generator cross-references: is `ELM-1231` in any deferred team's
`elm_work_items` column? If yes, raise a warning.

**Pros:**
- Precise — handles partial dependencies correctly. If Interfaces depends on
  ELM-1231 but func_config also delivers ELM-1230, deferring ELM-1230 alone
  does not trigger a false warning.
- Matches how ELM actually tracks work — dependency is at the item level, not
  the team level.

**Cons:**
- CM must know the specific ELM item numbers and keep them in sync with the
  manifest. More cognitive load than just naming a team.
- A team's work items can change during a sprint; the manifest entry can go
  stale.
- Still manual — still relies on CM recording the dependency.

**Best for:** Environments where ELM work items are well-defined, stable, and
developers actively communicate item-level dependencies.

---

## Option 4 — Pull dependencies from ELM API

Query the ELM (IBM Engineering Lifecycle Management) API at report-generation
time to fetch dependency links between work items. No manual entry in the
manifest — the script knows that ELM-1215 (Interfaces) blocks on ELM-1231
(Func Config) because a developer created that link in ELM.

**How it would work:**
1. `generate-report.py` collects all `elm_work_items` values from the manifest.
2. For each included team's work items, it calls the ELM REST API to fetch
   outgoing dependency links.
3. If a linked item belongs to a deferred team's work items, a warning is raised.

**Pros:**
- Authoritative — dependencies live where work is tracked, not duplicated in
  the manifest.
- No manual CM maintenance of dependency data.
- Handles partial dependencies naturally (item-level precision).
- Works even for dependencies CM doesn't know about, as long as developers
  linked the items in ELM.

**Cons:**
- Requires ELM API access (authentication, network access from the CM machine).
- Requires developers to actively create dependency links in ELM — if they
  don't, you get no signal.
- Adds external API call to the report generation step — adds latency and a
  potential failure mode if ELM is unavailable.
- More implementation complexity than any other option.

**Best for:** Mature ELM adoption where developers consistently use ELM
dependency tracking, and CM wants zero-maintenance dependency detection.

---

## Option 5 — Dependency validation as a pre-build checklist *(process only)*

No tooling change. The runbook has a mandatory pre-build checklist step:

> **Before cutting the build:**
> For each deferred team, CM checks in ELM whether any included team's work
> items have a dependency on the deferred team's items. If yes, CM reviews with
> the team lead before proceeding.

**Pros:**
- No code or schema changes.
- Works even when ELM dependency links are missing — CM can use judgment and
  direct team communication.
- Flexible — handles complex situations that tools can't anticipate.

**Cons:**
- Entirely reliant on CM discipline and ELM being up to date.
- Does not scale as the number of teams or work items grows.
- No audit trail of whether the check was done.

**Best for:** Interim measure while a more automated option is being implemented,
or for low-frequency dependency scenarios.

---

## Comparison Matrix

| Option | Implementation Effort | Detection Accuracy | CM Maintenance | Scales? | Best for |
|--------|-----------------------|--------------------|----------------|---------|----------|
| 1 — notes convention | None | Low (human) | High | No | Rare deps, small teams |
| **2 — `depends_on` column** | **Low** | **Medium (team-level)** | **Medium** | **Yes** | **Most cases** |
| 3 — ELM item level | Medium | High (item-level) | High | With discipline | Well-tracked ELM |
| 4 — ELM API | High | Very high (automated) | Low | Yes | Mature ELM adoption |
| 5 — Checklist process | None | Human-dependent | High | No | Interim / low frequency |

---

## Upgrading from Option 2

If cross-team dependencies become more complex and Option 2's team-level
granularity proves insufficient:

- **Move to Option 3:** Add a `depends_on_elm_items` column alongside `depends_on`.
  Update `generate-report.py` to cross-reference item keys across teams.
  Low disruption — Option 2 column can remain as a fallback.

- **Move to Option 4:** Add ELM API credentials to the CM environment and
  rewrite the dependency check block in `generate-report.py` to call the ELM
  REST API. The `depends_on` column can then be retired or kept as a manual
  override for cases where ELM links are missing.
