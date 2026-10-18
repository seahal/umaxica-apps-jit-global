# P3d public authentication route matrix

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty before this check. Existing staged, unstaged and untracked
changes were preserved. No reset, clean, stash, worktree, push, production operation or shared
database operation was used. The run-owned manifest was
`tmp/acceptance-isolated-20261010p8b-primary.json`, using the primary PostgreSQL host and four
workers.

## Public boundary collection

This focused collection covered the currently supported Email/Telephone sign-up OTP HTTP paths,
Email sign-in entry paths, App/Com/Org sign-in controllers, App/Com/Org passkey entry paths, the
Org Entra callback guards, App and Org social sessions, Email sign-in flow isolation, sign-up
completion, Email verification, delayed OTP transport and withdrawal reentry. It was selected to
extend the prior operation/adapter/source inventory without changing application behavior.

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<the 20 names from tmp/acceptance-isolated-20261010p8b-primary.json>" \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test \
  test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb \
  test/controllers/auth/com/sign/up/check/email/otps_controller_test.rb \
  test/controllers/auth/app/sign/up/check/telephone/otps_controller_test.rb \
  test/controllers/auth/com/sign/up/check/telephone/otps_controller_test.rb \
  test/controllers/auth/app/in/emails_controller_test.rb \
  test/controllers/auth/com/in/emails_controller_test.rb \
  test/controllers/auth/app/sign_ins_controller_test.rb \
  test/controllers/auth/com/sign_ins_controller_test.rb \
  test/controllers/auth/org/sign_ins_controller_test.rb \
  test/controllers/auth/app/in/passkeys_controller_test.rb \
  test/controllers/auth/com/in/passkeys_controller_test.rb \
  test/controllers/auth/org/in/passkeys_controller_test.rb \
  test/controllers/auth/org/omniauth/entra_callback_guards_test.rb \
  test/controllers/auth/app/social/sessions_controller_test.rb \
  test/controllers/auth/org/social/sessions_controller_test.rb \
  test/integration/email_sign_in_flow_isolation_test.rb \
  test/integration/email_signup_base_root_completion_test.rb \
  test/integration/email_verification_flow_test.rb \
  test/integration/signup_otp_delayed_transport_test.rb \
  test/integration/withdrawal_ceremony_reentry_test.rb
```

Observed result: `223 runs, 2525 assertions, 0 failures, 0 errors, 0 skips` in 16.154 seconds
with four workers. A read-only PostgreSQL follow-up reported zero remaining
`codex_integrity_20261010p8b_w%` worker databases and zero active sessions.

The result is current route evidence for the dirty worktree. It does not claim that every
provider-specific callback, every supported MFA/capacity/checkpoint route, or the remaining
cross-database transport fault campaign has been exercised. Those remain explicit CONTACT-4/5
follow-up items where their applicable consumers have not yet been mapped to an executed public
test. No raw OTP, token, provider secret or personal data was written to this record.
