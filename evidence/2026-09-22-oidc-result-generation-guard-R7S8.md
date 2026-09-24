# OIDC result generation guard

Date: 2026-09-22

Repository: `seahal/umaxica-apps-jit-global`

HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

Worktree: dirty; existing and current local changes were preserved. No external service, GitHub,
AWS, Cloudflare, provider, or production/shared datastore write was performed.

## Finding and change

The Base/Auth result transport already persisted a digest and generation in each surface-local
PostgreSQL authorization transaction and used Valkey as a retryable transport. The adversarial
review found a race between the initial result read and the finalization row lock: a newer result
generation could be issued after the read, while the old result still reached the finalization
block.

`OidcAuthorizationResultPost` now carries the Valkey payload generation into the surface-specific
Base authorization controller. `OidcAuthorizationTransactionable#finalize_base!` compares that
generation with the locked row before yielding to Browser Session finalization. A stale result is
rejected without running the finalization block; the PostgreSQL transaction remains unfinalized.
The session authority remains PostgreSQL and Valkey remains transport-only.

## Verification

Focused transaction, result-transport, admission, and Base authorization tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/services/oidc_authorization_transaction_service_test.rb \
  test/models/concerns/oidc_authorization_transactionable_test.rb \
  test/security/opaque_result_transport_test.rb \
  test/services/base_auth_admission_coordinator_test.rb \
  test/controllers/base/com/oauth/authorizations_controller_test.rb \
  test/controllers/base/org/oauth/authorizations_controller_test.rb \
  test/controllers/base/oauth_authorization_surfaces_test.rb
```

Result: `61 runs, 234 assertions, 0 failures, 0 errors, 6 skips`.

The new domain regression asserts that generation 1 cannot run finalization after generation 2 is
persisted, and that no Browser Session reference or finalization timestamp is written.

Additional checks:

- `bundle exec rubocop $(git diff --name-only --diff-filter=ACM -- '*.rb')`: 43 files, no offenses.
- `git diff --check`: passed after the implementation and final documentation amendment.
- `bin/rails test`: `11531 runs, 73397 assertions, 0 failures, 0 errors, 8 skips`.

The full suite used the explicit devcontainer environment file and the four prepared PostgreSQL
test databases. PostgreSQL and Valkey were reachable. No skip was added for this change.

## Remaining boundary

This closes the repository-side stale-result generation race. It does not claim distributed ACID
between PostgreSQL and Valkey, immediate invalidation of already-issued Access JWTs, external RP
registration/key deployment, production worker topology, or live external-network acceptance.
