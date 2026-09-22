# Previously blocked boundary regression revalidation

Date: 2026-09-21 UTC

The isolated PostgreSQL and Valkey services were available after the Phase 00 preflight. The
following previously environment-blocked or partially evidenced repository test groups were run
with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`, the explicit test
database preparation allowlist, and `PARALLEL_WORKERS=1`.

| Boundary | Result |
| --- | --- |
| OTP, one-time, confirmation, ceremony-candidate, and recovery-code tests | 405 runs, 1,920 assertions, 0 failures, 0 errors, 0 skips |
| OIDC, RP session, token exchange/revocation, refresh, realm, and logout tests | 175 runs, 795 assertions, 0 failures, 0 errors, 0 skips |
| Sign-up, enforcement, retention, JWT anomaly, and audit tests | 173 runs, 650 assertions, 0 failures, 0 errors, 0 skips |
| Withdrawal and recovery ceremony/re-entry tests | 212 runs, 987 assertions, 0 failures, 0 errors, 0 skips |

No production, shared, provider, AWS, Cloudflare, email, or SMS service was contacted. The first
attempt at the third group named one audit test with an incorrect path and therefore stopped
before test execution; the corrected existing repository path was rerun and produced the result
recorded above. That runner mistake is not treated as an application failure.

These results close the environment-only verification gap for the listed repository boundaries.
They do not prove live provider delivery, production TLS deployment, external queue operation, or
the separate provider receipt contract identified as remaining in FREQ-0064.
