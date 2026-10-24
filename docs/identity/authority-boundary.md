# Identity Authority Boundary

> **Current Rails contract note (2026-10-24):** The migration context in this document is retained
> for historical reference. Its `acme/www` and `sign/id` authority descriptions do not supersede the
> current Rails OIDC contract in `adr/visa-op-host.md`: Visa is the sole physical IdP/AS, Auth is a
> ceremony-only service, Base is the `www.umaxica.*` browser RP, and browser RP registrations are
> surface-specific.

> **Participation update (2026-10-13):** The current first-party browser RP set also includes Palm
> (`palm-app`) and Tech (`tech-org`). Palm's native RP and bearer API roles are retired. Tech is an
> operator RP that requires `tech.access`. See `adr/tech-and-palm-browser-rp-participation.md` for
> the accepted contract and its implementation status; this document's older Palm-native and
> RP-launcher statements are historical.

> **Historical component model (2026-06-12; superseded for Palm on 2026-10-13):** The target
> component model was `docs/architecture/acme-sign-core-base-port.md` and
> `adr/acme-sign-core-base-port-boundary.md`. Acme is the only IdP / Authorization Server, Sign is a
> special RP, Core is the Next.js web RP/BFF, Base is the Rails foundation/control-plane subdomain,
> and Palm is the native bearer-token API Resource Server. This document remains historical Rails
> migration context where it describes `acme/www` and `sign/id`.

> **Settings ownership update (2026-07-01):** For Auth settings to Base identity migration work,
> `adr/identity-authority-boundary.md` and `docs/architecture/sign-settings-to-acme-identity.md`
> supersede the older compatibility-route language below. Retired non-exception Auth settings routes
> must be removed without redirect, alias, or `410 Gone` compatibility shims.

> **Historical-reading rule:** The migration sections below may mention Acme, Sign, shared
> `base-rails-rp`, or legacy `/sign/in` routes. Those mentions describe historical state only and
> are not current registration, authority, or routing instructions. Use
> `adr/base-auth-ceremony-and-seven-rp-boundary.md` for the active Rails contract.

> **Global / Regional database ownership (2026-09-08):** `adr/global-regional-database-ownership.md`
> confirms that the databases backing this authority — `*_zenith` (Account / Identity /
> Organization), `*_ticket` (Session / Token / OIDC), `*_setting` (Preference) — are **Global-only**
> and are never owned or written by the future Regional repository. Regional trusts acme-issued
> downstream tokens; it does not read a Global database directly.

## Historical Migration Boundary

`acme/www` is the Session, Token, Account, Preference, Authorization, and downstream-token
Authority. It also owns the general `/identity` settings surface that moved from Sign.

`sign/id` is not the IdP. It is a Credential Gateway and Credential Ceremony Zone. Its remaining
settings scope is limited to passkeys, TOTP, Google, and Apple.

Logical authority moves now; physical DB movement is out of scope. Existing sign-side tables,
models, namespaces, and route names do not imply sign-side authority.

The public sign-up route vocabulary is frozen. The migration target is authority ownership, not
renaming accepted `/sign/up/*` or `/social/*` paths.

## Historical Migration Status

This section describes the historical migration boundary. The implementation was still being
inverted when this record was written. Some existing `sign/id` routes and controllers may remain
reachable as compatibility routes until the active implementation slices move or redirect them.

That compatibility allowance does not apply to the Auth settings to Base identity migration.
Non-exception Auth settings routes for emails, telephones, birthdate, secrets, secret credentials,
sessions, revocations, activities, and withdrawal must become unroutable. Auth settings may retain
only app passkeys/TOTP/Google/Apple, com passkeys, and org passkeys/Entra. TOTP is app-only; com and
org do not expose TOTP enrollment, sign-in, Step-Up, or settings routes.

Compatibility routes must not be treated as new authority assignments. If implementation currently
mutates session, refresh, preference, dashboard, withdrawal, token, account, or step-up freshness
state from a sign-side route, that behavior is a migration gap tracked by the Identity Authority
inversion plans, not a competing source of truth.

Current Rails browser identity contract uses Visa as the sole OP/AS, Base as the browser RP, and
Auth as the credential ceremony surface. Core, Warp, Edit, Palm and Tech have host-local
relying-party entry and callback routes at `/sign` and `/oidc/callback`; the POST `/sign` start
requires a valid Rails authenticity token even when Fetch Metadata reports `same-origin`. Tech
additionally requires `tech.access` for protected content. Palm's native registration, bearer API
and app-scheme callback are retired. RP-local sign-out routes use `/sign/out` and
`/sign/out/completion`; implementation of the shared parent-and-RP revocation transaction remains
incomplete and is tracked in
`adr/first-party-sign-out-shared-database-without-backchannel-logout.md`. Social login entry points
use `/social/:provider/sign/in`, `/social/:provider/sign/up`, and `/social/:provider/callback`.
`google` and `apple` are canonical provider names; `google_app` is retained only in historical or
compatibility data.

Acme's local browser flow and Base Rails surfaces use the shared browser RP client id
`base-rails-rp`. Callback ownership is host-local: Acme hosts use Acme `/oidc/callback` endpoints,
and Base hosts use Base `/oidc/callback` endpoints. The `/oauth/authorize` login step establishes
Acme authority for code issuance, while each RP callback validates state, PKCE, nonce, and ID token
claims before establishing that host's local product browser session. The callback is not a second
authority issuer.

The first implementation slice is limited to route/controller classification, acme authority entry
points, and sign-to-acme redirects or delegates for authority surfaces. It does not physically move
tables and does not implement the full ceremony grant/result protocol.

## Acme/WWW Authority

`acme/www` owns:

- user session creation, continuation, rotation, revocation, logout, and device/session listing;
- refresh token families, replay handling, compromise state, and token rotation;
- OAuth/OIDC token authority and downstream token issuance;
- account lifecycle, including sign-up finalization, recovery, withdrawal, and restoration;
- preference writes, settings, dashboards, and session-management UI;
- authorization decisions and step-up freshness confirmation.

`core`, `line`, and future downstream services trust acme-issued downstream tokens. They must not
trust sign-issued session, access, or downstream tokens.

## Current Rails Result Boundary

The active Rails implementation uses Auth as a credential-ceremony service and Base as the sole OIDC
Identity Provider / Authorization Server. The Auth-to-Base result is a short-lived opaque Valkey
transport capability. The matching surface-local PostgreSQL authorization transaction is the durable
authority for its digest, generation, expiry, and Base finalization state.

Base reads the result only after validating the surface and transaction binding, then rechecks the
generation while holding the PostgreSQL transaction-row lock. A valid result may be retried while
its transport TTL remains; Base finalization is idempotent and creates at most one Browser Session
for the transaction. Authorization-code aliases share one durable grant, and the
`authorization_grant_redeemed_at` transition is claimed atomically with RP Session creation or
resolution in the surface ticket database.

Raw result and authorization-code values are not stored in PostgreSQL. Valkey is transport state,
not the authority for Browser Sessions, RP Sessions, or authorization grants. Rails forgery
protection remains enabled for the local and cross-surface POST boundaries. This contract does not
claim distributed ACID across PostgreSQL and Valkey or immediate invalidation of already-issued
Access JWTs.

## Sign/ID Gateway

`sign/id` may:

- host unauthenticated sign-in and sign-up entry points;
- execute credential ceremonies for passkey/WebAuthn, OTP, TOTP, social callbacks, sign-in, sign-up,
  credential enrollment, credential assertion, and step-up;
- keep credential inventory and short-lived ceremony state;
- consume or introspect an acme session only to decide whether a ceremony is needed;
- write ceremony audit records.

`sign/id` must not:

- issue sessions, refresh tokens, access tokens, downstream tokens, or step-up freshness;
- own preference writes, settings, dashboards, session-management UI, account lifecycle, withdrawal,
  or authorization decisions;
- treat physical sign-side tables or models as proof of sign-side authority.

## Historical Result Boundary (superseded for the current Rails flow)

Delegated credential work crosses the boundary through an acme-issued ceremony grant and a signed
ceremony result.

The grant is short-lived, audience-bound, purpose-bound, one-shot, and bound to an acme transaction
or session when applicable. The sign result is evidence only. `acme/www` consumes the result,
decides whether it satisfies the purpose, and commits any session, account, preference, token,
authorization, or freshness state.

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`
- `docs/security/credential-gateway.md`
- `docs/security/session-token-authority.md`

## Org Emergency Access

Org Emergency Access (`docs/security/org-emergency-access.md`) adds no Sign-owned session or token
authority. It reuses the same shared session-establishment path as normal org sign-in, and the
authentication context it records is produced by the shared claim builder
(`AuthorizationTokenClaims`) that the authority side already owns, from a column on the session row.

Two compatibility seams are stated explicitly rather than left implicit:

- The org credential-gateway controllers still call `establish_signed_in_session!` directly. That is
  pre-existing bounded legacy from the migration, not something Emergency Access introduced or
  widened; the Emergency ceremony was deliberately implemented on the same path rather than given
  one of its own.
- Step-up freshness continues to be committed on the authority side by
  `IdentityStepUpCeremonyFreshnessCommitter`. The Emergency prohibition is enforced there as well as
  at the ceremony entry, so the refusal lives with the authority that owns the decision.
