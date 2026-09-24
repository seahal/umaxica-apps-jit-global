# Approved CF-003/CF-004 and CF-007 static gate recheck

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes present; no unrelated changes were reverted.
- Scope: approved pre-deployment owner-authority and regional-RP implementation slice, plus the
  bounded retention input guard.
- External writes: none. Production, provider, AWS, Cloudflare, GitHub, and shared external
  services were not accessed or changed.

## Preflight

The required environment file was selected explicitly and all required variable names were
present without printing their values. `config/credentials/test.key` was present without reading
its contents.

The required preflight command stopped before application checks because the current process could
not resolve the Compose PostgreSQL service name:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records in this process. No
localhost substitution, host-file edit, mock service, test skip, or application workaround was
used. Rails focused and full suites were not run after this failed preflight.

## Static and security checks

The following checks passed:

- Ruby syntax for the retention job, retention tests, regional matrix, authority backfill,
  cutover, guard, and owner-scope query.
- Targeted RuboCop for the seven affected Ruby files: no offenses.
- Brakeman 8.0.6: 0 errors and 0 security warnings.
- `git diff --check`: passed.

## Adversarial disposition

- CF-003/CF-004: implementation remains fail-closed for explicit owner input, ambiguous or
  inactive candidates, lifecycle conflicts, incomplete family mappings, duplicate mappings,
  repeated backfill, and post-marker backfill. Family cutover remains unaccepted in this process
  because the required isolated PostgreSQL evidence was not obtainable.
- CF-007: the approved 13-cell logical matrix, independent logical key namespaces, exact binding
  checks, and no-arbitrary-Host rule are present. Active regional registration remains blocked by
  the absent canonical Side US host source and regional audience SSOT. No client, key, audience,
  caller mapping, or credential was guessed or activated.
- Retention: direct `batch_size` input is rejected unless it is an integer or integral string in
  the inclusive `1..500` range, before kill-switch or destructive work. No dry-run, preview,
  simulation API, audit schema, or migration was added.

## Current status

The current process proves static safety only. CF-003/CF-004 remains `OPEN — EVIDENCE REQUIRED`;
CF-007 remains `OPEN — CONTRACT CONTRADICTION`; CF-008 remains blocked by its separate data
contract. CF-005 and CF-011 retain their earlier isolated pre-deployment closure evidence and
later deployment/provider gates.
