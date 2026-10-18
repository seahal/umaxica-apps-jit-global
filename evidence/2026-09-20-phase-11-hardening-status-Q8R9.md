# Phase 11 hardening status

Date: 2026-09-20
Repository HEAD: `52efa31df2a28763ad405f604bb3ef0c416b3b93`
Branch: `feature`

This record covers the repository-side verification performed after the Phase 00 baseline and
the request-size-limit slice. It does not claim live provider, deployment, or external queue
verification.

## Focused verification

With `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/services/oidc/token_exchange_service_test.rb \
  test/services/oidc/realm_binding_test.rb \
  test/services/oidc_token_revoker_surface_lookup_test.rb \
  test/services/oidc_token_revocation_service_coverage_test.rb \
  test/lib/outbound_http/connection_test.rb \
  test/services/oidc/rp_token_client_test.rb \
  test/unit/database_password_config_test.rb \
  test/lib/umaxica/valkey/settings_test.rb \
  test/jobs/sign_up_expiry_job_test.rb \
  test/services/sign_up/state_machine_test.rb \
  test/services/sign_up_termination_idempotence_test.rb \
  test/models/enforcement_appeal_test.rb \
  test/jobs/enforcement_reconciliation_job_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/services/authentication_security_event_emitter_test.rb \
  test/services/jwt_anomaly_subscriber_coverage_test.rb
```

Result: 192 runs, 828 assertions, 0 failures, 0 errors, 0 skips.

After formatting-only corrections to the neutral RP route and ceremony tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/integration/routes/neutral_rp_entry_contract_test.rb \
  test/controllers/auth/app/sign_in_admission_test.rb \
  test/controllers/auth/ceremony_admission_boundary_test.rb \
  test/controllers/auth/oidc_entrances_test.rb \
  test/integration/sign/app/layout_test.rb \
  test/middleware/request_body_size_limit_test.rb \
  test/integration/core_browser_api_boundary_test.rb
```

Result: 53 runs, 388 assertions, 0 failures, 0 errors, 0 skips.

## Broad verification

```text
bin/rails test
```

Result: 11,427 runs, 73,082 assertions, 0 failures, 0 errors, 5 skips; exit code 0.
The skips remain skips. Expected OmniAuth test-path errors/deprecation output and repeated
`LocalEnvironment::KEY` initialization warnings were observed without test failures.

```text
bun run test
```

Result: 85 test files, 1,065 tests passed.

```text
bun run check
```

Result: formatting, lint, TypeScript, dead-code, and OpenAPI checks passed. Knip reported four
configuration hints; it did not fail the command.

```text
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

Result: 0 errors and 0 security warnings.

```text
bin/bundler-audit
bun audit
```

Result: no Ruby or JavaScript dependency vulnerabilities reported.

```text
bun run test:coverage
```

Result: 85 test files and 1,065 tests passed; statements 99.95%, branches 99.56%, functions
99.86%, and lines 99.95%.

```text
COVERAGE=true bin/rails test test/
```

Result: 11,427 runs, 73,095 assertions, 0 failures, 0 errors, 5 skips. SimpleCov then failed
its existing gate with line coverage 95.96% against 98%, branch coverage 75.05% against 90%, and
method coverage 90.96% against 95% (exit code 2). The worktree already contained a change raising
the line threshold in `.simplecov` from 97% to 98% before this verification; no threshold,
exclusion, or skip was changed to obtain a result.

This is recorded as a coverage-gate failure, not as a test failure and not as evidence that the
new security behavior is untested. A clean baseline coverage run on the pre-existing checkout was
not available, so attribution of the aggregate shortfall to any one slice is unverified.

The repository-wide RuboCop gate still reports three pre-existing offenses in
`lib/umaxica/valkey/responsibility_urls.rb` and `lib/umaxica/valkey/settings.rb`. The files
changed in the current hardening and neutral RP-entry slices pass targeted RuboCop, and
`git diff --check` passes.

## Requirement disposition

- **FREQ-0059:** Repository behavior is covered by the OIDC realm-binding, token-exchange,
  unlink-fresh-code, and surface-local revoke tests above. No root-session revoke fallback or
  wrong-realm code consumption was observed in this verification.
- **FREQ-0060:** Implemented and verified. JSON bodies are bounded before Rails parameter parsing;
  malformed length, chunked oversize, unsupported compression, and exact-size boundaries are
  covered. See `evidence/2026-09-20-request-size-limit-N4P5.md`.
- **FREQ-0061:** Application-side production guards are implemented and verified. PostgreSQL
  requires `verify-full` and production Valkey requires `rediss://`; local development/test
  behavior remains explicit. Provider values, CA material, and live TLS handshakes remain
  unverified. See `evidence/2026-09-20-backend-transport-tls-enforcement-T9U0.md`.
- **FREQ-0062:** Repository-level request-time expiry, bounded Active Job cleanup, idempotent
  terminalization, and non-expired/terminal preservation are covered by the focused tests. Live
  Solid Queue scheduler/worker operation was not exercised here.
- **FREQ-0063:** Repository-level appeal decision persistence, partial side-effect failure, case
  end convergence, and legal-hold/retention interaction are covered by the focused and full
  suites. Cross-database atomicity is not claimed; the existing reconciliation boundary remains
  the recovery mechanism.
- **FREQ-0064:** **PARTIAL / residual follow-up.** JWT anomaly persistence, bounded hold-aware purge,
  and existing enforcement/retention occurrence records were rechecked. `AuthenticationSecurityEventEmitter`
  now writes a sanitized Chronicle row using the existing `security` retention policy and keeps the
  redacted application log as a secondary diagnostic record. No schema, legal duration, provider
  receipt ledger, or external configuration was added. Provider acceptance/delivery/retry facts and
  wiring of taxonomy events that currently have no real caller remain unverified or require a
  separately approved provider contract.

## External and operational limits

No production database, provider, Cloudflare, live email/SMS delivery, Solid Queue deployment, or
GitHub write was used. No secrets or connection values were recorded. The working tree was
preserved; no reset, clean, commit, or history rewrite was performed.
