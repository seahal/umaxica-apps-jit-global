# OTP writer database clock follow-up

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- External writes: none

## Environment

The required environment file was selected explicitly with
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`, and the four designated
PostgreSQL test databases were supplied through `POSTGRESQL_TEST_PREPARE_DATABASES`. The
repository preflight completed against PostgreSQL 17.7 and Valkey 7.2.4 on the core-service
network. Credentials and secret values were not recorded.

## TDD result

The initial RED run after changing OTP lifecycle code reproduced two stale test expectations:
the tests calculated the lockout timestamp from Rails `15.minutes.from_now` while the production
transition correctly used the selected writer database time. The expectations were changed to
assert the same explicit decision time. No production security control, assertion, skip, or mock
boundary was weakened.

The final focused command was:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/models/client_email_test.rb \
  test/models/client_telephone_test.rb \
  test/controllers/auth/sign_up_checkpoint_cancellation_test.rb \
  test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb \
  test/controllers/auth/app/sign/up/check/telephone/otps_controller_test.rb \
  test/controllers/auth/com/up/emails_controller_test.rb \
  test/controllers/auth/com/up/telephones_controller_test.rb \
  test/controllers/auth/app/in/emails_controller_test.rb \
  test/controllers/auth/app/up/emails_controller_test.rb \
  test/controllers/auth/app/up/telephones_controller_test.rb \
  test/controllers/base/app/identity/emails/registrations_controller_test.rb
```

Result: `283 runs, 1418 assertions, 0 failures, 0 errors, 0 skips`.

The final full command was:

```text
bin/rails test
```

Result: `11472 runs, 73290 assertions, 0 failures, 0 errors, 6 skips`.

Targeted RuboCop for the affected 20 implementation/test files reported no offenses. `git diff
--check` passed. Brakeman 8.0.6 on Rails 8.2.0.alpha reported 0 errors and 0 security
warnings. The six full-suite skips were existing skips and none was added by this slice. The
full suite emitted the repository's existing OmniAuth diagnostic/error logs for negative-path
tests; they did not produce test failures.

## Scope and limits

This evidence covers OTP issuance, cooldown, expiry, and failed-attempt state transitions that
were migrated in this slice. It does not claim every historical timestamp in the repository uses
the writer database clock, and it does not verify external provider timing, production deployment,
or live email/SMS delivery.
