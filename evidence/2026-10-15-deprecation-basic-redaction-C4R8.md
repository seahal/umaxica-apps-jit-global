# Deprecation Basic credential redaction

Executed on 2026-10-14 UTC against commit
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, with extensive uncommitted worktree changes.

REQ-029 requires secrets to be removed before message shortening. A new notification-boundary
regression reproduced an Authorization Basic credential remaining in the output: the existing
assignment matcher removed only the scheme word. The subscriber now removes the complete Basic
or Bearer authorization assignment before the general redactor and length limits.

Command: `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/subscribers/deprecation_notification_subscriber_test.rb`.
Red: 4 runs, 59 assertions, 1 failure, 0 errors, 0 skips.
Green: 4 runs, 61 assertions, 0 failures, 0 errors, 0 skips.

Targeted RuboCop inspected the subscriber and regression file with no offenses. Scoped
`git diff --check` passed. Only the standard Rails test database configuration was used.
Production boot/logging acceptance remains separately unverified; this result establishes the
subscriber's credential-redaction behavior, not production deployment acceptance.
