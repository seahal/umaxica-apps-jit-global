# Chronicle Audit Implementation Guidance

**Status:** Accepted (2026-05-20)

## Context

Chronicle records are the application's audit evidence model family. The accepted chronicle
consolidation decision places audit-style persistence under the `chronicle` database,
`ChronicleRecord`, and family-specific chronicle tables.

The implementation still needs a stable security reference model so future chronicle work does not
mix three different concerns:

- audit design intent and governance
- implementation review details
- operational retention, custody, and integrity handling

Using one framework for all three makes the guidance either too abstract for code review or too
implementation-heavy for governance. The chronicle model family should instead use each standard
where it is strongest.

## Decision

Chronicle audit implementation uses this reference split:

- ISO 27001 provides the audit design philosophy.
- OWASP provides the implementation checklist.
- NIST provides the operational, retention, and integrity guidance.

This ADR does not implement new schema, model, migration, digest-chain, or validation behavior. It
records the direction for chronicle model implementation and review.

## ISO 27001: Design Philosophy

Chronicle records exist to support accountability, traceability, incident investigation, and abuse
review. They are control evidence, not product analytics and not technical telemetry.

Chronicle design must preserve the existing application boundaries:

- Keep the `app`, `org`, and `com` surfaces separate.
- Do not mix controllers, routes, sessions, policies, or state across surfaces.
- Keep audit-style persistence in the `chronicle` database and `ChronicleRecord` family.
- Keep `occurrence` separate for counters, anomaly detection, and rate-limit style records.

Audit records should be written when the business outcome is known. The preferred write point is a
service or domain operation layer. Controllers may provide request context, but they should not
become the primary location where audit meaning is decided.

### User-Facing Activity Projection

An audit event's **Event Type**, **Risk Level**, and **Visibility Level** are independent
dimensions. Event type names what happened; risk ranks its security significance; visibility says
whether and how it should appear in an account owner's activity history. A low-risk event can be
user-visible, and a high-risk event can require attention. Neither risk nor visibility is inferred
from the other.

The legacy Client and Operator Chronicle catalogs have event and log-level references, but no
risk-level reference or user-visibility field. Their `level_id` is Chronicle logging severity, not
security risk. Until a persistent catalog is justified, the shared Base Identity presenter owns the
explicit event-ID to risk-and-visibility mapping. Risk uses a stable numeric rank; it is never sorted
alphabetically. User-facing reads filter `internal` event IDs in SQL and serialize a normalized
projection rather than exposing Chronicle IDs, raw context, provider metadata, or source IP
addresses.

Successful refresh rotation is a durable internal authentication audit event because it is useful
for investigation but too frequent for the user activity list. Refresh-token replay and failed
step-up verification are user-attention events. Audit context may include non-secret family
metadata, but never token values, OTPs, authorization codes, or PKCE verifiers.

## OWASP: Implementation Checklist

Chronicle implementations must be reviewed against a practical application-security checklist:

- Record security-sensitive, account-affecting, and operationally important business events.
- Do not record product analytics, ordinary page views, or low-risk feature usage as chronicle
  events.
- Use stable business-oriented event names or event catalog IDs that do not depend on UI copy,
  controller names, HTTP verbs, or route paths.
- Include enough context for investigation: actor, subject, event, occurred time, request
  correlation, IP address, and small structured metadata where needed.
- Do not store passwords, raw OTP values, raw tokens, authorization headers, cookies, full request
  parameters, message bodies, or other unnecessary sensitive payloads in chronicle context.
- Keep authentication, authorization, CSRF, verification, and rate-limit protections outside the
  audit write itself; chronicle records document outcomes and must not become a bypass path.
- Prefer explicit service or recorder APIs over model callbacks as the primary audit write point.

OpenTelemetry and chronicle records stay separate. OTEL describes technical execution. Chronicle
records describe meaningful business actions. They may be correlated by `request_id`, and by
`trace_id` only when that becomes operationally necessary.

## NIST: Operations, Retention, and Integrity

Chronicle operations must support evidence custody and later investigation:

- Treat chronicle writes as append-oriented operational evidence.
- Restrict write access and administrative access to the chronicle database.
- Preserve request correlation data needed to connect chronicle records with application logs and
  telemetry.
- Apply documented retention and purge rules through the existing retention model.
- Review chronicle access and export procedures as part of incident-response readiness.
- Avoid broad ad hoc data updates to chronicle records; correction should be handled by explicit
  follow-up events unless an approved migration or incident procedure requires otherwise.

Integrity is a chronicle-domain requirement, but this ADR limits the current decision to operational
handling. The existing chronicle consolidation decision's direction toward sequence and digest
support remains valid. Digest-chain fields, sequence assignment, validation behavior, and tamper
verification workflows belong in a later implementation plan.

## Consequences

- Future chronicle work has a clear review lens: ISO 27001 for purpose, OWASP for code-level safety,
  and NIST for evidence handling.
- Chronicle remains distinct from product analytics, ordinary telemetry, and occurrence counters.
- The first implementation step after this ADR should be a concrete chronicle recorder or model
  hardening plan, not scattered controller-level audit writes.
- No tests are required for this ADR-only change. Implementation work that changes chronicle write
  behavior must add focused Minitest coverage for success paths, failure paths, sensitive context
  exclusion, request correlation, and retention or integrity behavior where relevant.

## Related

- `adr/chronicle-audit-db-consolidation.md`
- `docs/architecture/database-boundaries.md`
- `plans/backlog/audit-log-write-points-and-otel-mapping.md`
