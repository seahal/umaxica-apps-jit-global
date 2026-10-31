# Jump source origin at the HTTP boundary

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected these checks.
- The integration test submits a correctly signed return token whose source has a path. The public receiver responds 400 without redirecting.
- `bin/rails test test/integration/jump_rt_return_verification_test.rb test/services/jump_rt/return_policy_test.rb test/services/jump_rt/return_verifier_test.rb`: 121 runs, 730 assertions, no failures or errors.
- A12 documentation and current implementation differ: two.md refers to a Base POST continuation and strict-origin, while the existing Visa continuation calls verified browser-navigation GET jobs; the old Base template has no current code references. The archived later-cycle work-unit definition describes this replacement. This observation does not prove all A12 conditions or authorize weakening CSRF checks.
