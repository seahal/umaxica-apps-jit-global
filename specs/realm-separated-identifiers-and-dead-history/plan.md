# Realm-separated identifiers and dead history implementation

Authority: the user's 2026-10-07 identifier/OTP/history contract and approved ceremony storage
extension; decision record: `adr/realm-separated-identifiers-and-dead-history.md`. Conflicting
`two.md` and historical shared-OTP recommendations are superseded for this task.

## Execution and acceptance

- [x] Telephone issuance timestamp in APP/COM/ORG; no `created_at` anchor; focused tests pass.
- [x] Independent Email/Telephone policy series; issuance/expiry/cancellation preserve failures;
      success reset, threshold and boundary tests pass for all realms; shared stateful policy
      removed. Current evidence: `evidence/2026-10-12-p3a-independent-policy-G5L2.md`.
- [ ] Ceremony-owned random-code keyed verifiers and bound delivery for every existing applicable
      signup/signin/recovery/withdrawal/registration route; actor/session/purpose/candidate checks,
      expiry, cancellation, atomic single-use and concurrency tests pass; identifier HOTP material
      and legacy serialized proof removed; Step-Up remains separate.
- [x] Six explicit live HMAC keys, model/realm lookup, same-realm normalization and cross-realm
      inequality; missing-key/channel/malformed-input tests and realm/channel rotation pass.
- [x] ARE inventory reconciled into explicit realm keyrings, current/previous rotation retained, no
      global fallback, encryption/rotation tests and actual local boot pass.
- [x] Six independent history models/tables with the approved minimal columns; keyed HMAC plus
      pinned Argon2id fingerprints; identity-scoped candidate matching only; privacy/visibility
      tests.
- [ ] Physical purge/history insertion atomic and hold/retention aware; logical deletion creates no
      history; reuse, duplicate purge, rollback and create/purge concurrency tests pass in every
      realm and separately for Email/Telephone; normalized live uniqueness enforced by database
      constraints.
- [ ] ADR/docs/plans/harness/state diagrams describe delivered behavior without historical policy
      recommendations; all focused controller/ceremony/model/security checks, full Rails tests,
      RuboCop and required invariant harnesses pass; final schema verification disposition recorded.

No push/PR, worktree, production or external-service mutation. The integrated nine.md instruction
permits narrow local commits for nine.md, durable acceptance/evidence documents and the minimum
required indexes; that exception does not authorize application-code, migration or unrelated
configuration commits. No compatibility layer or test weakening. Schema changes use migrations and
generated dumps. Environment construction is checked by execution and recorded in evidence, not
additional environment tests.

## Current implementation note

The 2026-10-12 implementation slice retired the direct Email OTP adapter and its rollout flags.
`OtpAdapter.for` now selects the concrete Noticed adapter for APP, COM and ORG Email delivery, with
no feature-flag or unavailable-store fallback to the former mailer adapter. Existing Noticed,
ActionMailer, interceptor, encrypted-payload and delivery-job behavior remains the transport
contract. This slice does not complete the unchecked ceremony-purpose/route matrix, physical
purge/retention matrix or final documentation and verification item above. Revision-scoped
implementation evidence is recorded in `evidence/2026-10-12-otp-email-noticed-final-Z4N7.md`; its
tested code was the dirty worktree at `8bd06dcd8261ed7697e23f1f0eace535254de1b3`, before the
document-only commit.

## Verification constraints observed

The normal test runner originally stopped on 14 pre-existing pending migrations; these were applied
only to test-prefixed databases on the configured test host. Telephone focused checks then passed.
`db:verify_no_schema_drift` dumps schemas and compares them with the Git index, so it reports
intended uncommitted migration changes as drift. The no-commit constraint remains authoritative; do
not weaken the verifier or claim a green result. Distinguish generated intended migration effects
from existing database/schema or PostgreSQL dump-format drift before final reporting.

Current run-owned recheck: on 2026-10-12, the same verifier passed against all twenty configured
non-replica writer databases and the current tracked dumps. See
`evidence/2026-10-12-schema-drift-current-D4K9.md`. This does not establish shared or production
schema application.
