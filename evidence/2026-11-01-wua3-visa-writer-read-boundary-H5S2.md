# WU-A3 Visa handoff writer reads

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was uncommitted, with 498 status
entries before this evidence file was added; there were no staged changes. Existing edits were
preserved.

The Visa authorization handoff now reads the just-created Auth Ceremony session and its OIDC or
step-up parent from the writer connection. OIDC authorization callbacks also resolve parents by
login challenge and transaction reference on the writer. This prevents replica lag from making an
immediately returned authorization look absent or inactive. The parallel secret-login integration
test now follows the Visa/Auth browser bootstrap, carries the Visa continuation form fields, and
copies cookies with the Visa host scope. Its teardown removes the authority-stop records created by
the test before deleting their referenced root tokens.

Verification:

- `bin/rails test test/integration/app_secret_parallel_login_test.rb:260`: 1 run, 33 assertions, 0
  failures, 0 errors, 0 skips.
- `bin/rails test test/integration/app_secret_parallel_login_test.rb`: 4 runs, 136 assertions, 0
  failures, 0 errors, 0 skips.
- `bundle exec rubocop app/controllers/concerns/base_ceremony_binding_confirmation.rb app/services/oidc_authorization_transaction_coordinator.rb test/integration/app_secret_parallel_login_test.rb`:
  3 files inspected, no offenses.
- `ruby -c` on the same three files and `git diff --check` passed.
- A read-only check after the test run found no `session_limit_selected_revoke` root targets and no
  remaining probe token with id `980190964` in the local test database.
- A second focused WU-A3 selection covering public APP/ORG cancellation, cancellation handoff state,
  OIDC cancellation state, binding retention, AC-53 initial attach, and Admission Binding
  concurrency passed: 20 runs, 410 assertions, 0 failures, 0 errors, 0 skips.
- `sign_entry_otp_admitted_order_test.rb`, `secrets_controller_test.rb`, and
  `auth_ceremony_session_concurrency_test.rb` passed: 27 runs, 264 assertions, 0 failures, 0 errors,
  0 skips. This covers the flowless Email Back refusal, pre-proof Secret entry, exact refusal
  cookie/header filtering, and concurrent ceremony replacement.
- The APP/ORG cancellation-versus-finalization concurrency cases passed: 2 runs, 28 assertions, 0
  failures, 0 errors, 0 skips.
- The canceled signup Secret lifecycle, registered identity curfew cleanup, sign-up cancellation,
  and cleanup atomicity selection passed: 11 runs, 64 assertions, 0 failures, 0 errors, 0 skips.
- Added an assertion that the registered Client row remains byte-for-byte unchanged after the
  canceled signup Secret lifecycle job. The focused case passed: 1 run, 8 assertions, 0 failures, 0
  errors, 0 skips; targeted RuboCop, `ruby -c`, and `git diff --check` also passed for that test.
- Extended the public Visa cancellation integration case to replay the same cancellation
  continuation after durable cancellation. The replay returned the same `access_denied` target and
  state while leaving the parent, stable Visa session authority values, cookie names, and Root count
  unchanged: 1 run, 33 assertions, 0 failures, 0 errors, 0 skips. The Rails session cookie value is
  re-signed on the repeated request, so the assertion checks stable authority values and cookie
  names instead of requiring byte-for-byte cookie equality.
- Final targeted RuboCop over the two handoff files and three affected tests passed: 5 files
  inspected, no offenses. Ruby syntax checks and `git diff --check` passed for the same files.

The first full-file run had one teardown error because an authority-stop target referenced a root
token that the test cleanup was deleting. The failed run left a single test-created stop record
(`authority_evidence_ref=session_limit_selected_revoke`) in the local test database. That exact
record was removed before retrying; no production or Neon database was accessed. The test teardown
now uses the existing `AuthorityStopCleanup` helper, and the repeat full-file run passed.

This is focused WU-A3 evidence only. It does not establish completion of WU-A3, WU-9, or all of
`two.md`; other acceptance work and pending owner-approved shapes remain tracked separately.

The Secret page Back test was extended to request the published back link and assert that the OIDC
parent, Admission Binding, Auth Ceremony, sign-up Flow, and `auth_sid` remain unchanged. Its first
run errored because the test called `request_uri` on a relative `URI::Generic`; the request now uses
the relative URI string. The focused retry passed: 1 run, 15 assertions, 0 failures, 0 errors, 0
skips. Targeted RuboCop, `ruby -c`, and `git diff --check` passed for the edited test file.
