# Email preference device session check

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- A test with a revoked device and otherwise valid target-bound Step-Up reproduced a successful preference mutation before the fix. The new locked-device check denied it and preserved the preference and proof.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_email_preference_committer_test.rb` passed: 6 runs, 40 assertions, no failures or errors.
- Other writers' device checks were not covered by this test.
- A separate test reproduced acceptance of a non-current token whose device had a newer current token. The writer now rechecks that binding; `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_email_preference_committer_test.rb test/integration/step_up_authentication_test.rb` passed: 36 runs, 168 assertions, no failures or errors.
