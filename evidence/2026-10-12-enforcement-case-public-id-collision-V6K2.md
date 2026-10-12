# EnforcementCase public-ID collision slice

Date: 2026-10-12

Repository: `/home/global/workspace` (`feature`)

Code revision under test: `f0f3ccfe0e4e3106e28ce2ef9d63b1a9b3a37af2` (the worktree was dirty; the
EnforcementCase concern and its new test were uncommitted during these checks). Existing unrelated
staged, unstaged and untracked changes were preserved.

## Scope

This slice covers only the APP, COM and ORG `EnforcementCase.public_id` creation boundary. It uses
the existing `PublicId.generate` mechanism, keeps the realm-local unique B-tree indexes as the final
authority, retries only their named collision within the finite shared budget, and keeps
post-creation public-ID mutation rejected. It does not alter migrations, protocol values, provider
secrets, cross-realm resolution or production data.

## Red and Green checks

The pre-implementation collision check reached the normal create boundary and reproduced the former
`ActiveRecord::RecordInvalid` on an internally generated duplicate public ID. After the smallest
implementation change, the focused public contract passed:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 ... bundle exec rails test test/models/enforcement_case_public_id_test.rb
5 runs, 16 assertions, 0 failures, 0 errors, 0 skips
```

The test covers normal validation, validation-disabled creation, bounded retry exhaustion and the
non-regeneration of a caller-supplied colliding ID. A real PostgreSQL unique-index collision was
used; the test does not rely on a random sample or an `exists?` check as the final guarantee.

The related EnforcementCase model, ordering, trigger and public-ID collection passed with four
workers:

```text
... bundle exec rails test \
  test/models/app_enforcement_case_test.rb \
  test/models/com_enforcement_case_test.rb \
  test/models/org_enforcement_case_test.rb \
  test/models/enforcement_case_apply_ordering_test.rb \
  test/models/enforcement_triggers_test.rb \
  test/models/enforcement_case_public_id_test.rb
42 runs, 133 assertions, 0 failures, 0 errors, 0 skips
```

Targeted style verification passed:

```text
bundle exec rubocop app/models/concerns/enforcement_case_applicable.rb \
  test/models/enforcement_case_public_id_test.rb
2 files inspected, no offenses detected
```

## Periodic full gate

Using the run-owned twenty-database manifest `tmp/acceptance-isolated-20261010p8b-primary.json`, the
Rails full suite ran with four workers:

```text
... bundle exec rails test
15,155 runs, 128,289 assertions, 0 failures, 0 errors, 0 skips
```

The JavaScript full suite then ran with the repository script:

```text
bun run test
99 test files passed; 1,140 tests passed
```

The Rails run used only the configured run-owned PostgreSQL test databases. No CI, Podman,
production or shared destructive operation was used.

## Limits

The application concern and test remain uncommitted in the shared worktree. This evidence records
the checks performed against the dirty worktree; it is not a claim that the implementation is
present in the commit object. The slice does not establish all-table identifier inventory,
database-level immutability for every permanent identifier, D-11 committed-transaction isolation,
Avatar cutover/write barriers, privacy-retention policy or independent acceptance by another AI.
