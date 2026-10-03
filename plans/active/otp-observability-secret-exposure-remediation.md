# OTP Observability Secret Exposure Remediation

Status: Open; mandatory resolution. Implementation is not complete.
Recorded: 2026-10-03.
Decision: [OTP observability remediation ADR](../../adr/otp-observability-secret-exposure-remediation.md).
Accountable role: repository maintainers; a remediation owner and security reviewer must be
identified before implementation and closure.

## Finding and escalation

An OTP-bearing email was observed in the existing APP mailer's `deliver.action_mailer` event
and DEBUG output using a synthetic OTP, test delivery adapter, in-memory logger, and
`Rails.event.with_debug`. The encoded MIME content can be decoded to recover the OTP.
See [retained evidence](../../evidence/2026-10-03-auth-boundary-foundation-7P4K.md).

Production exposure, the behavior of other mailers, and downstream exporter retention have not
been established. They require investigation; the synthetic reproduction is not evidence of a
production incident.

The finding was raised to the user, who requested escalation and a comprehensive, mandatory
resolution rather than proceeding with the isolated step-up logging proposal. This plan records
that handling decision. No external incident submission, production inspection, or runtime
logging change is claimed by this document.

## Required work

1. Inventory existing OTP producers and consumers by surface and purpose, including sign-in,
   sign-up, step-up, resend, and recovery where currently supported. Trace job arguments,
   Noticed params, mailer delivery events, Rails structured events, DEBUG/application logs,
   exception reporters, OpenTelemetry/exporters, audit records, and evidence capture. Include
   existing SMS OTP transports when they share these observability boundaries. Preserve the
   authentication method matrix; this work creates no additional ORG step-up Email OTP or TOTP.
2. Reproduce each applicable exposure using synthetic secrets. Distinguish encrypted job
   arguments from decrypted delivery content, reversible encodings, and recipient metadata.
   Identify the component owning each disclosure and the subscribers receiving it.
3. Select one coherent secret-protection design across the affected boundaries. Review any
   event or serialized format change under the existing data-shape approval rule before
   implementation. Prevent body and exception-content disclosure while preserving non-secret
   delivery outcomes and correlation. Keep Noticed, surface mailers, suspension interceptors,
   and authoritative audit storage responsibilities intact.
4. Implement and test success, suspension, delivery failure, retries, stale generations,
   cancellation, and expiry. Keep OTP delivery usable and authentication fail-closed. Confirm
   that enqueue success is not reported as delivery success.
5. Assess deployed log levels, subscribers, exporters, access and retention through authorized
   operational review. If historical exposure is confirmed, record its scope and obtain the
   required approval for incident response or destructive retention changes. Do not copy
   production secrets into diagnostics or evidence. Document unverified environments explicitly.
6. Record results in `evidence/`, update governing documentation, and have the remediation owner
   and security reviewer confirm closure against the criteria below.

## Completion criteria

- Synthetic OTPs, verification tokens, and other secrets carried by the affected messages are
  absent from captured job arguments in plaintext, delivery/event payloads, DEBUG and application
  output, exception reports, trace/exporter payloads, and audit/evidence records. Check raw values
  and recoverable encodings, including MIME Base64, rather than searching only for literal digits.
- These checks cover every identified existing surface/purpose path and the failure/retry states
  listed above. Secret absence is asserted at the emitted boundary, before downstream subscribers
  can receive it. Recipient information follows the applicable observability privacy policy.
- Intended recipients still receive the correct code through the existing transport. Suspension
  and failure remain distinguishable, and no logging workaround bypasses operational controls.
- Current affected deployment configuration and historical exposure have a recorded disposition.
  An unverified environment remains an explicit open item; it is not silently treated as safe.
- Evidence identifies the full commit hash, relevant uncommitted changes, executed checks,
  limitations, and the owner/reviewer closure decision. The authentication ledger's R15 gate
  remains open until the relevant secret-protection criteria are satisfied.

## Related work

- [Integrated authentication boundary plan](../backlog/integrated-auth-boundary-surface-consolidation-plan.md),
  especially its secret-protection and completion requirements.
- [Authentication implementation context](../../notes/implementation/2026-10-03-auth-boundary-step-up.md).

Disabling DEBUG, shortening retention, or encrypting queue arguments alone does not close this
plan. Recording and escalating the issue does not establish that it has been fixed.
