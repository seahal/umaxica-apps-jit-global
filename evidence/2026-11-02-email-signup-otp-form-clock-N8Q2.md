# Email signup OTP form clock consolidation

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained existing uncommitted changes. This check includes local changes to
  `EmailSignUpOtpFormQuery` and the existing Email signup HTTP delivery test.
- The reported OTP GET raised Prosopite on repeated `SELECT clock_timestamp()` calls. The read-only
  query now obtains one Ticket database instant and passes it to flow, actor, contact and OTP
  availability predicates. Transition writers and their clocks are unchanged.
- The existing HTTP signup test now follows the issued OTP URL and checks HTTP 200 and unchanged OTP
  generation.
- `bin/rails test test/integration/email_signup_http_delivery_commit_test.rb`: blocked before tests
  ran by `ActiveRecord::NoDatabaseError` for `test_com_setting_db`. No database was created or
  changed. Runtime reproduction and the new assertion remain unverified.
- `bin/rubocop app/queries/email_sign_up_otp_form_query.rb test/integration/email_signup_http_delivery_commit_test.rb`:
  2 files, no offenses.
- Ruby syntax checks for both files: passed. Scoped `git diff --check`: passed.
- No browser tool was available; the user's live signup was not replayed.
