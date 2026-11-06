# WU-A4 initial signup OTP commit-before-delivery

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree had 718 changed paths when this note was written, including pre-existing uncommitted
work. No changes were reset and no commit was made.

## Changes

- APP Email and Telephone initial signup now bind the selected candidate to the Ticket Flow,
  progress it to `CONTACT_PENDING`, and issue the first OTP in the initial Ticket transaction.
- Source cooldown is committed before delivery enqueue. Both delivery issuers reject an ambient
  Source or Ticket writer transaction.
- The controllers update the browser's signup sequence only after the Source and Ticket writes
  return committed. Notification failure leaves the committed OTP step available for retry.
- Added fixture-free public APP Email signup coverage for successful enqueue and refused enqueue.
  The refused enqueue returns 503, retains the Flow, OTP and cooldown, and permits the same browser
  to load the OTP step.

## Verification performed

All Rails commands below ran after sourcing the existing `.env.container.devcontainer` file.

- `bin/rails test test/operations/sign_up_otp_delivery_concurrency_test.rb`: 20 runs, 248
  assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/integration/telephone_signup_http_delivery_test.rb`: 4 runs, 143 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rails test test/integration/email_signup_http_delivery_commit_test.rb`: 2 runs, 37
  assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop over the four operations, two APP signup controllers and three test files: 9 files
  inspected, no offenses.
- `ruby -c` passed for those nine Ruby files. Scoped `git diff --check` passed.

These tests use the local test databases and Active Job test adapter. External email/SMS delivery
was not attempted. The full Ruby suite and baseline comparison were not run. Remaining XDB-14
requirements outside this initial-signup slice are not verified by this evidence.
