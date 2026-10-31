# WU-7 com legacy refresh read

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these results.

Before the change, the three fixtureless com Web Push, initialization, and retired-consent integration files passed with 32 runs and 379 assertions. After the change, the same files passed with 33 runs and 387 assertions, with automatic test schema maintenance disabled. A public Base com GET carrying legacy refresh and DBSC cookies produced no SQL writes, no replacement of those cookies, and no new preference JWT. RuboCop passed for the modified concern and integration test.

This check does not establish removal of the com creation path's legacy database columns, nor the complete WU-7 lifecycle, transaction, signing-key, and browser-binding contracts. No migration was applied by these checks.
