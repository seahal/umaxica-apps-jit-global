# Repeated isolated fleet reconstruction and role receipts

HEAD: `259a71e7543a9c09a1db038c7c0d905c4ef63a90`, branch feature. The rebuild script change, prior
application/test/migration/generated-schema work and unrelated source-policy/OTP documentation are
uncommitted. Documentation commits do not snapshot that implementation. Scope: owned fleet
20261010p3d2 on primary, all twenty manifest databases, one worker. No shared database, unknown
role, production resource, remote write or CI was used.

The earlier rebuild refreshed database OIDs but retained previous role creation OIDs. This was a
source-observed lifecycle gap, not a reproduced permission to adopt existing cluster roles. The
actual original `/tmp/p3d2-fresh-prepare.log` checksum matched the recorded receipt:
`0df12b05c59a2b75e4162c7e11093cebca11dc16073e74a0a3feeb5d6c11b219`. Its twelve CREATE ROLE
statements named exactly the recorded roles; current OIDs matched. No secret values or raw migration
log are included here.

## Observed direct checks

- `ruby -c scripts/postgresql-rebuild-isolated-test-fleet`: Syntax OK.
- `bundle exec scripts/postgresql-rebuild-isolated-test-fleet --verify-only` with the old receipt
  explicitly supplied by POSTGRESQL_ISOLATED_ROLE_CREATION_LOG: exit 0; verified twenty databases
  and twelve roles, including ownership/OIDs/comment, inactive sessions, restricted role attributes,
  membership and dependency checks.
- The same read-only preflight supplied another local log: exit 1, role creation record checksum
  mismatch, before DROP. It did not claim success or reconstruct a receipt from naming alone.
- The full owned rebuild command completed twice consecutively, both exit 0. Each invocation
  verified resources first, dropped only the owned fleet and its proven now-orphaned roles,
  recreated twenty databases, then completed normal db:test:prepare and db:migrate. Each recorded
  twelve fresh role OIDs and a real CREATE ROLE transcript under tmp. The second invocation used the
  first invocation's fresh receipt, without the old-log environment override.
- After the first rebuild, the no-override verify-only command exited 0 on the replacement
  identities. After the second rebuild, the manifest contains twenty database receipts and twelve
  role receipts; SHA-256 of its recorded log path matches its stored checksum.
- Final scoped RuboCop: one file, no offenses. git diff --check succeeded.

The command now serializes same-run rebuilds with a PostgreSQL advisory lock, accepts only the
explicit verify-only argument, checks the actual creation file/checksum/names, refuses role-specific
configuration, and records normal child-task output with mode 0600 before refreshing role receipts.
Migration failure remains failure; an unavailable or mismatched transcript leaves cleanup blocked.
No environment-construction Minitest/Vitest case was added.

Both required full suites started on the second rebuilt fleet. Vitest completed: 99 files, 1,140
tests, 13.44 seconds, exit 0. Rails completed with exit 0: 15,033 runs, 127,498 assertions, zero
failures/errors/skips, 940.671728 seconds. No next feature edit occurred before both outcomes were
resolved. This reconstruction is not proof of Avatar ownership real COMMIT, concurrency, dump/
restore, safe parallel clones, production readiness or independent acceptance. The isolated catalog
still enforces one worker until parallel clone ownership/cleanup is established.
