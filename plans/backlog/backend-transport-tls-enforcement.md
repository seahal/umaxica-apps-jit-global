# Backend Transport TLS Enforcement

Status: application-side fail-closed guards implemented on 2026-09-20. Provider values and live
handshakes remain deployment verification items.

## Context

The OWASP ASVS 5.0 review of 2026-09-19
(`evidence/2026-09-19-owasp-asvs-5-checklist-review-V5R8.md`, finding F3, ASVS 12.3 and 13.2) found
that encryption between the application and its backing services is decided entirely by deployment
values. The code does not refuse an unencrypted connection in production.

- PostgreSQL: `config/database.yml` reads `sslmode` from `NEON_PGSSLMODE` (primary) and
  `NEON_REPLICA_PGSSLMODE` (replicas). In production `ENV.fetch` requires the variable to exist, but
  any value is accepted, including `disable`, `allow`, and `prefer`, which permit a plaintext
  connection or a connection without server certificate verification.
- Valkey: `Umaxica::Valkey::ResponsibilityUrls` accepts both `redis://` and `rediss://`. The cache,
  rate-limit, and auth-state stores (`CACHE_REDIS_URL`, `RATE_LIMIT_REDIS_URL`,
  `AUTH_STATE_REDIS_URL`) can therefore run in plaintext. The auth-state store holds authorization
  codes and ceremony state, so its transport is security-relevant.

The current production values were not inspected; this plan does not claim that production is
unencrypted.

## Implemented application contract

Make the transport requirement explicit and fail at boot when it is not met, following
`no-silent-fallback`.

1. PostgreSQL: in production, accept only `verify-full` for `NEON_PGSSLMODE` and
   `NEON_REPLICA_PGSSLMODE`, and raise a configuration error naming the variable otherwise.
   `require` encrypts but does not verify the server certificate; accept it only if the provider
   cannot support `verify-full`, and record that exception in an ADR.
2. Valkey: in production, require the `rediss://` scheme for every responsibility URL, with server
   certificate verification left at the client default. Keep `redis://` for development and test.
3. Record the transport rule in an ADR and in `docs/operations/`, including which environment
   variables carry it.

## Remaining deployment verification

- Confirm the current production values of the four variables above, and that the managed
  PostgreSQL and Valkey providers support certificate verification.
- Decide whether local and staging environments share the production rule.

## Verification

Environment and configuration setup is not covered by Minitest. Boot the application with each
rejected value and with the accepted value, and record the observed result in `evidence/`.

## Current repository-side verification (2026-09-22)

The application-side fail-closed guards are present in the current checkout. The focused contract
set passed against the Compose-backed PostgreSQL/Valkey test environment:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/lib/umaxica/valkey/responsibility_urls_test.rb \
  test/lib/umaxica/valkey/settings_test.rb \
  test/config/test_environment_edge_contract_test.rb \
  test/unit/database_password_config_test.rb

28 runs, 174 assertions, 0 failures, 0 errors, 0 skips
```

The tests cover Valkey scheme rejection/production enforcement and the production PostgreSQL
`verify-full` configuration contract. No provider value, live TLS handshake, AWS, Cloudflare,
production, or shared service was contacted. The remaining production-value and live-handshake
checks therefore remain deployment verification, not an application-code blocker.

Evidence: `evidence/2026-09-22-backend-transport-tls-revalidation-N8P9.md`.
