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

The subsequent 2026-10-12 dead-history slice made the physical-destruction boundary explicit.
`EmailIdentifierPurger` and `TelephoneIdentifierPurger` now call the named
`purge_with_dead_history!` operation; ordinary identifier removal calls
`destroy_without_dead_history!`, owner-dependent whole-Identity erasure remains a separate
history-deleting contract, and an unmarked persisted identifier destruction aborts. The focused
history/concurrency collection passed `29 runs, 141 assertions`, the broader six-model collection
passed `181 runs, 918 assertions`, and the following shared-worktree Gate 2 passed
`15141 runs, 128212 assertions, 0 failures, 0 errors, 0 skips` with Vitest `99 files, 1140 tests`.
See `evidence/2026-10-12-dead-history-destroy-boundary-R7K3.md`. The physical-purge checkbox below
remains open because its full source/fixture/constraint, cross-database, legal-retention and D-11
matrix is not established by this slice.

The subsequent identifier slice standardized two remaining self-controlled issuer paths. New
`LogoutTransaction` rows now use `PublicId.generate`, retry only the named public-ID collision
within the finite shared budget, and reject post-creation public-ID changes. The APP, COM and ORG
`EnforcementCase` models now use the same issuer, retry only named `public_id` unique-index
collisions within the finite shared budget, and reject post-creation public-ID changes through
their shared concern. The focused issuer collection passed `40 runs, 135 assertions, 0 failures,
0 errors, 0 skips`; the current EnforcementCase regression collection passed `42 runs, 133
assertions, 0 failures, 0 errors, 0 skips`; the current run-owned full Gate passed `15155 runs,
128289 assertions, 0 failures, 0 errors, 0 skips`, with Vitest `99 files, 1140 tests`. This does not close the
remaining ceremony-route, physical-purge matrix, complete identifier inventory or final acceptance
checkboxes. See `evidence/2026-10-12-public-id-issuers-H4J2.md` for the commands and limits.

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

The 2026-10-12 OTP purpose/operation slice now rejects mismatched Email and Telephone proof pairs at
the locked issuance boundary and at delivery, verification and retained-evidence lookup. The focused
transaction collection passed `31 runs, 517 assertions`, the run-owned Rails Gate 2 passed
`15198 runs, 128490 assertions, 0 failures, 0 errors, 0 skips`, and Vitest passed `99 files, 1140
tests`. This is implementation evidence for the exercised pair guard, not closure of the unchecked
all-route ceremony matrix or the final acceptance item. See
`evidence/2026-10-12-p3b-purpose-operation-binding-Q7R1.md`.

The 2026-10-12 TOTP reference slice classified the APP TOTP enrollment factory's self-controlled
`transaction_id` and `grant_jti` as non-secret ceremony identities. The factory now uses separate
NanoID-21 values from `PublicId.generate` and retries only an exact generated single-column unique
B-tree collision inside a savepoint and the finite collision budget. The enrollment issuer delegates
that boundary instead of maintaining a second retry implementation. The focused TOTP collection
passed `43 runs, 398 assertions, 0 failures, 0 errors, 0 skips`; targeted RuboCop passed; the
subsequent run-owned Gate 2 passed `15199 runs, 128493 assertions, 0 failures, 0 errors, 0 skips`
and Vitest passed `99 files, 1140 tests`. Result `jti`, OTP generations, protocol values and
authenticator identities remain separate contracts. See
`evidence/2026-10-12-totp-ceremony-references-R2T6.md`. This does not close the remaining
purpose/provider applicability matrix, physical-purge matrix, D-11 isolation campaign, operational
cutovers or final acceptance checkbox.

The following 2026-10-12 Social candidate-reference slice moved newly issued
`IdentitySocialCeremonyCandidate.ref` values to NanoID-21 through the shared candidate factory. The
APP link-completion reader accepts the new NanoID form and retained UUID-v4 rows through a
Social-specific strict pattern; the unrelated global `AuthAdmissionBinding::REFERENCE_PATTERN`
remains unchanged. Generated collisions are retried only on the named candidate `ref` unique
index, with the existing finite budget and savepoint behavior. The focused Social contract and
link integration collection passed `35 runs, 303 assertions, 0 failures, 0 errors, 0 skips`; the
run-owned Rails Gate 2 passed `15201 runs, 128498 assertions, 0 failures, 0 errors, 0 skips`, and
Vitest passed `99 files, 1140 tests`. Existing UUID rows were not rewritten, and this slice does
not close the remaining ceremony-purpose matrix, physical-purge matrix, D-11 isolation campaign,
operational cutovers or final acceptance checkbox. See
`evidence/2026-10-12-social-candidate-references-K6P4.md`.

The next 2026-10-12 P2 foundation slice separated the shared `PublicId` issuer length from its
compatibility storage capacity. New values remain NanoID-21, while the concern now accepts explicit
existing values through the standard 25-character capacity and rejects 26-character values before
the writer. No column is widened or narrowed by this change; database-specific varchar bounds and
named capacity checks remain authoritative. The focused public-ID/capacity collection passed
`122 runs, 337 assertions, 0 failures, 0 errors, 0 skips`; targeted RuboCop, syntax checks,
`git diff --check` and the repository knowledge checker passed. The post-slice run-owned Rails
Gate 2 passed `15203 runs, 128507 assertions, 0 failures, 0 errors, 0 skips` with four workers,
and Vitest passed `99 files, 1140 tests`. See
`evidence/2026-10-12-public-id-storage-capacity-P5M8.md`.

The following P2 maintenance slice aligned the legacy telephone ceremony value object with the
same issuer contract. When callers omit `transaction_id` or `grant_jti`,
`IdentityTelephoneCeremonyTransaction` now generates NanoID-21 values through `PublicId.generate`;
explicit existing values remain unchanged. The focused coverage passed `3 runs, 26 assertions,
0 failures, 0 errors, 0 skips`, and the subsequent Rails/Vitest Gate 2 passed
`15203 runs, 128507 assertions, 0 failures, 0 errors, 0 skips` and `99` files / `1140` tests.
This does not reclassify result identities, protocol values or caller-supplied legacy references.

The next P2 slice aligned Step-Up's server-generated `passkey_challenge_ref` with the same opaque
issuer contract. New references on the APP, COM and ORG Step-Up session tables now use
`PublicId.generate` (NanoID-21), while existing opaque UUID references remain readable. The
existing named unique B-tree on each table remains the final collision guarantee; only a collision
on that exact index is retried in a savepoint within the finite challenge-reference budget.
WebAuthn protocol challenges, RP/origin binding, expiry and burn behavior remain unchanged. The
focused public-boundary/model collection passed `37 runs, 477 assertions, 0 failures, 0 errors,
0 skips`. The following run-owned Rails/Vitest Gate 2 passed `15204 runs, 128512 assertions,
0 failures, 0 errors, 0 skips` and `99` files / `1140` tests. This closes only the Step-Up challenge
reference issuer boundary; durable criterion `ID-3q` records the independent contract. It does not
close protocol identifiers, full route applicability, physical-purge coverage, D-11 isolation,
operational cutovers, privacy-retention decisions or the user-excluded independent acceptance
investigation.

The following documentation alignment records the legacy `IdentityTelephoneCeremonyTransaction`
value object accurately: it is not a persisted issuer, its omitted transaction and grant defaults
use the shared NanoID-21 mechanism, and explicitly supplied values remain caller-owned. The same
reference identifies short-lived social/local Valkey receiver capabilities as a separate UUID-v4
transport contract rather than treating them as durable resource IDs. This note changes no runtime,
schema or acceptance status and does not replace the remaining purpose, purge, D-11 or final
verification work.

The 2026-10-13 documentation alignment also marks the older Email sign-in OTP source snapshot and
generic HOTP design examples as historical traceability material. The current local boundary is
ceremony-owned keyed random-code proof with independent Email/Telephone policies, while admitted
authentication Email OTP and Step-Up Email OTP retain their separate contracts. This note changes
no runtime, schema or acceptance status; route/provider applicability and independent acceptance
remain revision-scoped work.
