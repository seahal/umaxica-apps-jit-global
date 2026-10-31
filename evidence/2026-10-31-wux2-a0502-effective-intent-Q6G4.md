# Historical A05-2 effective entry intent

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting these results.
- The APP effective-intent tests now send a contradictory Referer when requesting the wrong entry path both before and after confirmation, and send both a contradictory prompt query and Referer after admission. Refusal preserves the binding; the correct path can redeem it.
- `PARALLEL_WORKERS=1 bin/rails test test/resolvers/auth_entry_intent_resolver_test.rb test/controllers/auth/effective_entry_intent_test.rb`: 8 runs, 63 assertions, 0 failures, 0 errors. The existing Google and Apple signup request cases, which use the explicit Switch, also passed: 2 runs, 83 assertions.
- RuboCop passed for the modified effective-intent test after the final Referer additions; the full suite was not run. The retired COM authentication path was not rerun. Full external browser and provider behavior remain unverified.
