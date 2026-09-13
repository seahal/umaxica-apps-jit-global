# Apple Lifecycle Foundation Implementation Notes

## Context

- Original plan: `plans/apple-google-external-authentication-architecture-audit.md`, Phase 6.
- Related decisions: the Apple token-minimization and second-key decisions recorded in the audit.
- Implementation date: 2026-07-24.

## Decisions Made During Implementation

- Decision: isolate Apple client-secret JWT generation in an Apple-only adapter and port.
  - Why: the revoke operation needs a client secret without persisting the JWT or exposing the
    private key to application use cases.
  - Alternatives considered: reuse the OmniAuth strategy's private method. Rejected because that
    couples lifecycle operations to Rack strategy state and makes the credential boundary implicit.
  - Follow-up needed: wire the adapter to the approved secret source only when the revocation
    adapter is introduced; do not add automatic key selection or failover.
- Decision: isolate Apple refresh-token revocation behind an Apple-only adapter and typed result.
  - Why: Apple treats HTTP 200 as either successful revocation or an already-invalid token. The
    application needs an idempotent success classification without retaining response bodies.
  - Alternatives considered: let unlink controllers call HTTP directly. Rejected because local
    account changes must not depend on synchronous provider availability.
  - Follow-up needed: complete controlled Apple production verification before the endpoint is
    registered in production.
- Decision: use `ClientAppleCredentialRevocation` as the durable, encrypted boundary for both unlink
  and withdrawal.
  - Why: local identity removal must not depend on Apple availability, but a remote revocation
    attempt must survive the request that started it. The record is committed before its job is
    enqueued, and the job erases the token after success, already-invalid success, or bounded
    failure.
  - Alternatives considered: invoke Apple synchronously from unlink or erase the credential during
    withdrawal without a durable request. Rejected because both alternatives either block local
    security action on provider availability or silently lose the outstanding provider action.
  - Follow-up needed: confirm the operational alert destination and production retry monitoring.
- Decision: represent a missing legacy refresh token as an immediately terminal
  `credential_unavailable` revocation record.
  - Why: not all existing Apple identities can prove a durable refresh credential is available. The
    local unlink or withdrawal still succeeds, but the missing remote action remains visible as
    non-PII operational metadata rather than becoming an unrecorded fallback.
  - Alternatives considered: reject local unlink/withdrawal or silently skip remote revocation.
    Rejected because the approved policy keeps local security action available during provider or
    legacy-credential failure and requires an audit outcome.
- Decision: verify Apple server-to-server notification JWS payloads at the infrastructure boundary,
  then persist only a minimal, idempotent inbox event.
  - Why: the raw JWS and its claims are not needed after verification, while the verified `jti`,
    event type, timestamps, and processing state are necessary for retry and duplicate handling.
  - Alternatives considered: persist the raw JWS for diagnosis or process webhook requests inline.
    Rejected because raw assertions expand the secret/PII retention boundary and inline work makes
    Apple acknowledgement depend on application-side lifecycle processing.
  - Follow-up needed: configure the Apple notification URL and perform a controlled production
    delivery test before enabling enforcement.
- Decision: notification event references nullify when a client or identity is removed.
  - Why: a minimal notification audit record must not block unlink, retention, or withdrawal.
  - Alternatives considered: cascade-delete events or keep restrictive foreign keys. Rejected
    because the first loses lifecycle evidence and the second blocks an authorized local action.

## Deviations From Plan

- Change: no subject-encryption migration was started in this increment.
  - Why: the legacy Apple subject is protected by a unique lookup index. Encrypting it safely needs
    a capacity, backfill, uniqueness, and rollback design that must remain compatible with the
    one-way Phase 8 identity migration.
  - Risk: the existing legacy subject remains plaintext until its separately verified migration.
  - Follow-up: establish the explicit encrypted-subject migration plan before changing the legacy
    `uid` column.
- Change: do not reuse the existing `ClientIdentity` table for Phase 8 social bindings.
  - Why: it is an app-RP/persona identity table with a unique `source_record_id`, a different
    database boundary, and a one-to-one source-record contract. It cannot represent the approved
    Apple-plus-Google identity bindings for one client without changing unrelated identity graph
    semantics.
  - Risk: the Phase 8 migration still needs a new additive social identity binding schema and a
    production dry run. Treat the similarly named table as a deliberate non-reuse decision.
- Change: centralize social identity repository selection behind
  `ExternalAuthentication::IdentityRepositoryFactory::CURRENT_STORAGE`.
  - Why: the cutover from legacy tables to `ClientExternalIdentity` must happen in one verified
    deployment, not through long-lived dual writes or per-caller flags. The value remains `:legacy`
    until the one-way copy and `LegacyIdentityCopy.verify!` succeed in the controlled production
    migration window.
  - Risk: changing the value to `:common` before the production preflight/copy/verification would
    make existing identities unavailable. The switch is an operational cutover step, not a feature
    experiment.
  - Follow-up: after seven days of post-cutover observation and an approved destructive migration,
    remove the legacy repository adapter, tables, columns, and the `:legacy` factory mode.

## Implementation Update

- Implemented: Apple notification ingress (`POST /apple/notifications`) has a bounded JSON body, IP
  rate limit, strict JWS verification, no browser session dependency, and no raw payload
  persistence.
- Implemented: verified notification events are processed asynchronously with bounded exponential
  retries (ten attempts or 24 hours), a dead-letter state, and a non-sensitive error report.
- Implemented: consent revocation disables the Apple credential and invalidates App sessions;
  account deletion is terminal and cannot be regressed by an older event.
- Implemented: Phase 8 additive `ClientExternalIdentity` and Apple-credential tables, deterministic
  encryption for provider subject lookup, and non-deterministic encryption for refresh tokens.
- Implemented: Apple-only clients see a non-dismissible App identity-settings warning with direct
  Passkey and Google-link paths; the same skippable guidance appears on the App welcome page after
  signup while Apple remains the only AAL1 credential.
- Implemented: a guarded `external_authentication:identity_migration` task separates read-only
  preflight and verification from the one-way copy, which requires an exact operator confirmation
  value.
- Deferred: production data preflight, one-way copy, verification, repository cutover, seven-day
  observation, and legacy-table removal remain controlled operational steps. `CURRENT_STORAGE`
  deliberately remains `:legacy`.

## Review Notes

- Tests run: client-secret provider, credential-revocation adapter, durable revocation request/job,
  unlink, withdrawal anonymization, notification verifier/ingress/processor/job/controller,
  common-identity adapter/copy, and Google online-only strategy contract tests. The focused suite
  passes in both one worker and four parallel workers.
- Tests not run: remote Apple revoke and controlled Apple production E2E. Human Apple-console
  actions and production cutover remain incomplete.
- Documentation promotion needed: none; the permanent lifecycle policy remains in the audit plan.
