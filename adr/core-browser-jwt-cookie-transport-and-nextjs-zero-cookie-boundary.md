# Core Browser JWT Cookie Transport And Next.js Zero-Cookie Boundary

## Status

Accepted (2026-06-14)

## RP Credential Authority Amendment (2026-09-20)

The Base/Auth/RP authority decision supersedes the credential issuance and audience portions of
this ADR for Rails Core browser authentication. Base remains the sole physical OIDC Authorization
Server and owns the Base Browser Session and RP Session. Core's OIDC callback uses the Access and
Refresh credentials returned by Base for the exact Core RP (`core-app`, `core-com`, or `core-org`)
and stores them in the host-only `oidc_rp_access` and `oidc_rp_refresh` cookie slots (with the
`__Host-` prefix in secure contexts). It never calls the generic root `log_in` path and never
creates a second root Browser Session.

The old `core-browser` audience/root-browser-cookie contract below is historical for the Core RP
path and is not an accepted credential for the current Core browser API. The Core API still keeps
cookie-only transport, rejects `Authorization: Bearer`, keeps Rails CSRF protection, uses
`Cache-Control: no-store`, and validates the exact RP issuer/audience/client binding. Palm remains
an independent bearer-token boundary. The zero-cookie Next.js/edge contract is unchanged and its
TanStack SSR boundary remains a separate follow-up decision.

## Amendment (2026-08-09)

The Rails Core path list in "Decision" below — `/api/v0/*`, `/auth/*`, `/sso/*` — does not match
`config/routes/core.rb`. `/auth` is a host family (`auth.umaxica.*`) drawn under `constraints host:`
in `config/routes/auth.rb`, not a path prefix on the Core host, and `/sso/*` has no route on any
surface; `test/integration/routes/core_route_contract_test.rb` asserts both are unroutable on Core.
Likewise `/settings` and `/settings/*` are defined on the Auth and Side surfaces, not Base.

The correction matters because the omitted paths are the cookie-bearing ones: `/oidc/callback`,
`/sign/out`, `/sign/out/complete`, `/web/v0/*`, and `/edge/v0/*` set and clear the credential
cookies, and under the original list they would have fallen into the Cookie-stripped "all other
paths" row.

`config/routes/core.rb` is the source of truth for Core path ownership, per
`adr/core-canonical-public-host.md`. The corrected edge route table lives in
`docs/operations/core-nextjs-zero-cookie-edge-contract.md`. The security invariants this ADR
establishes — zero `Cookie` at the Next.js origin, no `Set-Cookie` from it, no user-bound SSR/RSC,
audience-to-transport binding — are unchanged.

## Supersedes

This ADR supersedes the Core browser `__Host-core_sid`-only invariant in
`adr/acme-sign-core-base-port-boundary.md` and the narrower cookie-stripping language in
`adr/core-browser-credential-transport.md`.

The superseded invariant was:

- the browser holds only `__Host-core_sid` for Core.

The new invariant is:

- the Core browser may hold an access JWT in the existing Rails auth access cookie, but only Rails
  Core may receive or consume it.
- the Next.js origin receives no `Cookie` header at all.
- the Next.js origin must not emit `Set-Cookie`.

## Context

Core is split between a browser-facing Rails Core BFF/API and a Next.js Core UI origin. The browser
calls `https://jp.umaxica.app/api/v0/*` directly for personalized data after hydration. Next.js
serves public UI, SSR, RSC, routing, SEO, and island shells only.

The current repository has Rails Core routes whose defaults still mention `www.jp.umaxica.app`. This
ADR chooses `jp.umaxica.app` as the canonical public Core host for the new boundary. Base owns Rails
foundation/control-plane paths such as `/settings`; Core must not accidentally route those paths to
Next.js.

This repository does not contain deployable Cloudflare ruleset or Worker code. Edge enforcement is
therefore recorded as an operational contract and production rollout blocker until the external
Cloudflare configuration is deployed and verified.

## Historical Decision (superseded for RP credentials)

Core browser credential transport is cookie-carried JWT access plus opaque refresh. Core uses the
same Rails auth cookie concern and cookie names as the existing Acme/Sign relying-party flows; it
does not fork the ceremony into Core-only cookie names.

| Cookie                                                              | Value                                                       | Attributes                                           |
| ------------------------------------------------------------------- | ----------------------------------------------------------- | ---------------------------------------------------- |
| existing auth access cookie, `__Host-` prefixed in secure contexts  | access JWT, `aud=core-browser`                              | Secure, HttpOnly, SameSite=Strict, Path=/, no Domain |
| existing auth refresh cookie, `__Host-` prefixed in secure contexts | opaque refresh handle, never JWT                            | Secure, HttpOnly, SameSite=Strict, Path=/, no Domain |
| existing Rails/OIDC transaction state                               | OIDC state / PKCE / nonce transaction material or reference | existing Rails auth ceremony controls                |

The access token TTL is short; use approximately ten minutes unless a later token-lifetime ADR
chooses a different Core browser value. The refresh handle remains opaque and uses the existing
refresh-token digest, rotation, replay-detection, and family-revocation model.

JavaScript cannot read the access token, refresh handle, or OIDC transaction state.

Rails Core is the only consumer of Core browser credential cookies. Rails Core owns:

- `/api/v0/*`
- `/auth/*`
- `/sso/*`

Next.js Core receives no `Cookie` header. This is stronger than selective auth-cookie stripping: all
cookies are removed before the request reaches the Next.js origin. Responses from Next.js have
`Set-Cookie` stripped before reaching the browser. Next.js holds no user credential, performs no
user-bound SSR/RSC, and does not fetch `/api/v0/session`, `/me`, settings, account, dashboard,
tenant-private, org-private, or other user-bound resources during SSR/RSC.

Side is private support infrastructure for non-user-bound SSR/RSC data. It receives no `Cookie`
header, must reject requests that contain `Cookie` if edge stripping is bypassed, authenticates only
with a service bearer token, and returns only non-user-bound read data.

Base owns `/settings` and `/settings/*`. Those paths must be routed to Base, not Next.js and not
Core settings controllers, unless a later ADR amends ownership.

Operational health endpoints (`/health` and children) remain internal-only and must be blocked at
the public edge.

## Transport Binding

Audience is bound to transport:

- `core-browser` is accepted only from cookie transport on Rails Core browser API/auth paths.
- `palm-api` is accepted only from `Authorization: Bearer` on the native/mobile API boundary.
- Side service credentials are service-only, never user-bound, and never accepted from cookies.

Reverse use is rejected:

- `core-browser` via `Authorization` is rejected.
- `palm-api` via cookie is rejected.
- Side service credentials via cookie are rejected.
- Side service credentials with a user subject are rejected.

## CSRF

Cookie transport requires Rails CSRF verification for unsafe methods. `SameSite=Strict` is
defense-in-depth, not the primary CSRF control. `GET /api/v0/session` returns a masked CSRF token
for browser JavaScript to echo in `X-CSRF-Token` on unsafe API requests.

## Compensating Controls

- HttpOnly cookies.
- Secure cookies.
- SameSite=Strict for access and refresh.
- Short access-token TTL.
- Opaque path-restricted refresh handle.
- Refresh rotation, revocation, replay detection, and family revoke.
- Audience-to-transport binding.
- Rails CSRF on unsafe cookie-authenticated API methods.
- Cloudflare request `Cookie` stripping for Next.js and Side.
- Cloudflare response `Set-Cookie` stripping for Next.js and Side.
- No user-bound SSR/RSC.
- No credential in the Next.js process.

## Rejected Alternatives

### Opaque `__Host-core_sid` Only

Rejected for this Core browser boundary because it does not reuse the Rails JWT access-token
verification pipeline directly. It remains the superseded classical BFF option.

### Core-Only Auth Cookie Names

Rejected for the auth ceremony. Forking `__Host-core_access`, `__Secure-core_refresh`, or
`__Host-core_oidc` into separate ceremony-only concerns would duplicate the existing Rails auth
cookie flow and increase drift risk. Host-only cookie rules, SameSite/HttpOnly/Secure attributes,
and JWT audience-to-transport binding are the safety boundary.

### Browser-Readable Token

Rejected. Browser JavaScript must never read access or refresh credentials.

### Next.js RP/BFF

Rejected. Next.js must not hold user credentials, Acme credentials, signing keys, refresh handles,
or client secrets.

### User-Bound SSR/RSC

Rejected. Personalized Core data is fetched after hydration from Rails Core with browser cookie
credentials and CSRF protection.

## Verification

- Cloudflare Trace, equivalent edge trace, or a controlled origin echo test proves `Cookie` is
  absent at the Next.js origin for `/_next/*` and page routes.
- Cloudflare Trace or equivalent proves `Cookie` is absent at the Side origin.
- Edge verification proves `Set-Cookie` from Next.js and Side does not reach the browser.
- Rails request tests cover cookie flags, CSRF, refresh, logout, transport binding, and JSON error
  contract.
- Static or CI checks cover checked-in edge contracts when the Cloudflare rules become code-owned by
  this repository.

## Related

- `adr/acme-sign-core-base-port-boundary.md`
- `adr/core-browser-credential-transport.md`
- `adr/api-route-vocabulary-consolidation.md`
- `adr/actor-current-facade.md`
- `adr/internal-health-endpoint-edge-isolation.md`
- `docs/operations/core-nextjs-zero-cookie-edge-contract.md`
