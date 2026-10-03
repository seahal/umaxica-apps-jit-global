# OTP Observability Secret Exposure Remediation

Accepted: 2026-10-03

## Context

During authentication-boundary implementation, a synthetic OTP was recovered from the existing
APP mailer's `deliver.action_mailer` notification payload and DEBUG output. The diagnostic used
the test delivery adapter, an in-memory logger, and `Rails.event.with_debug`. MIME Base64 encoding
preserves recoverable message content; it does not protect secrets. Production logs and deployed
configuration have not been inspected, so production exposure is unconfirmed.

The finding and its verification limits are recorded in
[the implementation evidence](../evidence/2026-10-03-auth-boundary-foundation-7P4K.md).
Encrypting OTPs before serialization into job arguments protects the queue boundary, but does
not protect the decrypted message at delivery, logging, event, exception, or telemetry boundaries.

## Decision

The issue was reported to the user during implementation review. The user directed that it be
escalated and tracked as a mandatory problem requiring a comprehensive resolution, with a durable
ADR and implementation plan. This records that instruction; it does not assert that an external
incident report or ticket has been submitted.

Track the unresolved work in
[the active remediation plan](../plans/active/otp-observability-secret-exposure-remediation.md).
Defer the previously proposed isolated step-up delivery-event replacement to that workstream.
The deferral is not acceptance of secret exposure, a completed fix, or approval of a particular
event schema. The issue must be resolved before the authentication ledger's R15 secret-protection
gate or the affected OTP observability remediation can be declared complete.

The resolution must protect existing OTP paths across their applicable surfaces, including job
serialization, delivery events, application and DEBUG logs, exception reporting, trace exporters,
and audit/evidence capture. It must preserve actual message delivery, surface ownership, Noticed
orchestration, delivery suspension controls, and the distinction between enqueue and delivery
outcomes. No new authentication method is authorized by this decision.

Existing decisions remain governing:

- [Application logging boundary](application-logging-boundary.md).
- [Notification orchestration via Noticed](notification-orchestration-via-noticed.md).
- [Observability boundary](../docs/security/observability-boundary.md).

## Consequences

Turning off DEBUG alone and encrypting job arguments alone are insufficient completion evidence:
secret-bearing events may reach other subscribers, and messages are decrypted for delivery.
Remediation must prevent secret content from entering observability channels at their owning
boundaries and retain useful non-secret outcome and correlation data.

The active plan owns verification, production-exposure assessment, and closure evidence. It must
remain open until those conditions are met; documentation of this finding does not resolve it.
