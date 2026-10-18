# Identity-centric AAA Architecture

## Status

- **Architecture principle: Accepted (2026-10-17).** UMAXICA relates Authentication, Authorization,
  and Accounting (AAA) to Identity as a cross-cutting design principle. The first application of
  that principle is Identity Security Accounting.
- **Detailed design and implementation: not decided.** This ADR adds no code, schema, migration,
  configuration, test, event, route, or behavior change. The items under "Pending Decisions" stay
  undecided until a later accepted decision settles them.

This ADR supplements the related ADRs listed below. It supersedes no ADR and changes no accepted
decision in them.

## Context

Identity-related security behavior is already spread across accepted decisions:

- `adr/base-auth-ceremony-and-seven-rp-boundary.md` makes Base the sole physical IdP and
  Authorization Server and makes Auth a ceremony-only service. Later amendments and
  `adr/tech-and-palm-browser-rp-participation.md` define current RP membership, and
  `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` defines the current
  sign-out route.
- `adr/authentication-security-cycle-consolidation-2026-10-15.md` records the current Security Mode,
  step-up, and AAL decisions and partially supersedes earlier authentication ADRs.
- `adr/operator-capability-authorization.md` and `adr/unified-enforcement.md` define Operator
  authorization and enforcement, including their audit paths.
- `adr/chronicle-audit-db-consolidation.md`, `adr/chronicle-audit-implementation-guidance.md`, and
  `adr/chronicle-tamper-resistance.md` define Chronicle as the audit evidence domain.
- `adr/application-logging-boundary.md` separates application logs from authoritative records.

Each decision covers a part of authentication, authorization, or audit. No decision names the
principle that relates them. Without that principle, future work can confuse an audit record with an
authorization check, treat an authentication failure as an identified Identity, or add a new central
audit or authorization service when one is not needed.

In general AAA usage, Accounting also includes service usage and resource consumption. This ADR uses
a narrower scope: the records of security-relevant decisions, actions, and outcomes that relate to
Identity.

## Decision

1. UMAXICA adopts **Identity-centric AAA Architecture** as a repository-wide design principle:
   - **Authentication** confirms the requesting principal and establishes the authentication result
     and its evidence.
   - **Authorization** permits or denies an operation based on the principal, the target resource,
     the operation, the strength of authentication, and other context.
   - **Accounting** provides traceability and accountability for authentication and authorization
     decisions, security-relevant operations, and their outcomes.
2. AAA is a logical principle. It does not require one service, one class, or one database for all
   three responsibilities, and it creates no new authentication or authorization path.
3. The first scope is **Identity Security Accounting**. Candidate subjects are: sign-up, sign-in,
   and sign-out; authentication success and failure; step-up authentication; registration, change,
   and removal of authentication methods such as passkeys; Security Mode changes; session and token
   revocation; significant authorization decisions, especially denials; suspension, restoration, and
   withdrawal of an Identity; and significant Operator administrative operations. This list is a
   scope statement, not an event catalog.
4. Chronicle is reused as the audit evidence store for Identity Security Accounting. No separate
   audit platform is introduced by this decision.
5. Unauthenticated operations and authentication failures can be Accounting subjects. Such a record
   must not treat an unconfirmed principal as an authenticated Identity.

## Responsibility Boundaries

| Area           | Responsibility                                                 |
| -------------- | -------------------------------------------------------------- |
| Identity       | Identification and sameness of a principal                     |
| Authentication | Authentication and its evidence                                |
| Authorization  | Permission decisions                                           |
| Accounting     | Traceability of actions, decisions, and outcomes               |
| Chronicle      | Persistence of audit evidence                                  |
| Occurrence     | Frequency, counters, anomaly detection, and rate-limit records |
| OpenTelemetry  | Observation of technical execution                             |

The principle preserves the existing authority boundaries:

- Performing an authentication ceremony (Auth) is distinct from holding Identity, Session, and
  authorization authority (Base). Physical placement of code or tables does not imply logical
  authority (`docs/architecture/database-boundaries.md`).
- Each RP keeps ownership of its business operations and their authorization. RPs stay independent
  of each other.
- The APP, ORG, and COM surfaces stay separate trust boundaries.
- The existing independent sign-up and sign-in paths are unchanged.
- Global and Regional database ownership is unchanged. Each side keeps its own `chronicle` database,
  and cross-boundary audit information moves only through an explicit contract
  (`adr/global-regional-database-ownership.md`, section 7.1).
- Accounting is not a reason to create a central authorization authority.

## Accounting and Chronicle

Accounting and Chronicle are related but not the same:

- Accounting is the responsibility: deciding which decisions, actions, and outcomes must be
  traceable, and with what context.
- Chronicle is the persistence domain for that evidence. Its role, database, `ChronicleRecord`
  interface, and family-specific tables are unchanged (`adr/chronicle-audit-db-consolidation.md`).

Accounting does not replace Authorization. The ability to record an operation never permits it. This
repeats the existing Chronicle rule that authentication, authorization, CSRF, verification, and
rate-limit protections stay outside the audit write and that Chronicle must not become a bypass path
(`adr/chronicle-audit-implementation-guidance.md`).

Occurrence and OpenTelemetry stay separate. High-volume, attacker-driven events can belong in
`occurrence` rather than Chronicle, as `adr/unified-enforcement.md` already decides for enforcement
denials. OpenTelemetry describes technical execution and may be correlated with Chronicle by request
identifiers; it is not audit evidence.

## Security and Evidence Principles

### Decision and outcome are different facts

Authentication result, Authorization Decision, and Operation Outcome are recorded and reasoned about
as different facts. A permitted operation can still fail. A denial is a decision, not a failed
operation.

### Traceability

Audit evidence should be able to identify and relate, where relevant: Actor, Subject, Action,
Resource, Authorization Decision, Operation Outcome, Occurred At, request and session correlation,
and Surface, RP, and Region. Actor and Subject stay distinct. These are conceptual information
requirements, not database columns or API arguments.

### Integrity

The existing Chronicle direction applies: append-oriented evidence, restricted write and
administrative access, documented retention and purge, and corrections through follow-up events
(`adr/chronicle-audit-implementation-guidance.md`). Tamper resistance through database role
privileges is decided but not implemented (`adr/chronicle-tamper-resistance.md`).

For significant operations, an audit-write failure must not be silently discarded. This ADR does not
decide that every audit-database failure stops every business operation. Existing accepted
operation-specific rules remain in force and are not generalized here:

- Operator Support revocation and IAM changes write a Chronicle intent first and do not start the
  operation if the intent cannot be written (`adr/operator-capability-authorization.md`).
- Enforcement commits its decision first and writes Chronicle through a separate idempotent job
  (`adr/unified-enforcement.md`).
- An audit-write failure after a successful OTP email enqueue is logged diagnostically and does not
  become a caller-visible delivery failure (`adr/application-logging-boundary.md`).

### Data minimization

Passwords, OTPs, private keys, authorization codes, access tokens, refresh tokens, cookies, and
similar secrets are never stored in audit context. IP addresses, identifiers, and user agents are
stored only with a stated need, access control, and retention period. The account owner's activity
history and the internal audit trail have separate visibility, as the user-facing activity
projection in `adr/chronicle-audit-implementation-guidance.md` already requires.

### Write point

Audit evidence is recorded at the domain or service boundary where the meaning and outcome of the
operation are known. Model callbacks and scattered controller audit logic are not the primary write
point. Controllers may supply request context. This ADR does not choose a recorder API.

## Consequences

- Future Identity-related design states which AAA responsibility each part owns and keeps the
  existing Base, Auth, RP, and surface authority boundaries.
- Identity Security Accounting work extends Chronicle rather than introducing a new audit store.
- Reviews can reject changes that use an audit record as authorization, merge decision and outcome
  into one fact, store secrets in audit context, or record an unauthenticated principal as an
  Identity.
- No current behavior changes. Existing Chronicle writers, event catalogs, and failure behavior stay
  as they are until a later decision changes them.

## Pending Decisions

- The detailed Accounting Event Catalog.
- Which authorization decisions are recorded, and at what granularity.
- A common audit event schema.
- The recorder API.
- Consistency between persistence and the business transaction beyond the operation-specific rules
  cited above.
- Behavior on audit-write failure, including the general fail-open and fail-closed boundary, beyond
  the operation-specific rules cited above.
- Asynchronous delivery, outbox use, retry, and deduplication beyond the existing paths.
- Concrete retention periods and deletion policy beyond values already decided, such as the 365 day
  compliance retention in `adr/operator-capability-authorization.md`.
- The implementation of integrity verification beyond the decided database role privileges, such as
  a digest chain and its anchor.
- Application of this principle to business domains other than Identity.
- The boundary between Usage Accounting and Security Accounting.

## Related ADRs

- `adr/chronicle-audit-db-consolidation.md`
- `adr/chronicle-audit-implementation-guidance.md`
- `adr/chronicle-tamper-resistance.md`
- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/tech-and-palm-browser-rp-participation.md`
- `adr/first-party-sign-out-shared-database-without-backchannel-logout.md`
- `adr/authentication-security-cycle-consolidation-2026-10-15.md`
- `adr/operator-capability-authorization.md`
- `adr/unified-enforcement.md`
- `adr/global-regional-database-ownership.md`
- `adr/application-logging-boundary.md`
- `docs/architecture/database-boundaries.md`
- `plans/backlog/audit-log-write-points-and-otel-mapping.md`
