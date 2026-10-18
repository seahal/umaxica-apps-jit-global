# Authentication and identifier verification planning follow-up

Status: backlog. Target: two delivery cycles after the current nine acceptance cycle. Recorded
2026-10-13 at the user's explicit request; this is a relative cycle target, not a date.

The user identified insufficient planning of the remaining verification scope and accepted these
gaps for the current delivery. Treat this as planning debt and deferred investigation, not evidence
that an IDOR exists or that every identifier contract passes. This supersedes their prior status as
current acceptance blockers. The already corrected setting-Preference ID defect is not reopened.

## Scope for the target cycle

- Authentication: inventory actual APP/COM/ORG routes, credentials/providers and original-flow,
  actor, browser/session and surface boundaries. Define expected stale A/new B, late callback,
  replay, expiry and concurrent-progression behavior before assigning implementation tasks.
- Identify existing tests that prove each supported boundary; unsupported combinations need an
  explicit applicability decision. Add only missing public-boundary and independent-connection
  cases. An exploitable authorization defect requires an actual reproduction, not a coverage label.
- Identifiers: classify owned permanent IDs, mutable references/state, external values and secrets;
  trace ordinary, bulk, job and migration producers/consumers. Identify exact missing guarantees and
  enforcement authority before proposing broader schema changes.
- Define bounded migration/continuity checks and concrete completion criteria before implementation.
  Existing catalog scans and passing suite totals do not prove a complete semantic inventory.

The output must distinguish existing verified behavior, newly reproduced defects and precisely
bounded residual gaps, with current revision-scoped evidence. Promote accepted implementation scope
into the owning spec when the target cycle starts; this backlog does not authorize broad schema,
workflow or production changes.

Sources: [R8D4](../../evidence/2026-10-13-nine-final-acceptance-R8D4.md),
[identifier protection](../../evidence/2026-10-13-setting-preference-id-protection-P3V8.md),
[flow criteria](../../docs/checklists/authentication-flow-integrity.md), and
[identifier criteria](../../docs/checklists/identifier-contracts.md).
