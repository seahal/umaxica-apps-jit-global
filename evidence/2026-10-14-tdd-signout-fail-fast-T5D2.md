# TDD sign-out fail-fast slice

Recorded 2026-10-14 UTC against full commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`.
The worktree was already dirty with the in-progress `one.md` implementation; this slice added
the changes to `app/controllers/concerns/authentication_logout_current_session.rb` and its focused
test. `one.md` remained unchanged at SHA-256
`663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`.

## Scope

This is the first bounded S3 slice. A Device Session revocation failure or SignOutFlow creation
failure must be raised instead of being converted into token-only revocation or a successful
logout. The slice does not claim the complete single-transaction parent/RP revocation contract or
the AppTicket binding migration.

## TDD loop

The focused test was changed first to assert the accepted fail-fast behavior. Before the application
change, the test run was intentionally red: 28 runs, 87 assertions, 4 failures and 0 errors. The
existing implementation swallowed the four failures and continued.

The implementation then retained the diagnostic log and re-raised both failure classes. The focused
test became green: 28 runs, 91 assertions, 0 failures, 0 errors and 0 skips.

## Verification

All commands used `RAILS_ENV=test`, an unset `POSTGRESQL_ISOLATED_TEST_RUN_ID`, one worker and the
ordinary Rails test databases. The final S3-related regression selection passed:

- 199 runs, 970 assertions, 0 failures, 0 errors, 0 skips.
- Security invariant guards: 16 runs, 117 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop over the two changed Ruby files: no offenses.
- `git diff --check`: passed.
- The active connection reported `test_primary_db`.

`bin/rails db:verify_no_schema_drift` remained non-zero because the worktree already contains
large schema-dump and migration edits across `db/`; this slice introduced no migration or schema
dump change and did not rewrite those files.

## Remaining boundary

The code still creates the SignOutFlow record and performs parent/child revocation through separate
existing transitions. A later S3 slice must move those writes under one realm Ticket transaction,
add unknown-COMMIT re-read behavior, and bind the Browser RP intent to the captured parent. No
isolated database was used or required for this fail-fast slice.
