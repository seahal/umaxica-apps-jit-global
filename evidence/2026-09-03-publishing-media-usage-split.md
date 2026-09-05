# Publishing media usage split (Phase 1B, final)

- Date: 2026-09-03
- Scope: Owner-explicit publishing media relations. No Edge code.
- Worktree: umaxica-apps-jit-global checkpoint `e0637959739d5eac31ce4f85269bf59fa2dc8763`

This record describes the **final** Phase B schema, not the discarded transitional copy/drop
migrations.

## Canonical schema

A fresh `db:migrate` creates media placements directly as:

- `publishing_revision_media_usages` → `entry_revision_id` (NOT NULL)
- `publishing_version_media_usages` → `entry_version_id` (NOT NULL)

There is no `publishing_media_usages` table. There is no INSERT...SELECT compatibility migration.
`entry_id` and `locale` are not stored on usage rows; they are derived from the owner revision or
version.

Defined in `db/migration_support/publishing_schema.rb`, applied by
`db/publishing_migrate/20260716180000_create_publishing_schema.rb`. Immutability and snapshot
completeness triggers live in `db/publishing_migrate/20260801142552_create_publishing_taxonomy.rb`.

## Reconstruction

```text
RAILS_ENV=test bin/rails db:drop db:create db:migrate
RAILS_ENV=development bin/rails db:drop db:create db:migrate
RAILS_ENV=development bin/rails db:seed
```

All succeeded against local `test_*` / `development_*` databases only. `publishing_media_usages` was
absent after both rebuilds.

## Tests

```text
bin/rails test
12207 runs, 66480 assertions, 1 failure (stale HTML title on /health),
0 errors, 1 skip
```

That health-title failure is corrected in the Phase B gate (this mission): `/health` is a text/plain
probe; the title contract no longer expects HTML.

Publishing-focused follow-up: 60 runs, 309 assertions, 0 failures.
