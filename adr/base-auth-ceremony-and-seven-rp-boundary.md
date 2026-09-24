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
Sign up; Auth owns that internal ceremony choice. The obsolete shared browser registrations
`sign-rp`, `base-rails-rp`, and `side-rails-rp` are retired from the local registry after the
surface-specific flows work. `core-next-rp` remains a separately gated compatibility registration
until its live `CoreRpBridge` path and external registration/key ownership are reconciled. Native
clients remain as a separate future-facing boundary. The read-only `docs`, `news`, and `help`
surfaces are Rails content/resource surfaces, not Rails-authenticated OIDC RPs; they have no
content RP registrations in the current static client registry.

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

The following paragraph records the state as of the 2026-09-17 amendment and is superseded for the
regional target by the approved 2026-09-23 regional expansion amendment below. External RP
configuration, deployed callers, and legacy-session migration remain separately gated.

## Regional RP expansion amendment (2026-09-23)

The prior seven-client target is superseded as the approved end-state for regional Core and Side
RPs. The approved pre-deployment target is thirteen logical clients: `core-app-jp`,
`core-app-us`, `core-com-jp`, `core-com-us`, `core-org-jp`, `core-org-us`, `side-app-jp`,
`side-app-us`, `side-com-jp`, `side-com-us`, `side-org-jp`, `side-org-us`, and global `edit-org`.
This is an expand-and-contract migration; the current seven-client registry and `core-next-rp`
compatibility path remain until explicit caller, session, code, key, and retirement evidence exists.

Every regional client is independently bound to its client ID, existing audience semantics, exact
redirect URI, post-logout URI, backchannel logout URI, private-key-JWT namespace, and RP Session
client identity. JP and US credentials are rejected across those bindings before authorization-code
consumption, token issuance, or RP Session issuance. Side/Wide to Warp naming is not part of this
amendment. Canonical URI and audience values must come from an existing repository SSOT; missing
values are an implementation gap, not permission to derive registrations from Host headers.

Production Base registration, real key fingerprints, deployed-caller migration, and retirement are
deployment acceptance gates. This amendment authorizes only repository contracts and isolated
pre-deployment verification.

The pre-deployment contract is the following single logical matrix; it is not permission to
activate incomplete registrations:

| Surface | JP | US |
| --- | --- | --- |
| Core App | `core-app-jp` | `core-app-us` |
| Core Com | `core-com-jp` | `core-com-us` |
| Core Org | `core-org-jp` | `core-org-us` |
| Side App | `side-app-jp` | `side-app-us` |
| Side Com | `side-com-jp` | `side-com-us` |
| Side Org | `side-org-jp` | `side-org-us` |

`edit-org` remains the single global RP. The matrix is a contract source for tests and migration
ordering; it does not derive an audience from the client ID or derive a registration from an
arbitrary Host header. Each cell must obtain its exact audience and URI bindings from a canonical
repository source before it can become an active registry entry. A missing regional audience or
canonical host is a fail-closed implementation gap, not a value to invent. The existing seven
client registry and `core-next-rp` remain during expand-and-contract migration until caller,
session, code, key, and retirement evidence is available.

`RegionalRpClientMatrix.expected_registry_contract` is the repository-side expected Base registry
contract for these thirteen cells. It is derived from `AuthBoundaryAuthorityMap` and records the
actor, region, logical key namespace, RP-session client binding, and source of the canonical host
and audience. It does not activate a registry entry, generate a key, or provide a missing host or
audience value. The `auth:regional_rp_contract` task evaluates the exact bindings when those sources
exist and reports missing inputs fail-closed. The active compatibility registry and `core-next-rp`
therefore remain unchanged in the pre-deployment cycle.

## Shared browser-client retirement amendment (2026-09-22)

The obsolete shared browser registrations and builders for `side-rails-rp`, `sign-rp`, and
`base-rails-rp` were removed from the local static registry after a repository call-path audit and
surface-specific test migration. Side, Core, and the app RP callback tests now use independent
surface registrations. This does not by itself retire any external registration or key. The
remaining `core-next-rp` registration remains a separate migration gate because its legacy
`CoreRpBridge` runtime path and external registration/key ownership still require reconciliation.

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

## Already-authenticated RP-start amendment (2026-09-22)

The neutral `POST /sign` boundary refuses a browser that is already authenticated by the root
Browser Session or by a valid access credential for that same RP. The refusal is evaluated on the
server before a new state/nonce/PKCE transaction is created; the browser must sign out before
starting another RP authentication. A credential for another surface is not accepted as proof for
the current RP. This check reuses the existing host, issuer, audience, resource-type, and client
binding of the RP access-cookie contract and does not add a per-request RP Session lookup or weaken
Rails CSRF protection. `GET /sign` remains a non-mutating entry page.

## OIDC result transport amendment (2026-09-20; amended 2026-09-22)

The browser result from Auth back to Base is POST-only. Auth's local `GET /sign/oidc/handoff`
renders a same-origin CSRF-protected form; its `POST /sign/oidc/handoff` issues the opaque,
surface-bound result. The result is a short-lived Valkey transport capability, while its digest,
generation, expiry, and finalization state are persisted on the surface-local PostgreSQL
authorization transaction. Auth then renders a cross-surface form that submits the result in the
body to the matching Base `POST /oauth/authorize` endpoint. The result is never placed in a
redirect URL, query string, fragment, or Rails-session pre-authentication map.

Base accepts the result only from the exact configured Auth origin (plus the existing same-site
null-origin proxy case), validates the result against the transaction before finalization, and
checks the surface before resuming the pending authorization transaction. The result generation
read from Valkey is passed into finalization and rechecked while the PostgreSQL transaction row is
locked, so a result superseded by a newer generation cannot execute Browser Session finalization.
A valid current result may be retried while its short Valkey TTL remains; PostgreSQL row locking
and `base_finalized_at` make Browser Session finalization idempotent. `GET /oauth/authorize?result=...` is not a result
consumer. Rails forgery protection remains enabled; no global CSRF configuration or normal Rails
CSRF boundary is weakened for this transport. Auth remains ceremony-only and Base remains the
authority for the authorization transaction and all resulting Browser Session, RP Session, and
authorization-code state.

The result transport is not the one-time authorization grant. Base creates one Browser Session per
OIDC transaction, and authorization-code aliases reference that durable transaction. The
surface-local `authorization_grant_redeemed_at` transition is atomically claimed in the same
ticket-database transaction that creates the RP Session, so a retrying or duplicated alias cannot
create a second RP Session or replace the first session's metadata. Raw result and authorization
codes are never stored in PostgreSQL; Valkey stores only their short-lived opaque transport state.

This amendment closes the Base/Auth OIDC finalization slice. It does not claim distributed
atomicity across PostgreSQL and Valkey: after the durable token transaction commits, Valkey code
cleanup is best-effort and no credential is returned from an unsuccessful database transaction.

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
