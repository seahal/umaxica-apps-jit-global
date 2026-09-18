# Org Emergency Access (Restricted Mode)

Emergency Access is a second, Entra-free way for an Operator to sign in to the org surface, and the
restricted authentication context the resulting session runs under.

It exists for the case where the Entra ID path is unavailable. It is not a convenience alternative
to normal sign-in, and it is not a privilege: it can only ever be narrower than the Operator's
ordinary session.

## Scope

Org only. The `app` and `com` surfaces have no Emergency ceremony, no Emergency routes, and no
column to record an authentication context in; their sessions are Normal by construction. Sign-up
and invitation provisioning are unchanged on every surface.

## The two ceremonies

Normal org sign-in is two-stage. Entra identifies the Operator; a credential authenticates them.
Entra alone completes nothing.

```text
Entra ID  ->  Passkey
Entra ID  ->  Secret/SecretKey        (existing fallback, for a lost passkey)
```

Emergency Access is one stage and uses no Entra:

```text
Emergency sign-in  ->  Passkey  ->  Restricted Mode session
```

Emergency Access uses the Operator's **existing registered passkeys**. There is no separate
emergency passkey registration, and no separate emergency credential of any kind. Secret/SecretKey
is **not** available in Emergency Access: Emergency Access is passkey-only.

| | Normal | Emergency |
| --- | --- | --- |
| Entry | `GET /sign/in` -> Entra | `GET /sign/in/emergency/passkey/new` |
| First stage | Entra ID | none |
| Credential | Passkey, or Secret/SecretKey if the passkey is lost | Passkey only |
| Actor selected by | the pending Entra transaction | the submitted identifier |
| Challenge purpose | `authentication` | `emergency_sign_in` |
| Session context | `normal` | `emergency` |
| Step-Up | available | **unavailable** |
| Sign-out | `/sign/out` | `/sign/out` (the same ceremony) |

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

## Eligibility

`OrgEmergencyAccessPolicy.eligible?(operator)` is the single authoritative decision. It currently
returns the ordinary sign-in eligibility, so every Operator who may sign in at all may use Emergency
Access.

It exists as its own decision so that restricting Emergency Access to a subset of Operators later is
a change to one method, not a hunt through controllers, concerns, views, and token code. It is
consulted twice per ceremony -- when the options are issued and again at verification -- because
eligibility can be withdrawn between the two requests.

Ineligibility is not observable from the options response: every syntactically valid identifier
receives the same padded, anonymised `allowCredentials` set, so Emergency eligibility is not an
enumeration oracle.

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

| Hook | Normal | Emergency |
| --- | --- | --- |
| `passkey_ceremony_purpose` | `:authentication` | `:emergency_sign_in` |
| `find_active_passkey_actor` | the Entra transaction's Operator | the identifier, if eligible |
| `allow_passkey_sign_in?` | must match the Entra transaction | must still be eligible |
| `perform_passkey_sign_in` | Normal context | Emergency context |

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

It binds the Operator, the Entra identity, the ceremony purpose, its issue and expiry times
(10 minutes), and it is one-shot: it is consumed before the session-establishing call, so a replayed
second stage has nothing to continue.

The second stage reads the Operator **only** from this transaction. The identifier parameter is not
consulted at all, and the passkey and secret pages no longer render a field for one. An attacker who
completes Entra as Operator A therefore cannot authenticate as Operator B: the challenge is issued
against A, the challenge store returns A at consumption, and credential ownership is checked
against A a second time.

Without a valid transaction, `/sign/in/passkey/*` and `/sign/in/secret/*` refuse to run. The generic
failure responses of both ceremonies are unchanged, so enumeration resistance is preserved.

## Authentication context and token claims

`AuthenticationContextValue` is a closed registry of `normal` and `emergency`.

- **Durable authority:** `operator_tokens.authentication_context`. Written once, at session issue,
  and never updated afterwards. `NULL` means Normal, which is what every session predating Emergency
  Access was.
- **Claim:** `authn_ctx`, present on every access token. `acr`, `amr`, `scp`, `sid` and the rest of
  the token keep their existing meanings.

This is deliberately **not** the existing restricted-session state. `Actor::Authentication#restricted?`
marks a session awaiting session-limit remediation; a session can be Normal and session-limit
restricted at the same time. The two axes never collapse into one flag.

Authentication context and DBSC binding are independent session properties. Session inventory may
label a session Emergency only from the persisted authentication context. `dbsc_enabled?`, binding
method, and device-bound credential state must never be used to infer Normal or Emergency mode.

Reading the claim is lenient in one direction only: a blank claim is Normal, and any unrecognised
value resolves to a capability-less context that denies everything. Issuing a session under an
unknown context raises.

## Capability model

Authorization is:

```text
DB role permission  AND  session capability  AND  the ordinary policy rule
```

DB-backed roles remain the authority for role membership. The session capability layer can only
narrow what those roles already allow; Emergency authentication never expands DB authorization and
never introduces a second role system.

Two mechanisms carry it:

1. **Scopes.** `AuthenticationContextValue#constrain_scopes` filters the token's `scp` claim. An
   Emergency operator token carries `read:org` but not `write:org`. Structural scopes
   (`authenticated`, `domain:operator`) are untouched.
2. **An Action Policy pre-check.** `ApplicationPolicy` runs `deny_capability_restricted_context`
   before every rule. A Normal context is unconstrained. Every other context is an **allowlist**:
   `AuthenticationContextValue::EMERGENCY_PERMITTED_RULES` is `index?` and `show?`, and a rule that
   is not named is denied.

The allowlist is the point. A sensitive action added next year is unavailable to a Restricted Mode
session by default, rather than by a developer remembering an `if emergency?` guard. Widening the
list is a security decision, and it belongs in this document.

## Step-Up is unavailable in Restricted Mode

This is not "step-up has not happened yet". The authentication context is not eligible to perform
step-up-protected operations at all, however valid the Operator's step-up passkey is. There is no
separate Emergency step-up mechanism, and normal step-up behaviour is unchanged.

Four independent layers enforce it:

1. `VerificationBase#require_step_up!` and `#enforce_step_up_prereqs!` refuse the ceremony entry with
   403 before any credential is requested.
2. `StepUpResolver` never reports a requirement as satisfied for an Emergency session, so a session
   that somehow held freshness columns still cannot authorize a sensitive action.
3. `IdentityStepUpCeremonyFreshnessCommitter` refuses to write freshness onto an Emergency session,
   which is where acme commits it (`docs/security/step-up-ceremony-delegation.md`).
4. The Action Policy pre-check denies the mutating rules those operations run under.

Operator retirement, destructive lifecycle actions, credential management, and role or permission
modification therefore remain unavailable.

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
