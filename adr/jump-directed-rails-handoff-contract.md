# Rails Directed Jump Handoffs

## Status

Accepted (2026-10-01), amended 2026-10-02 to freeze the twenty-edge Hono handoff contract.
Supersedes the Palm authorization-launcher restriction in
`adr/acme-sign-core-base-port-boundary.md` and the issuer/return-policy portion of the remaining
steps in `adr/core-canonical-public-host.md`. Their persistence and API ownership boundaries remain.

## Decision

Approved cross-surface browser GET navigation uses Jump. Registrable-domain equality does not merge trust
boundaries. The destination-indexed `JumpRtReturnPolicy::ALLOWED_SOURCES` defines these exact pairs,
in both directions:

| Base origin | Approved peers |
| --- | --- |
| `https://www.umaxica.app` | `auth.umaxica.app`, `jp.umaxica.app`, `www-jp.umaxica.app`, `palm-jp.umaxica.app` |
| `https://www.umaxica.com` | `auth.umaxica.com`, `jp.umaxica.com`, `www-jp.umaxica.com` |
| `https://www.umaxica.org` | `auth.umaxica.org`, `jp.umaxica.org`, `www-jp.umaxica.org` |

The normalized implementation graph is:

```text
auth-app-ww -> base-app-ww
auth-com-ww -> base-com-ww
auth-org-ww -> base-org-ww
base-app-ww -> auth-app-ww
base-app-ww -> core-app-jp
base-app-ww -> palm-app-jp
base-app-ww -> warp-app-jp
base-com-ww -> auth-com-ww
base-com-ww -> core-com-jp
base-com-ww -> warp-com-jp
base-org-ww -> auth-org-ww
base-org-ww -> core-org-jp
base-org-ww -> warp-org-jp
core-app-jp -> base-app-ww
core-com-jp -> base-com-ww
core-org-jp -> base-org-ww
palm-app-jp -> base-app-ww
warp-app-jp -> base-app-ww
warp-com-jp -> base-com-ww
warp-org-jp -> base-org-ww
```

All peers use HTTPS. This is the approved implementation graph, not a restatement of the earlier
observed inventory. Auth-to-RP, RP-to-RP, self-loops, cross-TLD edges, unregistered regions and Edit
are absent. Adding an RP requires an explicit decision. Core is `jp.*`; Warp is `www-jp.*`.
`www.jp.*` is rejected, never rewritten to Warp. Node region reflects the deployment; query `ri`
does not change these origins' identities.

Auth surface JWT identities are `AUTH_APP/COM/ORG` with `auth.umaxica.*` issuer origins. Retired
`SIGN_*` identities and `Sign::*` controller mappings have no fallback. `/sign/...` ceremony paths
and persisted/OIDC `side-*` and `SIDE_*` identifiers remain. Logical identity-ceremony contracts
using `log.*` are separate from Jump surface identity and remain unchanged.

Core, Warp and Palm publish their Jump signing keys on their canonical origin's
`/.well-known/jwks.json`. Auth App/Com/Org, Base App/Com/Org, Core App/Com/Org, Warp App/Com/Org and
Palm browser receivers verify Jump returns. Palm's machine callback also verifies returns.

### Palm native browser ceremony

Palm is an approved first-party RP with the implemented browser route
`Palm -> Base -> Auth -> Base -> Palm`. It is not destination-only. A native app opens
`https://palm-jp.umaxica.app/sign/in` in an external browser with its registered client ID, an
authorization-code request, S256 challenge, state and nonce. The PKCE verifier remains on the
device. Existing `app-ios-rp` and `app-android-rp` stay public clients with `palm-api` audience;
their Base redirect URI is now Palm's HTTPS `/oidc/callback`.

Palm holds only bounded, temporary browser continuity in the existing encrypted Rails session.
The callback requires a Base-sourced, Jump-verified response and matching browser state before
one-time delivery to the client's fixed native completion URI. Native completion URIs are app
delivery contracts, not OAuth redirect URIs accepted directly by Base. Native apps redeem the
code at Base with the original Palm redirect URI and their PKCE verifier, then verify their OIDC
nonce. Palm does not exchange codes, mint OAuth tokens, or authenticate its bearer API with cookies.
The native launch/delivery contracts require coordinated application rollout.

Palm logout retains the existing JSON keys and bearer-token revocation ceremony. `logout_url` now
contains a Palm-issued Jump URL to Base. Signed, CSRF-protected cross-origin POST continuations,
including coordinated logout and social handoffs, retain their methods and protections.

This follows external-user-agent and PKCE guidance in
[RFC 8252](https://www.rfc-editor.org/rfc/rfc8252.html) and
[RFC 7636](https://www.rfc-editor.org/rfc/rfc7636.html). It does not claim completed platform link
registration or device integration.

### Development and wire contract

Browser destinations use public HTTPS origins. Jump issuance rejects localhost, private ingress
names and private/loopback/link-local literal addresses, including HTTPS variants. No issuer-side
general destination allowlist is introduced by this work.

Development can issue to production Jump only with an explicit public contract per issuer.
`JUMP_DEVELOPMENT_<NAMESPACE>_{ISSUER_ORIGIN,JWKS_URI,RETURN_ORIGIN}` names a distinct HTTPS
identity, its exact `/.well-known/jwks.json`, and the same public origin for browser returns.
`JWT_DEVELOPMENT_<NAMESPACE>_*` supplies dedicated signing material with a `development-` kid;
local auto-generated and production `JWT_<NAMESPACE>_*` material is never a fallback. A required
production public-key snapshot rejects reuse of production kids or key coordinates. Missing,
partial, private, stale, or production-identity configurations fail explicitly.

Configured development identities map to the existing logical nodes only in development. The
return verifier applies the same twenty directed edges; this does not add production origin
aliases or graph edges. Surface host configuration and HTTPS ingress must expose the configured
JWKS and browser origin. Rails validates the issuance contract; public DNS/TLS reachability and
production Hono trust registration are separate deployment prerequisites, not inferred from Rails
configuration. See `docs/operations/jump-rt-key-rotation.md` for the required setting names.

`schema=1`, ES384, TTL and leeway remain. `rpl=once` consumes JTI and rejects reuse; `rpl=reuse`
continues to allow reuse. No new persistent replay storage or migration is introduced.

## Consequences

Deployment needs the same Rails Auth signing material under `JWT_AUTH_*` configuration names and
public Warp/Palm JWKS with registered trust at Jump. No secret changes are performed by this code
change. Existing Auth access tokens with the old logical issuer may require reauthentication;
retired issuer aliases are not accepted. Existing Core bridge rows/defaults remain pending a separately authorized persistence migration.
Production Host Authorization no longer includes the explicit legacy `jpx.*` entries.

Edit remains an OIDC RP with its client registration, assertion keys and callback contracts.
It has no Jump surface issuer, surface JWKS route or approved Jump edge. Its existing same-site
OIDC admission remains direct; an attempted Edit Jump handoff raises `JumpRtConfigurationError`.
Graph inclusion and general issuer-side destination least privilege require separate review.
Rollout and rollback gates are in `plans/active/rails-jump-directed-handoff-rollout.md`.
