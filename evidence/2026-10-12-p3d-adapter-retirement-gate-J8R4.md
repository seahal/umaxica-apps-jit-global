# P3d adapter retirement and cleanup gate

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty before this slice. Existing staged, unstaged and untracked changes
were preserved; no reset, clean, stash, push, production operation or shared-database operation was
used. This record covers a test-only proof-retirement assertion, two public delivery-adapter
regressions and an idempotent test-clone receipt repair. It does not claim P3d or the realm plan is
complete.

## Direct behavior

The current runtime inventory was read before editing. It found no application writer for the
retired identifier-owned HOTP fields or source proof contexts. `OtpTelephoneAdapter` already
rejects `sign_up_otp_counter` and `contact_otp_counter`; `OtpEmailNotifierAdapter` rejects those
retired keywords at its public method boundary. Tests now exercise both adapters and assert that
the transport/notifier is not called.

Focused command:

```text
bundle exec rails test test/adapters/otp_telephone_adapter_test.rb test/adapters/otp_email_notifier_adapter_test.rb
```

Result on the run-owned four-worker manifest: `19 runs, 73 assertions, 0 failures, 0 errors, 0
skips`.

Targeted style command:

```text
bundle exec rubocop test/adapters/otp_telephone_adapter_test.rb test/adapters/otp_email_notifier_adapter_test.rb test/support/parallel_test_database_cloner.rb
```

Result: all three files inspected with no offenses. The test helper change was required because a
parent could drop all run-owned worker databases and lose the final receipt write immediately
afterward. When every expected name is absent and no session remains, the helper now records
`cleanup_completed` without issuing another `DROP DATABASE`; a partial catalog still fails the
existing ownership check.

## Gate 2 after the helper change

The Rails command used the exact run-owned manifest, host `primary`, `RAILS_ENV=test` and four
workers:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 manifest database names> \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test
```

Result: `15154 runs, 128329 assertions, 0 failures, 0 errors, 0 skips` in 332.481 seconds.
The expected OmniAuth failure messages, Flipper warnings and local-environment warnings appeared
inside the suite; none was a test failure.

The four receipts from this run were reconciled through the repository cleanup helper. Every receipt
has `cleanup_completed: true`; a read-only PostgreSQL catalog query then found zero
`codex_integrity_20261010p8b_w*` databases and zero active sessions.

The JavaScript gate was:

```text
bun run test
```

Result: `99 files passed`, `1140 tests passed` in 13.21 seconds.

## Limits

This slice proves the adapter rejection boundary and the cleanup receipt behavior only. It does
not prove every Email/Telephone ceremony route, the complete legacy-proof reader/fixture inventory,
the full D-11 isolation matrix, production/shared-data behavior, host Alloy runtime verification,
P10b/P12b, or the unresolved privacy-retention policy. The four full-suite results are evidence for
this dirty worktree and run-owned disposable schema; they are not a committed-schema or production
acceptance claim. The repository schema-drift verifier remains separately classified because the
worktree contains intended uncommitted structure-dump changes.
