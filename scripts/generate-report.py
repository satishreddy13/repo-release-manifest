#!/usr/bin/env python3
"""
generate-report.py
Reads releases/<sprint>/manifest.yml and writes releases/<sprint>/RELEASE-NOTES.md.
"""

import sys
import os
from datetime import datetime

try:
    import yaml
except ImportError:
    sys.exit("Error: PyYAML not found. Install with:  pip3 install pyyaml")


TEAM_ORDER = ["conversion", "interfaces", "workflow_config", "func_config"]
TEAM_LABELS = {
    "conversion":    "Conversion",
    "interfaces":    "Interfaces",
    "workflow_config": "Workflow Config",
    "func_config":   "Functional Product Config",
}


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: generate-report.py <sprint>   e.g. generate-report.py sprint-12")

    sprint = sys.argv[1]
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root  = os.path.dirname(script_dir)
    manifest_path = os.path.join(repo_root, "releases", sprint, "manifest.yml")
    output_path   = os.path.join(repo_root, "releases", sprint, "RELEASE-NOTES.md")

    if not os.path.exists(manifest_path):
        sys.exit(f"Error: {manifest_path} not found")

    with open(manifest_path) as f:
        m = yaml.safe_load(f)

    teams       = m.get("teams", {})
    cots        = m.get("cots", {})
    envs        = m.get("environments", {})
    sit         = envs.get("sit", {})
    uat         = envs.get("uat", {})

    included = {k: v for k, v in teams.items() if v.get("included") is True}
    deferred = {k: v for k, v in teams.items() if v.get("included") is not True}

    lines = []

    def w(s=""):
        lines.append(s)

    # ── Header ────────────────────────────────────────────────────────────────
    w(f"# Release Notes — {m.get('release', sprint)}")
    w()
    w("| | |")
    w("|---|---|")
    w(f"| Sprint dates | {m.get('sprint_dates', 'TBD')} |")
    w(f"| Build date   | {m.get('build_date', 'TBD')} |")
    w(f"| Built by     | {m.get('built_by', 'TBD')} |")
    w(f"| ELM Sprint   | {m.get('elm_sprint_url', '')} |")
    w()
    w("---")
    w()

    # ── Included teams ────────────────────────────────────────────────────────
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
            items = t.get("elm_work_items") or []
            items_str = ", ".join(str(i) for i in items) if items else "none listed"
            commit = t.get("commit") or "not yet recorded"
            summary = t.get("summary") or "see ELM"
            w(f"### {label} ✅")
            w(f"- **Branch:** `{t.get('branch', '')}`")
            w(f"- **Commit:** `{commit}`")
            w(f"- **ELM items:** {items_str}")
            w(f"- **Summary:** {summary}")
            if t.get("notes"):
                w(f"- **Notes:** {t['notes']}")
            w()

    w("---")
    w()

    # ── Deferred teams ────────────────────────────────────────────────────────
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
            reason = t.get("reason") or "not specified"
            items  = t.get("elm_work_items") or []
            items_str = ", ".join(str(i) for i in items) if items else "none listed"
            w(f"### {label} ⏸")
            w(f"- **ELM items:** {items_str}")
            w(f"- **Reason:** {reason}")
            w("- Work deferred to next sprint.")
            w()

    w("---")
    w()

    # ── COTS ─────────────────────────────────────────────────────────────────
    w("## COTS Product")
    w()
    w("| | |")
    w("|---|---|")
    w(f"| Product           | {cots.get('product', 'N/A')} |")
    w(f"| Version           | {cots.get('version', 'N/A')} |")
    w(f"| Previous version  | {cots.get('previous_version', 'N/A')} |")
    w(f"| Included          | {'Yes' if cots.get('included') else 'No'} |")

    hotfixes = cots.get("hotfixes_included") or []
    if hotfixes:
        w(f"| Hotfixes          | {', '.join(str(h) for h in hotfixes)} |")

    w()
    if cots.get("notes"):
        w(f"> {cots['notes']}")
        w()
    cots_file = cots.get("release_notes_file", f"cots-{sprint}.md")
    w(f"See `{cots_file}` for full hotfix list and impact assessment.")
    w()
    w("---")
    w()

    # ── Environment status ────────────────────────────────────────────────────
    w("## Environment Status")
    w()
    w("| Environment | Status | Deployed | Notes |")
    w("|-------------|--------|----------|-------|")
    w(f"| SIT | {sit.get('status','pending')} | {sit.get('deployed_date','—')} | {sit.get('notes') or '—'} |")
    w(f"| UAT | {uat.get('status','pending')} | {uat.get('deployed_date','—')} | {uat.get('notes') or '—'} |")
    w()
    w("---")
    w(f"_Generated by generate-report.py on {datetime.now().strftime('%Y-%m-%d %H:%M')}_")

    # ── Write output ──────────────────────────────────────────────────────────
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
