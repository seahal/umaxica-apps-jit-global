# CF-010 Cross-Store OIDC Finalization Verification

Date: 2026-09-22

Commit under test: `277673d13547d722fc88f830711eee69b923a7e8`

The worktree contained uncommitted changes before and during this verification. Existing unrelated changes were preserved; no commit, push, pull request, GitHub write, external deployment, or external service configuration change was performed.

## Verification environment

The Rails test environment used the repository's test environment file and the four ticket databases:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
```

The test database preflight reached PostgreSQL 17.7 and the configured Valkey services. No secret values were printed. The six CF-010 ticket migrations had been applied successfully to the app, com, and org ticket test databases before the final suite.

## Tests and checks

Focused CF-010 collection:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/ceremony_admission_boundary_test.rb test/controllers/base/oauth_authorization_surfaces_test.rb test/controllers/base/oauth_oidc_authority_test.rb test/integration/routes/neutral_rp_entry_contract_test.rb test/models/concerns/oidc_authorization_transactionable_test.rb test/services/authentication_purpose_contract_test.rb test/services/base_auth_admission_coordinator_test.rb test/services/oidc/token_exchange_service_test.rb test/services/oidc_authorization_transaction_service_test.rb test/services/valkey/auth_state/opaque_admission_store_test.rb
```

Result: 207 runs, 1103 assertions, 0 failures, 0 errors, 6 skips.

Full Ruby suite:

```text
bin/rails test
```

Result: 11529 runs, 73449 assertions, 0 failures, 0 errors, 8 skips.

The skips are existing test-suite skips; no test was deleted, weakened, newly skipped, or replaced with a mock to obtain this result. Coverage was not used as a completion gate for this task.

Static and diff checks:

```text
bundle exec rubocop [33 CF-010 implementation, migration, and test files]
```

Result: 33 files inspected, no offenses detected.

```text
git diff --check
```

Result: passed.

The three ticket structure dumps contain only the new transaction finalization columns, the non-negative generation checks, and the corresponding schema migration records for this change. An unrelated org-ticket foreign-key dump change was detected and restored before the final check.

## Verified design properties

- PostgreSQL transaction rows store only result digest, generation, expiry, consumption, finalization, and grant-redemption metadata; raw result/authentication-code values are not persisted.
- PostgreSQL records the result generation before Valkey transport issuance. A Valkey issue failure leaves the durable generation and digest binding available for a controlled retry.
- Result reads validate purpose, surface, transaction reference, digest, generation, and expiry before resuming the ceremony.
- Base finalization is row-lock serialized and idempotent. A retry reuses the persisted Browser Session reference and rotates credentials on that existing root session rather than creating another root session.
- Authorization-grant redemption is claimed atomically on the surface-local PostgreSQL transaction row in the same ticket-database transaction that creates or resolves the RP Session.
- Valkey authorization-code cleanup occurs after the durable database transaction and is not treated as a distributed ACID transaction.
- Existing CSRF, state, nonce, PKCE, redirect, audience, realm, session, and surface boundaries remain enforced by the existing request and token paths.

## Residual limits

- PostgreSQL and Valkey do not form a distributed ACID transaction. Post-commit Valkey cleanup is best effort; the durable PostgreSQL grant and session state remain the correctness authority.
- Already issued Access JWTs retain the existing natural-expiry window. This change does not introduce per-request RP Session introspection or immediate Access JWT revocation.
- Live external RP deployment, Cloudflare Tunnel, and third-party provider verification were not performed in this local test run.
