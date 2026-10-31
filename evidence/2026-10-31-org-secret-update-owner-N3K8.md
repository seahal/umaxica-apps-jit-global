# ORG Secret update and removal owner status

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- Existing create, update and destroy tests passed before this slice (17 runs, 53 assertions). A new reserved-operator test then failed before the change: 10 runs, 18 assertions, 1 failure. The first failed assertion tested rename; removal was exercised after the fix.
- Update and removal now check the locked operator's login eligibility before using Step-Up or mutating a credential.
- `PARALLEL_WORKERS=1 bin/rails test test/services/staff_secret_credentials/create_test.rb test/services/staff_secret_credentials/update_test.rb test/services/staff_secret_credentials/destroy_test.rb`: 18 runs, 61 assertions, no failures or errors.
- RuboCop inspected the two changed services and test with no offenses.
- Cross-database commit ordering and independent-connection races remain unverified and are not resolved by this change.
