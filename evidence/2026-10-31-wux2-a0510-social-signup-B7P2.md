# Historical A05-10 social signup handoff

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this check.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/social_auth_app_flow_contract_test.rb -n '/(Google|Apple)_sign_up_entry_creates_one_client/'`: 2 runs, 82 assertions, 0 failures, 0 errors.
- Each case checks a single social identity and Client, the canonical `/sign/in/check` redirect after signup, and a Client token for that owner. The existing test substitutes the outbound transport while invoking local protocol controllers.
- These success cases do not establish the whole A05-10 matrix: the historical requirement also names sign-in guardrails, checkpoints, MFA, cooldown and session limits. Exact Root cardinality, actual provider/network delivery and all failure partitions were not verified in this check.
