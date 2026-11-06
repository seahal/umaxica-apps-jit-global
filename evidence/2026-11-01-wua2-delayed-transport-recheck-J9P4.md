# WU-A2 D-58 delayed signup transport recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. At final status check the shared worktree had 539
changed tracked paths, 261 untracked paths (including this evidence file), and no staged changes.
The changes were uncommitted; no commit was created. No application code or schema changed in this
slice.

The ignored workspace note `four.md` was updated and is not included in those Git status counts.

The delayed transport test file creates its own records. Its first grouped run failed during global
fixture setup because an unrelated `enterprise_units.enterprise_id` row referenced a missing
Enterprise. Setting `fixture_table_names` to an empty list prevented that unrelated fixture load.
The next run then isolated two test errors: both delivery issuer calls correctly raised
`DeliveryUnavailable` because Rails wrapped the test in a transaction, so Source and Ticket were not
committed.

The two suspension tests now call the OTP issuance operation and channel adapter directly. They
verify that a queued email or SMS delivery suppressed at transport time leaves the current OTP
generation usable. The actual signup delivery issuer remains covered at its production commit
boundary by the HTTP integration tests, which run without transactional tests.

Verification, with `.env.container.devcontainer` sourced for Rails boot:

- `bin/rails test test/integration/email_signup_http_delivery_commit_test.rb test/integration/telephone_signup_http_delivery_test.rb test/integration/signup_otp_delayed_transport_test.rb`:
  17 runs, 271 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop test/integration/signup_otp_delayed_transport_test.rb`: no offenses.
- `ruby -c test/integration/signup_otp_delayed_transport_test.rb`: syntax OK.
- `git diff --check`: passed.

This is focused D-58 evidence only. It does not establish other post-commit delivery outcomes or
close WU-A2. The full suite was not run.
