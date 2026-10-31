# Preference synchronization documentation

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected this review.
- Compared `PreferenceAdoption`, `PreferenceSignOutRotation`, preference models and the accepted record-recency ADR with the architecture document. The document incorrectly described corporate account adoption and whole-parent-record recency as current. It now describes the existing per-field app/org adoption, consent reconciliation and legacy sign-out limits, and identifies the pending two.md one-way contract.
- `git diff --check -- docs/architecture/preference.md` passed. With automatic schema maintenance disabled because the com binding migration is pending, the dormant-gate guard and real app/org rotation tests passed: 3 runs, 26 assertions.
- The accepted record-recency ADR still differs from both current code and the requested two.md target. This documentation correction does not implement the requested new app/org write boundary, migrate data, or verify sign-in end to end.
