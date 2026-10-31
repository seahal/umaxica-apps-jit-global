# Historical A05-7 social candidate boundaries

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting these results.
- The existing candidate failure file initially passed (3 runs, 8 assertions). Added cases inject `ConnectionNotEstablished` at the actual candidate INSERT and verify that the error propagates and no candidate for the operation remains. A separate case supplies a synthetic provider credential and verifies the stored payload consists only of the expected principal fields; the fetched candidate contains no credential.
- `PARALLEL_WORKERS=1 bin/rails test test/services/identity_social_ceremony_candidate_store_failures_test.rb test/services/identity/social_ceremony_contract_test.rb`: 19 runs, 131 assertions, 0 failures, 0 errors. The existing contract file also exercises consumed and expired candidates.
- RuboCop and scoped `git diff --check` passed after the final assertion. This is an injected failure under transactional test fixtures, not an actual OP database outage, independent commit fault, or HTTP-level check. No production code was changed.
