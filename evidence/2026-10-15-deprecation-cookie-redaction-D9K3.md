# Deprecation Cookie header redaction

Executed on 2026-10-14 UTC against commit
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, with extensive uncommitted worktree changes.

REQ-029 requires secret removal before length limiting. A notification-boundary test reproduced
the second cookie pair leaking after the first pair was redacted. The subscriber now removes the
Cookie or Set-Cookie header line before control-character normalization, general redaction and
shortening. The regression also verifies that safe explanation on the next line is retained.

Command: `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/subscribers/deprecation_notification_subscriber_test.rb`.
Red: 5 runs, 66 assertions, 1 failure, 0 errors, 0 skips.
Green: 5 runs, 68 assertions, 0 failures, 0 errors, 0 skips.

Targeted RuboCop inspected two files without offenses, and scoped `git diff --check` passed.
The run used only standard Rails test databases. Production logging acceptance and the other
plan requirements remain independently unverified; no broad completion claim follows this fix.
