# WU-A3 focused state tests after local test database rebuild

Date: 2026-11-01

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree contained existing uncommitted changes; no staged changes or commit were made. A
previous focused run had fixture setup errors in the local test database: `client_accounts` had 43
rows while `clients` had 73, with no orphan references in a read-only check. The fixture loader's
foreign-key error occurred while reloading clients. The local test database was disposable under the
owner's prior authorization to rebuild local databases.

## Environment action

Only `test_app_zenith_db` was rebuilt, using:

- `RAILS_ENV=test bin/rails db:drop:app_zenith`
- `RAILS_ENV=test bin/rails db:create:app_zenith`
- `RAILS_ENV=test bin/rails db:migrate:app_zenith`

All three commands succeeded. No development, OP Base, production or Neon database was reset.

## Verification

- Auth Ceremony, Admission Binding, OIDC cancellation, App/Org Cancel, purger, and AC-53 focused
  tests across 10 files: 85 runs, 1,250 assertions, 0 failures, 0 errors, 0 skips.
- Step-Up and OIDC authorization transaction parent purger tests: 10 runs, 45 assertions, 0
  failures, 0 errors, 0 skips.
- No application or test code was edited while either test run was active. No migration for the
  WU-A3 state shapes was applied or rerun in this check.

## Remaining scope

This verifies the selected state, Cancel, retention and AC-53 paths only. The full suite, the
complete WU-A3 acceptance matrix and the broader `two.md` acceptance remain open.
