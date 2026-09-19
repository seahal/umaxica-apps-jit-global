# OIDC endpoint realm contract verification

- Date: 2026-09-17
- Branch: `feature`
- Source HEAD at verification start: `ba33dd493c3c195c413d6a9ae8fe215cdfbd5702`
- Working tree: pre-existing unrelated changes plus the current realm-contract slice

## Change under verification

`BaseOauthTokenEndpoint` already supplies the surface-owned `oauth_token_resource_type` to
`OidcTokenExchangeCoordinator`. The coordinator now requires that argument at construction and
rejects a missing or unknown realm before client authentication, authorization-code consumption, or
refresh rotation. Authorization-code and refresh tests provide the intended `client`, `visitor`, or
`operator` realm explicitly; the coordinator never infers it from a code payload or client name.

## Checks performed

- `ruby -c app/services/oidc_token_exchange_coordinator.rb` — passed.
- `ruby -c test/services/oidc/realm_binding_test.rb` — passed.
- `ruby -c test/services/oidc/token_exchange_service_test.rb` — passed.
- Targeted RuboCop over the coordinator and changed OIDC tests — passed with no offenses.
- A repository search of application callers found no coordinator call or constructor without an
  explicit `expected_resource_type` argument.
- `git diff --check` — passed.

## Blocked or unverified

- `bundle exec bin/rails test test/services/oidc/realm_binding_test.rb test/services/oidc/token_exchange_service_test.rb`
  could not reach assertions because the isolated PostgreSQL service at `127.0.0.1:5432` is
  unavailable (`PG::ConnectionBad`). No development, staging, or production database was used.
- The new migrations and the full token exchange, refresh, and concurrency behavior remain
  unverified until isolated PostgreSQL and Valkey services are provisioned. No migration was run.
- External RP registration and redirect configuration remain outside this repository and were not
  changed.
