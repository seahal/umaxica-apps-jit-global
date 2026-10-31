# Recovery Case end reconciliation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The previous recovery completion change introduced a regression: constructing the existing end reconciler for `verification_completed` without the already-consumed ceremony raised `ArgumentError` (1 run, 4 assertions, 1 error). Validation now runs when starting an end operation, while the existing `reconcile` path remains available after a committed end.
- A test injected an audit-writer failure after Case end and ceremony consumption, then successfully called the existing end reconciler. The operation, reconciliation-job and recovery-action files passed together: 16 runs, 70 assertions, no failures or errors. RuboCop passed for the changed files.
- After adding an explicit missing-ceremony refusal case, the focused operation file passed again: 2 runs, 19 assertions.
- A temporary assertion then checked whether that ended Case would be found by `pending_end_convergence`; it failed (1 run, 5 assertions, 1 failure) because the previous applied audit had already populated the shared `audited_at` field. The assertion was removed rather than retaining a failing test. Automatic discovery of this missing end audit is therefore not fixed by the direct-reconciler change.
- The probe uses transactional fixtures and injected failure. A proposal for an explicit per-end delivery record was submitted for shape review; no schema, backfill, deployed data or production system was changed.
