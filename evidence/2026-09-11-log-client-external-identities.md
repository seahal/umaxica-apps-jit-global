# 2026-09-11 log client_external_identities

## What

`GET /identity` failed with `PG::FeatureNotSupported: cannot access temporary or unlogged relations during recovery` because `client_external_identities` was UNLOGGED and `AppPrincipalRecord` reads `app_zenith_replica` (hot standby).

## Commands

- `SAFETY_ASSURED=1 bin/rails db:migrate:app_zenith` — applied `20260911120000 LogClientExternalIdentities` (`ALTER TABLE client_external_identities SET LOGGED`, 0.0056s).
- `RAILS_ENV=test SAFETY_ASSURED=1 bin/rails db:migrate:app_zenith` — same migration on test.
- `bin/rails test test/tooling/replica_readable_unlogged_tables_test.rb` — 1 run, 5 assertions, 0 failures.
- Replica query after migrate: `relpersistence = p`, `SELECT COUNT(*) FROM client_external_identities` returned 2.

## Not verified

Authenticated browser request to `https://www.umaxica.app/identity?ri=jp` (needs a signed-in session on that host).
