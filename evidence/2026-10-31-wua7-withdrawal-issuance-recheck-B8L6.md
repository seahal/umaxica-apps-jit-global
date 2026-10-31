# APP withdrawal reentry issuance recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- An HTTP test performed real OTP verification and then released the Email binding before ceremony creation. Before the change it failed because a ceremony was created (1 run, 3 assertions, 1 failure); the actor-recovery iteration had not yet run.
- Withdrawal reentry now holds the Client and Email locks and rechecks subject ownership, eligibility and the current verified Email binding after OTP verification before issuing a status ceremony. Post-change coverage exercises both Email release and actual `WithdrawalLifecycle.recover!`, with no normal authentication cookies.
- The withdrawal reentry/session, lifecycle and Email verification files passed together: 34 runs, 193 assertions, no failures or errors. RuboCop found two existing extra blank lines outside this change in the integration test; the changed concern had no reported offenses.
- These tests use synchronous injection and transactional fixtures. Independent-connection races, real delivery and explicit withdrawal-state migration remain unverified; this retains the current timestamp-based eligibility until the separately reviewed state shape is implemented.
