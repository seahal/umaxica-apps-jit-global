# Org control plane convergence: final verification

Commit: `e423890e7357e1fa7975eac45aeacdb416b3bce9`, with uncommitted changes (this work plus the user's
unrelated pre-existing staged and unstaged changes, present during every run). Supersedes the
earlier `2026-09-26-org-control-plane-capabilities-K7Q2.md` for final results.

## Final results (last code state)

- `bundle exec rails test`: 11812 runs, 75485 assertions, 0 failures, 0 errors, 2 skips. Both skips
  are in files this work did not touch.
- `node node_modules/vitest/vitest.mjs run`: 87 files, 1054 tests passed.
- `bundle exec rubocop` on all 114 changed Ruby/rake files: 8 offenses remain, none in code written
  here: `roots_controller.rb:120` (present at HEAD), `preference_rotation_adoption_test.rb:30`
  (unchanged from HEAD), and lines in `sign_up_expiry_job_test.rb`, `authorization_code_store_test.rb`,
  and `enforcement_reconciliation_job_test.rb` (142, 181, 217) from the user's own changes.
- `tsc -p tsconfig.app.json --noEmit`: fails on one error, `src/pages/base/org/avatars/show.tsx(25,6)
  TS2375`. A clean `git archive HEAD` export produces the identical error, so it predates this work;
  the changed admin files have no type errors. oxlint on the new frontend files: clean.
- `bin/rails zeitwerk:check`: passes.

## Step-Up passkey 422

Root cause: the E2E test passed an explicit `Cookie` header (from `as_staff_headers`), which replaced
the integration cookie jar, so the auth host's session cookie holding the WebAuthn challenge was not
sent and `Webauthn::ChallengeStore#consume!` raised `ChallengeNotFoundError`, reported as
`verification_failed` with status 422. Located by tracing raised exceptions during the POST; the
assertion verifier was never reached. Fixed in the test fixture (the access token travels as the
bearer credential and the cookie jar carries each host's session, as a browser does). No application
code changed. `test/integration/org_admin_step_up_ceremony_test.rb` then passes end to end.

## Migration and structure dump

- Applied the full `org_principals` + `org_zenith` chain with `MigrationContext#migrate` on a freshly
  created, empty scratch database on the test server (104 tables), then `down` and `up` of
  `20260926120000`; CHECK, FK, index, and NOT NULL definitions read back from the database. Dumped
  with `ActiveRecord::Tasks::DatabaseTasks.dump_schema` and adopted as `db/org_zenith_structure.sql`.
  The scratch database was dropped.
- `bin/rails db:migrate` in this environment loads `structure.sql` into an empty database before
  running pending migrations, so it cannot prove the chain applies from zero; the scratch run does.
- The dump also adds four tables (`agent_lifecycles`, `bureau_lifecycles`,
  `agent_authority_cutovers`, `bureau_authority_cutovers`) whose migrations (`20260923170002`,
  `20260923180002`) are in HEAD but were never dumped at HEAD: pre-existing drift.
- `db:verify_no_schema_drift` was not run: it dumps every test database over the committed files.

## Concurrency

`test/concurrency/operator_capability_continuity_test.rb` passed three times in a row on separate
connections. With the `FOR UPDATE` lock removed (temporarily, then restored) it failed with
outcomes `[:revoked, :revoked]`, i.e. zero holders.

## Test database artifacts

An earlier verification script ran the org migrations through the default connection into
`test_primary_db`. The 102 resulting tables were dropped. Still present: functions
`check_staff_identity_emails_limit`, `check_staff_identity_passkeys_limit`,
`check_staff_identity_telephones_limit`, and extensions `citext`, `pgcrypto`. Evidence that they came
from that run: neither `db/structure.sql` nor `db/migrate` creates them, only `org_principals`
migrations do; `test_queue_db` and others show extensions are not supplied by the database template.
Removal was denied by the environment's permission check and was not retried. No development or
production database was touched.
