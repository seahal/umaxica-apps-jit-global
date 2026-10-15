# Tech callback nonce verification

Recorded on 2026-10-15 UTC against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, with extensive
uncommitted changes.

Added missing AT-048 nonce partition coverage at the Tech HTTP callback. Starting with the
production coordinator's token response, change only nonce and sign the altered ID Token using the
production ID Token codec and configured operator issuer key. The actual callback returns
422/no-store, issues neither RP authentication cookie nor Tech identity binding, and leaves the
existing parent and candidate RP row usable. Token transport is the existing explicit double; ID
Token validation is real. No production change was needed because this behavior already passed.

Command:
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/tech/org/oidc/callbacks_controller_test.rb`.
Result: 7 runs, 102 assertions, 0 failures, 0 errors, 0 skips. Targeted RuboCop: one file, no
offenses. Scoped diff check: clean. Only the ordinary Rails test databases were used; no reset,
migration or isolated fleet. Other protocol partitions and external/manual acceptance are separate
from this result.
