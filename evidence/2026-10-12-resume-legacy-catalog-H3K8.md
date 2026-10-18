# Resume legacy identifier and Avatar catalog check

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Worktree: dirty; unrelated staged, unstaged and untracked changes were preserved.
- Scope: read-only development-database catalog inspection after the Section 5.3/16/14.2
  resume procedure. No migration, write, reset, cleanup, cutover or shared-database operation was
  performed.

## Commands

```text
bundle exec rails runner /tmp/identifier_legacy_catalog.rb
bundle exec rails runner /tmp/avatar_cutover_catalog.rb
```

The first Avatar model-count probe was rejected by PostgreSQL because the development database
does not yet contain `avatar_group_concrete_ownership_periods`; it did not execute a write. The
second probe used `to_regclass` and `count(*)` only.

## Observed facts

- `development_app_zenith_db.legacy_replaced_clients` exists, has zero rows in this development
  database, an unbounded `character varying` `public_id`, a unique B-tree index on that column,
  and foreign keys to client/status tables plus dependent references.
- `development_org_zenith_db.legacy_operator_department_accounts` exists, has zero rows in this
  development database, an unbounded `character varying` `public_id`, a unique B-tree index on
  that column, and foreign keys to staff, department and status tables plus dependent references.
- In `development_avatar_db`, `avatars`, `avatar_groups`, the legacy and concrete Avatar period
  tables, `avatar_group_ownership_periods`, and `avatar_ownership_cutovers` exist with zero rows.
  `avatar_group_concrete_ownership_periods` is absent because the current development database
  has not received the prepared migration.

## Disposition

The two legacy identifier tables remain held for a reviewed consumer/retention decision; zero
rows in this development database does not prove safety for other databases or future retained
data. The Avatar Group backfill and writer cutover remain prepared-only. Applying migrations to
the development/shared database or establishing the cutover marker would exceed the current safe
scope. The next safe step requires a run-owned disposable database or an explicitly approved
operational environment, plus writer-quiescence evidence.
