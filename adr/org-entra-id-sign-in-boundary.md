# ADR: Org Entra ID Sign-In Boundary

**Status:** Accepted (2026-06-30), partially superseded (2026-08-11, 2026-09-09)

**Partially superseded by:** `adr/org-entra-single-tenant-credential-configuration.md`, which
replaces certificate-based `private_key_jwt` with a client secret held in Rails credentials, and
replaces per-`OrganizationEntraConnection` tenant/client resolution with a single tenant configured
in credentials. The `tid + oid` lookup key, no JIT provisioning, the exclusion of
email/UPN/`preferred_username`, the `acct = 0` requirement, `org_zenith` placement, default-inactive
records, and the callback boundary discipline are unchanged and still govern.

## Context

Enterprise customers whose staff accounts are managed in Microsoft Entra ID have requested SSO for
the org surface so that a single corporate credential can satisfy the sign-in ceremony. The org
surface currently supports Passkey (WebAuthn) and secret-credential sign-in only. There is no
third-party federated identity entry point.

The Cloudflare Access ADR (`org-cloudflare-access-authentication-layer.md`, 2026-06-29) explicitly
scopes Cloudflare Access to read-only org content (docs/help/info/news). `auth/org`, `base/org`, and
`core/org` continue using full Operator session and credential ceremonies. Entra ID sign-in must
therefore be implemented at the Rails application level as an additional credential ceremony, not at
the edge.

## Decision

### Sign-in only; no provisioning

The Entra ID flow is sign-in only. No Operator record, `OperatorEntraIdentity` record,
`OrganizationEntraConnection` record, or any other principal or membership record is created during
the callback. If a matching pre-provisioned `OperatorEntraIdentity` does not exist, the callback
fails. No JIT provisioning occurs.

### Stable lookup key: `tid + oid`

The only Entra-side identity key used for auth lookup is the combination of:

- `tid` — the Entra tenant ID (a UUID, stable for the lifetime of the tenant)
- `oid` — the Entra object ID (a UUID, stable for the lifetime of the user object in that tenant)

`iss` (derived from `tid`) and `sub` (pairwise pseudonymous, varies by client_id) are stored as
protocol evidence only and are never used for auth lookup.

`email`, `preferred_username`, and `upn` are mutable in Entra. They must not be stored as
identity-determining fields, must not be used as lookup keys or fallback keys, and must not be
requested from Entra. The scope is `"openid profile"` only. `"email"` scope is not requested. The
UserInfo endpoint is never called.

The application registration must emit the optional `acct` claim in ID tokens. Authentication
accepts only `acct = 0`; guest accounts, missing account-type evidence, and personal Microsoft
accounts fail closed.

### Database placement: `org_zenith`

Both `OrganizationEntraConnection` and `OperatorEntraIdentity` are placed in the `org_zenith`
database (base class: `OrgRpRecord`), alongside `OperatorIdentity`. Rationale: both records carry
identity-authority semantics (which tenant is trusted, which `(tid, oid)` pair maps to which
Operator). `org_zenith` is the identity database. `org_principal` is the actor database.
`org_ticket` is the session/token database. Federation records belong with identity, not sessions.

### Why not the existing `operator_identities` table

`OperatorIdentity` uses a generic `(issuer, subject, audience)` key designed for any OIDC IdP.
Entra-specific records require `tid` validation, connection-scoped activation state, and a fixed
`tid + oid` lookup path. Sharing the table would obscure the Entra-specific invariants and couple
the Entra schema to the generic OIDC schema, making independent evolution of either harder. Separate
tables also allow Entra-specific indexes and constraints without affecting the generic OIDC flow.

### OmniAuth is not used on the org surface -- superseded

**Superseded by `adr/org-entra-omniauth-strategy-migration.md` (2026-07-31).** The blanket
`OmniAuthNonAppSocialGuard` block on all `/social/*` traffic for non-app hosts is replaced by an
explicit provider/surface allow matrix (`OmniAuthSocialProviderHostMatrix`) that allows only `entra`
on the org (staff) host and only `apple`/`google` on the app host. Entra ID sign-in is now
implemented as a Umaxica-specific OmniAuth strategy under `/social/entra/*`. Every other decision in
this ADR (no JIT provisioning, `tid + oid` lookup key, no email/UPN/name, `org_zenith` placement,
certificate-based `private_key_jwt`, default-inactive records, callback boundary discipline, MFA
bypass policy) is unchanged and still governs the new implementation; see the new ADR for what
changed and why.

### Logical references for `organization_id` and `operator_id`

`OrganizationEntraConnection#organization_id` is a logical reference to `organizations` in
`org_principal`. `OperatorEntraIdentity#operator_id` is a logical reference to `operators` in
`org_principal`. Both are in a different database (`org_zenith` vs `org_principal`), so no enforced
cross-DB foreign key exists. Presence and uniqueness are enforced at the ActiveRecord layer. If
Organization or Operator canonical placement later moves fully into `org_zenith`, the Entra lookup
contract remains unchanged: `tid + oid`.

### Default inactive status

Both `OrganizationEntraConnection` and `OperatorEntraIdentity` default to `status: :inactive`. No
activation occurs automatically. An administrator must explicitly activate each record before it can
be used for sign-in. This is deny-by-default applied at the data layer.

### `operator_id` uniqueness (v1: one Entra identity per Operator)

For v1, `operator_id` is unique across `operator_entra_identities`. One Operator may have at most
one Entra identity mapping. This is intentionally strict. If multi-tenant or multi-provider Operator
mappings are needed in the future, the unique constraint can be loosened and the lookup key adjusted
without changing the `tid + oid` auth contract.

### Certificate credential reference

`OrganizationEntraConnection#entra_credential_key` stores only the name of a Rails credential. The
referenced value contains the certificate and private key PEM. Token exchange uses a short-lived
PS256 `private_key_jwt` assertion with an `x5t#S256` certificate thumbprint. Neither private key nor
client secret is stored in the database.

### Callback boundary -- superseded

**Superseded by `adr/org-entra-omniauth-strategy-migration.md`.** The callback is now
`GET /social/entra/callback`, handled by the OmniAuth strategy
(`lib/omniauth/strategies/umaxica_entra.rb`) plus
`Auth::Org::Omniauth::OmniauthCallbacksController`; neither
`ExternalAuthentication::EntraProviderAdapter` nor `ExternalAuthenticationOrgEntraCeremonyStore`
exist anymore -- the strategy owns code exchange and token verification directly, and
state/nonce/PKCE are the OmniAuth gem's own session-based mechanism rather than a bespoke ceremony
store. The redirect URI is still never derived from request host, forwarded host, or referer, and
the deny-by-default identity resolution, discard of raw tokens, and `ENTRA_SOCIAL_CEREMONY_ENABLED`
gate are all unchanged in substance; see the new ADR for exactly how each is implemented now.

### Entra is the first stage of normal sign-in, not the whole of it (2026-09-09)

A successful Entra callback no longer establishes a session. It identifies the Operator and records
that identification in a short-lived, purpose-bound, one-shot pending transaction
(`OrgNormalSignInTransaction`), then hands the browser to the passkey stage; the ceremony completes
there, or at the existing Secret/SecretKey stage when the passkey is lost. Entra authentication
alone is therefore no longer sufficient to complete the normal org sign-in ceremony.

The second stage reads the Operator only from that transaction, never from a request parameter, so
an Entra result for Operator A cannot be completed with Operator B's credential. The identity-key
decisions, the no-JIT-provisioning guarantee, the claim exclusions, and the callback boundary
discipline below are unchanged.

The org surface also gained a second, Entra-free sign-in ceremony, Emergency Access, which produces
a restricted session. See `docs/security/org-emergency-access.md`.

### MFA bypass policy: `entra_id` is not bypassed

Entra ID sign-in does not bypass local MFA. `AuthenticationBase#mfa_bypassed_for_auth_method?`
(`app/controllers/concerns/authentication_base.rb:2858-2860`) returns `true` only for `"passkey"`;
`"entra_id"` falls through to `false`, matching `"secret_credential"`. An external IdP assertion is
not treated as equivalent to local strong evidence of presence. An operator who signs in via Entra
ID and has TOTP enrolled is still required to complete the TOTP step-up before the session is
established. Since 2026-09-09 the callback establishes no session at all, so the question is settled
a stage earlier: the session is established by the passkey or secret stage that follows, through the
same `establish_signed_in_session!` path, with the same MFA gate. This keeps Entra ID at AAL1 unless and
until an explicit trust policy is introduced for it.

### Scope of this ADR

This ADR covers the data model boundary, identity key decisions, callback boundary, the
no-provisioning guarantee, and the MFA bypass policy above.

## Consequences

- `OrganizationEntraConnection` and `OperatorEntraIdentity` are new models in `org_zenith`.
- Neither model contains an `email`, `upn`, `preferred_username`, or `display_name` column.
- All records default to `:inactive`; sign-in is impossible until explicit activation.
- The callback resolver must be deny-by-default: raise on any miss, never create.
- App Google/Apple social login is unaffected.
- Since 2026-09-09 the callback issues a pending transaction and redirects to the passkey stage
  instead of establishing a session; `handle_sign_in_result` no longer exists on this controller.
- `OmniAuthNonAppSocialGuard` is replaced by `OmniAuthSocialProviderHostMatrix`; see
  `adr/org-entra-omniauth-strategy-migration.md`.
- `omniauth_openid_connect` is now the production Entra path, subclassed by a Umaxica-specific
  strategy (`lib/omniauth/strategies/umaxica_entra.rb`); see the new ADR for the contract tests that
  gated this and the overrides that preserve every guarantee above.
