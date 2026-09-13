# ADR: Org Entra ID single-tenant, credential-configured sign-in

**Status:** Accepted (2026-08-11)

**Supersedes:** the client-authentication and per-connection sections of
`org-entra-id-sign-in-boundary.md` and `org-entra-omniauth-strategy-migration.md`. Every other
decision in those ADRs is unchanged and still governs; see "What is unchanged" below.

## Context

The org Entra ID ceremony had never completed a sign-in. The implementation assumed a multi-customer
federation — each customer organization holding its own Entra app registration as an
`OrganizationEntraConnection` row with its own tenant id, client id, and a certificate reference for
`private_key_jwt` client authentication. Because tenant and client were per-row, the ceremony could
not build an authorize URL until a connection was chosen, so an interstitial page asked the operator
to supply a `connection_public_id`.

The deployment looked nothing like that:

- `OrganizationEntraConnection` and `OperatorEntraIdentity` were both empty, and nothing could
  create either. `Auth::Org::Settings::EntrasController#create` only looked up an existing
  connection and redirected; no seeds defined them. The runbook's claim that pre-registration
  happened through that settings surface was false.
- Rails credentials held `OMNI_AUTH_ENTRA_ORG_TENANT_ID`, `OMNI_AUTH_ENTRA_ORG_CLIENT_ID`, and
  `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET` — the same flat shape used for Google and Apple — and **no
  code read any of them**.
- No certificate credential existed at all, so the token exchange could only ever fail with
  `client_assertion_unavailable`.

The org surface federates exactly one tenant: the company's own. No other company's staff will ever
sign in to the org surface. The multi-customer machinery was carrying a cost — an extra page, an
extra record to provision, an extra failure mode — for a capability that is not required.

## Decision

### Single tenant, configured in Rails credentials

Tenant id and client id are named on the `ExternalAuthentication::ProviderRegistry` entry for
`entra` (`tenant_credential_key`, `audience_credential_key`) and read from Rails credentials,
exactly as Google and Apple name theirs. The registry resolves the concrete issuer as
`issuer_template % tenant_id`. Missing configuration raises at boot naming the key rather than
registering a provider that cannot complete an exchange.

`OrganizationEntraConnection` is no longer read on the sign-in path.

### Client authentication is a client secret held in Rails credentials

Client authentication is `client_secret_post` (`client_auth_method: :client_secret_post`), with the
secret in Rails encrypted credentials. Certificate-based `private_key_jwt` is not used, and
`ExternalAuthentication::EntraClientAssertionAdapter` was deleted.

This reverses `org-entra-id-sign-in-boundary.md`'s "Do not create or store a client secret", and it
is worth being precise about what changed relative to
`20260731120000_replace_entra_client_secrets_with_certificate_references.rb`, which removed the
`entra_client_secret` **column**. This is **not** a return to that state: the old design stored a
client secret in the **database**; this design stores it only in **Rails encrypted credentials**,
and no secret is stored in the database at all. The secret-handling posture is better than the
pre-migration state, and the certificate option remains available if the threat model later warrants
the operational cost of certificate rotation.

### Entra rejoins the app surface's external-authentication interface

Entra is built by `ExternalAuthentication::ProviderAdapterFactory` like Apple and Google. The new
`EntraProviderAdapter` implements the same contract — `#call(auth_hash:, verified_at:)` returning a
`CallbackResult` wrapping a `VerifiedPrincipal` — and populates the `tenant_context` field that
`VerifiedPrincipal` already required for `"entra"`. Claim validation stays in
`ExternalSignIn::Providers::EntraId`; the adapter only normalizes claims that verifier already
checked.

The registry entry, `VerifiedPrincipal`'s `"entra"` provider, and `EntraTenantContext` already
existed. This completes a unification the codebase had already anticipated.

### Ceremony start is a reviewed shared abstraction

`SocialCeremonyEntry` is now surface-neutral: it holds the provider allow-list check, the provider
availability gate, and the 307 handoff to the OmniAuth request phase, and nothing else. Surfaces
supply `social_ceremony_surface`, `social_ceremony_providers`, and `social_ceremony_abort_path`;
these three raise `NotImplementedError` rather than defaulting, so a surface cannot silently inherit
another surface's provider list or redirect target.

`AppSocialCeremonyEntry` includes it and adds everything app-specific: `SocialAuth`,
`SignUpSuspensionGuard`, sign-up entry detection, ceremony replay grants, `ClientSignUpFlow`
issuance, and the link/step-up intents. The org surface implements the three hooks only.

This is the explicit reviewed shared abstraction `.agents/harnesses/rules/project/surfaces.mdc`
requires — that rule forbids _unreviewed_ cross-surface sharing, not sharing as such. **Only
ceremony start is shared.** Identity storage, session establishment, and callback handling remain
surface-local, and the org surface has no social sign-up at all.

`Auth::Org::Social::SessionsController` and its `session/new` + `session` routes are kept so both
surfaces expose the same ceremony shape; only the connection lookup and its input field were
removed.

### Schema

`operator_entra_identities.connection_id` became nullable and lost its foreign key
(`20260811190000_detach_operator_entra_identities_from_connections.rb`). The lookup key is
unchanged: the `(entra_tenant_id, entra_object_id)` unique index.

`organization_entra_connections` is **left in place and is now vestigial** — nothing on the sign-in
path reads it. It was not dropped because dropping a table is destructive and multi-tenant
federation is a plausible future requirement. It should not be read as an active mechanism.

## What is unchanged

Every security property of the original boundary ADR still holds and is still tested:

- `tid + oid` is the only identity lookup key. `iss` and `sub` are audit evidence only.
- **No JIT provisioning.** `ExternalSignIn::OrgEntraResolver` raises `IdentityNotFoundError` and
  creates nothing; an operator without a pre-provisioned identity cannot sign in.
- `email`, `upn`, and `preferred_username` are never stored, requested, or used as keys. Scope is
  `openid profile`; UserInfo and Microsoft Graph are never called.
- `acct = 0` required; guests, missing account-type evidence, and personal Microsoft accounts fail
  closed. The Microsoft consumer tenant is rejected.
- Endpoints stay tenant-fixed: `common`, `organizations`, and `consumers` are never used, and
  Discovery stays disabled.
- No raw ID token, access token, or refresh token enters the AuthHash. `info` and `credentials`
  remain plain-method overrides, because the base gem's block DSL would merge ancestors' blocks and
  re-introduce the UserInfo call.
- PKCE S256, `state`, and `nonce` remain required, handled by the base gem's session mechanism.
- Identity records still default to inactive; activation is deliberate.

### Tenant restriction without a connection row

Previously an inactive or absent connection stopped a tenant. Now the strategy verifies every ID
token against the single configured tenant, so a token from any other tenant is rejected before
identity resolution. Revoking one person's access is an identity-state change
(`SUSPENDED`/`REVOKED`), which the resolver honours and which is covered by test.

## Amendment (2026-09-09): client_secret_post and boot-time credential validation

Two parts of the decision above are refined; nothing else in this ADR changes.

### Client authentication moved from `client_secret_basic` to `client_secret_post`

The original decision specified `client_auth_method: :basic`, which rack-oauth2 renders as an
`Authorization: Basic` header. The strategy now passes `:client_secret_post`, which rack-oauth2 has
no named branch for, so it falls through to the default that puts `client_id` and `client_secret` in
the token request body and sends no `Authorization` header. Entra's v2.0 token endpoint accepts
both.

The reason to prefer the POST body form is that `client_secret_basic` requires the client id and
secret to be `application/x-www-form-urlencoded` **before** base64 encoding, per RFC 6749 §2.3.1.
That is a step implementations disagree about, and getting it wrong on a secret containing reserved
characters produces an authentication failure that looks like a wrong secret. `client_secret_post`
has no such encoding subtlety, and it keeps the credential in one place instead of split across a
header and a body.

The wire shape is pinned by `test/contracts/omniauth_entra_token_request_contract_test.rb`, which
drives the real `Rack::OAuth2::Client` with the transport stubbed and asserts that the credentials
are in the body and that no `Authorization` header is sent. That test is the regression detector for
a future rack-oauth2 upgrade that changes this fall-through.

### All three Entra credentials are validated at boot

The original wording — "Missing configuration raises at boot naming the key" — was only true of
`OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET`. Tenant id and client id were read lazily through
`ExternalAuthentication::ProviderRegistry` on the first sign-in, so a deployment missing either
booted healthy and failed at the first staff sign-in instead.

`EntraOmniauthBootCredentials.resolve_for_boot` now validates all three in
`config/initializers/omniauth.rb`:

| Credential | Required | Shape |
| --- | --- | --- |
| `OMNI_AUTH_ENTRA_ORG_TENANT_ID` | yes | non-blank, UUID |
| `OMNI_AUTH_ENTRA_ORG_CLIENT_ID` | yes | non-blank, UUID |
| `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET` | yes | non-blank |

The UUID rule also rejects `common`, `organizations` and `consumers` as tenant ids, which this ADR
already forbids, so the single-tenant constraint is now enforced at boot rather than only by
convention.

Validation is presence and shape only. Boot performs no network I/O, so it cannot depend on
Microsoft being reachable; semantic checks (issuer metadata, tenant reachability, redirect URI)
remain in `OrgEntraSignInPreflight`. No credential value appears in an exception message or a log —
the errors name the key only.

Development and test still boot without any Entra credentials, and omit the provider, so non-Entra
suites do not need an IdP credential. A **partially** configured local environment fails rather than
silently disabling staff sign-in.

## Consequences

- The interstitial page and its free-text `connection_public_id` field are gone; the org sign-in
  button behaves like the app surface's Google and Apple buttons.
- Provisioning an operator still requires creating an `OperatorEntraIdentity`, and there is still no
  UI for it. That gap is unchanged by this ADR and remains the last step before first sign-in.
- The connection-lookup timing pad in the strategy's request phase was removed with the lookup it
  protected: there is no longer a pair of inputs whose handling could differ in time.
- Multi-customer federation would need this decision revisited, the connection concept restored on
  the sign-in path, and per-connection credentials reintroduced.
