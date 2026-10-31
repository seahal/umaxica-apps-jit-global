# Enforcement method visibility and architecture ratchet

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

The full suite reported the architecture baseline test outside the baseline. Its focused rerun reproduced six visibility offenses in `Operator` against an allowance of four. Explicit public singleton visibility was added for the two new availability methods. The guard then exposed one additional offense in `EnforcementCaseApplyOperation`; its new reconciliation method was explicitly marked public. No baseline or allowlist was changed.

The focused architecture ratchet then passed (1 run, 2,332 assertions). The complete architecture test, enforcement apply authority/failure/concurrency tests, and Operator model tests passed together (63 runs, 2,481 assertions). Scoped RuboCop passed. An initial combined command named a nonexistent test file and failed before running tests; the corrected command produced the passing result above. The full suite was not rerun after this change.
