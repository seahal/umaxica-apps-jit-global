# Completion Origin, missing token and immutable GET matrix

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
implementation, test and documentation changes present.

Added missing REQ-006/AT-045 completion cases across all twelve registered clients: a valid intent
proof without a Rails token, and valid proof/token with a foreign Origin. Both return 422 and
preserve origin_cleanup_issued. Strengthened GET immutability assertions to compare all persisted
transaction attributes before and after the unbound and bound challenge GETs, including timestamps.
The later valid POST and one-shot completion still succeed. No further production change was needed
beyond the previously recorded required-token correction.

Executed
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_rp_completion_matrix_test.rb`:
1 run, 603 assertions, 0 failures, 0 errors, 0 skips. The prior run before the full-attribute
assertions passed 1 run / 579 assertions. Scoped diff checking passed. Only normal Rails test
databases were used; no reset or isolated fleet. Full authority-flow and live-browser acceptance
remain separate unfinished work.
