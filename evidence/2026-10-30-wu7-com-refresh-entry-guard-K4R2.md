# WU-7 com refresh entry guard

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The shared refresh lookup still had a com branch that could create an anonymous row through the old transport. That branch now refuses com before examining an already loaded preference or creating a row. Existing app/org refresh paths remain in place.
- Before this change the com journey, initialization and CSRF tests passed: 80 runs, 696 assertions. Afterward those files plus the issuance boundary invariant passed: 82 runs, 702 assertions, 0 failures, 0 errors, 0 skips. A generic screen save with a legacy refresh cookie creates one new com row through the write boundary, with no refresh digest.
- `bin/rails test test/integration/preference_refresh_replay_test.rb`: 2 runs, 11 assertions, 0 failures, 0 errors, 0 skips. RuboCop found no offenses in the two changed files.
- This does not prove that all legacy schema and DBSC references have been removed or that WU-7 is complete. No migration or full suite was run.
