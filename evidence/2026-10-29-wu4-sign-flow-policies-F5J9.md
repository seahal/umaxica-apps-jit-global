# WU-4 sign-flow policy cleanup

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes, including corporate authentication removal and these policy edits, affected the results.
- Removed deleted visitor model branches from sign-in and sign-up policy actor matching. The operator sign-in policy now reaches its own actor match; its owner, another surface actor, and an anonymous actor were exercised.
- Removed retired corporate signup routes and deleted model references from `SignUpStepGate`; corporate email OTP and birthdate requests are rejected as unsupported before flow lookup.
- `PARALLEL_WORKERS=1 bin/rails test test/policies/sign_in_cycle_policy_test.rb test/policies/sign_up/policies_test.rb`: 35 runs, 168 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/services/sign_up_step_gate_test.rb`: 6 runs, 20 assertions, no failures, errors or skips.
- No full-suite rerun was performed after these changes. Rails test database preparation was used; no production persistence operation or external write was performed.
