#!/usr/bin/env python3
"""
generate-report.py
Reads releases/<sprint>/manifest.xlsx and writes releases/<sprint>/RELEASE-NOTES.md.

Usage:
    python3 scripts/generate-report.py sprint-12
"""

import sys
import os
from datetime import datetime

try:
    from openpyxl import load_workbook
except ImportError:
    sys.exit("Error: openpyxl not found. Install with:  pip3 install openpyxl")


TEAM_ORDER = ["conversion", "interfaces", "workflow_config", "func_config"]
TEAM_LABELS = {
    "conversion":      "Conversion",
    "interfaces":      "Interfaces",
    "workflow_config": "Workflow Config",
    "func_config":     "Functional Product Config",
}


# ── Parsing helpers ───────────────────────────────────────────────────────────

def cell_str(cell):
    """Return cell value as a stripped string, or empty string if None."""
    v = cell.value
    if v is None:
        return ""
    return str(v).strip()


def parse_kv_sheet(ws):
    """Parse a two-column key-value sheet (row 1 = header, rows 2+ = data).
    Returns a dict {field: value}.
    """
    result = {}
    for row in ws.iter_rows(min_row=2):
        key = cell_str(row[0])
        val = cell_str(row[1]) if len(row) > 1 else ""
        if key:
            result[key] = val
    return result


def parse_bool(val):
    """Treat Excel TRUE boolean or string 'true'/'TRUE' as Python True."""
    if isinstance(val, bool):
        return val
    if isinstance(val, str):
        return val.strip().upper() == "TRUE"
    return bool(val)


def parse_teams_sheet(ws):
    """Parse the Teams sheet. Row 1 = headers, rows 2+ = data.
    Returns a dict keyed by team_key.
    """
    header_row = next(ws.iter_rows(min_row=1, max_row=1))
    headers = [cell_str(c) for c in header_row]

    teams = {}
    for row in ws.iter_rows(min_row=2):
        values = [cell_str(c) for c in row]
        # Skip entirely blank rows
        if not any(values):
            continue
        record = dict(zip(headers, values))
        # Parse the raw cell value for 'included' (may be Excel boolean TRUE)
        included_raw = row[headers.index("included")].value if "included" in headers else ""
        record["included"] = parse_bool(included_raw)
        key = record.get("team_key", "")
        if key:
            teams[key] = record
    return teams


def parse_environments_sheet(ws):
    """Parse the Environments sheet. Row 1 = headers, rows 2+ = data.
    Returns a dict keyed by environment name.
    """
    header_row = next(ws.iter_rows(min_row=1, max_row=1))
    headers = [cell_str(c) for c in header_row]

    envs = {}
    for row in ws.iter_rows(min_row=2):
        values = [cell_str(c) for c in row]
        if not any(values):
            continue
        record = dict(zip(headers, values))
        env_name = record.get("environment", "")
        if env_name:
            envs[env_name] = record
    return envs


# ── Report generation ─────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: generate-report.py <sprint>   e.g. generate-report.py sprint-12")

    sprint = sys.argv[1]
    script_dir    = os.path.dirname(os.path.abspath(__file__))
    repo_root     = os.path.dirname(script_dir)
    manifest_path = os.path.join(repo_root, "releases", sprint, "manifest.xlsx")
    output_path   = os.path.join(repo_root, "releases", sprint, "RELEASE-NOTES.md")

    if not os.path.exists(manifest_path):
        sys.exit(f"Error: {manifest_path} not found")

    wb = load_workbook(manifest_path, data_only=True)

    # Parse all sheets
    build_info = parse_kv_sheet(wb["Build Info"])
    teams      = parse_teams_sheet(wb["Teams"])
    cots_data  = parse_kv_sheet(wb["COTS"])
    envs       = parse_environments_sheet(wb["Environments"])

    sit = envs.get("sit", {})
    uat = envs.get("uat", {})

    included = {k: v for k, v in teams.items() if v.get("included") is True}
    deferred = {k: v for k, v in teams.items() if v.get("included") is not True}

    lines = []

    def w(s=""):
        lines.append(s)

    # ── Header ─────────────────────────────────────────────────────────────────
    w(f"# Release Notes — {build_info.get('release', sprint)}")
    w()
    w("| | |")
    w("|---|---|")
    w(f"| Sprint dates | {build_info.get('sprint_dates', 'TBD')} |")
    w(f"| Build date   | {build_info.get('build_date', 'TBD')} |")
    w(f"| Built by     | {build_info.get('built_by', 'TBD')} |")
    w(f"| ELM Sprint   | {build_info.get('elm_sprint_url', '')} |")
    w()
    w("---")
    w()

    # ── Included teams ─────────────────────────────────────────────────────────
    w("## Teams Included in This Build")
    w()
    if not included:
        w("_No teams included._")
        w()
    else:
        for key in TEAM_ORDER:
            if key not in included:
                continue
            t     = included[key]
            label = TEAM_LABELS.get(key, key)
            sc    = t.get("source_control", "git").lower()

            items_raw = t.get("elm_work_items", "") or ""
            items_str = items_raw if items_raw else "none listed"

            w(f"### {label} \u2705")

            if sc == "sharepoint":
                # SharePoint-hosted team: show URL + artifact version
                sp_url   = t.get("repo_or_sharepoint_url", "")
                artifact = t.get("commit_or_artifact_version", "") or "not yet recorded"
                summary  = t.get("summary", "") or "see ELM"
                w(f"- **Source Control:** SharePoint")
                w(f"- **Location:** {sp_url}")
                w(f"- **Version:** `{artifact}`")
                w(f"- **ELM items:** {items_str}")
                w(f"- **Summary:** {summary}")
            else:
                # Git-hosted team: show branch + commit
                branch = t.get("branch", "")
                commit = t.get("commit_or_artifact_version", "") or "not yet recorded"
                summary = t.get("summary", "") or "see ELM"
                location = t.get("repo_or_sharepoint_url", "")
                w(f"- **Source Control:** git")
                w(f"- **Location:** {location}")
                w(f"- **Branch:** `{branch}`")
                w(f"- **Version:** `{commit}`")
                w(f"- **ELM items:** {items_str}")
                w(f"- **Summary:** {summary}")

            notes = t.get("notes", "")
            if notes:
                w(f"- **Notes:** {notes}")
            w()

    w("---")
    w()

    # ── Deferred teams ─────────────────────────────────────────────────────────
    w("## Teams Deferred (not in this build)")
    w()
    if not deferred:
        w("_All teams included in this build._")
        w()
    else:
        for key in TEAM_ORDER:
            if key not in deferred:
                continue
            t     = deferred[key]
            label = TEAM_LABELS.get(key, key)
            reason = t.get("reason_if_deferred", "") or "not specified"
            items_raw = t.get("elm_work_items", "") or ""
            items_str = items_raw if items_raw else "none listed"
            w(f"### {label} \u23f8")
            w(f"- **ELM items:** {items_str}")
            w(f"- **Reason:** {reason}")
            w("- Work deferred to next sprint.")
            w()

    w("---")
    w()

    # ── COTS ───────────────────────────────────────────────────────────────────
    w("## COTS Product")
    w()
    w("| | |")
    w("|---|---|")
    w(f"| Product           | {cots_data.get('product', 'N/A')} |")
    w(f"| Version           | {cots_data.get('version', 'N/A')} |")
    w(f"| Previous version  | {cots_data.get('previous_version', 'N/A')} |")
    cots_included = parse_bool(cots_data.get("included", ""))
    w(f"| Included          | {'Yes' if cots_included else 'No'} |")

    hotfixes = cots_data.get("hotfixes_included", "") or ""
    if hotfixes:
        w(f"| Hotfixes          | {hotfixes} |")

    w()
    cots_notes = cots_data.get("notes", "")
    if cots_notes:
        w(f"> {cots_notes}")
        w()
    cots_file = cots_data.get("release_notes_file", f"cots-{sprint}.md")
    w(f"See `{cots_file}` for full hotfix list and impact assessment.")
    w()
    w("---")
    w()

    # ── Environment status ─────────────────────────────────────────────────────
    w("## Environment Status")
    w()
    w("| Environment | Status | Deployed | Notes |")
    w("|-------------|--------|----------|-------|")
    w(f"| SIT | {sit.get('status','pending')} | {sit.get('deployed_date','—') or '—'} | {sit.get('notes','') or '—'} |")
    w(f"| UAT | {uat.get('status','pending')} | {uat.get('deployed_date','—') or '—'} | {uat.get('notes','') or '—'} |")
    w()
    w("---")
    w(f"_Generated by generate-report.py on {datetime.now().strftime('%Y-%m-%d %H:%M')}_")

    # ── Write output ────────────────────────────────────────────────────────────
    with open(output_path, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Report written to: {output_path}")
    print()
    print("=== Next steps: ===")
    print(f"  1. Review {output_path}")
    print(f"  2. git add releases/{sprint}/ && git commit -m 'Release: {sprint} build report'")
    print(f"  3. Open PR titled 'Release {sprint}' for CM team review")
    print(f"  4. Deploy to SIT, then run: ./scripts/tag-environments.sh {sprint} sit")


if __name__ == "__main__":
    main()
