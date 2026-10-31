# Jump return source origin

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected the checks.
- Jump source and destination origin normalization rejects paths, queries and fragments rather than discarding them. The receiver rejects signed return tokens whose `src` has these components. The Jump ADR and acceptance checklist describe the restriction.
- `bin/rails test test/services/jump_rt/return_policy_test.rb test/services/jump_rt/return_verifier_test.rb`: 98 runs, 665 assertions, no failures or errors.
- `bundle exec rubocop app/policies/jump_rt_return_policy.rb test/services/jump_rt/return_policy_test.rb test/services/jump_rt/return_verifier_test.rb`: no offenses.
- This does not establish all WU-A11 flows or completion of two.md.
