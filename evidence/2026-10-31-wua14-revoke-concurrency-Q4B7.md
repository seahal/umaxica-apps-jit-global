# A44-10 concurrent login test investigation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result. The test uses nontransactional test-database records.
- `PARALLEL_WORKERS=1 timeout 75s bin/rails test test/concurrency/root_revoke_others_concurrent_login_test.rb` initially timed out in the `pg_stat_activity` polling loop: 1 run, 0 assertions, 1 error. The same test ID is recorded as an error in the baseline.
- The polling query was then executed uncached. The test reached its next assertion and returned `session_limit_pending` rather than the expected `success`; it reported 1 run, 1 assertion, 1 failure. The existing teardown additionally emitted a foreign-key error when deleting the sign-in flow referenced by the newly created session-limit transaction. The test database may therefore retain test-created actor/flow/resolution rows. No cleanup outside the test was performed.
- Current code sets `ClientToken::MAX_SESSIONS_PER_USER` to 2; this scenario already creates two active sessions before asking for a third. This explains why its expectation needs reconciliation with the session-limit contract, but does not establish the actual revoke/login race outcome. No product locking change was made and the race remains unverified.
