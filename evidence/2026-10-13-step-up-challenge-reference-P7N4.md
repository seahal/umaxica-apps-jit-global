# Step-Up passkey challenge reference issuer — implementation evidence

- Date: 2026-10-13
- Repository: `/home/global/workspace`
- Branch: `feature`
- Tested code HEAD: `7576ff7cbc6787f7f80f1f42bfa538914ace6de1`
- Worktree: already contained unrelated staged, unstaged and untracked changes; this slice preserved them and was tested against the dirty worktree.

## Change

`StepUpSessionConsumable` now issues new `passkey_challenge_ref` values through the shared `PublicId.generate` NanoID-21 path for Client, Visitor and Operator Step-Up sessions. Existing opaque references remain readable by exact row-bound equality. The existing per-table unique B-tree is the final collision guarantee; only its named `passkey_challenge_ref` collision is retried in a savepoint, with a finite budget. WebAuthn protocol challenge bytes, RP/origin binding, expiry and burn semantics are unchanged.

## TDD and focused verification

The pre-change public controller check passed with `9 runs, 150 assertions, 0 failures, 0 errors, 0 skips`.

The new public-boundary assertion first produced the expected Red against a UUID reference: `9 runs, 132 assertions, 1 failure, 0 errors, 0 skips`.

After implementation, the focused command was:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> bundle exec rails test test/models/step_up_passkey_challenge_test.rb test/controllers/auth/step_up_admission_test.rb test/models/step_up_session_revocation_test.rb
```

Result: `37 runs, 477 assertions, 0 failures, 0 errors, 0 skips`.

The focused suite includes a real unique-index collision followed by a successful savepoint retry. Targeted RuboCop passed for:

- `app/models/concerns/step_up_session_consumable.rb`
- `test/controllers/auth/step_up_admission_test.rb`
- `test/models/step_up_passkey_challenge_test.rb`

Result: `3 files inspected, no offenses detected`.

## Required post-slice gates

Rails full gate:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> bundle exec rails test
```

Result: `15204 runs, 128512 assertions, 0 failures, 0 errors, 0 skips`.

Vitest full gate:

```text
bun run test
```

Result: `99 files passed, 1140 tests passed`.

These are implementation verification results for the current dirty worktree, not an independent acceptance decision. CI, Podman, production/shared destructive operations, external delivery and the user-excluded independent acceptance investigation were not performed.
