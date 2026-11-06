# O-9 Visa-mediated ceremony design

Status: owner-reviewed direction; revised on 2026-11-05 per the review recorded in `zero.md`.
Implementation is in progress. The endpoints remain disconnected until their source-write and
recovery paths pass the listed verification.

## Ownership and flow

Auth is the source writer for APP and ORG passkey registration and APP Google/Apple social linking.
WebAuthn options, browser ceremony and attestation verification stay on the Auth origin. The
existing RP ID does not change. Bootstrap registration at `verification/registration/passkey` is
unchanged and out of scope.

1. Base starts the operation from its CSRF-protected passkey-registration or APP social-link route.
   Its server calls the realm-specific Visa endpoint with the registered Base client assertion and
   current Access JWT. The Base route fixes the purpose and provider; neither is chosen by the
   browser. Visa derives actor and grant from verified evidence, checks the current Step-Up event,
   and records a short-lived admission bound to the client, actor, grant `sid`, RP session reference
   and absolute expiry, browser binding, purpose, provider, complete Step-Up event snapshot and OIDC
   authorization transaction. Admission expiry is no later than the Base RP session expiry. Visa
   creates the Auth ticket/admission in this owner boundary; Base does not write OP tickets or
   admission bindings.
2. Visa associates the admission with the existing OIDC authorization context and sends the browser
   through the existing Visa-to-Auth flow. State, nonce, PKCE and browser binding remain owned by
   that OIDC context. Auth receives the admission reference only through the authenticated OP
   context. A URL, form field or callback parameter cannot supply authority, actor, grant or
   provider. A second browser with a copied Visa authorization URL cannot complete the operation.
3. Auth performs the passkey or social ceremony on its origin. Before any credential or social
   source write, Auth returns the browser to a Base confirmation representation. Base accepts only a
   same-origin, CSRF-protected POST from the original RP browser, rechecks its exact RP session and
   browser binding, and calls Visa with its client assertion and current Access JWT. Visa locks the
   matching admission, verifies its attached Auth admission binding and all RP/actor/grant facts,
   then advances `issued` to `browser_confirmed`. The browser returns to the same Auth ceremony.
   Auth resolves the authenticated actor and admission, locks the Zenith actor first, then starts an
   OP authority transaction and locks/rechecks device, root, grant and admission. It requires
   `browser_confirmed` and checks status, expiry, realm, client, actor, grant `sid`, RP session
   reference, purpose, provider, event and current RP-session validity under those locks. It commits
   the source credential/link and exact durable result receipt together on Zenith while the OP
   authority locks remain held. The passkey ceremony must not change its RP ID or origin. No HTTP
   call is made while either database lock is held.
4. Auth commits the Zenith source mutation and exact durable receipt while the OP authority
   transaction still holds the admission row lock, then marks that same admission `source_committed`
   before releasing the OP transaction. This does not create a distributed atomic commit: the Zenith
   transaction commits first, and OP terminalization can still fail or have an unknown
   acknowledgement. On retry, Auth uses a fresh Zenith writer read to resolve the exact receipt; it
   never repeats a source write when that receipt exists. It can then complete the same admission
   under the OP authority locks. Visa's OIDC callback only reads the terminal admission result and
   performs no authorization write. Holding the OP row lock through the source commit serializes the
   source write with Visa-owned RP-session cancellation.
5. Visa returns the browser to Base using the original OIDC state and a non-authorizing completion
   reference. Base rechecks its original state, current RP session and browser binding, then reads
   the result from Visa using its client assertion. Base only displays the confirmed result; it
   performs no credential or social-link write. Missing, expired, replayed, mismatched or
   indeterminate results fail closed.

## Admission, revocation and result records

The existing `client_sensitive_admissions` and `operator_sensitive_admissions` tables require
`secret_digest` for the superseded bearer-secret flow. Do not insert a placeholder, derived or
otherwise meaningless digest. Add purpose-specific Visa admission tables for new O-9 rows, one in
each OP realm database. They bind the admission to the existing Visa OIDC authorization context and
persist the same verified identity and browser/session fields listed above, with an explicit status
and expiry. These additive tables do not contain `secret_digest`. The legacy admission, attachment,
confirmation, redemption and Auth-session schemas remain in place and are not read or written by the
new flow. No table is dropped and no existing row is rewritten.

### Request and response shape

Before, Base creates a credential-registration Auth admission locally and redirects directly to
Auth. There is no Base-to-Visa O-9 API shape or Visa-owned browser-confirmation state.

After, Base's server calls the same-realm Visa owner API with the Base client assertion and Access
JWT. The body uses form encoding and contains only server-derived references and OIDC parameters:

```text
POST /api/v0/sensitive_admissions
{
  "rp_session_ref": "<Base RP session public reference>",
  "rp_session_expires_at": "<Base RP session absolute expiry>",
  "browser_binding_digest": "<SHA-256 of Base browser binding>",
  "purpose": "passkey_registration | social_link",
  "provider": "none | google | apple",
  "state": "<OIDC state>",
  "nonce": "<OIDC nonce>",
  "code_challenge": "<S256 challenge>",
  "redirect_uri": "<registered Base callback URI>"
}
```

Visa derives the actor, root, grant, event, client and realm from the authenticated request and
creates the OIDC authorization context and Auth ticket/admission itself. The body cannot select an
actor, grant, provider outside the fixed route policy, or another RP session. `state`, `nonce`,
`code_challenge` and `redirect_uri` are validated against the registered Base RP and persisted in
the Visa OIDC transaction. The response is
`{"admission_ref":"<opaque selector>","authorization_url":"<Visa same-realm URL>"}`. The reference
only locates the OP record; it cannot authorize a source write or retrieve a result alone. Before
Auth's source write, Base submits a second server-to-server request from its CSRF-protected browser
confirmation POST:

```text
POST /api/v0/sensitive_admission_confirmation
{
  "admission_ref": "<opaque selector>",
  "rp_session_ref": "<Base RP session public reference>",
  "browser_binding_digest": "<SHA-256 of the original Base browser binding>"
}
```

The Base controller derives all values from its authenticated request and browser-bound session; the
body cannot choose actor, grant, realm, client or provider. Visa requires the exact attached Auth
binding, matching active grant and `issued` status, then commits `browser_confirmed`. Replays are
idempotent only for the same immutable binding. Auth's source writer requires that state and cannot
advance from `issued`. At the Base callback, an authenticated Visa result read returns only
`{"outcome":"completed","purpose":"passkey_registration | social_link"}` after exact receipt
verification. Missing, expired, mismatched and indeterminate outcomes use fixed refusal responses.
Client assertions, Access JWTs, OIDC state, authorization codes, provider credentials and browser
proofs never appear in response bodies or logs.

The APP passkey, APP social-link, and ORG passkey O-9 admission tables are purpose-specific. The APP
passkey and ORG passkey tables each require their own step-up ceremony transaction FK and Auth
admission binding FK. The APP social-link table requires its own social ceremony transaction FK and
also records the step-up ceremony transaction and Auth admission binding used only to attach the
Auth browser session. The social transaction FK is authoritative for the provider callback and
candidate; the step-up FK cannot substitute for it. Their shared identity columns are: unique
`public_ref`; fixed `client_id`; `actor_subject`; `grant_sid`; `rp_session_ref`;
`browser_binding_digest`; orthogonal `purpose` and `provider`; verified event `jti`, `auth_time`,
`acr` and `amr`; OIDC authorization transaction reference; Auth ticket and admission-binding
references; and explicit `status`, `expires_at` and timestamps. Status values are `issued`,
`browser_confirmed`, `source_committed`, `refused`, and `cancelled`. Persist the complete event
snapshot: `event_acr` is a non-empty string and `event_amr` is a JSON array of non-empty strings, in
addition to `event_jti` and `event_auth_time`. The Auth ticket/binding reference is created by Visa
and cannot be supplied by Base. APP allows passkey with provider `none` and social link with
provider `google` or `apple`; ORG allows only passkey with provider `none`. The Visa API route fixes
the realm. The table owner supplies `created_at`/`updated_at`; the API derives the identity and
evidence fields from the verified Access JWT, and the transaction reference from the Visa OIDC
request. `rp_session_expires_at` is asserted by the authenticated Base server from the exact current
RP-local session and is persisted; `expires_at` is capped at this value. No tuple or
compound-purpose enum is used.

Visa owns the O-9 RP-session liveness decision. Before Base revokes an RP-local session, it sends an
authenticated, same-realm Visa request identifying the exact `rp_session_ref`. Visa locks the
matching admission rows and changes pending `issued` or `browser_confirmed` admissions to
`cancelled`. Auth's source writer locks and rechecks that same Visa admission row while holding the
actor-first authority boundary. If cancellation wins the row-lock race, Auth refuses without a
Zenith write. If Auth's source commit wins, Base waits for Visa's response and then revokes the
local RP session; the operation linearized before logout. Base must not revoke its local session
when Visa is unavailable or the cancellation result is unknown. No HTTP call occurs while either the
OP admission lock or the Base RP session row lock is held. Existing OP-grant revocation and
back-channel logout remain independently authoritative and are rechecked by Auth. Natural RP session
expiry is covered by the admission expiry cap.

This protocol applies to every Base-local path that revokes or replaces the bound session, not only
the user-facing sign-out route. The implementation inventory must enumerate those writers before O-9
activation; any path that cannot notify Visa before local revocation must fail closed or remain
outside the enabled flow.

On APP and ORG Zenith, the passkey registration outbox row is the durable source receipt. Its
`operation_ref` is the new Visa admission reference, and exact replay compares event type, realm
surface, actor and credential external ID. Add a partial unique index for registration operation
references. APP social linking gets an additive immutable source-receipt table committed with the
external identity row; it records the admission reference, actor, provider, canonical identity
reference and source commit time. No provider token, assertion, state, browser proof or credential
secret is persisted in either receipt.

The receipt is the source of truth for a successful Zenith commit. A retry may return success only
after a fresh writer read confirms the exact receipt and source row. A missing or unreadable receipt
after an unknown commit acknowledgement is indeterminate, never proof of rollback. Audit delivery
uncertainty does not repeat the source mutation. Receipt retention must exceed the OIDC and recovery
windows.

## Superseded flow retirement

Remove the callable `SensitiveAdmissionCeremony#attach!`, `#confirm!` and `#redeem!` writers, their
Base-to-Auth handoff endpoints and temporary routes, and tests that only asserted those transitions.
Keep the legacy database schemas as inert historical storage until a separately approved cleanup.
The new implementation must not leave a route or operation that can start or complete the old
bearer-secret flow. Existing independent OIDC ceremony-binding `redeem!` writers are unrelated and
remain unchanged.

## Required verification before enabling the routes

- A second browser with a copied Visa authorization URL cannot complete the first browser's
  admission.
- Callback and API substitution across actor, realm, provider, client, purpose, event, grant `sid`
  and RP session are refused without a source write.
- Revoking the RP session after admission issuance but before Auth completion causes refusal.
- Visa cancellation failure prevents Base from revoking the local session; cancellation and Auth
  source completion serialize on the Visa admission row.
- Concurrent completion creates exactly one credential/link and one source receipt; exact replay
  returns the same result, while conflicting replay refuses.
- Source rollback creates no receipt and no OP terminal success. Unknown Zenith commit
  acknowledgement is resolved from a fresh writer connection; it never causes a duplicate write.
- OP terminalization rollback or lost acknowledgement is recoverable from the exact source receipt.
- Logs and error responses contain no OIDC state, authorization code, provider credential, client
  assertion, access token or browser proof.
- Passkey options and attestation verification remain on Auth's origin with the existing RP ID.

No Auth CSRF or Origin exception is introduced. O-9 authorization remains inactive until these
boundaries and their tests are complete.
