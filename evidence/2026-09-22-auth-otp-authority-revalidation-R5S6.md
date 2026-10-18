# Compose-backed authentication, OTP, and authority revalidation

- Date: 2026-09-22 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- Scope: re-run database-backed focused tests that were previously recorded as blocked by the
  unavailable isolated PostgreSQL/Valkey services.
- External writes: none. No production, shared, provider, AWS, Cloudflare, email, or SMS service
  was contacted. The tests used the existing Compose test services and test databases only.

## Environment

The test process used the repository's explicit environment file and isolated test database
preparation list. `primary` PostgreSQL and `valkey-kvs` resolved from the current Compose-backed
execution context. Secret values were not printed.

## Verification

The following focused groups completed with `PARALLEL_WORKERS=1`:

| Boundary | Result |
| --- | --- |
| RP Session, OIDC token exchange, child revoke independence, refresh expiry | 133 runs, 609 assertions, 0 failures, 0 errors, 0 skips |
| OIDC authorization, Base authority, Auth handoff, browser RP flow | 89 runs, 469 assertions, 0 failures, 0 errors, 3 skips |
| OTP, resend, TOTP window, sign-up and telephone delivery boundaries | 115 runs, 600 assertions, 0 failures, 0 errors, 0 skips |
| Authority schema/vocabulary, owner inventory, creator concurrency and route contracts | 55 runs, 479 assertions, 0 failures, 0 errors, 0 skips |
| Enforcement appeal/reconciliation, signup expiry, Solid Queue, dashboard and observability | 95 runs, 722 assertions, 0 failures, 0 errors, 0 skips |

Combined: **487 runs, 2,879 assertions, 0 failures, 0 errors, 3 skips**.

The three skips were reported by the OIDC group; no test was deleted, weakened, or newly skipped
for this revalidation. This result verifies the listed local database-backed contracts. It does not
prove production worker topology, external RP registration, provider delivery, Cloudflare routing,
or the blocked Auth/Base issuer migration and authority cutover decisions.

The full Rails suite was then run with the same explicit test environment and completed with
**11,500 runs, 73,296 assertions, 0 failures, 0 errors, 5 skips**. The five skips are pre-existing;
no assertion, skip, coverage threshold, or security check was changed for this run. Normal
OmniAuth debug/error log lines appeared for tests that intentionally exercise provider failure and
CSRF/deprecation paths; they did not produce test failures.

## Disposition

The environment blocker is resolved for these focused local verification paths. Historical entries
that recorded the earlier unavailable-service state remain historical and are not treated as current
failures. The remaining architectural and external-contract blockers are unchanged.
