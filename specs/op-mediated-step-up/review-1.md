# Review 1: OP-mediated step-up

Date: 2026-11-03

Disposition: changes required before acceptance. The OP-mediated, RP-session-scoped, fixed-deadline
direction is coherent, but the proposed cutover scope, commit/failure semantics and completion
contract are not yet sufficiently consistent to implement safely.

Requested by the final `zero.md` entry, "Review request: specs/op-mediated-step-up". This is a
requirements/plan review, not implementation or approval of an ADR change.

## Review basis and limits

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; extensive pre-existing uncommitted changes
  affect the inspected application. Line references describe this worktree, not necessarily HEAD
  alone.
- Reviewed `spec.md`, `plan.md` and consolidated requirements items 1-22. Their SHA-256 hashes were:
  - spec: `80a5efd6365735c54b5045d7c4fb4940f41eb840b65eca039f5aaa7d14bd8612`.
  - plan: `1ab549eafc181c3fd0bbe435b99521cc926cedb0672c57d7e95487afd00b9df7`.
  - consolidated requirements: `fef83ccced9ed04c42aec3221c9fcdccb2f205a8863d99d80a9a79220643ff73`.
- Read the applicable security, lifecycle, data-shape, object-placement, identifier, replacement,
  language, testing and Browser RP rules and relevant current code. Inspected test definitions; did
  not execute Rails/Vitest tests, migrations, database cleanup, providers or browser flows.
- Confirmed defects below are defects in the proposed contract or plan. Attack scenarios identify
  requirements that need to be enforced; they are not demonstrations of a live exploit.

## Findings

### SU-R1 — High — APP-only scope conflicts with removal of shared ORG and registration paths

Evidence: `spec.md:20-28,72-73`; `plan.md:71-78`; consolidated requirements:91-96.
`app/controllers/base/org/verification/completions_controller.rb:8,18-24` uses
`BaseStepUpCompletion`; that concern calls `BaseSelfRpCredentialIssuer` at
`app/controllers/concerns/base_step_up_completion.rb:145-160`. The APP bootstrap issuer still calls
`BaseStepUpAdmissionIssuer` at `app/controllers/concerns/base_step_up_intent.rb:120-136`. The APP
completion controller handles bootstrap and credential registration as well as step-up at
`app/controllers/base/app/verification/completions_controller.rb:31-43`.

Deleting the named shared classes/step-up portions while excluding ORG and registration breaks
out-of-scope consumers. AC-17's universal prohibition on another step-up writer also contradicts
retaining ORG's current behavior. The no-compatibility rule requires consumer mapping, not removal
of unrelated functionality. This is a concrete scope contradiction, not a request for compatibility
aliases.

Proposed disposition: inventory consumers before specifying deletion. Replace APP ordinary step-up
completely, and preserve separately owned ORG and registration/full-reauthentication behavior with
explicit retained responsibilities. Scope the writer assertion to the migrated APP mechanism. If
complete cross-surface retirement is desired instead, obtain an explicit scope change and add ORG
acceptance; do not infer it from a shared class name.

### SU-R2 — High — AC-12 and AC-14 disagree, and lost-response refresh recovery is underspecified

Evidence: `spec.md:47-48,59-67`; consolidated requirements:70-77,122-123; `plan.md:14-19,54-56`.
Rotation changes the current digest and generation at `app/models/concerns/rp_session.rb:121-143`.
Reuse of a consumed predecessor is rejected and can revoke the grant at
`app/operations/oidc_refresh_token_issuer.rb:65-67,95-105`. The RP's indeterminate refresh outcome
is refused rather than replayed at `app/operations/rp_refresh_committer.rb:74-85`.

AC-12 unconditionally says an indeterminate outcome grants no authority, while AC-14 says the
committed event is reusable. In the response-loss case the browser may never receive the new refresh
token, so it cannot simply refresh with its old token: AC-7 deliberately invalidates it. These
outcomes cannot share one expected test result.

Proposed disposition: distinguish pre-commit refusal, committed OP event with unknown delivery,
credential installation, and protected-operation execution. State that the failed original request
never automatically executes; a committed event may exist even though its delivery is unknown.
Specify recovery with an actually available credential. Test response lost before delivery, response
received but installation refused, and a later valid-current-credential refresh separately. Preserve
the no-replay/no-grace contract and do not promise rollback across HTTP. Specify what happens to a
previously valid step-up event when a later ceremony fails; failure must not create or extend one.
Make AC-12 explicitly consistent with the selected commit semantics.

### SU-R3 — High — The existing-session capability is not bound through a defined protocol carrier

Evidence: `spec.md:38-39,62-64`; `plan.md:11-19,49-62`.
`app/services/oidc_token_exchange_coordinator.rb:859-865` rejects a non-retired grant for the same
device/client; `app/operations/rp_callback_committer.rb:51-72` checks the immutable Identity and
refuses an already-live local session. The RP cell owns its local data and does not read the OP
store (`app/controllers/concerns/rp_cell_local_session.rb:4-9`).

State, nonce and PKCE protect the authorization exchange, but do not alone specify which existing
grant and local session are being updated. A client ID or subject does not uniquely authorize an
update to an arbitrary current session. The plan also says the OP resolves the RP session without
stating how it respects the separate stores and owners.

Proposed disposition: define a server-selected initiation context bound to the exact current RP
session/Identity and the intended existing OP grant, carry its correlation through the
transaction/code, and verify it again on both completion boundaries. Define a distinct completion
transition; preserve both sign-in guards. Require no local principal creation, account switch, root
login issuance, session-limit/cooldown changes or revival of a logged-out session. Include wrong
same-client session, wrong subject/issuer, foreign browser, intercepted code/PKCE mismatch, expired
pending flow, logout and stale-completion HTTP cases. Do not introduce OP reads/writes of RP-local
session tables or pretend the two commits are one database transaction.

### SU-R4 — High — Refresh event snapshots and late installation need a concrete consistency rule

Evidence: `spec.md:45-48,83-86`; `plan.md:20,54-56`; consolidated requirements:85-89. Refresh reads
`usage.oidc_auth_time` before rotation at `app/services/oidc_token_exchange_coordinator.rb:214-226`.
That value is captured into the response builder at lines 263-279. The issuer reloads the grant
under lock at `app/operations/oidc_refresh_token_issuer.rb:89-107`, whereas class/methods are read
from the locked usage during encoding at
`app/services/oidc_token_exchange_coordinator.rb:949,991-998`. RP installation orders only callers
participating in its generation protocol (`app/operations/rp_refresh_committer.rb:90-103`).

The new writer makes an existing split snapshot significant: an event time captured before a
concurrent event change must not be combined with a later class/method tuple. Rotation may refuse
some orderings, but the plan neither specifies those orderings nor proves the split is harmless. A
late ordinary response must also not overwrite credentials installed by step-up completion.

Proposed disposition: define event fields as one authoritative snapshot read under the same
current-grant check/lock as issuance; make step-up and refresh participate in one RP installation
ordering contract. Test both orderings, not only sequential refresh. Reword "refresh keeps its
current encoder" as reuse of low-level encoding only after ownership/snapshot changes are settled.
Define whether an earlier valid access token remains accepted until its own expiry; rotation of a
refresh token does not revoke existing access tokens. A stolen access token still needs the
applicable RP session/sender binding and must not extend freshness.

### SU-R5 — High — DBSC continuity is deferred despite changing credential issuance

Evidence: `spec.md:62-64,91-92`; `plan.md:97-98`. `app/models/concerns/device_sessionable.rb:48-54`
stores the session digest, public-key thumbprint and binding time. Keeping that row can preserve
those stored facts. It does not prove proof enforcement survives a new exchange.
`AuthenticationBase#device_session_refresh_allowed?` checks proof and binding at
`app/controllers/concerns/authentication_base.rb:1841-1879`. The inspected OIDC refresh coordinator
has a separate DPoP check at `app/services/oidc_token_exchange_coordinator.rb:220-228`; DPoP is not
DBSC. The accepted boundary requires proof once a session is DBSC-bound
(`adr/device-session-dbsc-device-id-boundary.md:69-72`).

Proposed disposition: promote binding continuity to explicit acceptance and a named plan step.
Identify which credential/host is bound and which request checks it; preserve the existing binding
and refusal for missing, mismatched, revoked or invalid proof. Verify that the new installer does
not clear/rebind it and does not weaken DPoP where applicable. Existing data preservation is
partially inspectable; actual DBSC enforcement for the proposed completion and browser behavior
remain unverified. Resolve this before acceptance, not after the cutover.

### SU-R6 — Medium — Essential/voluntary request handling and Discovery are not a complete contract

Evidence: `spec.md:40-41,49-51`; `plan.md:36-41`. Visa APP `authorize_params`
(`app/controllers/visa/app/authorization_base_controller.rb:269-277`) and ORG
(`app/controllers/visa/org/authorization_base_controller.rb:234-242`) omit both `claims` and
`acr_values`. The Visa-controller and request-resolver search found no processing of either.
`AuthorizationTokenClaims#normalize_acr` defaults/downcases at
`app/controllers/concerns/authorization_token_claims.rb:58-61`.

The plan introduces both request forms without defining their combination, absent values,
`essential` typing, unsupported values or the distinction between a malformed request and an unmet
authentication requirement. Publishing support in unit 1 before units 2-3 implement it would
advertise a capability that cannot yet be fulfilled. OIDC Core 5.5.1.1 leaves simultaneous specific
requests through both forms unspecified; essential claims concern the ID Token, and `claims` support
itself must be implemented rather than assumed.

Proposed disposition: specify one canonical essential request shape for this RP, exact requested
value(s), error classification, safe handling of combined forms and refusal of voluntary downgrade.
Use essential `auth_time` or another explicit request/output requirement so the timestamp is
guaranteed, not merely optional. Verify returned access and ID claims consistently. Preserve exact
class values throughout issuer and verifier. Advertise support only in the coherent completed
release and only for enabled realms. ORG need not acquire step-up in this APP-only scope, but its
unchanged behavior and realm-specific metadata require regression coverage.

### SU-R7 — Medium — Several acceptance criteria are placeholders rather than decidable outcomes

Evidence: `spec.md:33-44,70-75,91-92`; consolidated requirements:37-48,80-81. The spec has no exact
class, skew or request/output shape. AC-5 says invalid inputs behave "as specified" without
specifying their outcomes. AC-1 says an operation proceeds after step-up even if other authorization
fails; AC-18's "any method" can be read to include methods prohibited by AC-16. These are
ambiguities at public decision boundaries, not reasons to add strength tiers.

Proposed disposition: state that satisfying step-up removes only that prerequisite; independent
authorization, current session, CSRF and no-lockout checks still apply. Define "any method" as any
server-permitted method for the current Security Mode, and explicitly amend E2 rather than calling a
changed restriction merely a clarification. Select the exact class and skew (recommend zero extra
step-up-window leeway), numeric timestamp contract and status/error partitions. With a fixed
exclusive deadline, test the anchor, its nearest neighbors and exact end; retain independent JWT
expiry validation. Ensure clock/configuration failure is explicit instead of a guessed default.

### SU-R8 — Medium — Cancellation, replay, return targets and abuse limits lack acceptance

Evidence: `spec.md:54-67,98-103`; `plan.md:11-19,55-62`. Current bootstrap freshness uses
`root_login_established_at`, not the grant time
(`app/operations/base_step_up_admission_issuer.rb:198-205`). Existing APP completion dispatches
bootstrap separately (`app/controllers/base/app/verification/completions_controller.rb:31-43`). The
current state-machine rules require a named writer, database-clock recheck and absorbing terminal
transitions (`generic/lifecycle-transition-writers.mdc`).

The plan mentions replay tests but does not specify public outcomes/side effects, the winning state
for competing cancel/complete requests, method-unavailable behavior or retention of attempt limits.
A server-held return target alone does not establish safe navigation; a user-controlled target can
still be stored server-side. Claim reuse must not confer target/tenant ownership.

Proposed disposition: add acceptance for state-machine rejection of stale/duplicate/conflicting
requests with no extra token/event/rotation, cancellation ordering, no-method refusal and retained
server-side throttling across restarts. Define safe same-RP return-target validation, CSRF/Origin/
Fetch Metadata rejection and no mutation by GET/HEAD. Test a reusable event against an unauthorized
target/tenant to rule out a confused deputy. Preserve bootstrap's original login anchor and forbid
registration evidence from granting ordinary step-up freshness. This makes AC-2 compatible with the
unchanged bootstrap exception instead of forcing a nonexistent authenticator.

### SU-R9 — Medium — Accounting is late in the plan and omits failure durability semantics

Evidence: `spec.md:23,59-69`; `plan.md:80-93`; consolidated requirements:78-79. Earlier owner
direction requires Accounting correctness now, while anomaly detection is deferred. The current
logging boundary distinguishes persisted authoritative audit from diagnostic logs
(`adr/application-logging-boundary.md:33-36,52`).

AC-15 covers successful issuance/installation but does not define durable failure, cancellation,
expiry, refusal or indeterminate-delivery facts, nor an audit-write failure. Unit 7 comes after the
destructive cutover even though the plan says every unit is coherent. A cross-store audit failure
cannot be waved away as if an already committed token issuance rolled back.

Proposed disposition: specify authoritative event names/outcomes, safe correlation (no raw
credentials or full request data), retention, duplicate handling and audit persistence-failure
behavior. Include audit persistence in the owning issuance/install transactions or an explicitly
specified durable handoff as appropriate; do not assume cross-database atomicity. Integrate it
before activating each writer, with forced-failure tests. Anomaly detection remains out of scope.

### SU-R10 — Medium — Plan units do not yet form coherent implementation/release boundaries

Evidence: `plan.md:3-4,24-41,49-93,97-98`; `spec.md:20-28,78-79`. Unit 0 claims no behavior change
while requiring retention-row repair and unspecified test-residue cleanup. Unit 3 assumes an
initiating RP request/installer that unit 4 has not defined, and unit 4 needs the challenge contract
in unit 5. Unit 1 advertises support before it is usable. Unit 6 inventories consumers only at
removal time. Unit 0 updates current diagrams/docs before the implementation they purport to
describe.

Proposed disposition: define the complete protocol, storage shapes and consumer inventory before
coding. Treat implementation slices as a single non-activatable change until all dependencies and
audit pass, or specify real safe activation boundaries. Build OP and RP completion against the same
contract. Amend ADR intent before implementation, but update current diagrams/inventories with the
corresponding behavior, not as claims of delivered work in a document-only prerequisite. Add
explicit front-end build, shared Inertia handling, locale changes/i18n checks, bootstrap/ORG
regressions, DBSC checks and relevant lifecycle/identifier guards. Do not require ORG feature parity
unless scope changes; do require no regression from shared changes.

The claimed test-residue cause was not reproduced in this review. First record a narrow failing
baseline and distinguish assertion failures, fixture errors and tooling failures. Do not make
unbounded cleanup or destructive database reset an implicit prerequisite of accepting this spec. Run
environment/build construction directly and record evidence; do not add Minitest/Vitest tests whose
subject is environment construction.

### SU-R11 — Medium — Persisted request/completion shapes and class ownership are missing

Evidence: `plan.md:37-39,49-60`; `spec.md:62-64`; consolidated requirements:85-90. The authorization
transaction currently has explicit intent validation including step-up
(`app/models/concerns/oidc_authorization_transactionable.rb:36-43`) but its construction API at
57-70 has no essential-class or initiating-RP-session argument. The plan calls for persisting new
context without a schema or transition contract.

Proposed disposition: present before/after request, persisted transaction, completion and audit
shapes under `generic/data-shape-design.mdc` before implementation. Identify existing fields that
can be reused and required new constraints/migrations. Represent any new state/decision explicitly
with NOT NULL semantics; nullable absence is not a workflow state. Map each lifecycle change to one
named writer and matching diagram/inventory. Classify new verifier/value/operation objects under
`project/value-object-boundaries.mdc`; a passive value must not write or call the OP. Classify
transaction references, local session IDs, OP sid, JWT JTI and secret/non-secret values separately
under `project/identifiers.mdc`; preserve issued identifiers and use the appropriate generator. No
migration, destructive operation or compatibility mechanism is authorized by this review. The
current plan contains no actual new column definition, so no specific NULL defect is asserted yet;
this is a missing design prerequisite.

## AC-by-AC assessment

"Decidable" means a concrete public test can be written after the named contract is fixed; it does
not mean that the behavior exists or a test passed.

| AC  | Assessment and required disposition                                                                                                                               |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Qualify with independent authorization and allowed methods; test at least two distinct sensitive operations in one session. SU-R7.                                |
| 2   | Decidable for ordinary step-up. Explicit bootstrap non-interference and unchanged original-login anchor are needed. SU-R8.                                        |
| 3   | Decidable negatives; missing initiating-session carrier and completion binding. SU-R3.                                                                            |
| 4   | Exact string is unresolved; case, missing/empty/unknown partitions are useful once fixed. SU-R6/R7.                                                               |
| 5   | Not yet decidable for skew/invalid inputs; formula and all statuses must be explicit. SU-R7.                                                                      |
| 6   | Decidable sequentially; add locked snapshot and late-response race outcomes. SU-R4.                                                                               |
| 7   | Decidable at token endpoint; include reuse's specified family effect and scope, not merely cookie change. SU-R2.                                                  |
| 8   | Needs claims schema, supported metadata, voluntary/combined request behavior and both token checks. SU-R6.                                                        |
| 9   | Decidable after header parameters are fixed; keep authentication, step-up, forbidden and dependency failures distinct. SU-R6/R7.                                  |
| 10  | Good public intent; define Inertia/fetch/full-document handling and start/return refusal cases. SU-R8/R10.                                                        |
| 11  | Public allow/refuse is decidable; "one shared verifier" is a structural review property, not an extra implementation-mirroring unit test. SU-R3/R7.               |
| 12  | Contradicts unqualified AC-14; enumerate pre/post-commit outcomes and prior valid evidence. SU-R2.                                                                |
| 13  | Observable continuity assertions possible; add DBSC and no root-login/cooldown/limit side effects. SU-R3/R5.                                                      |
| 14  | Not decidable as written for lost refresh credential; split delivery and installation scenarios. SU-R2.                                                           |
| 15  | Public operations can assert durable audit records; missing failure/dedup/persistence-refusal contract. SU-R9.                                                    |
| 16  | Decidable with success/disallowed-method/changed-policy cases at both acceptance boundaries. SU-R4/R7.                                                            |
| 17  | Inconsistent with scope and retained callers; code search is supplementary structural evidence, not a public behavior criterion. SU-R1.                           |
| 18  | Define any permitted method; preserve no-lockout and current authorization. E2 is an explicit policy amendment. SU-R7.                                            |
| 19  | Decidable with before/during/after-ceremony revocation races; preserve local revocation propagation and do not assume instantaneous global observation. SU-R3/R4. |
| 20  | Appropriate document-review deliverable, not a runtime acceptance test. Map changed axes and update with implementation. SU-R10/R11.                              |

## Requested implementation facts verified in this session

- Existing-grant guard: confirmed at `app/services/oidc_token_exchange_coordinator.rb:859-865`.
  `retirement_pending?` deliberately also covers recently revoked grants whose JWTs may still be
  valid (`app/models/concerns/rp_session.rb:24-35`). Preserve that distinction from merely active.
- Live-local-session guard: confirmed at `app/operations/rp_callback_committer.rb:72`; result
  success is only committed at lines 21-24. It is not an idempotent existing-session installer.
- Visa ORG: `authorize_params` at
  `app/controllers/visa/org/authorization_base_controller.rb:234-242` omits both request parameters.
  The Visa/controller-resolver source search found no handler. This confirms their absence in that
  inspected path, not all possible future mounted code.
- DBSC: binding fields and existing proof checks are present as cited in SU-R5. The planned
  purpose-bound completion does not exist, so survival/enforcement cannot be verified. No live
  DBSC/browser interoperability claim is made.
- `step_up_until`: application search found only optional plumbing in
  `app/controllers/concerns/authorization_token_claims.rb:10,47-53`,
  `app/values/security_jwt_auth_access_token_codec.rb:23,55`,
  `app/lib/oidc_id_token_issuer.rb:9,23,51` and
  `app/values/security_jwt_oidc_id_token_codec.rb:43,67`. No application caller setting it to a
  non-nil value was found. A test does exercise non-nil codec output at
  `test/services/branch_coverage_batch30_lib_easy_arms_test.rb:101-106`. Thus "no application
  producer found" is supported; "no caller anywhere" is too broad. Not adopting it is coherent.
- Grant fields: source search found readers/writers in `BaseSelfRpCredentialIssuer`,
  `BaseStepUpCompletion`, and `OidcTokenExchangeCoordinator`. Refresh reads stored time at
  coordinator:214, stored methods at 949, class at 991/1018, and emits event time at 998/1024.
  Overwriting changes subsequent access and ID Token events for that grant; it must not change
  sibling grants or the OP root event. Handle late snapshots as SU-R4; dispose of old consumers
  explicitly as SU-R1. Current access-claim normalization is not exact for arbitrary classes.

## Security scenario coverage required by the request

| Scenario                             | Required contract/test disposition                                                                                                                                                                                                 |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Stolen refresh credential            | Model applicable private-key client auth, sender binding and RP session requirements; verify predecessor rotation refusal, no unearned event and fixed deadline. Never equate a raw RT with full attacker capability. SU-R2/R4/R5. |
| Stolen access token inside window    | Within declared bindings it may represent legitimate recent evidence; enforce exact RP/session/Identity/audience, independent authorization, expiry and no extension. Do not claim rotation revokes it. SU-R3/R4/R7.               |
| Intercepted authorization code       | Retain client authentication, exact redirect, PKCE, state/nonce/issuer and single use plus initiating-session binding; foreign browser/client/session cannot install. SU-R3.                                                       |
| Cross-RP / same-client other session | Update the exact grant and install only into the initiating live local session, not another subject/client lookup match. SU-R3.                                                                                                    |
| Confused deputy during reuse         | A valid event does not authorize another target, tenant, capability or operation; final authorization remains independent. SU-R7/R8.                                                                                               |
| CSRF / open redirect                 | Reject invalid CSRF/provenance before start writes; validate server-selected return target, no arbitrary external target or automatic POST replay. SU-R8.                                                                          |
| Completed/canceled ceremony replay   | Absorbing state, one completion/rotation/audit outcome; distinguish new transaction from retrying a consumed code. SU-R2/R8.                                                                                                       |
| Voluntary class downgrade            | A weak/missing returned class never passes; parser/Discovery support and combined requests have defined behavior. SU-R6.                                                                                                           |
| Overwritten grant claims             | Keep event tuple consistent, root anchor and sibling grants unchanged, class historical after deadline but unusable. SU-R4/R7.                                                                                                     |

## Plan and acceptance readiness

The current draft is not ready to mark accepted. SU-R1 through SU-R5 are material scope/security
contract blockers. Resolve the remaining public outcomes and shapes before implementation; do not
interpret "unverified implementation" alone as requiring the feature to be built before acceptance.
All source-based gaps listed here can be addressed in a revised proposal first.

Recommended dependency order:

1. Map APP/ORG/registration consumers; settle scope, existing protections and accepted-ADR changes.
2. Define request/transaction/completion shapes, exact class/window/errors, event commit semantics,
   refresh snapshots, session/DBSC bindings, installation order and Accounting outcomes.
3. Define AC-to-public-test mapping and targeted baseline; record unrelated test failures honestly.
4. Implement OP request/evidence/completion and RP start/verifier/installer against that common
   contract, with Accounting integrated before activation. Keep the release non-activatable until
   the complete chain works; no unit 1 premature Discovery advertisement.
5. Implement client/HTML/locale handling and migrate the inventoried APP callers atomically; keep
   excluded flows working. Run concurrency, authorization and bound-session regressions plus the
   real front-end build. Update current diagrams/docs with the owning code changes.
6. Run warranted broader checks, retain evidence and close with explicit unverified limits.

Owner-only decisions are formal acceptance of the scope and lasting policy reversals, including
E2/D3/path C, and any material expansion needed if shared retirement cannot stay APP-only. If the
recorded OP-commit semantics are intended to weaken the earlier fail-safe promise, that risk
tradeoff must be explicit in the acceptance rather than hidden in AC wording. The recorded five
minutes, fixed-deadline reuse, rotation, same-session scope and single-class direction are not
reopened simply because implementation needs design work. Exact schema, safe class identifier,
zero-extra-window-skew recommendation, object placement, parser errors, test mapping and dependency
ordering are routine proposal corrections; they do not each require a separate owner question. No
approval or implementation is performed by this review.

## Primary sources

- [OIDC Core section 2](https://openid.net/specs/openid-connect-core-1_0.html#IDToken) for claim
  meanings and case-sensitive classes;
  [section 5.5.1.1](https://openid.net/specs/openid-connect-core-1_0.html#acrSemantics) for
  essential requests and undefined combined request behavior.
- [RFC 9470 sections 3, 6.1 and 7](https://www.rfc-editor.org/rfc/rfc9470.html) for challenge,
  immutable event information on renewal and metadata support.
- [RFC 9700 section 4.14](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14) for refresh
  credential binding, rotation and replay handling.

Only this review and the requested short `zero.md` response are authored for this task. The spec,
plan, consolidated requirements and implementation remain unchanged.
