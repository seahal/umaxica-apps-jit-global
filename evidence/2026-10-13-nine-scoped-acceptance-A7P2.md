# Nine scoped acceptance after clean database rebuild

Date: 2026-10-13. HEAD: `4828aeedd141b54163236672890799b9b01128c2`. The worktree had uncommitted
acceptance changes, including the OTel correction, three setting Preference migrations and generated
schemas, behavioral tests, and scope documentation. Other contributors' unrelated documentation
changes were preserved. No commit or deployment was performed. These results describe this dirty
worktree, not HEAD alone.

## Decision

**PASS for the user-approved current delivery scope, with explicit exceptions.** The
[final scope decision](../specs/integrated-stack-delivery/acceptance.md#final-user-approved-delivery-exceptions--2026-10-13)
controls this result. This is not unrestricted production readiness or proof of every original
criterion. Earlier failing evidence remains intact.

- The ORG missing durable halt audit remains a known defect in
  [its backlog](../plans/backlog/org-normal-sign-in-durable-halt-audit.md). Only the deferred audit
  assertion was removed; the controller regression still checks safe GET/HEAD refusals, attributable
  POST HALT, and no token/challenge creation on replay. It was not skipped and does not assert that
  missing audit is correct. Application behavior was not changed.
- Remaining authentication/identifier verification planning is deferred to
  [two delivery cycles later](../plans/backlog/nine-auth-identifier-verification-two-cycles.md).
  Missing verification was not reported as executed or as a repaired IDOR.
- Previously accepted Avatar follow-up, JavaScript coverage exception, and environment, policy and
  production exclusions remain as documented in the acceptance scope.

## Test prerequisite correction

`PasskeyMutationAuthorizationTest` disabled automatic fixtures and depended on existing token
reference rows. Explicitly load binding-method and DBSC-status fixtures for APP, COM and ORG in this
class. No global test helper, application validation or database constraint was changed. The first
focused run with only binding-method fixtures exposed three missing DBSC-status errors; adding those
prerequisite fixtures resolved them. The final focused run of this class and the ORG passkeys
controller class passed: **23 runs, 248 assertions, zero failures/errors/skips**.

## Fresh rebuild and full verification

The owned disposable run was `20261013n9a`, manifest `tmp/acceptance-isolated-20261013n9a.json`. The
original `20261010p8b` fleet was not reset. After the focused correction,
`scripts/postgresql-rebuild-isolated-test-fleet` again verified ownership and rebuilt all 20
databases from migration source files. Both `db:test:prepare` and `db:migrate` completed, with fresh
creation receipts for 12 roles; exit 0. No focused test populated the rebuilt parents before the
full run.

Commands used `RAILS_ENV=test`, the n9a run ID/manifest, `POSTGRESQL_TEST_HOST=primary`,
`POSTGRESQL_DATABASE=postgres`, and all 20 manifest names as `POSTGRESQL_TEST_PREPARE_DATABASES`.
The rebuild used one worker; the full `bin/rails test` used `PARALLEL_WORKERS=4`.

| Executed check                                                                | Result                                                                                 |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Full Minitest after rebuild, `bin/rails test`                                 | 15,250 runs; 128,965 assertions; 0 failures, 0 errors, 0 skips; 351.68 seconds; exit 0 |
| `bun run test`                                                                | 99 files; 1,140 tests passed; 13.57 seconds; exit 0                                    |
| Actual schema dump comparison through `SchemaDriftVerification.dump_matches?` | All 20 current database dumps matched worktree schemas; exit 0                         |
| Post-exit catalog verification                                                | 20 parent databases verified; 0 remaining worker databases; exit 0                     |
| RuboCop on both edited test files                                             | 2 files, no offenses; exit 0                                                           |
| `git diff --check`                                                            | Exit 0                                                                                 |

The schema comparison is not a Git-clean claim: three intended schema files remain uncommitted. The
earlier Git-based drift gate failure is retained in
[P3V8](2026-10-13-setting-preference-id-protection-P3V8.md). The coverage-threshold command was not
rerun or reclassified as passing; its prior shortfall is explicitly accepted for this delivery.
Fresh-suite results supersede the current blocker status of the test-prerequisite error in
[C6R2](2026-10-13-nine-clean-database-retest-C6R2.md), without erasing its reproduction.
