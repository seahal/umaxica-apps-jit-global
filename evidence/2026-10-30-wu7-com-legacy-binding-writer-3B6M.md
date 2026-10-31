# WU-7 com legacy binding writer removal

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting these checks.

The legacy shared preference update path contained a com-only browser-binding writer outside the com write transaction. The old writer and its call were removed. The shared legacy dual-write methods now reject com setting children before changing them, and the Base com preference transport no longer bootstraps a preference during unsafe requests. The dedicated and generic com preference screens use the authorized write boundary; app/org continue using their existing shared paths.

Before the change, the com write journey, Web Push API and write-boundary tests passed: 55 runs, 382 assertions. After the change, those tests plus the com initialization and issuance-boundary invariant tests passed: 84 runs, 760 assertions, no failures, errors, or skips. The same checks were repeated after the guard was narrowed from the parent to the submitted com setting child, with the same result; RuboCop also passed for the final application files.

The checks do not prove every possible writer is inventoried or that realm-specific keys, lifecycle migration, transaction races and the remainder of WU-7 are complete. No destructive migration or production write was performed.
