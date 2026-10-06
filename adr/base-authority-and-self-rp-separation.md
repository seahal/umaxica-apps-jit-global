# Base Authority and Self-RP Separation

## Status

Accepted (2026-10-06) as the target architecture for the `two.md` implementation cycle.

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
  `/oidc/callback`. They use the shared Browser RP lifecycle and never use the root cookie family
  as an authentication fallback.

The Browser Session is OP login state. It is not an RP credential, but a valid Browser Session may
authorize an OIDC request under the explicit `prompt` and `max_age` contract. Identity to Browser
Session to RP Session is 1:N; an RP Session is parented by the stable DeviceSession and has at most
one active row per DeviceSession and RP client. The current root token remains the carrier for
step-up freshness, restricted-session state, establishment, idle, and absolute expiry.

The shared layer owns state, nonce, PKCE, authorization start, callback validation, ID Token and
UserInfo checks, identity binding, RP sessions, cookie credentials, refresh, failure behavior, and
RP logout for Base self-RP, Warp app/com/org, Edit org, and Core app/com/org. Palm remains a public
PKCE client with `token_endpoint_auth_method=none`.

UserInfo is the scope-filtered claims authority and accepts only Bearer headers on GET or POST.
Discovery advertises exactly the supported endpoints and grant types. Token refresh evaluates the
refresh credential independently of the access credential. Safe GET/HEAD refresh and unsafe
request refresh are separate orchestrators; unsafe requests perform CSRF, Origin, and Fetch
Metadata checks before refresh and the one mutation.

Rotation uses Base `/oauth/token`, per-RP-session Valkey single-flight, and a five-second fixed
encrypted delivery receipt. The database receipt is the recovery authority after a process or
publication failure. The receipt is encrypted with the Rails key generator and bound to the RP
Session, client, realm, predecessor digest, and generation. Valkey failure prevents rotation from
starting; confirmed credential failure clears RP cookies, while dependency failure returns 503 and
preserves them.

Logout is authority-first. The parent Browser Session is revoked at the irreversible commit point,
then authority cleanup, origin cleanup, initiating RP-session revocation, and finalization occur.
Already-issued access JWTs remain valid through `exp` plus leeway, and sibling RP rows are not
synchronously revoked.

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
