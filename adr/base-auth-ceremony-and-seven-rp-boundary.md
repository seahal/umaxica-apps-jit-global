# Base Physical Authority, Auth Ceremony Service, and Seven First-Party RPs

## Status

Accepted (2026-09-13)

Supersedes conflicting authority claims in:

- `adr/acme-sign-core-base-port-boundary.md` where it calls Base an RP or Auth/Sign a special RP
- `adr/sign-residual-idp-surface-retirement.md` where it retains Sign as a special RP framing
- `adr/logout-ceremony-boundary.md` where browser completion is `GET /sign/out/complete`
- `adr/base-lobby-unauthenticated-entry.md` for Base lobby and dashboard-as-home
- `adr/valkey-cache-and-rate-limit-stores.md` and
  `adr/solid-cache-removal-and-valkey-cache-separation.md` for **development/test Valkey service
  topology only** (not for Solid Queue or cache/rate-limit semantics)

Acme remains the conceptual authority vocabulary for shared logout/session services. Base is the
physical Rails Identity Provider and Authorization Server implementation.

## Context

The repository previously mixed Base RP routes, Auth RP routes, shared browser client IDs
(`sign-rp`, `base-rails-rp`, `side-rails-rp`, `core-next-rp`), TokenUsage child sessions, PostgreSQL
authorization codes, Auth JWT ceremony grants, six Auth/Base `/dashboard` homes, Base `/lobby`, and
`/sign/out/complete` completion pages. The consolidation plan requires one authority surface, seven
independent first-party RPs, ceremony-only Auth, Valkey auth-state, Root homes, and one-shot
`GET /sign/out`.

## Decision

### Authority

- **Base** is the sole physical OIDC IdP / Authorization Server surface (`/oauth/*`, discovery,
  JWKS, token, refresh, revocation, userinfo, end-session). Global OAuth/OIDC contracts remain.
- **Auth** is a credential and authentication ceremony service only. It must not act as an OIDC RP,
  store RP callback state, exchange RP tokens, or grant Identity / Base Browser Session / RP Session
  / AAL / authorization policy.
- Auth may keep actor-specific opaque ceremony-local browser sessions (`ClientAuthCeremonySession`,
  `VisitorAuthCeremonySession`, `OperatorAuthCeremonySession`) bound to random-only
  `__Host-auth_sid`. Those sessions are not Base login proof.

### Seven first-party RPs

Exact independent client IDs, keys, faces, browser transactions, and RP Sessions:

`core-app`, `core-com`, `core-org`, `side-app`, `side-com`, `side-org`, `edit-org`

Each exposes a neutral `GET /sign` entry page, CSRF-protected `POST /sign` flow starter, exact
`GET /sign/callback` protocol callback, and `/sign/out`. The RP does not choose Sign in versus
Sign up; Auth owns that internal ceremony choice. Shared browser registrations (`sign-rp`,
`base-rails-rp`, `side-rails-rp`, `core-next-rp`) are retired after the seven flows work. Native
and content clients remain.

### Session hierarchy

Identity → Base Browser Session (`ClientToken` / `VisitorToken` / `OperatorToken`) → RP Session
(rename of TokenUsage). No polymorphic / STI / generic auth_flows table. Access JWT remains RFC 9068
(~5 minutes + 30s leeway) and normal auth performs no RP Session row lookup.

### Handoff and codes

- Base↔Auth handoff/results: opaque 256-bit, digest-only, 60s, atomic, no JWT ceremony grants.
- OAuth authorization codes live in Valkey (digest key, issued→consumed CAS/tombstone).
- `private_key_jwt` JTI replay remains in PostgreSQL.

### Roots and logout

- Six Auth/Base Roots: Base authenticated Root keeps former Dashboard content/guards; Auth Root is
  always public ceremony entry. Remove six `/dashboard` routes and Base `/lobby`.
- Browser `/sign/out` is a one-shot `show`; retire `/sign/out/complete`. `GET /sign/out` never
  mutates authority state (only presentation-marker consume).

### Edit

Edit is an independent `edit-org` RP. Publishing UI stays on Edit; Publishing DB/domain stay in
Global. Replace Publishing route loops with twelve explicit declarations.

### Canonical map

`AuthBoundaryAuthorityMap` is the written route/authority map for client IDs, faces, retired paths,
and surface roles. Live registries, routes, and docs must converge on it.

## Consequences

- Implementation proceeds as P2–P9 of
  `plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`.
- Conflicting active ADR statements above are historical where superseded; Jump JWKS on Auth
  remains.
- Preserve Google/Apple/Entra callback contracts, Core/Side/Edit dashboards, and global `/oauth`.

## Implementation progress

See `evidence/2026-09-13-auth-boundary-consolidation.md` for phase SHAs and remaining gaps.

## Current hardening amendment (2026-09-17)

The Base token and revocation controllers now pass an endpoint-owned resource type into the token
exchange/revocation boundary. The request cannot select a realm from its payload or client naming.
The authorization-code resource type is checked before Valkey consumption; refresh checks the
surface-local RP-session class before rotation. A mismatch is an OAuth failure without token
consumption, rotation, or session replacement.

An RP Session is unique for the same parent Browser Session and registered RP while the existing row
is unrevoked or still within its retirement window. A new authorization code never overwrites the
old row's JTI, scope, refresh family, or other credentials. Each surface RP-session table records
the monotonically greatest issued Access JWT expiry in `oidc_access_token_max_expires_at`; a missing
value on a legacy row is conservative and blocks replacement until its issuance history is resolved.
This does not make an already-issued Access JWT immediately invalid: natural JWT expiry and the
verifier clock-skew allowance remain the boundary.

OIDC connection revocation is also bound to the authorization-code issuance time. A code issued
before a connection was revoked cannot restore that connection and is rejected before consumption; a
new authorization code issued after revocation may explicitly establish the new connection state.
The recorder locks the connection row and repeats this check so a revoke/exchange race cannot turn
an old code into a reconnection.

OIDC revocation is scoped to the matching surface-local RP Session and requires its client binding
and JTI. The revoker does not fall back from an RP `sid` lookup to a parent Base Browser Session;
parent termination is a separate explicit logout/revocation scope.

The amendment does not resolve the separate regional JP/US RP-registration conflict with the
accepted seven-client ADR. Client IDs, redirect registrations, external RP configuration, and
legacy-session migration remain blocked until that matrix is approved and verified.

## Base-to-Auth admission transport amendment (2026-09-21)

Base-to-Auth browser admissions do not place the opaque admission code in a URL. The initial Auth
GET may carry only the short-lived transaction or local-entry reference required to render a
same-origin continuation form. That GET is non-consuming. The form carries the reference and the
Auth Rails authenticity token in a POST body; the POST atomically consumes the reference-indexed,
purpose- and surface-bound Valkey record and redirects to a clean ceremony URL. The reference index
contains only a pointer to the digest-keyed admission record and never the raw admission code.

Rails forgery protection remains enabled for the Auth POST. This transport does not add a bearer
fallback, a Rails-session pre-authentication map, or a compatibility `admission` query consumer.

## Neutral browser RP entry amendment (2026-09-20)

The canonical first-party browser entry is now `GET /sign` followed by a CSRF-protected
`POST /sign`; `GET /sign/callback` is protocol infrastructure. The former RP `/sign/in` and
`/sign/in/callback` aliases are removed. Auth ceremony routes under `/sign/in/*` remain separate
and are not RP entrypoints. This amendment does not alter the Jump RT cryptographic or key
architecture.

## OIDC result transport amendment (2026-09-20)

The browser result from Auth back to Base is POST-only. Auth's local `GET /sign/oidc/handoff`
renders a same-origin CSRF-protected form; its `POST /sign/oidc/handoff` issues the opaque,
surface-bound, one-shot result. Auth then renders a cross-surface form that submits the result in
the body to the matching Base `POST /oauth/authorize` endpoint. The result is never placed in a
redirect URL, query string, fragment, or Rails-session pre-authentication map.

Base accepts the result only from the exact configured Auth origin (plus the existing same-site
null-origin proxy case), performs atomic one-shot consumption, and checks the surface before
resuming the pending authorization transaction. `GET /oauth/authorize?result=...` is not a result
consumer. Rails forgery protection remains enabled; no global CSRF configuration or normal Rails
CSRF boundary is weakened for this transport. Auth remains ceremony-only and Base remains the
authority for the authorization transaction and all resulting Browser Session, RP Session, and
authorization-code state.

This amendment is limited to removing secret result transport from URLs and making the browser
handoff explicit. It does not yet retire the remaining legacy Base callback/session issuance path;
that remains a later implementation slice under the authority-boundary plan.

### Result-purpose binding amendment (2026-09-21)

Base resolves the expected result purpose from the server-side authorization transaction before
attempting Valkey consumption. The result consumer no longer probes every result-purpose namespace
until one happens to match. A result must therefore match the transaction's purpose, surface,
actor type, and transaction reference at the atomic consume boundary; a mismatch is rejected
without consuming the result. The existing `local_sign_in` and `local_sign_up` namespaces remain
restricted to Base's own local landing entry and are not ordinary first-party RP result purposes.

## RP credential authority amendment (2026-09-20)

The seven first-party RP callbacks now use the Access and Refresh credentials returned by Base's
token endpoint directly. Core, Side, and Edit store them only in the dedicated host-only RP cookie
slots (`oidc_rp_access` and `oidc_rp_refresh`, or their `__Host-` names in secure contexts). They do
not call generic root `log_in` and do not create a second ClientToken, VisitorToken, or OperatorToken.

The Core Browser API validates the Access JWT locally against the exact RP client binding and
resource type, without a per-request RP Session lookup. Refresh, revocation, and logout return to
the Base/RP Session authority. The older `core-browser` root-browser-cookie audience is not a
credential for this RP path. This amendment does not weaken Rails CSRF protection, change the
zero-cookie edge contract, or make TanStack an authentication authority.

For OIDC UserInfo and the equivalent bearer validation boundary, `sid` remains the RP Session
protocol identifier, while the private `umx_base_sid` claim binds the JWT to the parent Base Browser
Session that issued it. Verification resolves the Base Browser Session and actor from those signed
claims; it does not resolve an RP Session row or compare a persisted RP-session JTI on every request.
The RP Session remains authoritative for refresh, revocation, and logout. Child-only revocation
therefore prevents further issuance without retroactively invalidating an already-issued JWT before
its natural expiry and verifier clock-skew boundary.

## RP logout authority amendment (2026-09-20)

The seven first-party browser RP sign-out controllers authenticate POST `/sign/out` with the
surface-local RP Access/Refresh cookies. They require the registered client and resource realm,
verify the Access JWT issuer/audience/client binding, bind `sid` and JTI to the exact RP Session,
and verify the subject against the RP Session owner. A valid refresh cookie may identify the same
RP Session when the Access JWT is expired; no root Browser Session or Bearer fallback is permitted.

Successful logout uses the PostgreSQL RP-session revoke operation and clears only the browser's RP
credential cookies as credentials. The parent Base Browser Session and sibling RP Sessions remain
usable. GET sign-out pages do not perform authoritative mutation, and existing Rails CSRF
protection remains in force for POST mutation. Revocation prevents refresh and new Access JWT
issuance; it does not claim immediate invalidation of an Access JWT already issued, which remains
usable until its natural expiry and verifier clock-skew boundary.
