# OIDC connection revocation hardening evidence

- Date: 2026-09-17 UTC
- Branch: `feature`
- Parent commit: `e7d0cc08e`
- Working tree: pre-existing `README.md` modification and `misc.md`/`refactor.md` deletions were
  preserved and were not staged.

## Implemented check

`OidcConnectionRecorder` now requires the authorization-code `issued_at`. A revoked connection is
only cleared when the new authorization code was issued after `revoked_at`. The exchange path
rejects an older code before Valkey consumption, and the recorder locks the connection row and
repeats the comparison to cover a concurrent revoke.

## Verification

- `ruby -c app/operations/oidc_connection_recorder.rb`: passed.
- `ruby -c app/services/oidc_token_exchange_coordinator.rb`: passed.
- `ruby -c test/services/oidc/token_exchange_service_test.rb`: passed.
- `bundle exec rubocop --force-exclusion app/operations/oidc_connection_recorder.rb app/services/oidc_token_exchange_coordinator.rb test/services/oidc/token_exchange_service_test.rb`:
  passed; 3 files, no offenses.
- `git diff --check`: passed.
- The affected integration test command was attempted with isolated test Valkey variables:
  `bundle exec bin/rails test test/services/oidc/token_exchange_service_test.rb`. It was blocked
  before assertions because PostgreSQL host `primary` could not be resolved.

## Not verified

The PostgreSQL lock/transaction race, Valkey code state, and the new stale-code regression test
remain unverified until isolated test services are available. No production or shared datastore was
used.
