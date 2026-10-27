# Checks to run before the first production deployment

Status: Open (owner, 2026-10-26). Moved out of the 2026-10 authentication cycle's acceptance: they
need the deployed environment, not the local one. Source cases: `three.md` A36, A37, A41.

- **Host-only cookies (WU-36, D-115).** Every `Set-Cookie` and cookie deletion from authentication,
  preference, withdrawal and enforcement-recovery paths, observed on the deployed hosts, carries no
  `Domain` and no `Partitioned`. `grep -rn "CoreCookieDomain" app lib config` has no match.
- **Puma capacity (WU-37, D-120).** A load estimate with the chosen workers, threads and DB pool,
  and a measurement under that load: concurrent requests, RP→OP self-call latency and timeouts, DB
  connection use. Saturation is not claimed impossible.
- **Database timeouts (WU-41, D-142).** `SHOW lock_timeout` / `SHOW statement_timeout` on every
  production connection return the configured values, not 0; retention, expiry and secret-lifecycle
  jobs complete once without a cancelled statement.

Record each run in `evidence/`.

## Sign Entry Sentry flags (A29-11, added 2026-10-27)

Before enforcement in each deployed environment, run `bin/rails feature_flags:status` and record that
all six `sign_{in,up}_available_{app,com,org}` flags are in the intended state. Development was
recorded on 2026-10-27 (all on, after seeding).
