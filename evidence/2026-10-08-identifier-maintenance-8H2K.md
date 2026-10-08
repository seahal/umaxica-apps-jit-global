# Scoped identifier HMAC maintenance verification

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. The worktree has uncommitted
identifier/OTP/history implementation changes affecting every result below.

Three forward migrations installed realm-local audit ledgers, scoped NOLOGIN roles and
SECURITY DEFINER functions successfully on verified `test_app_zenith_db`,
`test_com_zenith_db` and `test_org_zenith_db` only. No production database, secret, login
membership or connection setting was changed. Existing APP/COM binding guards were retained
with an exact digest-only maintenance boundary; no generic trigger-disable facility exists.

`bin/rails test test/services/identifier_hmac_maintenance_boundary_test.rb
test/services/realm_identifier_hmac_rotation_test.rb
test/services/identifier_hmac_emergency_rotation_test.rb
test/lib/realm_identifier_digest_test.rb test/lib/identifier_blind_index_test.rb
test/models/contact_binding_constraints_test.rb` passed: 45 runs, 560 assertions,
zero failures/errors/skips, seed 21822.

After adding SQL public-boundary argument and stale-snapshot checks, the focused maintenance
file passed: four runs, 96 assertions, zero failures/errors/skips, seed 65295. APP/COM x
Email/Telephone exercise low-privilege function execution, unchanged-row no-op, malformed
arguments, digest length neighbors 63/64/65, source compare-and-swap conflicts, refusal of
direct writes and peer-channel execution, and atomic rollback when audit insertion conflicts.

`bin/rails -T identifier_hmac` succeeded and listed the new explicit realm/channel task.
The task was not run against a fleet: no real key rotation or batch identifier mutation was
performed. Its required maintenance URL is read only when explicitly executing the task;
normal application startup and Rails tests require no additional variable.

Focused RuboCop initially reported formatting issues; these were corrected. Final lint,
migration down/up reconstruction, full Rails tests, full RuboCop and all repository gates
remain to be completed. Earlier class-ending and PostgreSQL result-type errors were corrected
before the green matrix; pending migration setup was not counted as a behavioral TDD failure.
The previous test process result could not be recovered after its handle closed, so only the
observed seed 21822 run is claimed here. This is partial verification, not Definition of Done.

The structure dump omitted function ownership and ACLs. Four public-boundary owner-mismatch
tests reproduced missing fail-closed rejection: seed 20588, four runs, 100 assertions, four
failures. An exact expected-owner guard was then added to the six functions. A first rollback
probe selected the wrong migration execution connection and failed before DDL. The corrected
probe used Rails DatabaseTasks.with_temporary_connection and verified current_database explicitly.
All three new migrations then rolled back and reapplied successfully on empty local test audit
ledgers only. Only their new empty ledgers/functions/roles were removed and recreated; no existing
identifier or authoritative audit fact was deleted. Generated Source dumps were refreshed through
the normal schema dump tasks. Bare structure loading still requires explicit privilege provisioning;
the functions refuse an incorrect restored owner rather than inheriting schema-loader authority.

Focused lint for the dedicated task, service and four-case SQL boundary passed: three files,
zero offenses. Final expanded post-owner-guard test and lint results follow when observed.

Post-owner-guard six-file matrix passed: 45 runs, 620 assertions, zero failures/errors/skips,
seed 7683. The expanded eleven-file lint then identified three migration helper length offenses
and two sensitive-comparison cop suggestions. The helper's function-authority restriction was
extracted without changing DDL; the comparison retains boolean output to avoid exposing HMACs.

Expanded focused RuboCop passed after those corrections: eleven files, zero offenses. Whole-goal
OTP integration, full-suite lint/tests and architecture/security harnesses are still outstanding.

After selecting the caller role from the validated actual function owner instead of a guessed
worker database name, the HMAC six-file matrix plus Identity erasure file passed under normal
parallel execution: 53 runs, 664 assertions, 16 processes, zero failures/errors/skips, seed 22757.
Focused task/owner/SQL-boundary/HTTP test lint subsequently passed: six files, zero offenses.

Actual CLI rejection checks: `RAILS_ENV=test bin/rails identifier_hmac:rotate` exited 1 with
the explicit missing-domain ArgumentError. Executing COM/Telephone with an empty maintenance URL
also exited 1 before opening a connection, requiring explicit user/host/database. The task no longer
lets an empty PG connection string inherit implicit libpq defaults. Malformed URL parsing raises a
static error without retaining a secret-bearing parser exception as its cause. Neither rejection
ran rotation or changed persistent data; no environment-construction Minitest case was added.
