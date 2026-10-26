# WU-10 standard refresh — local verification

- Date: 2026-10-25
- Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`
- Worktree: about 268 uncommitted files of other in-progress work were present; the results below
  were produced against that worktree plus the WU-10 changes (uncommitted).

## Change verified

- D-25: `OidcRefreshTokenIssuer` has one rotation path (writer role, grant lock, response built
  inside the lock). Receipt replay, Valkey coalescing (`OidcRpRefreshCoordinationAdapter`),
  `OidcRefreshDeliveryReceipt`, `OidcRefreshDeliveryQuery`, the Visa `refresh_delivery_queries`
  controllers/route and `OidcOpTokenClient.query_delivery` were removed.
- `RpRefreshCommitter` dispatches once and installs with an `installed_generation` CAS; the
  `rp_*_refresh_attempt` models were removed.
- D-80/D-110: a refused or indeterminate refresh on a top-level HTML navigation starts one
  `prompt=none` authorization; JSON answers 401.
- Visa `edge/v0/token/*` routes were moved inside the per-surface scope, so they resolve to
  `Visa::{App,Com,Org}::Edge::V0::Token::*` and `visa_<surface>_edge_v0_token_refresh_url`.
  Before the move they resolved to the missing `Visa::Edge::V0::Token::RefreshesController`.

## Migrations

- `db/rp_<cell>_migrate/20261025100000_drop_rp_refresh_attempts_rp_<cell>.rb` (12 cells).
- `db/op_base_{app,com,org}_migrate/20261025100100_remove_refresh_delivery_receipt_op_base_*.rb`
  (drops `refresh_delivery_*` columns and their all-or-none check).
- `bin/rails db:migrate` (development) and `RAILS_ENV=test bin/rails db:migrate` succeeded.
  `bin/rails db:rollback:rp_base_app`, `bin/rails db:rollback:op_base_app`, then `db:migrate`
  succeeded (down and up both exercised).
- `bin/rails db:schema:dump` refreshed the structure files. It also rewrote
  `app_zenith`, `avatar`, `chronicle`, `com_zenith`, `org_zenith` and `publishing` structure files
  with pg_dump CHECK-constraint formatting differences unrelated to WU-10; these were not reverted.
- `bin/rails db:verify_no_schema_drift` failed before comparing:
  `ArgumentError: HMAC definer role does not match database development_com_zenith_db`
  (com_zenith, outside WU-10). Drift was therefore not verified by that task.

## Tests

- `bin/rails test` on 31 files (refresh, RP committer, token client, token exchange, browser RP,
  Tech revocation, Core browser API, invalid-cookie recovery, callback, no-store, CSRF route,
  runtime-role, RP schema contract, model/table consistency):
  `411 runs, 2291 assertions, 0 failures, 0 errors, 0 skips`.
- New tests: `test/integration/rp_refresh_recovery_test.rb` (6 runs, 21 assertions, pass), three
  D-25 cases in `test/services/oidc/token_exchange_service_test.rb`, one `login_required` case in
  `test/controllers/concerns/oidc/callback_test.rb`. They were written alongside the change, so no
  separate Red run was recorded; the D-25 reuse/unknown cases describe behavior that already held.
- `test/controllers/base/oauth_oidc_authority_test.rb` with the two refresh-route tests:
  75 runs, 10 failures. All 10 are `/oauth/authorize` cases answered with a 303 to the Sentry
  admission (Design D change), not refresh behavior; the 15 edge refresh failures (404) are gone.

## Known limits

- Reuse detection covers the immediate predecessor (`previous_refresh_token_digest`). An older
  consumed verifier of the same grant is answered `invalid_grant` without revoking the family.
- Concurrent refreshes with one credential (two tabs) now revoke the family by design (no grace).
- Back-Channel Logout on refresh-reuse revocation (D-26) is not sent; it belongs to WU-15/WU-16.
