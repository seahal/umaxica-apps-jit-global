# Avatar transfer registry focused verification

- Commit under test: `2a1644f73238839ed7ed513bd4681ea393a86682`.
- The worktree contained pre-existing and current uncommitted changes; no unrelated changes
  were reset or staged.
- Database: disposable PostgreSQL catalog `20261009social3`, using the recorded isolated test
  manifest and `PARALLEL_WORKERS=1`. No shared or production database was used.
- Migration applied before the test: `20261010150000_create_avatar_transfer_reservations.rb`.

Command:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261009social3 POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261009social3.json POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 databases recorded in the run manifest> bundle exec rails test test/models/avatar_transfer_reservation_test.rb
```

Result: `7 runs, 21 assertions, 0 failures, 0 errors, 0 skips`.

The test exercises the four concrete detail families, deferred direct-SQL cardinality, global
pending and idempotency uniqueness, same-request replay, changed-input refusal, and two independent
committed PostgreSQL connections racing on the same idempotency key. It does not establish the
legacy Request/Accept/Cancel transport cutover or the complete four-direction ownership transition.
