# WU-4 retired corporate sign-entry flags

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected these results.
- Removed the retired corporate sign-in and sign-up entries from the sign-entry resolver and feature registry. The resolver explicitly rejects both corporate pairs; app and org availability flags retain their existing fail-closed behavior.
- The feature-registry invariant now derives declared sign-entry flags from the resolver itself, so every remaining resolver flag must be registered. The old global test setup still enables the two old names directly through Flipper; it is not an application read and was not changed.
- `PARALLEL_WORKERS=1 bin/rails test test/resolvers/sign_entry_sentry_resolver_test.rb test/security/invariants/feature_flag_registry_invariant_test.rb`: 8 runs, 253 assertions, no failures, errors or skips.
- No full-suite rerun was performed after these changes. Rails test database preparation was used; no production persistence operation or external write was performed.
