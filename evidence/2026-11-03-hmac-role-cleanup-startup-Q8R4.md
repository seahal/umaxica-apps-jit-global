# Approved HMAC foreign-dependency cleanup and startup

- Revision: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; extensive pre-existing uncommitted changes
  affect the application. No application source or migration was edited for this cleanup.
- The user explicitly approved deletion of the two databases identified in
  `2026-11-03-hmac-role-dependency-preflight-H7D2.md` after being given their inventory, risk and
  backup/recovery plan.
- Rechecked original database OIDs (APP 282878947, ORG 282878956), owner `root`, zero connections,
  and both backup SHA-256 hashes against the preflight record. Both matched. Backups remain in
  `/tmp/umaxica-hmac-recovery-20261103/`.
- `dropdb -h primary -U root leak_template_test_app_zenith_db` and its ORG counterpart both exited 0
  without forced connection termination. No roles or other databases were dropped.
- Post-cleanup `pg_database` reported zero matching databases. `pg_shdepend` reported no HMAC-role
  dependency in any remaining `leak_template_*` database.
- Started `bin/dev`, retaining its normal `db:prepare`. Preparation advanced past the former
  migration failure and completed; Foreman started Web, Vite and jobs. Puma reported listening on
  `0.0.0.0:3000` with two booted workers. Vite 8.3.5 reported ready on port 3036. Jobs started its
  child processes. The Foreman session was left running.
- A local HTTP request to `http://127.0.0.1:3000/up` received 404 with a route-not-found error. This
  confirms an HTTP response, not a successful health check; no product journey, queue execution or
  full test suite was verified.
- Startup output was retained outside the repository in `/tmp/umaxica-bin-dev-20261103.log`.
  Database restoration was not needed or rehearsed. No isolation checks were weakened and no
  environment-construction tests were added.
