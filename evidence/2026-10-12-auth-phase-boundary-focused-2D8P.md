# Authentication phase-boundary focused verification

- **Revision:** `a1ec83a7384a424c97671356268ec5c4ad8347d4` (working tree dirty; no unrelated
  changes were discarded).
- **Scope:** Existing public controller boundaries for app/com/org sign-in, app/com/org sign-up,
  discoverable passkey sign-in, and sign-up checkpoint cancellation.

## Command and result

```text
RAILS_ENV=test PARALLEL_WORKERS=4
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json
POSTGRESQL_TEST_PREPARE_DATABASES=<run-owned app/com/org/avatar/primary databases>
bundle exec rails test \
  test/controllers/auth/app/in/passkey/authentication_flow_test.rb \
  test/controllers/auth/app/sign_ins_controller_test.rb \
  test/controllers/auth/com/sign_ins_controller_test.rb \
  test/controllers/auth/org/sign_ins_controller_test.rb \
  test/controllers/auth/app/sign_ups_controller_test.rb \
  test/controllers/auth/com/sign_ups_controller_test.rb \
  test/controllers/auth/org/sign_ups_controller_test.rb \
  test/controllers/auth/sign_up_checkpoint_cancellation_test.rb
```

Result: **68 runs, 437 assertions, 0 failures, 0 errors, 0 skips**.

An initial command named a non-existent helper test file and failed before loading tests with
`Rails::TestUnit::InvalidTestError`; it was corrected by selecting only files that exist. That
file-selection error is not a product regression.

This focused result does not establish every authentication-family, race, or full Gate 4
requirement. The repository-wide Rails gate remains separately recorded with its known unrelated
Acme terminology inventory failure.
