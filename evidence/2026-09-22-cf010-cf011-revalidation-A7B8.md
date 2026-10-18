# CF-010 and CF-011 revalidation

Date: 2026-09-22

Repository: `seahal/umaxica-apps-jit-global`

HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

Worktree: dirty before and after verification. Existing changes were preserved. No provider,
AWS, Cloudflare, GitHub, or other external service was contacted.

## CF-010

The current implementation was reviewed against the accepted Base/Auth finalization model. The
three surface-local OIDC transaction tables persist result digest/generation/expiry and durable
finalization references. Raw result and authorization-code values are not persisted in the
transaction rows. PostgreSQL row locking protects authentication registration, Base finalization,
and authorization-grant redemption. Valkey result and authorization-code state remains transport
state; it is not used as the durable Browser Session or authorization-grant authority.

The focused verification command was:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/concerns/oidc_authorization_transactionable_test.rb test/services/base_auth_admission_coordinator_test.rb test/services/oidc_authorization_transaction_service_test.rb test/services/oidc/token_exchange_service_test.rb test/controllers/base/oauth_authorization_surfaces_test.rb test/security/opaque_result_transport_test.rb test/jobs/processor_erasure_notification_job_test.rb test/models/processor_erasure_notification_state_test.rb test/jobs/retention_purge_job_test.rb
```

Result: `161 runs, 711 assertions, 0 failures, 0 errors, 6 skips`.

The focused result confirms the current generation guard, result retry transport behavior,
idempotent Base finalization reference, durable one-winner grant claim, authorization-code
realm/session binding, replay behavior, and the existing retention/processor notification
boundary. It does not claim distributed ACID across PostgreSQL and Valkey, immediate invalidation
of already-issued access JWTs, or external RP/provider deployment readiness.

## CF-011

`ProcessorErasureNotificationJob` still has no concrete processor adapter, authenticated receipt
contract, approved retry-exhaustion policy, or approved permanent-failure status. Its success
allowlist remains empty. Unsupported processors are explicitly recorded as
`processor_unavailable` failure with retry metadata; they are not falsely marked `NOTIFIED`.

The current state and retry-window behavior are covered by the focused tests. No provider adapter,
receipt ledger, retry limit, or new permanent state was added because those semantics are not
defined by the repository or an approved contract. CF-011 therefore remains open and independent
of Retention and CF-010.

## Full Rails regression

The command was:

```text
bin/rails test
```

Result: `11536 runs, 73426 assertions, 0 failures, 0 errors, 8 skips`.

No code, test, configuration, database schema, or external service was changed to make the
environment pass. The test environment used the repository's Compose-backed PostgreSQL and Valkey
services through `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`.
