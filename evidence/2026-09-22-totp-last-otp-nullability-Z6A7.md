# TOTP `last_otp_at` nullability verification

- Date: 2026-09-22
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained unrelated uncommitted changes; this verification preserved them.
- Scope: `ClientTotpCredential.last_otp_at` lifecycle correction only.

## RED

Before the model and schema correction, the focused regression set failed as expected:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/client_totp_credential_test.rb test/consumers/totp_window_consumer_test.rb
29 runs, 68 assertions, 3 failures, 0 errors, 0 skips
```

The failures were the old `-infinity` default, the old presence validation, and the old
revoked-credential expectation.

## Change verified

- Removed the fabricated `-infinity` default and `NOT NULL` requirement for
  `client_totp_credentials.last_otp_at`.
- Converted existing `-infinity` values to `NULL` in the reversible migration
  `20260922130000_allow_null_for_client_totp_last_otp_at`.
- Kept accepted-code timestamps finite and preserved replay checks.
- Updated the app settings display and schema annotations.
- Applied the migration only to the disposable `test_app_zenith_db`; no production, shared,
  AWS, Cloudflare, or provider environment was accessed or modified.

## Verification

The focused regression set passed after the change:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/client_totp_credential_test.rb test/consumers/totp_window_consumer_test.rb
29 runs, 70 assertions, 0 failures, 0 errors, 0 skips
```

The broader TOTP set passed:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/consumers/totp_window_consumer_test.rb \
  test/consumers/totp_window_consumer_concurrency_test.rb \
  test/models/client_totp_credential_test.rb \
  test/models/client_totp_credential_enrollment_concurrency_test.rb \
  test/controllers/auth/app/in/mfa/totps_controller_test.rb \
  test/controllers/auth/app/verification/totps_controller_test.rb \
  test/controllers/auth/app/settings/totps_controller_test.rb \
  test/controllers/auth/route_naming_test.rb
91 runs, 747 assertions, 0 failures, 0 errors, 0 skips
```

The full Rails suite passed after the schema change:

```text
bin/rails test
11533 runs, 73416 assertions, 0 failures, 0 errors, 8 skips
```

The structure-load/reset path was then verified on the disposable test database. After
`RAILS_ENV=test bin/rails db:reset:app_zenith`, the live column remained nullable with no default,
the focused model/consumer set passed with 29 runs / 70 assertions, and the full suite passed with:

```text
11533 runs, 73419 assertions, 0 failures, 0 errors, 8 skips
```

Additional checks passed:

- `RAILS_ENV=test bin/rails db:migrate:status:app_zenith`: migration `20260922130000` is `up`.
- The migration was explicitly rolled back and reapplied on `test_app_zenith_db`; both operations
  succeeded. The post-reapply focused model/consumer set passed again with 29 runs / 70 assertions.
- The live test database reports `last_otp_at` as nullable with no default.
- Standard `RAILS_ENV=test bin/rails db:schema:dump:app_zenith` was run. The committed structure
  dump retains only the intended column change and migration version; unrelated live-database
  constraint-state differences were not copied into the repository.
- Ruby syntax checks passed for the changed Ruby and migration files.
- Scoped RuboCop passed for the changed Ruby and migration files.
- Repository-wide `bundle exec rubocop` inspected 4755 files with no offenses.
- `bundle exec brakeman -q --no-pager` reported 0 errors and 0 security warnings.
- `git diff --check` passed.

The full suite reported eight existing skipped tests; no skip was added or changed for this work.

Final review found and corrected one stale schema annotation in the model test file; the focused
model/consumer set was rerun afterward and passed with 29 runs / 70 assertions.
