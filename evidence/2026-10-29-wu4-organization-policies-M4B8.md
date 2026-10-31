# WU-4 organization authorization boundaries

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes, including corporate authentication model removal and these policy changes, affected the results.
- Removed corporate Visitor authorization branches from account, organization and membership policies. Existing Company, Individual and membership records remain; their corporate authorization now denies access through these policies. The app/operator cross-surface refusal test uses a surviving operator actor.
- `PARALLEL_WORKERS=1 bin/rails test test/policies/organization_membership_policy_test.rb test/policies/account_policy_test.rb test/policies/ownership_and_status_gate_sweep_test.rb`: 20 runs, 44 assertions, no failures, errors or skips.
- `PARALLEL_WORKERS=1 bin/rails test test/policies/retired_corporate_authority_policy_test.rb`: 1 run, 12 assertions, no failures, errors or skips. The test checks denial of corporate account, organization and membership authorization for clients, operators and anonymous actors.
- No full-suite rerun was performed after these changes. Rails test database preparation was used; no production persistence operation or external write was performed.
