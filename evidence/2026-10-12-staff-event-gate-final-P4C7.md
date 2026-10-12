# Staff-event staging final Gate 2 recheck

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty and contained 122 staged, unstaged or untracked paths at the
start of this record. Existing changes were preserved. No reset, clean, stash, worktree, push,
production operation or shared-database operation was performed.

## Failure classification and focused recheck

The first Rails Gate 2 recheck after adding metadata assertions to the staff-event transition
test completed the test body with one unrelated failure:

```text
SignUpExpiryJobTest#test_expires_overdue_in-progress_tickets_on_both_ticket_databases
Expected ... to be sign_up_in_progress?
15096 runs, 128106 assertions, 1 failures, 0 errors, 0 skips
```

The failure was in the existing sign-up expiry timing test, not in the staff-event migration,
operation, model contract, or schema. With the same run-owned PostgreSQL manifest, the named
expiry test passed in both single-worker and four-worker executions:

```text
6 runs, 16 assertions, 0 failures, 0 errors, 0 skips
```

No application repair was made for that unrelated timing observation. The first parallel run's
worker-database cleanup also refused while transient connections were present. After the test
process ended, a read-only catalog check found no remaining connections. The four worker
databases created by that run were then cleaned only through the repository cleanup helper, which
verified the run receipt, database owner, comment, identity and absence of active connections.

## Final Rails and Vitest gate

The Rails command used the isolated manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, all twenty manifest databases, and four
workers:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="$(ruby -rjson -e 'm=JSON.parse(File.read("tmp/acceptance-isolated-20261010p8b-primary.json")); print m.fetch("databases").map { |x| x.fetch("name") }.join(",")')" \
RAILS_ENV=test PARALLEL_WORKERS=4 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
bundle exec rails test
```

The final run completed successfully with:

```text
15096 runs, 128109 assertions, 0 failures, 0 errors, 0 skips
```

All four worker receipts for the final run recorded `cleanup_completed: true`.

The Vitest recheck used `bun run test` and reported:

```text
99 files passed (99)
1140 tests passed (1140)
```

These results validate the current worktree and staged staff-event schema in the disposable test
environment. They do not close the remaining P12a capacity review, final staff-event PK/FK
cutover, D-11 committed-transaction isolation matrix, P10b/P12b Avatar cutover, host Alloy
runtime verification or privacy-retention decision.
