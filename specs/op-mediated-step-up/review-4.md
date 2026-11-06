# Review 4: contract revision 2

Date: 2026-11-03. Disposition: changes required before unit 1. HEAD:
`efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, extensive existing uncommitted changes. Scope:
contract/inventory revision 2 and the final Claude request in `zero.md`. No implementation or
reviewed-document changes. Source inspection only; no tests or live flows.

## Findings

### RV-81 — High — Unauthenticated failures must not terminalize a legitimate ceremony

Evidence: `contracts/contract-draft.md:69-71,133-136`. An OIDC error parameter is listed as
sufficient to cancel/refuse the RP state; the OP's FAILED edge includes invalid binding, PKCE and
client. These rows omit the authority required before changing that state.

An attacker must not be able to cancel a pending transaction by submitting its reference with an
invalid proof/client or forged error. A genuine authenticated policy refusal can be terminal;
invalid request authentication is not automatically authority over the referenced transaction.
Current callback ordering verifies state and response issuer before processing errors
(`app/controllers/concerns/oidc_callback.rb:27-41`).

Disposition: require browser/state/session/issuer correlation before processing every OIDC error,
including cancellation. At OP/token boundaries authenticate the caller and bind the transaction
before any terminal write; invalid client/PKCE/binding attempts must not burn an unrelated or
otherwise valid pending flow. Specify the authoritative validation-refusal edges separately and test
forged errors, foreign browsers and bad-client/bad-PKCE requests with unchanged victim state.

### RV-82 — High — The pending RP state lacks a one-dispatch claim before code exchange

Evidence: contract:106-110,139-161. The RP has PENDING followed by terminal installation states, and
locks/rechecks during installation, but no pre-dispatch consumption/reservation is defined.

Two callbacks can both observe PENDING, exchange the same code, and only later compete for
installation. Refusing the second installer does not undo its token request; code replay can
invalidate the grant or credentials issued by the first. Holding a database lock across an HTTPS
exchange is not an acceptable substitute for an explicit dispatch contract.

Disposition: define a database-clock, browser-bound, atomic one-dispatch transition/claim before
exchange, with separate in-flight/indeterminate outcomes where required. Release local locks before
network I/O. Specify races with cancellation, refresh and logout, and recover uncertain exchanges
without resending a consumed code. An additional lifecycle state is a proposal to model actual
behavior, not permission to introduce a grace/receipt protocol. Test simultaneous callbacks at the
public boundary and assert token-endpoint dispatch count as well as final state.

### RV-83 — High — OP-current grant is not necessarily the initiating RP's intended grant

Evidence: contract:98-105. The OP selects a grant using its current session and requesting client;
only the returned sid is compared with the RP sid later. OP and RP identity/session selection can
diverge before or during the ceremony. The contract therefore allows updating/rotating a different
grant before the RP refuses its result.

Disposition: bind an authenticated OP-owned expected grant/sid and Identity context before OP
commit, and compare it with the active OP session and completed evidence. This need not expose an
RP-local database ID or let the OP access RP tables. Define how the existing authenticated OIDC
request/exchange carries or resolves that expectation. A post-commit RP check remains necessary but
cannot replace the OP check. Test switched OP Identity, replaced root and another same-client
session; the wrong grant must receive no event or rotation.

### RV-84 — Medium — Retained credential eligibility cannot use the proposed evidence fields

Evidence: contract:81-86,187-191; inventory section 5. The retained policy at
`app/policies/client_passkey_policy.rb:64-83` chooses a credential using `last_step_up_method` and
`last_step_up_credential_ref`, then checks active/UV eligibility. The new evidence value includes
neither credential reference nor method information (`amr`).

Disposition: identify which checks remain enrollment constraints, which remain current credential
eligibility and which ordinary freshness rules are replaced. Provide a trusted carrier for any
retained evidence-credential checks, or explicitly disposition their removal under the accepted
policy. Do not silently keep reading the old root evidence after ordinary cutover, or claim that
retaining the policy unchanged is compatible with the listed value fields. Any added field needs
authoritative provenance; browser-supplied credential IDs are not evidence.

### RV-85 — Medium — Outbox principle is sound, but persistence/delivery shapes remain incomplete

Evidence: contract:171-184. The referenced job was read this session:
`app/jobs/passkey_audit_delivery_job.rb` uses bounded batches, source-row locks, stable
`event_uuid`, Chronicle lookup/uniqueness, identity comparison, local acknowledgement and a raised
failure for retries. It commits across stores without claiming a distributed transaction.

The new draft specifies table names but no event identity, dedup unique constraints, immutable
payload schema, acknowledgement lifecycle, polling/enqueue recovery or crash-after-delivery rule. An
in-memory after-commit enqueue alone could lose delivery. Copying the existing nullable
acknowledgement pattern would contradict the new shapes' declared NULL discipline.

Disposition: define both outbox shapes, event UUID/identity and uniqueness, constrained payloads,
explicit delivery status/attempt facts, retry discovery and Chronicle idempotency. Test committed
row with lost enqueue, Chronicle write followed by lost acknowledgement and concurrent jobs. Require
token preparation/signing to succeed before the OP commit that records issuance; sending the
prepared HTTP response after commit is distinct. The current text does not settle that preparation
boundary. Actual table and delivery contracts are needed before migrations.

### RV-86 — Medium — Claimed existing CSRF response and some integration details are inaccurate

Evidence: contract:61-64 claims 422 via `SignErrorResponses#handle_csrf_failure`. That method raises
for non-JSON at `app/controllers/concerns/sign_error_responses.rb:68` and returns JSON 403 at 70-71;
it is not evidence of a universal 422. Verify the actual new controller inheritance/rescue mapping
before selecting a response. `GET /verification` "any" must still respect its
authentication/authorization and no-store requirements; HEAD behavior is not specified.

Disposition: correct the source claim, specify browser/JSON/HEAD statuses, and test the routed
controller. Do not weaken Rails CSRF handling to fit a proposed table. Fix the contradictory RP
transition descriptions too: the outcome table says errors become CANCELLED or REFUSED, while the
state table says any OIDC error becomes CANCELLED. Distinguish user cancellation from refusal.

## Previous findings and inventory verification

- RV-75: the eight omitted consumption-bearing files and corrected 22 invocation sites are now
  listed. The lexical footprint is clearly distinguished from reachability. It remains a mapping
  input, not proof that every family has a correct public evidence boundary.
- RV-76: explicit evidence and reuse of owner-side token verification are improvements. RV-83/84
  expose remaining binding and data-carrier gaps. Preserve issuer/audience/client checks when
  adapting each owner endpoint; a value's Ruby type alone is not authentication authority.
- RV-77: local transactional outboxes correctly replace diagnostic fallback as the proposed
  durability boundary; RV-85 identifies the concrete schema/delivery work still needed.
- RV-78: token replay is now separated from browser 409 conflicts. The CSRF source claim and
  error-to-state mapping require RV-86's corrections.
- RV-79: OP and RP table ownership, reference states and transition records improve the proposal.
  RV-81/82 and outbox shapes prevent declaring it migration-ready yet.
- RV-80: dynamic/full-reauthentication conditions are explicitly retained. The owner-chosen HTTPS
  class removes the prior URN authority question; its APP-looking hostname is an identifier and does
  not authorize cross-realm access. Window and exact-value semantics need no new decision.

Rechecked previously unread step-up references:

- `authentication_session_revoker.rb:42` includes roots with `last_step_up_method == "totp"` in
  method-specific revocation. Migrate this attribution where ordinary events move, while preserving
  retained-flow/root revocation behavior. It is not a freshness gate to delete.
- `client.rb` matches are a schema comment and `configured_mfa_level_methods` delegation to
  `step_up_methods` at 459-460. The latter is configured-method availability, not proof storage.
- `authentication_base.rb:2804-2810` mentions attribution during primary/MFA session issuance. This
  is not permission to replace login establishment with ordinary step-up; keep the primary method
  and root-login/cooldown anchors independent. The lexical matches alone do not prove every
  inherited runtime path has been exercised.

## New callback integration

`AuthBoundaryAuthorityMap::callback_path_for` returns the canonical sign-in path unconditionally at
`app/values/auth_boundary_authority_map.rb:124-125`; the new flow must select its explicitly
registered purpose-specific URI without changing ordinary sign-in's canonical callback.

`lib/runtime_role.rb:103-109` includes the `verification` prefix, and matching is hierarchical at
154 onward. Thus `base/{app,org}/verification/oidc/callbacks` is already within the Base RP prefix
family; the draft should not assume a new OP role is needed merely because the old list also names
`oidc/callbacks`. Verify the actual resolved route/role and all invariant inventories when
implementing. This source observation is not a runtime route/authorization test.

The ordinary completion route is also used by retained bootstrap/registration. Keep those actions
and dispatch semantics until all retained callers are mapped; the draft's "removed for ordinary
step-up" is acceptable only as a purpose-specific change, not unconditional route deletion.
Resourceful route declarations and exact callback registration are consistent with owner direction.

## Next deliverable and limits

Revise the contract for RV-81 through RV-86, with exact outbox shapes, one-dispatch lifecycle,
pre-commit intended-grant binding and retained eligibility/attribution mapping. Then draft the ADR
amendments already planned. No new owner policy question is necessary for these technical fixes;
formal acceptance and implementation authorization remain pending. Unit 1 cannot start from table
names with unspecified durability or dispatch semantics.

Only this review and an append-only `zero.md` reply were written. No spec, plan, contract,
application or test changes. No migration/test/build/provider/browser verification was performed.
