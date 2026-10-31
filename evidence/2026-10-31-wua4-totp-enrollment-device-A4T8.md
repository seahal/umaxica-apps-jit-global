# TOTP enrollment device boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A focused test reproduced finalization from a revoked device (1 run, 1 assertion, 1 failure).
- With device and current-token checks inside the Client and OP locks, the final enrollment and verification operation tests passed: 12 runs, 180 assertions, 0 failures, 0 errors, 0 skips. Tests cover revoked and superseded device refusal before credential creation and ticket consumption.
- A wider run including `test/integration/totp_registration_boundary_test.rb` produced 17 runs, 200 assertions, 1 failure and 4 errors. All five affected test IDs appear in `plans/2026-10-28-baseline-failing-tests.md`; their causes were not established. That run preceded the added superseded-device case.
- RuboCop passed for the two touched files and scoped `git diff --check` passed. This does not verify the full XDB-10 audit and failure-window contract.
