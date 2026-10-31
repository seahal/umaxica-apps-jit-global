# Sign-entry Sentry parent writer read

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

Non-transactional APP HTTP tests initially received 400 at `/ceremony_bindings`: a temporary exception probe identified `RecordNotFound` for the newly committed authorization parent. The Sentry had resolved the binding on the writer, then read its parent through the request's current database role. Its APP/ORG parent reads now explicitly use the corresponding OP writer and use the returned parent directly. The local test replica is a separate database; this check does not measure deployed replication lag.

`PARALLEL_WORKERS=1 bin/rails test test/integration/sign_in_otp_resend_committed_http_test.rb test/concurrency/sign_in_otp_resend_serialization_test.rb test/integration/sign_entry_sentry_parent_failure_test.rb test/integration/sign_entry_sentry_test.rb` passed: 30 runs, 236 assertions. This includes APP real/fake resend HTTP successes, ORG binding attachment, outer-transaction refusal, and injected missing-parent refusal on both surfaces. Scoped RuboCop passed. The APP HTTP tests use an injected adapter, and the admission confirmation is called directly; real delivery and full browser behavior were not tested.

During test development two cleanup-order errors left synthetic records. Exact known binding, session and parent IDs from those failures and one contact/owner identified by the synthetic session were removed from the local test database. The first failed run may also have left one synthetic contact and owner whose IDs were not captured; no broad cleanup was attempted. The previously recorded 21 fixture-transaction failures remain unresolved and were not rerun in this check.
