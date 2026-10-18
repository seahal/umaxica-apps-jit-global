# Rails Directed Jump Rollout

The accepted contract is `adr/jump-directed-rails-handoff-contract.md`. This Rails change is
separate from the Hono minor release; it performs no gateway deployment, binding/secret write or
migration.

## Required implementation

1. Palm RP round-trip: browser entry, Palm-to-Base RT, public JWKS, Base-to-Palm return
   verification, state-bound native delivery and existing sign-out handoffs. Preserve native PKCE
   ownership and the `palm-api` audience.
2. Core issuer normalization: `jp.umaxica.*` for JWT/Jump/JWKS. Keep persistence normalization in a
   separately approved migration; do not silently rewrite stored bridge identities.
3. Stale `www.jp.*` removal: no executable positive contract or alias. Keep negative regression
   cases to prove rejection. Warp canonical origins remain `www-jp.*`.
4. Directed return policy: exact same-TLD Base/Auth and Base/approved-RP pairs. Required RPs are
   Warp App/Com/Org JP, Core App/Com/Org JP and Palm App JP. Deny self-loop and cross-TLD.
5. Receiver parity: Auth Com/Org and Palm receive the same Jump signature, claim, URL and source
   verification as the existing receivers. Preserve rate limits and security-control ordering.
6. Public destination and production Jump contract: public HTTPS browser targets; explicit opt-in
   development issuance with explicit public issuer/JWKS/kid/return configuration and dedicated
   keys. Hono trust registration remains a separate deployment prerequisite.
7. Obsolete Sign issuer removal: `AUTH_*`, `auth.*`, matching JWKS and configuration references.
   Keep `/sign/...`, stored `side-*`, `SIDE_*`, and independent ceremony protocol values.

## Deployment prerequisites

- Register the approved graph and Rails issuer/JWKS trust in the separately managed gateway.
- Supply `JWT_AUTH_{APP,COM,ORG}_{ACTIVE_KID,PRIVATE_KEY,PUBLIC_KEYSET,REVOKED_KIDS}` using the
  existing Auth material; retire the old variable names without a runtime alias or implicit copy.
- Supply scoped Palm signing configuration and check Warp/Palm public JWKS from the gateway's
  network. A development-generated key published in a canonical origin's JWKS becomes a full signing
  key of that canonical issuer; publish one only as a deliberate operating decision.
- Confirm the public host variables match the canonical graph, especially Core `jp.*`, Warp
  `www-jp.*`, Palm `palm-jp.*`, Base `www.*` and Auth `auth.*`.
- Coordinate native apps: browser launch on Palm, new Palm HTTPS redirect URI for Base code
  redemption, and fixed native delivery callbacks. The HTTPS Palm receiver must reach Rails before
  native link interception; any claimed app-link endpoint must be a separate delivery endpoint.
- Development live Jump derives each issuer, return origin and JWKS URI from the existing `PUBLIC_*`
  surface setting and signs with installer-owned local keys. `Rails.env` does not select the
  identity: a canonical origin is allowed when its public JWKS publishes the local kid, while
  localhost, private ingress and other non-public values fail at boot.
- `PUBLIC_JUMP_GATEWAY_URL` is the sole gateway setting; JWKS URI and `aud` are derived, and
  `JUMP_GATEWAY_URL` plus the old JWKS/audience settings fail boot. `PRIVATE_JUMP_GATEWAY_URL` fails
  boot when set, even empty, because Rails has no private path to Jump. Hono must emit a required
  `rpl: "reuse"` on return tokens before the round trip works again; Rails provides no compatibility
  fallback in the meantime.
- Specify independent host-bound browser continuity for development RP/Base/Auth surfaces as part of
  that contract. Production uses host-only `__Host-session`; the shared-domain test session cookie
  requires explicit per-host transport in the multi-surface integration fixture.
- Plan reauthentication for old Auth surface access JWTs and drain incompatible native/Core
  authorization ceremonies before cutover. Their lifetimes are separate from Jump's RT TTL.

## Verification and rollout

Verify the complete graph's allowed and denied pairs; issuer-to-public-JWKS key agreement; receiver
claim and exact-URL binding; required exact `rpl: "reuse"` and receiver-owned one-time state. Verify
PKCE, state, nonce propagation and Palm missing/mismatched/expired/replayed callbacks. Keep native
bearer API and signed POST ceremonies under their existing independent controls.

Retain the prior production artifact and configuration reference, then deploy in a coordinated
window. Smoke Base/Auth for each TLD and required RP round-trips, including native authorization
code redemption and logout. Local automated tests do not establish public DNS, gateway trust, device
callbacks or production acceptance. Retain deployment evidence before declaring rollout done.

## Rollback contract

- Introduce no DB/KV/persistent storage migration.
- Keep production Jump signing keys, active kid and public JWKS unchanged.
- Preserve the `schema=1` and ES384 Jump wire contract.
- Separate secrets/bindings changes from application code; record their independent rollback refs.
- Retain the immediately preceding production revision/artifact.
- Account for N/N-1 RTs throughout TTL plus clock leeway. Coordinate incompatible issuer/graph
  cutover by draining tokens rather than introducing retired-host or issuer aliases.
- Roll back native client registration/application behavior together if their contract changed;
  drain outstanding authorization codes and transactions according to their actual lifetimes.
- After rollback smoke existing same-TLD Base/Auth in both directions.

## Review then fix

- Edit Org RP round-trip and graph inclusion require a separate explicit design decision.
- A finite destination allowlist in `JumpRtIssuer` requires a separate issuer least-privilege
  decision. This change validates public URL form and receivers' graph but does not add that list.
- Existing Core bridge column defaults/rows need a separate persistence/cutover plan. Explicit
  legacy production Host Authorization entries are removed; this change supplies no migration.

## Final Rails contract freeze

The graph is thirteen canonical nodes and exactly twenty directed edges, listed in the accepted ADR.
The fixed test enumerates all 169 ordered canonical pairs and compares the entire runtime allowlist
against literal expected edges. The authority test signs and verifies RTs with each of the thirteen
issuer origins' published public JWKS. Palm is implemented and approved; native custom-scheme
completion is final device delivery, never a Jump destination.

Edit's Jump issuer mapping, surface registry entry and surface JWKS endpoint are removed. Its OIDC
client namespace, private-key assertion configuration and callback/logout registration remain.
Canonical same-site admission is characterized independently from the unsupported Jump path.
Production `jpx.*` Host Authorization aliases are removed without changing stored rows.

Development issuance requires the documented public settings and isolated keys. Supplying valid
Rails settings does not establish gateway registration or public reachability. Hono receives this
frozen graph and the canonical issuer/JWKS contract; development identities must be registered
explicitly against their logical node IDs before public rollout.
