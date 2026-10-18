# Avatar migration draft disposition

This read-only check records the migration-history observation used to update the Avatar
organization-ownership specification. It was performed on 2026-10-12 against
`ccceabd05d2e3a8f923ce398046f99d026a5b78e` with the worktree already containing unrelated and
implementation changes; no source or database mutation was performed by the check.

## Scope

The six historical drafts under
`specs/avatar-organization-ownership/migration-drafts/` were read in full. They remain outside
Rails migration discovery. The successor files were compared with the current
`db/avatars_migrate/` inventory.

## Database observation

Using the run-owned `20261010p8b` manifest and `AvatarRecord.lease_connection`, the query

```sql
SELECT version
FROM schema_migrations
WHERE version::bigint IN (
  20261009180016, 20261009180021, 20261009180026,
  20261009180032, 20261009180037, 20261009180042
)
ORDER BY version;
```

returned an empty set for the current Avatar parent catalog. The same catalog contains the reviewed
successor migration series, including `20261010130000`, `20261010140000`, `20261010150000`,
`20261010160000`, `20261010170000` through `20261010180000`, `20261011212119`, `20261011220000`,
`20261011220500`, and `20261012130001`.

The earlier acceptance record in the owning specification reports that draft version
`20261009180016` was applied in an older disposable catalog before the next draft was rejected by
`strong_migrations`; that historical catalog was not modified or dropped here. No claim is made
that every PostgreSQL catalog has been enumerated.

## Result

The final successor/abandonment table is recorded in
`specs/avatar-organization-ownership/spec.md`. The six drafts remain tracked and quarantined; no
draft was restored to `db/avatars_migrate/`, and no migration command was run.
