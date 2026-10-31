# Historical A29-2: unknown Sentry surface or flow

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the resolver and tests; this result applies to that worktree.

Historical acceptance case A29-2 requires an `ArgumentError` for an unknown Sign Entry Sentry surface or flow. Current `SignEntrySentryResolver` raises for a pair absent from its registered mapping. `PARALLEL_WORKERS=1 bin/rails test test/resolvers/sign_entry_sentry_resolver_test.rb:39` passed: 1 run, 4 assertions. The public resolver test covers retired COM for both sign-in and sign-up, an unknown `net` surface, and an unknown `ticket` flow on APP.

This establishes the local A29-2 case for those inputs, not the other historical cases or complete WU-X2 reconciliation.
