# Validate OIDC result parameters before one-shot consume

- Date: 2026-09-22 UTC
- Repository HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Branch: `feature`
- Worktree: already contained unrelated/in-scope modified and untracked files; no existing work
  was reset, staged, committed, or discarded.
- External writes: none. AWS, Cloudflare, provider, production, shared-database, email, and SMS
  services were not contacted or modified.

## Finding and change

The Base Auth result POST previously consumed the one-shot Auth result before revalidating the
stored OIDC authorization request. A valid result paired with an invalid persisted redirect URI
could therefore be consumed even though Base rejected the authorization request. The result
consumer now performs `validate_authorization_request!(transaction.authorize_params)` before the
atomic Valkey consume. No CSRF, origin, surface, purpose, or one-shot behavior was weakened.

## TDD evidence

A public integration regression was added to
`test/controllers/base/oauth_authorization_surfaces_test.rb`. It creates an authenticated result
whose stored redirect URI is not registered, posts it to the matching Base endpoint, asserts the
fixed invalid-request response and unchanged authenticated transaction, then consumes the opaque
result through the public store API to prove that the endpoint did not consume it.

The pre-change RED command was attempted with the repository test environment:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
export PARALLEL_WORKERS=1
bin/rails test test/controllers/base/oauth_authorization_surfaces_test.rb
```

Both the pre-change and post-change attempts stopped during Rails test-schema boot before any
assertion because `primary` was not resolvable:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

Therefore the behavioral test is authored but runtime-unverified in this shell. No localhost
fallback, mock datastore, skipped test, or application/configuration workaround was used.

## Static verification

- `bundle exec rubocop app/controllers/concerns/oidc_authorization_result_post.rb test/controllers/base/oauth_authorization_surfaces_test.rb`: passed.
- `ruby -c app/controllers/concerns/oidc_authorization_result_post.rb`: passed.
- `ruby -c test/controllers/base/oauth_authorization_surfaces_test.rb`: passed.
- `git diff --check`: passed.
- `bundle exec brakeman --no-pager --quiet`: passed; 0 errors and 0 security warnings.

## Scope and remaining risk

This closes one local fail-closed ordering boundary and reduces one partial-success case. It does
not solve the separate cross-store recovery/idempotency problem involving PostgreSQL transaction
state, Valkey result issuance/consumption, Browser Session creation, and authorization-code
issuance. That remains `CF-010` and still requires an approved protocol plus failure-injection
tests before the complete Base-only handoff can be accepted.
