# Completion without Fetch Metadata

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
implementation/test/documentation changes.

Extended the twelve-client matrix with invalid-token JSON POSTs lacking Fetch Metadata, and changed
its final positive continuation to omit that header while keeping correct Origin, same-session token
and intent proof. Every client refuses invalid tokens with 403 without state progression, then
accepts the legitimate continuation. The previously executed matrix separately covers present
same-origin metadata. No application change was needed for this partition.

Executed the completion matrix and existing CSRF strategy/standard guards using
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`: 7 runs,
663 assertions, 0 failures, 0 errors, 0 skips. Targeted RuboCop inspected one file without offenses;
scoped diff check passed. Only normal Rails test databases were used. Other acceptance and
external/manual gates remain unfinished.
