# O-9 implementation design

Status: working implementation design for the accepted revision 13; not evidence of implemented
behavior. This document fixes the protocol choices needed by unit 6b. Revision 13 remains the
governing contract. Existing bootstrap and legacy admission flows retain their own entry and
lifecycle.

## Owners and persistent records

Create equivalent tables in `op_base_app` and `op_base_org`, owned by `OpBaseAppRecord` and
`OpBaseOrgRecord`. The RP database is not queried from Auth or Visa. An admission row has NOT NULL
columns for: a random public reference; a SHA-256 digest of a separate 256-bit random admission
secret; realm; registered Base client ID; actor OIDC subject; OP grant public `sid`; Base RP-local
session public reference; browser-binding digest; purpose; provider; proof event `jti` and
`auth_time`; issuance time; expiry; and status. Store the full proof snapshot only if needed for the
existing verifier, and never store the bearer token or raw browser nonce. Purpose is
`passkey_registration` or `social_link`; provider is the explicit enum `none`, `google`, or `apple`,
with a database check requiring `none` for passkey and the two real providers only for APP social
link. ORG has no social-link purpose. Reference and secret digest have unique indexes. References
identify records; they are never authority by themselves.

Status has a NOT NULL checked enum: `issued`, `attached`, `confirmed`, `redeemed`, `cancelled`.
Every transition locks the admission row and checks the current status and the OP database clock;
expiry is a condition checked at every transition, not a NULL or a background job. Attach,
confirmation and redemption have their own NOT NULL fact rows, each with a unique admission foreign
key. Attach records a server-derived digest of the freshly issued Auth ceremony cookie and a random
confirmation reference; confirmation records its timestamp. Redemption records the digest of the
newly rotated and admitted Auth ceremony cookie, its time, a random ceremony public reference and
continuation expiry. The attached and admitted digests differ: the O-9-specific session transition
revokes the attached session and issues a replacement. This session uses its own host-only cookie
and is separate from the legacy Auth ceremony session: the legacy admitted-purpose CHECK does not
include social link, so reusing an unrelated legacy purpose would grant the wrong authority. The
continuation resolves the current cookie server-side and requires the active admitted session
matching the redemption digest. Neither digest is accepted from a browser parameter. Unexpected
additional rotation fails closed until an explicit replacement protocol exists. Fact insertion and
the matching status update commit in one OP transaction. Unique constraints and status checks reject
parallel or repeated transitions, including repeats from the same session. The scheduled retention
worker may remove only terminal admission facts whose expiry, last update, continuation expiry and
delivered closure accounting timestamp are at least seven days old. A missing or undelivered closure
event retains the records. Auth sessions are not restricted by an admission foreign key: the facts
retain non-secret digest snapshots, and any missing or inactive session fails continuation closed.
This keeps existing session purgers independent and does not delete Chronicle accounting. An expired
record cannot be reactivated by cleanup.

Create an OP-owned continuation record atomically with redemption. It fixes admission ID, realm,
actor subject, grant SID, purpose, provider, Auth ceremony ID, creation and continuation expiry,
with explicit checked status and one-use child facts for each security-sensitive result. The
continuation is **not** an access token, login session, general-purpose step-up grant, or authority
for a different action. It is readable only in its owning Auth/OP realm. Auth resolves the actor
from the subject and uses this record plus the actual Auth host-only ceremony cookie to authorize
only the admitted operation. Never put the admission secret or continuation authority in a URL,
logs, provider state, or a browser-readable cookie. Resolve the actor afresh and check active status
before writes.

At issuance the expiry is
`min(OP database now + 5 minutes, event auth_time + StepUpEvidenceValue::MAX_AGE_SECONDS, access-token exp)`.
The last bound prevents an admission from outliving the credential that authorized issuance. Redeem
before this deadline; an already redeemed ceremony has its own bounded deadline, fixed at issuance
of the continuation and no later than the existing equivalent passkey or social ceremony lifetime.
The admission deadline does not itself silently extend the step-up event. A callback after the
continuation deadline is rejected. Browser-initiated restart is a new authorization and requires a
currently valid RP session and current step-up evidence.

## Issue and transport

1. Base's normal, CSRF-protected POST authorizes the requested operation for the currently
   authenticated RP-local session. It resolves the signed access-token event with
   `StepUpEvidenceResolver`, checks its actor and cell, and creates a fresh unpredictable host-only
   browser nonce in the Base session. It calls the Visa endpoint with the Base Self-RP's
   `private_key_jwt` bound to that exact endpoint and the verified access token. The body contains
   only the RP session public reference, a domain-separated digest of the nonce, and an allowlisted
   purpose/provider selected by the Base route. Reject duplicate, malformed, unknown or mismatched
   inputs; client-supplied subject, root token and grant are not accepted as authority. The nonce
   itself need not leave Base.
2. `POST /api/v0/sensitive_admissions` on the realm's Visa host authenticates the assertion and
   access token exactly as the existing owner API, verifies the registered Base client and realm,
   derives actor and grant from the verified token, and obtains fresh owner-side
   `StepUpEvidenceResolver` evidence. Under principal writer lock followed by OP device, root and
   grant locks, `StepUpEvidenceVerifier` rechecks the event, root/device/grant status, subject and
   current authorization. It creates the admission in that transaction. OP does not claim to verify
   the RP session reference: its authenticated Base caller vouches for that local binding and must
   recheck it on confirmation. The endpoint returns the public reference and secret only in a
   no-store server response. A failed check or uncertain issuance outcome refuses; no fallback to
   root-token authority.
3. Base renders a no-store, no-referrer, frame-denied document containing a POST form to the exact
   configured Auth realm endpoint. Its body contains the reference and secret; it contains no access
   token or nonce. Do not redirect with a 307 carrying unrelated Base form fields. A cross-origin
   POST cannot carry an Auth CSRF token: this single admission-entry action instead strictly
   validates the `Origin` against the configured Base origin, rejects missing/multiple/incorrect
   origins and malformed content types, and verifies the secret in constant time. It accepts no CORS
   access. This is a narrowly classified cross-origin entry, not a general CSRF exemption.
   Rotate/issue an Auth host-only ceremony cookie on attach to prevent fixation, while preserving
   isolation from any existing signed-in identity. The body and headers must be excluded from
   parameter/request logging.
4. `POST /sensitive_admission` on Auth locks the OP admission on the writer, checks secret digest,
   purpose, expiry and `issued`, creates a fresh Auth ceremony session and attach fact, and
   transitions to `attached` in the same OP transaction. The response is a 303 to the RP
   confirmation representation with the random confirmation reference only. This reference is a
   non-authorizing lookup handle: it cannot cause a transition or start the operation. Never include
   the admission reference or secret in the redirect. Do not attach an already-attached admission or
   reuse a preexisting ceremony session.

## Base confirmation and Auth redemption

5. The new Base RP confirmation GET is served by `rp-base-app-ww` or `rp-base-org-ww`, not the
   existing `BaseCeremonyBindingConfirmation` route, whose `RuntimeRole` owner is `op-base-*`. GET
   renders a no-store, frame-denied CSRF-protected confirmation form and performs no write. Base
   obtains the expected RP session reference and browser digest through a read-only Visa owner
   endpoint authenticated by the same registered client and a currently verified access token, or an
   equivalently authenticated owner response. It checks the actual RP session is active, has the
   stored public reference and same actor/grant, and compares the digest with the nonce in this Base
   browser's host-only session. It rejects missing nonce, changed session, expired admission,
   malformed or wrong-realm reference and access-token failures. The reference is not itself browser
   proof.
6. The Base confirmation POST repeats every session, nonce, authorization and CSRF check immediately
   before calling `POST /api/v0/sensitive_admission_confirmations` on Visa with a fresh
   exact-audience assertion, verified access token, confirmation reference, RP session reference and
   browser-binding digest. Visa derives actor and grant again, locks the admission and attached fact
   on the OP writer, and compares all bound fields, expiry and `attached` status before inserting
   the confirmation fact. No caller-provided actor/grant is trusted. A refresh that drops step-up
   evidence fails this confirmation closed. Visa returns only success or a generic denial, with no
   secret. After confirmed success Base navigates to an Auth continuation GET with only the
   confirmation reference; it is not proof of Auth browser possession.
7. Auth checks the host-only ceremony cookie against the attach fact. GET is representation only; a
   same-origin, Auth-CSRF-protected POST locks admission and continuation, verifies the confirmation
   and matching Auth ceremony, rechecks deadline and status, and atomically inserts redemption and
   continuation facts. Only then may Auth display passkey registration or begin a social provider
   redirect. A different browser with only the admission secret or confirmation reference cannot
   satisfy both original Base nonce/session and attached Auth cookie. In particular, no GET
   automatically confirms or redeems.

All response bodies, transport forms and redirects use the configured realm hosts, TLS, no-store and
no-referrer. The only cross-origin entry bypass is the explicit Base-origin-checked POST above. A
confirmation reference may appear in a URL solely as a lookup handle; it is not the admission
secret, OAuth callback state or proof of browser possession. Refuse framed navigations and
duplicated admission parameters. Fail closed on missing Origin rather than falling back to Referer.

## Continuations and commit boundaries

Passkey settings registration uses a dedicated Auth route distinct from
`verification/registration/passkey` bootstrap. Before options and attestation, load the active
continuation using the Auth host-only ceremony cookie; require `passkey_registration`, matching
realm, actor and grant. Bind challenge, RP ID, origin and candidate to that continuation and consume
each challenge once. Base finalization rechecks its authenticated RP session and browser nonce and
accepts only a candidate associated with the same continuation, actor, grant and purpose. Keep the
bootstrap route and its eligibility contract independent. Do not treat a successful attestation as
proof of a new step-up event.

For APP social link, Auth derives provider from the continuation; it does not accept a provider
override from the browser. Bind the existing provider flow state, callback transaction and
completion candidate to the continuation, Auth ceremony, actor, grant and provider. Existing
login/signup social flows retain their own semantics. Callback validates state and provider normally
and stages a one-use candidate; it does not bind an identity merely because a provider callback
arrived. The final CSRF-protected completion POST checks the Auth cookie and candidate, authorizes
the same actor and exact provider, and commits once. Replace the current requirement for a separate
Auth root login cookie and legacy `consume_step_up_evidence!` with continuation authority; do not
turn the continuation into a general signed-in session.

Before either principal credential write, recheck the actor and active OP device/root/grant chain
under the accepted O-10 ordering: lock the Zenith actor first, then OP device, root, grant,
continuation and candidate in a documented consistent order; commit the Zenith mutation while OP
locks remain held. Check realm, actor, grant, purpose/provider, continuation lifetime, candidate
status and current policy at that boundary. There is no atomic distributed commit. In the same
Zenith transaction as the credential mutation, insert a durable operation receipt whose unique key
is the randomly generated continuation public reference and whose NOT NULL columns include actor
reference, realm, purpose, provider and outcome. A uniqueness conflict refuses a second mutation; it
does not independently authorize the caller to read an outcome. The receipt is also the accounting
record for the committed change. Commit Zenith before recording OP completion, while holding OP
locks. A known principal rollback leaves no successful operation; do not record OP success before
that commit. If the principal commit outcome or subsequent OP commit outcome is unknown, return
failure/unknown and do not retry the mutation or issue another authorization automatically. An
operator can reconcile the receipt against the OP continuation without secrets. This protocol must
also conform to O-10's final outcome implementation; an ordinary nested transaction is insufficient.
No network calls occur while these database locks are held.

## Failure and concurrency requirements

- Network/storage uncertainty at any issue, attach, confirm or redeem boundary fails closed. Never
  retry a possibly committed attach, confirmation or redemption as a fresh transition. An observed
  duplicate is a refusal, not proof of the caller's ownership. The user can start a new ceremony
  only through a new explicit Base POST with current evidence.
- An issuance response lost after commit can leave an unusable orphan until expiry; this does not
  authorize another issuance automatically. A lost attach response likewise strands that attempt. A
  lost confirm or redemption response must not trigger a second provider start or credential
  operation. A record status lookup is not itself authority to continue; recovery requires proving
  both stored browser bindings and the exact ceremony and must be explicitly implemented and tested,
  otherwise reject and restart.
- Recheck expiry using the OP database clock after locks are obtained. Row locks plus unique facts
  ensure only one competing attach, confirm, redemption or final candidate consumption wins. Do not
  accept status or facts from replicas.
- Switching RP session, changing actor/grant/client/realm, missing nonce, wrong provider, revoked
  grant, expired proof or a replaced Auth ceremony all refuse. The nonce must be rotated at new
  issuance and never silently regenerated during continuation. A second initiation may invalidate an
  older pending browser flow, which must fail closed.
- Record fixed accounting outcomes without raw secrets, tokens, nonce, assertion, callback state,
  provider credentials, form bodies or headers. Do not place any such values in exceptions, URLs,
  traces or access logs.

## Required verification and existing-code deltas

Cover APP and ORG passkey, APP Google and Apple link, and the unchanged bootstrap route. Include
wrong realm/client/subject/grant/purpose/provider/session, CSRF and Origin failures, missing/changed
nonce and cookie, duplicate fields, event and admission deadline boundaries, revocation and actor
disable, invalid access token, network ambiguity, and absent/failing persistence. Exercise
concurrent attach, confirmation, redemption and final commit with real database transactions;
exactly one succeeds. Test a stolen admission and confirmation handle in a second browser before and
after attachment, including an attacker-controlled Auth ceremony; neither may start the operation
without the originating Base browser's confirmed session. Test provider callback substitution and
replay, passkey challenge/candidate replay, refresh removing step-up, and loss of each response.
Verify no admission secret, provider state or token appears in URL, Referer or logs. Run scoped
checks and relevant browser/session regression tests, including legacy/bootstrap non-interference,
before activation.

Current code does not yet implement this protocol. `Auth::*::CeremonyBindingsController#show`
accepts GET entry references; `AuthAdmissionBinding` requires legacy parents/root bindings; the
existing Base confirmation owner is OP, not the RP process; `BaseIdentityPasskeyManagement#create`
calls the root-token issuer; and Auth social completion expects a root login session and consumes
legacy step-up evidence. Those paths require deliberate replacement or isolation for O-9, not a
permissive fallback. Existing admission status diagrams remain intact; add and maintain the O-9
transition diagram and inventory with the implementation. Ensure retention, audit, database access
roles and exact host/origin configuration are verified against deployment before use.

No contradiction with the accepted revision 13 is intended. The access-token-expiry bound and the
explicit Origin check are stricter fail-closed implementation choices. The revision 13 requirement
to review the precise design before implementation is superseded in workflow by the later 15:00
owner instruction to implement unit 6b and report the endpoint and persistence together; O-9 and the
lock-order work still require their specified review before unit 7. The current legacy code
conflicts with the desired behavior as described above and must not be treated as an implementation
of it.
