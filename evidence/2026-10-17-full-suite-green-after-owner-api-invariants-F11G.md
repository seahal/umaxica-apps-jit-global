# Full suite green after owner API invariant fixes

- Commit: 17903f7d121aa33efe29f2db9235c9aa5db4b001 (worktree has the uncommitted one.md R4/R5
  changes; they are the subject of this run)
- Date: 2026-10-17T08:53:21Z
- Fleet: isolated test DBs `codex_integrity_20261017c1a2_*`, PARALLEL_WORKERS=8, seed 42061

## Changes verified

- New ActionController::API roots (Base owner APIs, backchannel logouts) declare DefaultNoStore and
  are registered in DefaultNoStorePolicyInvariantTest.
- `PUBLIC_BASE_OWNER_API` category added (test and docs/security/public-entrypoints.md); `/sign/bye`
  covered by `PUBLIC_SIGN_OUT`.
- CsrfRouteCoverageTest treats owner APIs, `/oidc/backchannel-logout` and
  `/oauth/refresh-deliveries/query` as protocol endpoints.
- OpenapiRouteCoverageTest exempts the owner API paths (internal Base Self-RP to owner contract);
  open for user decision.
- Architecture baseline regenerated.

## Result

`bin/rails test test/ --seed 42061`: 15429 runs, 131660 assertions, 0 failures, 0 errors, 0 skips.
The previous run (run 10) had 11 failures and 1 error.
