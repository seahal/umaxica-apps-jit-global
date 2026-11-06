# Org Emergency Access (Restricted Mode)

Emergency Access is intended to provide an Entra-free way for an Operator to sign in to the org
surface and run the resulting ORG Root session under a restricted authentication context. The
current Auth-to-Visa implementation does not yet carry Standby through Root issuance; see
[Current end-to-end issuance status](#current-end-to-end-issuance-status).

It exists for the case where the Entra ID path is unavailable. It is not a convenience alternative
to normal sign-in, and it is not a privilege: it can only ever be narrower than the Operator's
ordinary session.

## Terminology (R5-WU18)

The session context this ceremony produces is named **Org Standby** in code and data: the context
value is `standby` (`AuthenticationContextValue::STANDBY_KEY`), the policy is
`OrgStandbyAccessPolicy` and the ceremony concern is `SignOrgStandbyPasskeyCeremony`. The pre-R5
literal `emergency` is no longer accepted from an access token; it resolves to the fail-closed
UNKNOWN context. Public URLs (`/sign/in/emergency/...`), their controllers, challenge purpose
`emergency_sign_in` and user-facing copy keep their existing names. "Emergency Access" below refers
to this Standby context. Unrelated Emergency mechanisms (identifier HMAC emergency rotation, token
emergency service, emergency session revocation events) are a separate matter and unchanged.

## Scope

Org only. The `app` and `com` surfaces have no Emergency ceremony, no Emergency routes, and no
column to record an authentication context in; their sessions are Normal by construction. Sign-up
and invitation provisioning are unchanged on every surface.

## The two ceremonies

Normal org sign-in is two-stage. Entra identifies the Operator; a credential authenticates them.
Entra alone completes nothing.

```text
Entra ID  ->  Passkey
```

Emergency Access uses one credential stage and no Entra:

```text
Emergency sign-in  ->  Passkey  ->  Standby Auth evidence  ->  OIDC Root issuance
```

The final arrow is an intended continuation, not a currently working Standby Root path. The current
Visa ORG issuer creates a Normal-context Root; see
[Current end-to-end issuance status](#current-end-to-end-issuance-status).

Emergency Access uses the Operator's **existing registered passkeys**. There is no separate
emergency passkey registration, and no separate emergency credential of any kind. Secret/SecretKey
is **not** available in Emergency Access: Emergency Access is passkey-only.

|                   | Normal                        | Emergency                                 |
| ----------------- | ----------------------------- | ----------------------------------------- |
| Entry             | `GET /sign/in` -> Entra       | `GET /sign/in/emergency/passkey/new`      |
| First stage       | Entra ID                      | none                                      |
| Credential        | Passkey                       | Passkey only                              |
| Actor selected by | the pending Entra transaction | the submitted identifier                  |
| Challenge purpose | `authentication`              | `emergency_sign_in`                       |
| Auth evidence     | `normal`                      | `standby`                                 |
| OIDC Root today   | `normal`                      | `normal` (Standby propagation incomplete) |
| Step-Up           | available                     | **unavailable**                           |
| Sign-out          | `/sign/out`                   | `/sign/out` (the same ceremony)           |

## Current end-to-end issuance status

The Emergency Passkey verifier calls `establish_signed_in_session!` with
`AuthenticationContextValue::STANDBY_KEY`. For an OIDC-started ceremony, `AuthenticationBase`
records authentication evidence and leaves Browser Root issuance to the later authorization
continuation. `Visa::Org::AuthorizationBaseController#login_for_oidc` currently calls `log_in` with
`AuthenticationContextValue::NORMAL_KEY`. Therefore the checked-in path does not issue a
Standby-context ORG Browser Root from this ceremony, even though the Auth-side evidence is marked
Standby. The Emergency flow must not be treated as an available Entra-outage sign-in path until the
exact verified ceremony is bound to its OIDC authorization and that binding is checked at Root
issuance. A request parameter, actor identity, or authentication method alone cannot establish that
binding. An Auth-side test that stops after recording evidence does not demonstrate a Standby Root.

## Routes

```text
GET  /sign/in/emergency/passkey/new
POST /sign/in/emergency/passkey/options
POST /sign/in/emergency/passkey/verification
```

Resourceful, and the same resource shape as the normal passkey ceremony
(`adr/rails-routing-resourceful-policy.md`). The existing normal org sign-in URLs are unchanged.

There is deliberately **no** emergency sign-up route and **no** emergency sign-out route. Both modes
terminate through the one canonical sign-out ceremony.

The three Emergency entry controllers declare the `sign_in` classification and a fixed standby-only
exception to the normal ORG Sign In stop. The exception is restricted to those named controllers and
cannot be selected with a request parameter. Admission, credential eligibility and the existing
rate, CSRF and verification controls still apply.

## Eligibility

`OrgStandbyAccessPolicy.eligible?(operator)` is the single authoritative decision. It currently
returns the ordinary sign-in eligibility, so every Operator who may sign in at all may use Emergency
Access.

It exists as its own decision so that restricting Emergency Access to a subset of Operators later is
a change to one method, not a hunt through controllers, concerns, views, and token code. It is
consulted twice per ceremony -- when the options are issued and again at verification -- because
eligibility can be withdrawn between the two requests.

Every syntactically valid identifier receives an empty `allowCredentials` array. Real credential IDs
are never mixed with random padding: repeated responses could otherwise identify the stable real
IDs. Challenges retain the selected Operator's fixed-length public reference, or an invalid
fixed-length sentinel for unknown/ineligible selections. A sentinel challenge cannot authenticate
any Operator. See [response nondisclosure](../../adr/credential-response-nondisclosure.md).

Org registration requires discoverable credentials. Existing non-discoverable keys remain usable in
normal Entra-bound sign-in but require re-registration before Emergency Access can use them. No
database update can convert a non-discoverable authenticator credential. Establish usable
discoverable keys before depending on Emergency Access during an Entra outage.

Nothing reachable from an Emergency session can write the inputs this policy reads. An Emergency
session cannot grant or widen its own eligibility.

## One WebAuthn implementation, two policies

Emergency Access is a different authentication policy, not a different cryptographic implementation.
**This is a security requirement, not a style preference:** a duplicated ceremony is one where a
future fix lands in one path and not the other.

Both org ceremonies run through `PasskeySignInFlow` and `PasskeyCeremonyContext`, and therefore
through the same `Webauthn::AssertionVerifier` and `Webauthn::ChallengeStore`. Shared, and shared
deliberately: request-option construction, challenge creation, persistence, expiry, one-shot
consumption, challenge binding, actor binding, credential-ownership validation, RP ID and origin
validation, user verification, signature verification, sign-count verification, authenticator
metadata, passkey status validation, `last_used_at`/`uv_verified_at` updates, CSRF, Turnstile, rate
limits, timing defences, normalised error behaviour, risk-event emission, logging redaction, and
WebAuthn exception handling.

The differences are narrow hooks:

| Hook                        | Normal                           | Emergency                   |
| --------------------------- | -------------------------------- | --------------------------- |
| `passkey_ceremony_purpose`  | `:authentication`                | `:emergency_sign_in`        |
| `find_active_passkey_actor` | the Entra transaction's Operator | the identifier, if eligible |
| `allow_passkey_sign_in?`    | must match the Entra transaction | must still be eligible      |
| `perform_passkey_sign_in`   | Normal context                   | Emergency context           |

`EmergencyPasskeyVerifier`, `EmergencyWebauthnVerifier`, and `EmergencyChallengeStore` must not
exist. `test/unit/security/org_emergency_access_invariants_test.rb` enforces both the shared-seam
and the no-parallel-implementation rules.

## Challenge purpose separation

`Webauthn::ChallengeStore::PURPOSES` is a closed registry of separate namespaces, not labels:

```text
authentication  !=  emergency_sign_in  !=  step_up  !=  registration
```

A challenge issued for one purpose is rejected by every other verifier, in both directions, and the
rejecting consumption still burns the challenge. `Webauthn::UvPolicy` carries a matching
`emergency_sign_in` purpose, required like every other.

## Entra-to-Operator binding

`OrgNormalSignInTransaction` holds the state between the two stages of normal sign-in. It is
session-backed, in the same place and with the same shape as the pending-MFA state that already
gates a second factor, because the ceremony spans two requests of one browser session rather than
the sign/base boundary.

It binds the Operator, the Entra identity, the ceremony purpose, its issue and expiry times (10
minutes), and it is one-shot: it is consumed before the session-establishing call, so a replayed
second stage has nothing to continue.

The second stage reads the Operator **only** from this transaction. The identifier parameter is not
consulted at all, and the passkey page does not render a field for one. An attacker who completes
Entra as Operator A therefore cannot authenticate as Operator B: the challenge is issued against A,
the challenge store returns A at consumption, and credential ownership is checked against A a second
time.

Without a valid transaction, `/sign/in/passkey/*` refuses to run. Permanent-secret sign-in routes
were retired; there is no secret fallback for the normal or emergency org ceremony.

## Authentication context and token claims

`AuthenticationContextValue` is a closed registry of `normal` and `standby`.

- **Durable authority:** `operator_tokens.authentication_context`. Written once, at session issue,
  and never updated afterwards. `NULL` means Normal, which is what every session predating Emergency
  Access was.
- **Claim:** `authn_ctx`, present on every access token. `acr`, `amr`, `scp`, `sid` and the rest of
  the token keep their existing meanings.

This is deliberately **not** the historical token-status state. `RESTRICTED` (103) is the retired
session-limit placeholder that is no longer issued; the session-limit waiting unit is a resolution
with no session (`docs/security/session-limit.md`). Authentication context is read from the durable
token context and is never inferred from historical status 103.

Authentication context and DBSC binding are independent session properties. Session inventory may
label a session Emergency only from the persisted authentication context. `dbsc_enabled?`, binding
method, and device-bound credential state must never be used to infer Normal or Emergency mode.

Legacy non-OIDC consumers retain the general claim reader's blank-to-Normal behavior. OIDC Access
acceptance has a stricter contract: `authn_ctx` must be an explicit string from the closed registry
and must equal the current bound root's context. A missing, null, empty, unknown or wrong-type claim
is refused. A signed `normal` claim bound to an Emergency root is also refused; signature validity
alone cannot establish the correct context. Existing issuer, audience, client, subject, session and
expiry checks remain necessary.

Issuance derives context from the authoritative root on initial issue, Code exchange, Refresh and
reissue. App/com roots are Normal because they have no alternative-context column. On org roots, SQL
`NULL` and explicit `normal` mean Normal, and `standby` means Standby (Emergency Access). The NULL
storage representation is not a missing token claim and does not require a data backfill. An unknown
or empty stored context cannot authorize issuance.

This correction can require reauthentication for an existing RP credential that lacks context or
contradicts its root. Correctly bound existing credentials remain usable. A separately valid Refresh
credential may obtain corrected Access through the existing rotation authority, preserving the root
context, lifetime and replay rules. A live root without a valid RP continuation requires the
ordinary Code Flow; root reuse is governed by its existing rules. A rejected Access token does not
authorize arbitrary root lookup, reconstruction of a Refresh credential or inference of Normal. No
new root login or cooldown anchor is created by credential reissue.

## Capability model

Authorization is:

```text
DB role permission  AND  session capability  AND  the ordinary policy rule
```

DB-backed roles remain the authority for role membership. The session capability layer can only
narrow what those roles already allow; Emergency authentication never expands DB authorization and
never introduces a second role system.

An Emergency session is fully authenticated, so it answers to the same policy rules as a Normal
session. What it cannot do is Step-Up (next section). An operation is withheld from Restricted Mode
by giving it a Step-Up gate, not by listing it in the capability layer.

Two mechanisms carry the capability layer:

1. **Scopes.** `AuthenticationContextValue#constrain_scopes` touches a token's `scp` claim only for
   an unrecognised context, which keeps the structural scopes and loses every capability-named
   scope. A Standby token issues exactly the same scopes as the same Operator's Normal token
   (`authenticated`, `domain:operator`, `read:org`, `write:org`); withholding a scarce operation
   happens at that operation's Step-Up gate, so the scp claim is not a second place where the same
   restriction could drift apart.
2. **An Action Policy pre-check.** `ApplicationPolicy` runs `deny_capability_restricted_context`
   before every rule. Normal and Emergency contexts pass it and meet the ordinary rule; it never
   widens a rule that denies. An unrecognised context fails it for every rule instead of falling
   through to Normal.

`test/unit/security/authentication_context_operation_inventory_test.rb` enumerates zero-argument
predicate rules declared in each loaded policy class's `ApplicationPolicy` ancestry, excluding
inherited `Object` methods and argument-taking helpers. It applies each rule through Action Policy's
`apply` path under installed Normal, Standby and unknown token claims, so the real application
pre-check runs. The generic comparison uses no actor or record except for the authentication access
context; it verifies context parity and fail-closed behavior, not actor-specific permissions or
public HTTP operations. AC-41's per-operation checks therefore remain open: the Step-Up-required
operation inventory must be derived from policy and checked for Standby refusal plus Normal Step-Up
success; writes outside that inventory also need an explicit disposition.

A focused recheck on 2026-11-02 passed the four ORG enforcement-case operations and IAM grant and
revocation on both sides of the context boundary: the Standby controller file passed with fresh
matching Step-Up evidence (6 runs, 78 assertions), and the Normal enforcement/IAM controller files
passed (28 runs, 128 assertions). The Standby file also covers contact and Telephone refusals. These
are selected public cases; the policy-derived operation inventory, all remaining operation pairs,
and the disposition of writes outside the inventory remain open. See
[`wua6-standby-enforcement-matrix-recheck-B5J9.md`](../../evidence/2026-11-02-wua6-standby-enforcement-matrix-recheck-B5J9.md).

The support-account session-revocation and IAM grant screens are now covered through the owner API:
an ORG Standby access token with their required grants receives `403 step_up_required` without an
active-session count or grantable-capability list; the same operator in Normal with fresh matching
Step-Up receives the screen data. This closes only these read boundaries; it does not close the
policy-derived AC-41 operation matrix.

Focused ORG HTTP checks also refuse Standby Passkey rename/deletion, Email and Telephone
registration, Secret bootstrap, session revocation, and the tested enforcement mutations. These
cases preserve the Standby context and leave their protected records unchanged. They cover selected
operations only; the policy-derived Normal Step-Up / Standby comparison and actual Standby Root
issuance remain open. See `evidence/2026-11-02-wua6-org-owner-stepup-ops-N3F6.md` and the linked
operation-specific evidence below.

A separate Normal ORG integration flow now passes real WebAuthn verification in Auth, Base result
consumption, freshness resolution, and access to the protected Passkey page (5 tests, 35 assertions
in the affected file). It does not perform a sensitive mutation after Step-Up, so it verifies the
shared ceremony boundary but does not close AC-41's per-operation comparison. See
`evidence/2026-11-01-wua6-normal-step-up-fixture-isolation-F7N3.md`.

One write outside the catalogued Step-Up scopes has an explicit current-policy disposition:
`PublishingEntryPolicy#create?` requires an active Operator but has no Step-Up requirement. Under
R-AU-10, its policy result is the same for Normal and Standby; the focused policy check confirms
that parity and refuses an unknown context. A fixture-free integration test now calls the Base ORG
Publishing create API with a valid Edit client assertion and signed access tokens bound to
separately seeded Normal and Standby roots. Both requests create an entry attributed to the same
active Operator. This verifies the downstream HTTP authorization path with a directly seeded Standby
root; it does not demonstrate Visa issuance from the Auth Standby ceremony. That Root issuance path
remains unavailable. See `evidence/2026-11-01-wua6-publishing-http-parity-P8J2.md`.

The pre-check reads the context from the verified access-token claims that
`AuthenticationBase#load_from_token` records and `ActorSupport#resolved_current_token` returns.
Before 2026-09-19, `resolved_current_token` read the preference token loader instead. That left the
pre-check with no claims, so it treated every session as Normal.

## Step-Up is unavailable in Restricted Mode

This is not "step-up has not happened yet". The authentication context is not eligible to perform
step-up-protected operations at all, however valid the Operator's step-up passkey is. There is no
separate Emergency step-up mechanism, and normal step-up behaviour is unchanged. The Base ORG
Step-Up start and first-authenticator bootstrap pages also refuse Standby before offering or issuing
any verification admission.

Three independent layers enforce it:

1. `VerificationBase#require_step_up!` and `#enforce_step_up_prereqs!` refuse the ceremony entry
   with 403 before any credential is requested.
2. `StepUpResolver` never reports a requirement as satisfied for an Emergency session, so a session
   that somehow held freshness columns still cannot authorize a sensitive action.
3. `IdentityStepUpCeremonyFreshnessCommitter` refuses to write freshness onto an Emergency session,
   which is where acme commits it (`docs/security/step-up-ceremony-delegation.md`). An operation is
   unavailable to an Emergency session exactly when it carries a Step-Up gate (`step_up only:` or a
   `require_*_step_up!` callback). A sensitive operation without one is reachable from Restricted
   Mode, so adding a sensitive operation means adding its gate. The inventory of write actions that
   still lack one is tracked in GitHub issue #884.

## No in-session mode transitions

There is no supported transition between authentication contexts inside a session.

```text
normal     -> emergency    forbidden
emergency  -> normal       forbidden
```

Forbidden by every route: visiting an Emergency URL while normally authenticated, visiting normal
sign-in while authenticated through Emergency Access, completing Entra during an Emergency session,
re-running the passkey ceremony, running the secret ceremony, step-up, access-token rotation,
refresh-token rotation, session renewal, and any session field change.

Changing mode is:

```text
sign out  ->  unauthenticated  ->  a new sign-in ceremony
```

`AuthenticationModeSwitchGuard` replaces the guest-only rejection on the org sign-in entries with a
403 that names the sign-out ceremony, so an authenticated operator is told what to do rather than
bounced to a dashboard that explains nothing.

## Session lifetime and continuation

Session lifetime and refresh architecture are unchanged: an Emergency session uses the ordinary org
lifetime. Shortening it is possible follow-up work and is deliberately not attempted here.

The hard invariant is continuity of context, not lifetime:

```text
Emergency  +  refresh / rotation / renewal  ->  Emergency
```

Every access token -- first issue, refresh rotation, and mid-session reissue -- derives `authn_ctx`
from the session row, so there is nowhere else for the value to come from. Refresh rotation replaces
the session row, so `RefreshTokenable.copy_rotated_token_authentication_context` carries the context
onto the replacement; without it a rotation would silently produce a Normal session.

## Sign-out

Both modes terminate through the existing canonical sign-out ceremony. Nothing about sign-out is
duplicated for Emergency Access. Signing out of an Emergency session and signing in normally
produces a **new** session row rather than the old one relabelled.

## Restricted Mode in the UI

An Emergency session is presented as `制限モード — Emergency Access`.

The indicator is published by `SurfaceChrome` as a shared layout prop and rendered by
`SurfaceLayout`, above everything else in the header, for the whole life of the session. No page
supplies it, so no page can omit it. It is derived from the session row the request authenticated
against -- never from a request parameter, a browser-writable cookie, or page state.

There is no "解除" or "switch to normal mode" control. The one offered way back is
`サインアウトして通常モードでサインインし直す`, which ends the session first.

Hiding navigation is not authorization. Unavailable operations are denied server-side regardless of
what the UI shows.

## Related

- `adr/acme-sign-core-base-port-boundary.md`
- `adr/org-entra-id-sign-in-boundary.md`
- `docs/identity/authority-boundary.md`
- `docs/security/session-token-authority.md`
- `docs/security/step-up-ceremony-delegation.md`
- `docs/security/webauthn-architecture.md`
- `docs/security/webauthn-security-invariants.md`
