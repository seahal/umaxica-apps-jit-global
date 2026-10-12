# OTP Observability Secret Exposure Remediation

Accepted: 2026-10-03

## Context

During authentication-boundary implementation, a synthetic OTP was recovered from the existing APP
mailer's `deliver.action_mailer` notification payload and DEBUG output. The diagnostic used the test
delivery adapter, an in-memory logger, and `Rails.event.with_debug`. MIME Base64 encoding preserves
recoverable message content; it does not protect secrets. Production logs and deployed configuration
have not been inspected, so production exposure is unconfirmed.

The finding and its verification limits are recorded in
[the implementation evidence](../evidence/2026-10-03-auth-boundary-foundation-7P4K.md). Encrypting
OTPs before serialization into job arguments protects the queue boundary, but does not protect the
decrypted message at delivery, logging, event, exception, or telemetry boundaries.

## Decision

The issue was reported to the user during implementation review. The user directed that it be
escalated and tracked as a mandatory problem requiring a comprehensive resolution, with a durable
ADR and implementation plan. This records that instruction; it does not assert that an external
incident report or ticket has been submitted.

Track the unresolved work in
[the active remediation plan](../specs/otp-observability-secret-exposure-remediation/plan.md). Defer
the previously proposed isolated step-up delivery-event replacement to that workstream. The deferral
is not acceptance of secret exposure, a completed fix, or approval of a particular event schema. The
issue must be resolved before the authentication ledger's R15 secret-protection gate or the affected
OTP observability remediation can be declared complete.

The resolution must protect existing OTP paths across their applicable surfaces, including job
serialization, delivery events, application and DEBUG logs, exception reporting, trace exporters,
and audit/evidence capture. It must preserve actual message delivery, surface ownership, Noticed
orchestration, delivery suspension controls, and the distinction between enqueue and delivery
outcomes. No new authentication method is authorized by this decision.

Existing decisions remain governing:

- [Application logging boundary](application-logging-boundary.md).
- [Notification orchestration via Noticed](notification-orchestration-via-noticed.md).
- [Observability boundary](../docs/security/observability-boundary.md).

## Local P1 implementation amendment

The first local implementation slice applies the primary controls without changing mail
delivery, Noticed orchestration, suspension behavior, Sentry, or production infrastructure.
`config.filter_parameters` keeps broad matching for meaningful secret names, while short
ambiguous names use explicit Rails `ParameterFilter` regular expressions. `code_verifier` remains
an explicit sensitive key so narrowing the exact `code` match cannot weaken PKCE protection.

`config.action_mailer.logger = nil` is the common Rails configuration. The installed Rails Railtie
was inspected and the resulting `ActionMailer::Base.logger` is nil after boot; the test delivery
adapter and existing surface mailers remain available. The Rails process does not replace
ActionMailer internals or rewrite MIME.

The installed `opentelemetry-instrumentation-action_mailer` version is 0.8.1. Its formal
`notification_payload_transform`, `process_payload_transform`, and `email_address: :omit` options
are configured allowlist-first: delivery spans retain only `email.x_mailer`, and process spans
retain only `mailer` and `action`. Subject, addresses, arguments, body, MIME and future unknown
keys are excluded before export. `ObservabilityRedactor` and `ObservabilitySpanScrubber` remain
secondary controls. The in-process span scrubber also treats every `email.*` attribute except the
explicitly allowed `email.x_mailer`, and every `args` attribute, as sensitive if an instrumentation
regression bypasses the ActionMailer transform.

The development Alloy configuration adds a secondary deletion rule for ActionMailer subject,
address, body/MIME, arguments, OTP and token-shaped attributes. The existing read-only Compose
mount declarations remain the host-managed configuration boundary. This container has no Alloy or
Podman binary, so effective remount/write-denial and processor-runtime checks remain unrun. The
production topology, retention and access policy remain unbuilt and require a separate deployment
acceptance review.

This amendment records a local implementation slice; it does not close this ADR or the active
remediation plan. Current evidence is recorded in
`evidence/2026-10-10-p1-observability-gate3-N6T2.md`.

## Consequences

Turning off DEBUG alone and encrypting job arguments alone are insufficient completion evidence:
secret-bearing events may reach other subscribers, and messages are decrypted for delivery.
Remediation must prevent secret content from entering observability channels at their owning
boundaries and retain useful non-secret outcome and correlation data.

The active plan owns verification, production-exposure assessment, and closure evidence. It must
remain open until those conditions are met; documentation of this finding does not resolve it.
