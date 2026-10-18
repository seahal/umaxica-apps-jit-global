# Avatar Group inventory chain validation

Date: 2026-10-12

Repository: `/home/global/workspace`
Branch: `feature`
HEAD at verification: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree contained pre-existing staged, unstaged and untracked changes. They were preserved;
no reset, clean, stash, rebase, merge, push, production operation, shared-database destructive
operation, or Podman operation was performed.

## Change

The read-only `AvatarGroupOwnershipTransitionInventoryQuery` now treats a non-empty legacy or
concrete Group ownership history as a manual-review conflict when it has no exactly-one open period,
does not begin at the Group creation timestamp, or contains a gap between adjacent periods. The
backfill remains bounded and idempotent and does not choose an owner or establish the cutover
marker.

A public query test first reproduced the defect: a legacy chain with a one-second gap was classified
as `needs_backfill`. The query was then changed to return `conflict` with the reason
`Group ownership periods do not form one uninterrupted chain`.

## Verification

Focused Group ownership slice:

```text
RAILS_ENV=test PARALLEL_WORKERS=4
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 run-owned databases in the manifest>
bundle exec rails test \
  test/models/avatar_group_concrete_ownership_period_test.rb \
  test/models/avatar_group_ownership_period_source_test.rb \
  test/operations/avatar_group_concrete_ownership_backfill_operation_test.rb \
  test/queries/avatar_group_ownership_transition_inventory_query_test.rb
```

Result: `8 runs, 36 assertions, 0 failures, 0 errors, 0 skips`.

Targeted style check:

```text
bundle exec rubocop \
  app/queries/avatar_group_ownership_transition_inventory_query.rb \
  test/queries/avatar_group_ownership_transition_inventory_query_test.rb
```

Result: 2 files inspected, no offenses detected.

Rails full gate after the change:

```text
bundle exec rails test
```

The command used the run-owned manifest and four workers described above. Result:
`15085 runs, 128065 assertions, 0 failures, 0 errors, 0 skips`.

Vitest full gate:

```text
bun run test
```

Result: `99` test files passed and `1140` tests passed.

Documentation and source checks also passed:

```text
git diff --check
scripts/check-repository-knowledge
ruby -c app/queries/avatar_group_ownership_transition_inventory_query.rb
```

The diff check was clean, the repository knowledge checker reported
`Knowledge structure passed: 8 Skills/adapters, 67 documents, 0 evidence records.`, and Ruby
syntax was `Syntax OK`.

## Scope and limits

This evidence covers inventory classification and the safe pre-cutover backfill boundary. It does
not establish Group account semantics, the Avatar cutover marker, P12b writer quiescence, production
conversion, D-11 isolated committed-transaction concurrency, or the unresolved personal-data
retention policy. Registry admission remains guarded until its approved Group/Grant consequences and
cutover evidence are complete.
