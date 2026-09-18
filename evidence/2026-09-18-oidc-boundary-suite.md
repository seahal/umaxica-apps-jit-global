# OIDC boundary follow-up verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Starting commit for this follow-up: `1ccffc7a3`
- Existing worktree changes in `Gemfile.lock`, `README.md`, deleted `misc.md`/`refactor.md`, and
  browser-block notification files were preserved and were not included.

## Checks

- `bundle exec ruby -c test/services/oidc/token_exchange_service_test.rb` — passed.
- `bundle exec rubocop test/services/oidc/token_exchange_service_test.rb` — passed; one file, no
  offenses.
- The focused token-exchange case at line 1672 reached its Valkey write and no longer raised the
  previous missing-keyword `ArgumentError`; it stopped with `Umaxica::Valkey::Unavailable` because
  loopback Valkey is not available in this environment.
- The combined OIDC exchange/realm/refresh/controller command ran 147 tests / 234 assertions and
  ended with 8 failures / 86 errors / 0 skips. Most cases failed at the unavailable Valkey
  authorization-code/admission stores. This is an environment result, not a passing security result.
- `bundle exec scripts/test-environment-check` with explicit loopback Valkey variables stopped
  before the checks because PostgreSQL host `primary` could not be resolved. `pg_isready` on
  `127.0.0.1:5432` also reported no response.

## Change boundary

The test case now supplies the required client, redirect URI, PKCE challenge, and method when
planting a pre-revocation authorization code. Production token exchange, Valkey stores, realm
binding, and revocation behavior were not changed. The isolated PostgreSQL/Valkey boundary remains
open under `CF-002`; no non-test datastore or external provider was used.
