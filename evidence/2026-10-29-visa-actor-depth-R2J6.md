# Visa authorization Actor read depth

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Extensive uncommitted worktree changes affected this result.
- In the app and org Visa authorization base controllers, read `Actor.authn.amr` into a local value before taking its first entry. The read remains conditional on the absence of an explicit authentication method, preserving the prior short-circuit behavior.
- `PARALLEL_WORKERS=1 bin/rails test test/security/invariants/actor_context_invariant_test.rb test/integration/acceptance_wu02_issuer_consistency_test.rb`: 8 runs, 28 assertions, no failures, errors or skips. The Actor read-depth invariant previously failed for these two controllers (see `2026-10-29-wu4-risk-boundary-T3R7.md`).
- No full-suite rerun was performed after these changes. Rails test database preparation was used; no production persistence operation or external write was performed.
