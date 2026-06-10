# COTS Version Record — sprint-12

| Field | Value |
|-------|-------|
| Product | Acme ETL Platform |
| Version | 2.4.0 |
| Previous version | 2.3.8 |
| Vendor release date | 2026-06-15 |
| Received by team | 2026-06-16 |
| Included in build | Yes |

---

## What Changed from 2.3.8

- Audit log table schema updated — column `created_by` renamed to `audit_user`
- REST API retry timeout increased from 30s to 60s by default
- New configuration property `etl.parallel.threads` (default: 4)
- Deprecated `legacy_mode` flag removed — any scripts using this must be updated

---

## Hotfixes Included

| Hotfix ID | Description | Affected area |
|-----------|-------------|---------------|
| HF-2024-011 | Fix memory leak in large CSV batch processing | ETL engine core |
| HF-2024-012 | Correct date parsing for ISO-8601 with timezone offset | Date utilities |

---

## Impact Assessment

| Team | Impact | Notes |
|------|--------|-------|
| Conversion | Medium | audit_log references in bash scripts need column rename |
| Interfaces | Low | REST timeout increase is compatible — no changes required |
| Workflow Config | None | Not deploying this sprint |
| Func Config | Low | Review `etl.parallel.threads` default — may need tuning |

---

## Checksums / Verification

```
Installer SHA256 : d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5
```

---

## Notes

Conversion team must run the migration script `rename_audit_column.sql`
as part of deployment before starting the ETL jobs. Script is in
`repo-conversion/scripts/migrations/rename_audit_column.sql` (ELM-1208).
