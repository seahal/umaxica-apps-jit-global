# Review 3: unit 0 contracts and revision 3

Date: 2026-11-03. Disposition: changes required before unit 1 or acceptance. HEAD:
`efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, extensive existing uncommitted changes. Scope:
`contract-draft.md`, `consumer-inventory.md`, revision 3 and Standing instruction in `zero.md`.
Source inspection and primary-source reading only; no tests, migrations or live flows. Earlier
review findings are not evidence of runtime success.

## Findings

### RV-75 — High — Inventory omits active consumers and counts a definition as a call

Evidence: inventory:17-20 and section 3. `rg -n consume_step_up_evidence! app` returned 23 lines,
one being the method definition at `app/models/concerns/token_status_management.rb:97`: there are 22
invocation sites, not 23. The inventory does not list these invocation-bearing files:

- `app/operations/identity_totp_enrollment_final_committer.rb:142`.
- `app/operations/identity_passkey_registration_final_committer.rb:232`.
- `app/operations/identity_passkey_name_committer.rb:88`.
- `app/operations/enforcement_case_apply_operation.rb:41`.
- `app/operations/enforcement_case_end_operation.rb:93`.
- `app/models/concerns/enforcement_appeal.rb:64`.
- `app/controllers/auth/app/social/link_completions_controller.rb:78`.
- `app/controllers/base/org/api/v0/support/enforcement_cases_controller.rb:106`.

The broader `rg -l 'StepUpResolver|last_step_up_|consume_step_up_evidence!' app` found 48 files.
That is a lexical footprint, not 48 final writers or proof of reachability. The listed table has
about thirty rows, but it is not a complete final-consumer inventory.

Disposition: add every invocation site, direct evidence reader, policy and caller chain with its
ordinary versus retained purpose. Registration can remain a separate ceremony while its existing
step-up prerequisite migrates. Do not remove enrollment, candidate single-use, ownership or
no-lockout checks together with evidence consumption. Establish the test/HTTP boundary per row.

### RV-76 — High — Owner-side proof propagation is missing from the new contract

Evidence: `contract-draft.md:74-90` defines OP/RP completion but no owner-API evidence contract.
`app/controllers/concerns/avatar_authority_api_endpoint.rb:7-11,26-40,99-114` authenticates the
calling RP and actor access JWT, then checks root-token evidence. `owner_page_responses.rb:46-61`
constructs a root-bound requirement and returns a JSON 403. These are also ORG administration
boundaries, not merely APP page helpers. The invocation in the ORG enforcement controller above is
another example.

Replacing controller gates alone either leaves operations unusable after root freshness is removed,
or encourages trusting a browser/RP-supplied boolean. Disposition: define how the authenticated
owner receives and validates the OP-signed event for the same actor, client, sid and intended
operation/tenant, respecting token audience and caller authentication. Pass a validated immutable
evidence value to the final writer, with expiry/current authorization checks at the write boundary.
Do not introduce an untrusted `step_up: true` flag or broaden token audiences silently. Reuse
existing authenticated transport only after documenting its verifier and purpose bindings. This
owner boundary must be included in unit 0, not inferred in unit 6.

### RV-77 — High — Audit fallback is diagnostic logging, not a durable atomic fact

Evidence: `contract-draft.md:119-121`; `app/operations/chronicle_fallback_recorder.rb:18-20` calls
`Rails.logger.error` only. `manual_recovery_required` in that fallback does not persist a Chronicle
fact or make it atomic with OP issuance. The contract also places context on an OP database and
audit in Chronicle, without a cross-store commit/recovery design.

Disposition: define durable intent/outcome recording and the precise local commit boundary or an
explicitly approved durable handoff. Specify behavior before issuance, after issuance and on
installation audit failure separately. Do not call a log record durable Accounting, or claim that an
audit failure reverses a completed remote commit. Retain diagnostic fallback as a diagnostic. Fix
the retention prerequisite and test each persistence failure at public boundaries.

### RV-78 — Medium — Outcome table applies conflicting rules to consumed-code replay

Evidence: `contract-draft.md:68-70`: duplicate/stale token exchange is 409, while consumed code is
`invalid_grant`. The same request matches both. A universal 503 for OP dependency failure also fails
to distinguish authorization error responses from resource responses.

Disposition: keep browser ceremony conflicts as explicitly defined 409 responses; token endpoint
errors use the OAuth token error contract (normally HTTP 400 `invalid_grant`, with the defined
client-authentication exceptions). Authorization endpoint errors use a validated redirect only after
client/redirect validation. Define statuses for start GET/HEAD and CSRF/provenance rather than
"existing refusal". Avoid ambiguous precedence in every row.

### RV-79 — Medium — The schema and state table are still a sketch, not migration-ready shapes

Evidence: `contract-draft.md:94-110`. An OP-only context row cannot by itself prove the RP's pending
browser/session state. The draft has names but no types, keys, uniqueness, expiry policy, origin of
each reference, RP-local carrier or valid-edge table. A blanket all-NOT-NULL statement does not
specify when terminal timestamps exist. A `failed` state has no defined incoming edges.

Disposition: keep a purpose-owned context as a reasonable proposal, but supply explicit OP and RP
shapes, authenticated correlation, clock owner, constraints, lifecycle facts and transition matrix.
Do not invent NULL states or placeholder timestamps for not-yet-completed transitions. Identify
which existing authorization states own code issuance/redemption and which new states own RP
installation. Preserve retained old tables/writers; new binding does not prove every old table is
disposable. No migration is ready to implement from the current table.

### RV-80 — Medium — Literal searches do not justify removing authentication conditions

Evidence: inventory:25-28. No literal `*_required: true` match was found in the search, but
`verification_base.rb:120-132` accepts and forwards requirement parameters, and
`identity_step_up_ceremony_freshness_committer.rb:332-375` checks dynamic requirements and
full-reauthentication purpose. `client_passkey_policy.rb:67` also requires a UV-verified passkey
record independently of those literal booleans.

Disposition: preserve retained full reauthentication and credential eligibility checks. Replace
ordinary scope/consumption under the accepted single-class policy, but classify derived and
forwarded conditions before deletion. Absence of a literal does not prove unreachable behavior. The
precise URN is also not justified by repository uniqueness: `urn:umaxica` already occurs in
`app/values/problem_type.rb:17` and `config/initializers/jwt.rb:14`. RFC 8141 namespace allocation
is separate from local use; verify authority or choose an absolute HTTPS class URI under an owned
domain. No external registration status was verified here.

## Revision 3 and previously unread files

RV-71 through RV-74 are addressed at requirements level: refusal categories, audit observations,
stable AC-20/21/22 meanings and causal ordering are now explicit. RV-78 concerns the concrete
outcome table, not reversal of that disposition. No need to reopen fixed-deadline reuse, rotation,
the owner-approved ORG scope or the E2 change.

Read `verification_step_up_guard`, `verification_client`, `verification_operator`,
`owner_page_responses`, `avatar_authority_api_endpoint`, `actor.rb` and `token_status_management`.
`verification_cookieable` is at `app/models/concerns/verification_cookieable.rb`, not the controller
concern location implied by the inventory. Its host-only cookie-name API has an old
verification-record reader, with no writer shown in that concern. Do not automatically remove it as
ordinary step-up until its model/reader consumers are mapped.

The client/operator verification concerns delegate to `VerificationBase`; adapt the shared ordinary
gate and preserve bootstrap entry semantics. `Actor` is a pushed request-snapshot reader:
`step_up_fresh?` and `requires_step_up?` read `Actor::StepUp`; it is not a new evidence store and
should not perform token decoding or database writes. Keep/adapt that public value where consumers
remain. `TokenStatusManagement` owns revocation as well as consumption: remove ordinary consumption
while preserving revocation and retained ceremony cleanup.

## Answers to C-1 through C-6

| Point | Recommended disposition                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C-1   | Keep the standard Bearer challenge if the cookie carries the OP access token whose event is being evaluated. Describe it as an OAuth access-token authentication requirement transported by cookie, not an invented cookie scheme. A client reads the header and starts the existing RP action; the header does not authorize exposing tokens to JavaScript. Define the Inertia/fetch handler and full-document response. Do not claim generic browser automation or complete RFC interoperability from the header alone. |
| C-2   | Browser lifecycle conflict may be 409; token replay is the OAuth error in RV-78. A 409 body is not an Inertia external-location response unless it actually uses that distinct protocol.                                                                                                                                                                                                                                                                                                                                  |
| C-3   | Proposed names are usable once registered with retention/outcome schemas. Dedup needs owner/realm/client plus transaction and reason; define unknown/invalid-transaction handling, bounded payloads and uniqueness. Never merge issuance and RP-installation facts merely because their event name or transaction is equal. RV-77 remains blocking.                                                                                                                                                                       |
| C-4   | Same shape, separate realm stores and issuer/client/Identity bindings; ORG enforces ADVANCED passkey-only server-side. Both Visa controllers need parsing, essential checks, completion and realm-correct Discovery. No APP fallback.                                                                                                                                                                                                                                                                                     |
| C-5   | Identify root/device DBSC binding and its host-specific proof endpoint separately from the RP access/refresh cookies and from DPoP. Preserve the existing bound device and validate the required proof on the actual issuance/refresh path. New completion behavior is unimplemented and unverified; the contract must name the checks, not infer them from unchanged row IDs.                                                                                                                                            |
| C-6   | Zero extra step-up-window skew is consistent with the fixed predicate. Missing clock/configuration never passes; dependency failure is distinct from insufficient proof. At a protected resource an actual outage is 503. Missing required configuration should fail explicitly at its owning startup/boundary, not become a default or an endlessly retriable authentication challenge.                                                                                                                                  |

## Answers to O-1 through O-6 and concrete work division

| Point | Recommended disposition                                                                                                                                                                                                                                                            |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| O-1   | One coherent cutover of all ordinary APP/ORG consumers; preserve old machinery only for retained purposes. Use the work packages below, not two runtime evidence authorities.                                                                                                      |
| O-2   | Keep the catalog where retained flows validate return targets or need existing operation/audit names. It is not the new authentication-policy source. Remove only mappings proven unused after the caller inventory.                                                               |
| O-3   | Enforce ORG passkey-only at Auth and OP acceptance, and current session/policy at the owning write. A single class does not authorize a different realm or relax active-count rules.                                                                                               |
| O-4   | Replace the 22 invocation checks atomically with validated reusable evidence, preserving each operation's independent transaction, idempotency, candidate single-use and authorization. Add the omitted eight files before assigning work.                                         |
| O-5   | Ordinary freshness becomes 300 seconds everywhere; old 15-minute constants must not govern a new verifier. Do not globally rewrite bootstrap, full-reauthentication or unrelated transaction lifetimes without classifying purpose.                                                |
| O-6   | Keep/adapt the request snapshot value for live readers; remove the old ordinary root-store resolver only after all relevant readers migrate. Preserve the retained-flow decision APIs explicitly. Neither Actor nor lifecycle revocation is simply a non-step-up reader to delete. |

Concrete implementation packages I could carry out after acceptance, serialized against shared
files:

1. Freeze the complete consumer matrix and contracts; define immutable verified-event value and
   shared verification API, owner transport, persistence and failure semantics. No runtime cutover.
2. Add approved OP/RP purpose-owned persistence and lifecycle writers plus durable audit boundaries.
3. Implement both realm OP admission/issuance and RP start/install paths, including refresh
   ordering, bound-session checks and client challenge handling, as one unpublished development
   change.
4. Migrate owner-side verification and final writers in explicit families:
   credential/contact/Secret; social/registration prerequisites; session/withdrawal/security
   transitions; avatar/ORG enforcement and capability management. Each receives the same validated
   evidence contract. Preserve retained workflows and all non-step-up locks/guards. Update
   corresponding public tests with each family.
5. Switch all inventoried ordinary callers together; remove their root-evidence readers/consumption,
   keep retained machinery, publish only after full chain checks and diagram/doc reconciliation.
   Column/table drops remain a separately approved persistence operation.

These are local development packages, not independently deployable stages, feature flags or a
compatibility layer. Unit 1 can start only after exact types/keys/constraints, ownership, reference
and transition shapes and safe audit durability are approved; current names alone are insufficient.
The minimum test baseline is the affected public OP/RP/owner and retained-flow tests with known
failures classified, not an unrelated test-database cleanup project. No tests were run here.

## Readiness and sources

Acceptance/unit-1 blockers: RV-75 through RV-79, exact carrier/schema and lifecycle definitions,
DBSC request ownership, final consumer/test mapping, and the remaining ADR drafts. RV-80 needs
correction before deletion decisions. Most are technical design work for Claude to resolve; no new
owner question is necessary unless a proposed solution changes agreed scope/security policy or
requires destructive persistence. Formal spec and ADR acceptance remain pending.

Primary references read in this session:
[RFC 6749 section 5.2](https://www.rfc-editor.org/rfc/rfc6749.html#section-5.2),
[RFC 9470 section 3](https://www.rfc-editor.org/rfc/rfc9470.html#section-3), and
[RFC 8141](https://www.rfc-editor.org/rfc/rfc8141.html). No namespace registration, complete runtime
reachability, test result or browser interoperability is certified. Only this review and the
append-only board response were authored; the reviewed documents and implementation stay intact.
