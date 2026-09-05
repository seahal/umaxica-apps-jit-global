# Publishing Phase 1B finalization

- Date: 2026-09-03
- Starting worktree: Phase B checkpoint `bd6e7094f`
- Scope: rewrite canonical publishing schema so a fresh migrate never creates
  `publishing_media_usages`; drop `entry_id`/`locale` from media usages; full local test/development
  reconstruction.

## Obsolete history removed

- `db/publishing_migrate/20260903180000_create_publishing_owner_media_usages.rb`
- `db/publishing_migrate/20260903180100_split_publishing_media_usages.rb`

Canonical create is `PublishingSchema.create_media` in `db/migration_support/publishing_schema.rb`,
invoked by `20260716180000_create_publishing_schema.rb`.

## Final media columns

Neither table has `entry_id` or `locale`.

- revision:
  `id, public_id, media_file_id, entry_revision_id, role, field_path, block_path, position, alt_text, caption, presentation_metadata, timestamps`
- version: same with `entry_version_id` instead of `entry_revision_id`

## PostgreSQL-specific SQL remaining

- `publishing_reject_mutation` on version media (immutability)
- `publishing_promoted_revision_guard` on revision media
- `publishing_assert_version_media_complete` (placement + presentation fields)

No INSERT...SELECT data copy remains.

## Reconstruction

Test (21 `test_*` databases, no production names):

```text
RAILS_ENV=test bin/rails db:drop db:create db:migrate
```

Result: success. `publishing_media_usages` absent; owner-explicit tables present.

Development (21 `development_*` databases):

```text
RAILS_ENV=development bin/rails db:drop db:create db:migrate
RAILS_ENV=development bin/rails db:seed
```

Result: success. Note: Rails `db:drop` in development also dropped the test databases; test was
migrated again afterward.

Seed: `db/seeds.rb` does not touch publishing media. Vocabularies come from
`20260810013000_seed_publishing_vocabularies`. Sample Client/Operator created. No seed file changes
required.

## Tests

```text
bin/rails test
12207 runs, 66480 assertions, 1 failure, 0 errors, 1 skip
```

The remaining failure is
`HtmlTitleContractTest#test_the_health_snapshot_takes_its_TLD_from_the_host_that_serves_it`
expecting HTML while `/health` now returns `text/plain`. That is the unrelated health-probe work in
this worktree, not publishing.

Publishing/architecture/operation/matrix tests pass.

## Dependency hygiene

Attempted `git checkout 80dc4151 -- Gemfile.lock`. Boot failed: vendor has `rails-ac15cd1cbbfa`, not
`rails-7d3b098615d0`. Restored the lockfile matching the installed Rails git gem. CMS work did not
require a dependency upgrade.

## Remaining Phase 1C items

- region semantics
- Edge CMS consumption
- Worker cache / sitemap / RSS
- `restored_from_*` provenance exclusive-arc on revisions
- BCNF of taxonomy copied attributes
- stub `*_structure.sql` dumps
- unrelated health HTML-title test
