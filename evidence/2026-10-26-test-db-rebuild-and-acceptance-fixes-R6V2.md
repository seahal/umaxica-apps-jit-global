# Test database rebuild and acceptance fixes

Date: 2026-10-26  
Full git commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`  
Worktree: dirty before and throughout this task, with unrelated active-cycle changes. No files were
staged or committed. Development databases and `db/*structure.sql` were not changed.

## Test database rebuild and orphan search

The documented multi-database test preparation procedure was used:

```sh
RAILS_ENV=test bin/rails db:drop db:create
RAILS_ENV=test bin/rails runner 'ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: "test") do |pool|; next if pool.db_config.replica?; ActiveRecord::Tasks::DatabaseTasks.migrate(skip_initialize: true); end'
```

The pre-rebuild orphan queries returned no client or operator chronicle rows. No visitor chronicle
table pair exists in this schema. The rebuild recreated 32 writable `test_*` databases; the
migration runner exited 0 and the known HMAC definer-role error did not occur. The final query was:

```sh
# Local test database password supplied by the environment; omitted from this record.
PGHOST=primary PGUSER=root PGPASSWORD='<redacted>' psql -X --no-psqlrc -v ON_ERROR_STOP=1 -At -d test_chronicle_db -c "SELECT 'client', c.id, c.event_id FROM client_chronicles c WHERE NOT EXISTS (SELECT 1 FROM client_chronicle_events e WHERE e.id = c.event_id) UNION ALL SELECT 'operator', c.id, c.event_id FROM operator_chronicles c WHERE NOT EXISTS (SELECT 1 FROM operator_chronicle_events e WHERE e.id = c.event_id) ORDER BY 1, 2;"
```

It returned no rows. The schema catalog still has no visitor chronicle pair.

The candidate set in `/tmp/step2-candidates.txt` contains 170 files selected from
`use_transactional_tests = false` tests and tests mentioning Chronicle rows. Each file ran by itself
with `PARALLEL_WORKERS=1 bin/rails test <file>`, followed by the orphan query. This full pass was
repeated twice. No orphan appeared after any file and no individual file or narrow leaking set was
reproduced. Ten files per pass exited nonzero; their failures/errors are listed below for the second
pass. Each still produced no orphan rows. No test cleanup change was justified without a reproducing
leak.

Second-pass nonzero candidate results (each followed by an empty orphan query):

| Test file | Result |
|---|---|
| `test/controllers/auth/app/settings/totps_controller_test.rb` | 21 runs/62 assertions, 17 errors |
| `test/controllers/base/app/verification/setups_controller_test.rb` | 9/108, 1 failure |
| `test/controllers/concerns/sign/org_verification_base_included_do_test.rb` | 9/49, 1 failure |
| `test/integration/app_secret_parallel_login_test.rb` | 4/0, 4 errors |
| `test/integration/app_secret_receipt_collection_journey_test.rb` | 1/2, 1 failure |
| `test/integration/app_secret_root_login_concurrency_test.rb` | 3/0, 3 errors |
| `test/integration/apple_social_flows_test.rb` | 4/5, 3 errors |
| `test/integration/authentication_flow_test.rb` | 5/15, 1 failure |
| `test/integration/org_admin_step_up_ceremony_test.rb` | 9/61, 2 failures, 1 error |
| `test/jobs/client_secret_audit_delivery_job_test.rb` | 9/74, 1 error |

## Acceptance fixes

- **A06-4:** Red reproduction was 1 run/4 assertions: the Auth ceremony expired 1 µs before its
  Binding curfew. APP/COM/ORG attach and redemption now pass the exact stored `curfew_at` to Auth
  ceremony issuance and rotation. The test checks equality, active 1 µs before, expired at/after,
  and the transaction/login-challenge retention boundaries.
- **A12-3:** Red reproduction was 1 run/19 assertions: redeemed-entry repeats returned
  `[303, 303, 303]`. Same-browser repeats now require the original Binding issuance + 10 s window;
  after that, redemption follows the atomic replay refusal path. The test snapshots the Binding,
  admitted ceremony, session count, admission-store payload, and browser cookies.
- **A13-4:** Updated the stale definition to D-38: reject `cancellation_ref` and `switch_handoff`
  with 400 before transaction or Binding allocation. All six APP/COM/ORG combinations pass.
- **A29-4:** Updated acceptance to permit at most one state-free redirect before 503. The request
  test checks hop count, final status/cache header, and unchanged Binding, ceremony, Flow,
  registration-principal, and direct-hop cookie state.

## Verification results

Changed test files and supporting tests:

| Command / case | Result |
|---|---|
| `PARALLEL_WORKERS=1 bin/rails test test/integration/admission_curfew_test.rb` | 8 runs, 71 assertions, 0 failures/errors |
| `PARALLEL_WORKERS=1 bin/rails test test/integration/acceptance_wu12_relay_repeat_test.rb` | 4 runs, 49 assertions, 0 failures/errors |
| `PARALLEL_WORKERS=1 bin/rails test test/integration/acceptance_wu13_authorize_unrelated_params_test.rb` | 1 run, 1 assertion, 0 failures/errors |
| `PARALLEL_WORKERS=1 bin/rails test test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb` | 1 run, 69 assertions, 0 failures/errors |
| `PARALLEL_WORKERS=1 bin/rails test test/models/auth_ceremony_session_concurrency_test.rb` | 3 runs, 15 assertions, 0 failures/errors |
| `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/admission_redemption_input_boundary_test.rb` | 84 runs, 672 assertions, 0 failures/errors; existing in-window repeat contract retained |
| `bundle exec rubocop` on the 9 changed application/test Ruby files | 9 inspected, no offenses |
| `git diff --check` | Passed |

The 15 fixture-blocked line cases were re-run individually after rebuilding. Ten passed: A12-4 expired
attachment (1/5), A12-4 consumed relay (1/12), A12-6 (1/34), A27-3 OP (1/12), A27-3 RP (1/5),
A29-8 Welcome (1/4), A29-8 Step-Up (1/35), A29-9 Emergency (1/8), A29-9 invitation (1/6), and
A34-2 APP TOTP (1/1). The former fixture FK error did not recur.

The other five did not pass: A27-1b errored before assertions (`NoMethodError`, nil `session` at the
test line); A34-2 APP Passkey returned 422 instead of expected 401; APP Secret errored on a nil
response body; COM OTP returned 403 instead of expected 422; COM Passkey errored with
`ActiveRecord::StaleObjectError` for `Visitor`. These are recorded in `three.md` and `seven.md` and
were not changed as unrelated to the authorized defects. A29-8 Sign Out remains untested under the
task constraint. The full test suite was not run, as instructed.

The worktree is still dirty. No database-consistency finding, Sign Out/logout/authority-stop/BCL
code or test, `one.md`, `two.md`, or `nine.md` was modified for this task.
