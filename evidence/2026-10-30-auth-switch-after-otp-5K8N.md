# Auth switch after an email challenge

- Commit: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- Command: `RAILS_ENV=test bundle exec ruby -Itest -r ./config/environment -e 'ActiveRecord.maintain_test_schema = false; ARGV.each { |path| require File.expand_path(path) }' test/integration/sign_entry_otp_admitted_order_test.rb test/integration/sign_entry_invitation_parent_test.rb`.
- Result: 7 runs, 90 assertions, no failures, errors, or skips. Schema maintenance was disabled; pending migrations were not applied.
- After OTP delivery failure and the email Back operation, a switch request was refused while the current auth SID, ceremony and pending OIDC parent remained intact. The response currently remains 400, not the phase-409 contract proposed by `two.md`; this does not establish the full D-52 boundary.
- RuboCop passed for the changed concern; one test formatting offense was corrected after the run.
- Handoff failure follow-up: the same two integration files passed with 8 runs and 103 assertions. In an otherwise valid Switch, injected handoff generation failure rolled back ceremony cancellation and preserved the SID and pending parent; a subsequent successful Switch cancelled the ceremony and left the parent pending. RuboCop passed for the Switch controller and test. Parent-lock serialization, replacement binding creation, and concurrent Switch acceptance remain unverified and incomplete.
