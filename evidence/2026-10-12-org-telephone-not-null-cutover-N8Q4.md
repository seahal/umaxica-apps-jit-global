# ORG Telephone public identity NOT NULL cutover rehearsal

Date: 2026-10-12

Repository: `/home/global/workspace`
Branch: `feature`
HEAD for this work: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree already contained staged, unstaged and untracked changes. They were preserved. No
reset, clean, stash, rebase, merge, push, production operation, shared-database destructive
operation or Podman operation was performed. All database work used the run-owned PostgreSQL
manifest `tmp/acceptance-isolated-20261010p8b-primary.json` on host `primary`.

## Change and Red result

The existing ORG Telephone public-identity expansion and NULL-only operational backfill were
already present. A new public model contract first asserted that
`OperatorTelephone.columns_hash.fetch("public_id").null` is false. The focused test initially
failed because the current column was still nullable:

```text
5 runs, 28 assertions, 1 failure, 0 errors, 0 skips
OperatorTelephonePublicIdImmutabilityTest#test_the_public_identity_is_required_after_the_operational_NULL-only_backfill
Expected true to be nil or false
```

The first one-step migration attempt was rejected by Strong Migrations because changing an
existing column to NOT NULL without a validated check can block reads and writes. That migration
was removed because it was generated during this slice and had not been applied. The safe split
was then generated with the repository's multi-database Rails generator:

- `db/org_principals_migrate/20261012081257_add_not_null_check_to_operator_telephone_public_ids.rb`
  adds a `NOT VALID` `public_id IS NOT NULL` check.
- `db/org_principals_migrate/20261012081301_validate_operator_telephone_public_id_not_null.rb`
  validates both the existing nonblank check and the new not-null check, changes the column to
  `NOT NULL`, and removes the transitional checks. Its reverse restores nullable metadata and both
  checks without rewriting data. The reverse was corrected after a rehearsal exposed that the
  first version restored only the nonblank check; the corrected `down` was then exercised in a
  run-owned database.

The migration never generates, truncates, or rewrites identifiers. A stale NULL or whitespace
value fails validation before the metadata transition.

## Verification

Focused command:

```text
bundle exec rails test \
  test/models/operator_telephone_public_id_immutability_test.rb \
  test/operations/operator_telephone_public_id_backfill_operation_test.rb
```

With the run-owned test manifest and four workers, the result was:

```text
17 runs, 92 assertions, 0 failures, 0 errors, 0 skips

The 17-run slice included the Group transition inventory and backfill tests that share the same
current migration/test preparation boundary. The ORG-only subset remained green within that run.

Migration preparation and reversibility checks were also executed against the run-owned
`codex_integrity_20261010p8b_org_zenith` database:

- `db:test:prepare` completed after the disposable database was recreated with the manifest-owned
  identity; no PostgreSQL role was changed.
- `db:migrate:down:org_zenith VERSION=20261012081301` left `public_id` nullable with both
  transitional checks present.
- `db:migrate:up:org_zenith VERSION=20261012081301` validated both checks, set `NOT NULL`, and
  removed both transitional checks.
- Read-only inspection after reapplication reported `public_id_null: false` and no transitional
  checks.
```

The current backfill test contract is post-cutover: an existing identity is never regenerated or
overwritten, and the retained operation reports no missing rows. NULL-only assignment, exact unique
collision retry, savepoint recovery and exhaustion were run against the pre-cutover nullable
schema before this migration and remain recorded in
`evidence/2026-10-11-org-telephone-identity-backfill-K6V2.md`. The current NOT NULL schema
correctly rejects constructing those legacy rows.

Targeted RuboCop:

```text
bundle exec rubocop \
  test/operations/operator_telephone_public_id_backfill_operation_test.rb \
  db/org_principals_migrate/20261012081257_add_not_null_check_to_operator_telephone_public_ids.rb \
  db/org_principals_migrate/20261012081301_validate_operator_telephone_public_id_not_null.rb
```

Result: the migration/backfill and Group inventory slice inspected 12 files with no offenses.
Both migration files and the touched Ruby files returned `Syntax OK`.

The ORG schema dump was generated through `db:schema:dump:org_zenith` from the run-owned test
database. It now records `operator_telephones.public_id` as `NOT NULL`, removes the transitional
nullable check, and records both migration versions. The Avatar schema dump was also generated
through `db:schema:dump:avatar` to preserve the earlier Group ownership migration. The repository
schema-drift task still reports `db/avatar_structure.sql` and `db/org_zenith_structure.sql` as
dirty because those intentional generated changes are uncommitted; this is not reported as a
clean committed-schema gate.

Full gates after the corrected migration and test update:

- `bundle exec rails test` with `PARALLEL_WORKERS=4`: `15085 runs, 128036 assertions, 0 failures,
  0 errors, 0 skips`.
- `bun run test`: 99 files passed, 1140 tests passed.

## Limits

Additional static checks after the corrected migration passed: `git diff --check`,
`scripts/check-repository-knowledge`, and the targeted RuboCop/syntax commands. The repository
schema-drift task still reports the intentionally dirty generated `db/avatar_structure.sql` and
`db/org_zenith_structure.sql`; this is not represented as a clean committed-schema gate.

This is a disposable test-schema rehearsal, not production or shared-data application. It does not
prove writer quiescence, legacy proof-drain completion, consumer cutover, the unresolved ORG
uniqueness semantics, D-11 independent committed-transaction coverage, Alloy runtime remount, or
the remaining P12a identifier inventory. No local commit or remote synchronization was performed.
