# Base Authority and Self-RP Separation

## Status

Accepted (2026-10-06) as the target architecture for the `two.md` implementation cycle.

> **Partial supersession (2026-10-13):**
> `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` replaces the statement
> below that sibling RP rows are not synchronously revoked, and ends the retained back-channel scope
> freeze: the parent and all of its RP rows are revoked in one transaction and first-party
> Back-Channel Logout is removed. Authority-first logout and the irreversible commit point are
> unchanged.

## Context

Base is both the physical OAuth/OIDC authority and an ordinary browser relying party of itself.
Treating those roles as one controller hierarchy lets an RP credential become authority proof or a
root cookie become an RP fallback. The shared Browser RP layer also needs one explicit contract for
Warp, Edit, and Core, including refresh and logout behavior.

## Decision

Base separates two controller roles on the same FQDN:

- Authority controllers serve discovery, authorization, token, UserInfo, revocation, end-session,
  and ceremony result receivers. They use protocol authentication or the existing root resolver as
  appropriate and never read an RP credential as authority proof.
- Self-RP controllers serve `/`, `/dashboard`, `/identity`, credential management, `/sign`, and
  `/oidc/callback`. They use the shared Browser RP lifecycle and never use the root cookie family as
  an authentication fallback.

The Browser Session is OP login state. It is not an RP credential, but a valid Browser Session may
authorize an OIDC request under the explicit `prompt` and `max_age` contract. Identity to Browser
Session to RP Session is 1:N; an RP Session is parented by the stable DeviceSession and has at most
one active row per DeviceSession and RP client. The current root token remains the carrier for
step-up freshness, historical status-103 rejection, establishment, idle, and absolute expiry.

The shared layer owns state, nonce, PKCE, authorization start, callback validation, ID Token and
UserInfo checks, identity binding, RP sessions, cookie credentials, refresh, failure behavior, and
RP logout for Base self-RP, Warp app/com/org, Edit org, and Core app/com/org. Palm remains a public
PKCE client with `token_endpoint_auth_method=none`.

UserInfo is the scope-filtered claims authority and accepts only Bearer headers on GET or POST.
Discovery advertises exactly the supported endpoints and grant types. Token refresh evaluates the
refresh credential independently of the access credential. Safe GET/HEAD refresh and unsafe request
refresh are separate orchestrators; unsafe requests perform CSRF, Origin, and Fetch Metadata checks
before refresh and the one mutation.

Rotation uses Base `/oauth/token`, per-RP-session Valkey single-flight, and a five-second fixed
encrypted delivery receipt. The database receipt is the recovery authority after a process or
publication failure. The receipt is encrypted with the Rails key generator and bound to the RP
Session, client, realm, predecessor digest, and generation. Valkey failure prevents rotation from
starting; confirmed credential failure clears RP cookies, while dependency failure returns 503 and
preserves them.

Logout is authority-first. The parent Browser Session is revoked at the irreversible commit point,
then authority cleanup, origin cleanup, initiating RP-session revocation, and finalization occur.
Already-issued access JWTs remain cryptographically valid through `exp` plus leeway, and sibling RP
rows are not synchronously revoked. Cryptographic validity is not acceptance: see the amendment
below for the Browser RP access credential.

The Side-to-Warp rename is destructive for operational identifiers and has no old-client fallback.
Auth/Xper remain ceremony/workflow boundaries, and D-82 is the one narrow Auth admission-binding
exception. Token introspection, Palm redesign, back-channel changes, and deployment configuration
are outside this cycle.

## Consequences

Role separation is visible in inheritance and concerns, so a controller cannot silently acquire the
other role's credential lifecycle. A parent security context can inform an explicitly authenticated
RP operation but cannot authenticate it. Refresh failures have materially different cookie behavior,
and access-token retirement cannot be inferred from logout completion.

This ADR is **new**. The earlier Base/Auth boundary is **amended**, the old no-SSO statement is
**partially superseded**, and the Auth/Xper, Palm, and back-channel scope freezes are **retained**.

## Amendment: live validation of the Browser RP access credential (2026-10-08)

Decided by the user on 2026-10-08; it revises D-53 of the implementation plan.

Two checks are kept apart. Cryptographic verification covers signature, issuer, audience, client and
expiry. Server-side validity covers state the token cannot carry.

The Browser RP access credential, the cookie that authenticates Base self-RP, Warp, Edit and Core
pages, passes both on every request. After cryptographic verification the request reads the RP
Session, its Browser Session, that session's current root token and the actor, and treats the
browser as authenticated only when every link is present, unrevoked and consistent with the token.
The rule is the same on every page. With an invalid credential Home renders its anonymous page and a
protected page refuses; no page has a rule of its own.

Consequences accepted with this decision:

- Immediate revocation. Once a revocation commits, the next server request with that credential is
  unauthenticated. This cannot retract what a browser already displays.
- Database dependency. Every authenticated Browser RP request reads the ticket and principal
  databases. No cache may stand in for the state read.
- Failure behavior. When the state cannot be read the request fails closed with the dependency
  response (503, RP cookies preserved). There is no fallback to cryptographic-only verification.

Every other credential keeps its existing verification contract; this amendment changes none of
them. Optimizations that weaken revocation or the fail-closed behavior are outside this decision.
