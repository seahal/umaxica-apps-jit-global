# Test database leftover isolation check

Date: 2026-10-25
Full git commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`
Worktree: many uncommitted changes from other work were present. This work changed only
`test/concurrency/sign_up_passkey_termination_http_test.rb` (setup ensures reference rows).

## Database state

During this work another agent ran `bin/rails db:migrate:reset` and then
`RAILS_ENV=test bin/rails db:drop db:create db:schema:load`. The test databases were therefore
structure-loaded and unseeded. In that state
`ClientStatus/ClientSecurityMode/ClientMfaStatus/ClientVisibility` counts were `[0, 0, 0, 0]`:
structure.sql carries schema and migration receipts but no reference rows, and a test with
`fixture_table_names = []` loads none. `RAILS_ENV=test bin/rails db:reset` and
`db:test:prepare` attempted by this work did not complete (pending-migration abort during seed;
`PG::DuplicateTable operators` in org_principals migration replay; concurrent create collisions).

## Checks performed (PARALLEL_WORKERS=1, base test databases)

- Per-file row-count snapshot of every public table in every test writer database before and after
  each of the 52 files containing `use_transactional_tests = false`: no
  `op_{app,com,org}_authority_stop*` row was left by any file.
- All 52 files in one command, run twice: 230 runs, 1963 / 1959 assertions, 2 failures, 7 errors
  each time; 0 `ForeignKeyViolation` in either log. Snapshot diff across both runs showed no
  authority-stop rows.
- Then `test/controllers/auth/app/up/emails_controller_test.rb` (fixture loading): 65 runs,
  570 assertions, 0 failures, 0 errors.
- `test/concurrency/sign_up_passkey_termination_http_test.rb` alone: before the change 5 errors
  in setup (`Client.create!` RecordInvalid); after, 5 runs, 139 assertions, 2 failures, 0 errors.

## Remaining failures (not caused by leftover rows)

- SignUpPasskeyTerminationHttpTest `at`/`after` cases fail `@actor.reload.lapsed?`: the expiry
  job runs inside `travel_to(expires_at + 1.second)` and sets `discard_at` to that time, while
  `lapsed?` is evaluated afterwards against the real clock.
- AppSecretParallelLoginTest (4) and AppSecretRootLoginConcurrencyTest (3): `GET /oauth/authorize`
  for `base-app-ww` answers 303 instead of rendering `form#base-authorization-ceremony-start-form`.
