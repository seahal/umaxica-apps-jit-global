# Rails Directed Jump Handoffs

## Status

Accepted (2026-10-01), amended 2026-10-02 to freeze the twenty-edge Hono handoff contract, and
amended again 2026-10-02 to derive issuer identity from the existing `PUBLIC_*` surface settings and
make `rpl` a required `"reuse"`. Amended a third time on 2026-10-02 to make
`PUBLIC_JUMP_GATEWAY_URL` (not `JUMP_GATEWAY_URL`) the sole gateway setting, to record that no
`PRIVATE_JUMP_GATEWAY_URL` exists, and to withdraw the rule that development may not present a
canonical issuer origin: the Rails environment name never selects a Jump identity. Amended a fourth
time on 2026-10-02 to reject `PRIVATE_JUMP_GATEWAY_URL` at boot instead of ignoring it. Amended a
fifth time on 2026-10-02 to move the Palm native entry from `/sign/in` to the neutral `GET /sign`
page and `POST /sign` starter shared by every first-party RP FQDN. Supersedes
the Palm authorization-launcher restriction in `adr/acme-sign-core-base-port-boundary.md` and the
issuer/return-policy portion of the remaining steps in `adr/core-canonical-public-host.md`. Their
persistence and API ownership boundaries remain.

## Decision

Approved cross-surface browser GET navigation uses Jump. Registrable-domain equality does not merge
trust boundaries. `JumpRtReturnPolicy::ALLOWED_EDGES` lists the twenty directed
`[source, destination]` pairs between the logical issuer namespaces; with the production `PUBLIC_*`
settings they connect these origins in both directions:

| Base origin               | Approved peers                                                                    |
| ------------------------- | --------------------------------------------------------------------------------- |
| `https://www.umaxica.app` | `auth.umaxica.app`, `jp.umaxica.app`, `www-jp.umaxica.app`, `palm-jp.umaxica.app` |
| `https://www.umaxica.com` | `auth.umaxica.com`, `jp.umaxica.com`, `www-jp.umaxica.com`                        |
| `https://www.umaxica.org` | `auth.umaxica.org`, `jp.umaxica.org`, `www-jp.umaxica.org`                        |

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
`https://palm-jp.umaxica.app/sign` in an external browser with its registered client ID, an
authorization-code request, S256 challenge, state and nonce. The PKCE verifier remains on the
device.

Every first-party RP FQDN, Palm included, starts sign-in at the same path: `GET /sign` renders a
neutral page and the CSRF-protected `POST /sign` starts the flow. Palm's `GET /sign` validates the
native request and carries it to `POST /sign` as form fields; it creates no browser state. The
`POST` records the pending flow and issues the Jump handoff to Base. Palm has no `/sign/in` route.
The page is an interim, minimal confirmation step while the Palm launch UX is undecided; it keeps
the path and method contract aligned with the other RPs in the meantime. Existing `app-ios-rp` and `app-android-rp` stay public clients with `palm-api` audience;
their Base redirect URI is now Palm's HTTPS `/oidc/callback`.

Palm holds only bounded, temporary browser continuity in the existing encrypted Rails session. The
callback requires a Base-sourced, Jump-verified response and matching browser state before one-time
delivery to the client's fixed native completion URI. Native completion URIs are app delivery
contracts, not OAuth redirect URIs accepted directly by Base. Native apps redeem the code at Base
with the original Palm redirect URI and their PKCE verifier, then verify their OIDC nonce. Palm does
not exchange codes, mint OAuth tokens, or authenticate its bearer API with cookies. The native
launch/delivery contracts require coordinated application rollout.

Palm logout retains the existing JSON keys and bearer-token revocation ceremony. `logout_url` now
contains a Palm-issued Jump URL to Base. Signed, CSRF-protected cross-origin POST continuations,
including coordinated logout and social handoffs, retain their methods and protections.

This follows external-user-agent and PKCE guidance in
[RFC 8252](https://www.rfc-editor.org/rfc/rfc8252.html) and
[RFC 7636](https://www.rfc-editor.org/rfc/rfc7636.html). It does not claim completed platform link
registration or device integration.

### Gateway configuration

`PUBLIC_JUMP_GATEWAY_URL` is the single source of truth for the Jump gateway, following the
repository's `PUBLIC_*` / `PRIVATE_*` naming: it is the browser-facing canonical Jump origin, the
origin Rails redirects browsers to, and the origin from which the Jump RT audience and the gateway
JWKS URI are derived. It is required in every Rails environment and has no default; boot fails when
it is missing. It must be a public HTTPS root origin: blank values, `0`, control characters,
relative or scheme-less values, `http`, `localhost`, `*.localhost`, `*.local`, `*.internal`, other
reserved non-public suffixes, IP literals, userinfo, explicit ports, paths, queries and fragments
are rejected. The normalized origin is the only internal gateway value.

With `PUBLIC_JUMP_GATEWAY_URL=https://jump.umaxica.net`:

| Value            | Result                                           |
| ---------------- | ------------------------------------------------ |
| Gateway origin   | `https://jump.umaxica.net`                       |
| Jump RT `aud`    | `https://jump.umaxica.net`                       |
| Gateway JWKS URI | `https://jump.umaxica.net/.well-known/jwks.json` |

- None of the three is configurable on its own; the JWKS URI cannot name another origin or path.
- `JUMP_GATEWAY_URL`, `PUBLIC_JUMP_GATEWAY_JWKS_URL`, `JUMP_GATEWAY_JWKS_URL`,
  `PUBLIC_JUMP_GATEWAY_AUDIENCE` and `JUMP_GATEWAY_AUDIENCE` were removed. They are not aliases or
  fallbacks; setting any of them, even to an empty value, is a boot-time configuration error so a
  stale value is never silently ignored. The independent audience setting was removed to make a
  gateway/audience mismatch unrepresentable.
- The environment is selected by the value, never by the Rails environment name. Development, test
  and production all currently use the production Hono gateway when they use live Jump.
- `JUMP_RT_TTL_SECONDS` (1..30) and `JUMP_RETURN_REVOKED_KIDS` remain independent policy settings.
- Boot validates the gateway value only syntactically. It performs no DNS, TLS or HTTP request and
  does not depend on Cloudflare or Internet reachability; whether the public endpoints answer is a
  deployment smoke check.

#### No private gateway path

Rails currently has no private transport path to Jump: the only Jump endpoint Rails can use is the
browser-facing public Jump. `PRIVATE_JUMP_GATEWAY_URL` is therefore not supported: boot fails when
it is present, including as an empty string, with an error stating that Rails has no private
transport path to Jump, so the setting cannot be silently ignored. It is not a removed setting and
it is not added to the environment templates even as an empty placeholder. A localhost or private
ingress name must not stand in for it, and it must not be introduced as an alias of the public Jump
URL.

Only when a private transport usable from the Rails network actually exists (a VPC, a service
binding, private ingress or an equivalent) is a `PRIVATE_JUMP_GATEWAY_URL`-like setting designed
again. Such a setting is server-to-server transport only: it must not change the browser redirect
origin, the public Jump identity, the JWT `aud` or the public JWKS identity, all of which stay
derived from `PUBLIC_JUMP_GATEWAY_URL`.

#### Audience and future providers

Today Jump has a single public entrypoint, so the gateway transport origin equals the JWT audience,
and the independent audience setting was removed to prevent configuration drift. This is not a
decision that Jump stays a single point of failure. A second provider beyond Cloudflare,
active-active operation, failover or several ingress endpoints may be introduced. That work must
design a stable logical audience, multiple audiences, or a separation of gateway identity from
transport endpoint. It is an ADR revision covering the wire contract, issuer validation, receiver
validation, rollout and rollback; it is never done by reintroducing a `JUMP_GATEWAY_AUDIENCE`-style
setting. That redesign is intentionally deferred.

### Issuer identity and keys

Jump issuer capability is exactly thirteen namespaces, held in `JumpRtSurface::ISSUER_NAMESPACES`
and kept separate from the general JWT registry namespaces: `AUTH_APP/COM/ORG`, `BASE_APP/COM/ORG`,
`CORE_APP/COM/ORG`, `WARP_APP/COM/ORG` and `PALM_APP`. `ACME_*` remain general registry namespaces
but have no Jump issuer capability; no `Acme::*` controller exists, and Base-hosted Acme behavior
issues through the Base or Auth controller handling the request. Edit is a receiver only.

Each issuer origin is derived from the existing public surface setting (`PUBLIC_AUTH_*_URL`,
`PUBLIC_BASE_*_URL`, `PUBLIC_CORE_*_URL`, `PUBLIC_WARP_*_URL`, `PUBLIC_PALM_SERVICE_URL`). The same
origin is the return origin, and the issuer JWKS URI is that origin plus `/.well-known/jwks.json`.
There are no Jump-specific issuer, return or JWKS settings, and the `JUMP_DEVELOPMENT_<NS>_*` and
`JWT_DEVELOPMENT_<NS>_*` families were removed without replacement. The receiver maps origins to
namespaces through the same settings, so another environment's identities use the same twenty edges;
a duplicated origin is a configuration error.

Each issuer keeps its own ES384 key. In development and test the surface keys are owned by
`JitSecurityJwtLocalKeysetInstaller` and persisted in `tmp/local_jwt_keysets.json`; a `JWT_<NS>_*`
value in the environment that does not match that store is a configuration error, so copied
production signing material cannot become a local Jump key. Outside local environments the registry
already rejects kids carrying environment markers.

The Jump trust contract is the binding of three things: the issuer public origin, that issuer's
active signing key, and the public key published at that origin's `/.well-known/jwks.json`. The
Rails environment name is not part of it. Development may therefore present a canonical origin such
as `https://www.umaxica.app` as `iss`, provided the JWKS at that origin publishes the kid and public
key this Rails instance signs with. Rails never rewrites an issuer into another identity because of
`Rails.env`. Issuer origin validation is identical in every environment: an issuer must be an HTTPS
root origin with a host and no userinfo, query, fragment, path or port, and must not be `localhost`,
`*.localhost`, `*.local`, `*.internal` or an IP literal (which covers private, loopback and
link-local addresses); `Rails.env.local?` does not relax this.

Publishing a development-generated key in a canonical origin's JWKS makes that key a full signing
key of the canonical issuer in the Jump protocol. A kid containing `development` does not weaken it
cryptographically or for authorization, so any environment holding the private key is a signing
authority for that canonical identity. This is a deliberate current operating decision, not an
accident of configuration.

Inside Rails the binding is checked without network access. At boot, `JitSecurityJwtRegistry` builds
each Jump issuer record with `JumpRtSurface.issuer_origin`, so an invalid or missing `PUBLIC_*`
issuer origin fails boot, and the record holding the signing key names the same `iss` that Jump RTs
carry. `test/integration/jump_rt_issuer_jwks_authority_test.rb` signs an RT for each of the thirteen
issuers, checks `iss`, `alg=ES384` and the kid, fetches that surface's `/.well-known/jwks.json` from
the Rails renderer, confirms the kid is present and no private fields are exposed, and verifies the
RT signature against that JWKS.

Configuration failures (gateway, issuer identity, signing key) raise. The existing
`fallback_internal` same-host downgrade covers only an unusable target URL and never a Jump
configuration error; there is no direct cross-origin fallback.

### Wire contract

`schema=1`, ES384, TTL and leeway remain. `rpl` is a required claim whose only valid value is the
exact string `"reuse"`. Issuers always emit it and callers cannot choose a policy. Receivers compare
it by exact equality without coercion; a missing, null, empty, `"once"`, differently cased, padded,
NUL-containing, numeric, boolean, array or object value is rejected. A schema 1 Jump RT is a
short-lived, signed, reusable navigation instruction. Jump does not provide single-use semantics,
and Rails no longer consumes Jump JTIs. `SecurityConsumedJti` remains for OIDC logout requests and
tokens, sign-out notices and client assertions. No migration or persistent replay storage is
introduced.

Live Jump requires HTTPS public origins in every Rails environment; `Rails.env.local?` does not
relax issuance, gateway URL construction or return URL comparison.

### Receiver responsibility

Jump authorizes only a transition between explicitly approved origins. Successful Jump verification
does not authorize authentication completion, authorization, state mutation or any replay-sensitive
side effect.

A receiver first verifies the Jump return signature, `iss`, `aud`, time claims, `src`, exact
URL/request binding and the directed source policy. It then MUST independently verify every
protocol-specific condition of its own operation, including state, nonce, PKCE, authorization code
validity, transaction state, CSRF and authorization.

Arriving through Jump does not make `redirect_uri`, `return_to`, `next`, `redirect_to`, `continue`
or any other follow-on redirect parameter trustworthy. A verified return only removes `rt` and
re-enters the same URL on the receiving host; a receiver that redirects further validates that
destination itself. Because Jump RTs are reusable, one-time behavior and idempotency belong to
receiver-owned transaction or protocol state, as Palm's pending-flow check does.

### Emulator

No Jump emulator is implemented. A future emulator requires an explicit emulator transport and
profile security contract, recorded as an ADR revision, before any localhost or `http` origin is
accepted. Until then, the strict public HTTPS validation applies everywhere and Rails is verified
against the production Hono gateway only.

### Rollout state

These Rails changes tighten the contract before Hono follows. Until Hono emits a required
`rpl: "reuse"` on return tokens and accepts the derived audience and identities, the Jump round trip
may fail; no compatibility fallback is provided.

## Consequences

Deployment needs the same Rails Auth signing material under `JWT_AUTH_*` configuration names and
public Warp/Palm JWKS with registered trust at Jump. No secret changes are performed by this code
change. Existing Auth access tokens with the old logical issuer may require reauthentication;
retired issuer aliases are not accepted. Existing Core bridge rows/defaults remain pending a
separately authorized persistence migration. Production Host Authorization no longer includes the
explicit legacy `jpx.*` entries.

Edit remains an OIDC RP with its client registration, assertion keys and callback contracts. It has
no Jump surface issuer, surface JWKS route or approved Jump edge. Its existing same-site OIDC
admission remains direct; an attempted Edit Jump handoff raises `JumpRtConfigurationError`. Graph
inclusion and general issuer-side destination least privilege require separate review. Rollout and
rollback gates are in `plans/active/rails-jump-directed-handoff-rollout.md`.
