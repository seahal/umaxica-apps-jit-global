# OIDC Discovery Profile (historical Acme vocabulary)

> **Current-contract supersession (2026-10-24):** This profile predates the Visa OP / Base RP host
> split. Its Acme issuer vocabulary and discovery descriptions are retained for protocol-history
> context only. The active Rails OIDC authority is Visa, Auth is ceremony-only, and Base is the
> browser RP. The current client/route contract is defined by `adr/visa-op-host.md`,
> `app/values/oidc_issuer.rb`, and the live Visa/Base route registries. Do not use this document to
> restore an Acme route family or a shared Base OP/RP host.

Visa (`https://visa.umaxica.app`, `.com`, `.org`) is the only IdP / Authorization Server. Sign /
Core / Base / Palm are relying parties and hold no IdP authority. The historical sections below
retain Acme names where they describe the former profile. This document records the intentional,
non-default choices in Acme's published OIDC metadata so reviewers do not mistake them for gaps.

Source of truth: `app/values/oidc_discovery_document.rb`, `app/values/oidc_issuer.rb`.

## ES384-only is a private profile, not strict OIDC conformance

`id_token_signing_alg_values_supported` and `token_endpoint_auth_signing_alg_values_supported` are
both `["ES384"]`. The OpenID Connect Core conformance profiles expect `RS256` support; Visa
**intentionally does not** offer `RS256`.

First-party JWT access tokens (`auth_access` and preference access) follow RFC 9068 in token
structure, claims, semantics, and validation requirements. ES384 is the sole supported signing
algorithm. UMAXICA intentionally does not implement the RFC 9068 §2.1 requirement that conforming
authorization servers and resource servers include RS256 among their supported signature algorithms.
ES384 itself is permitted by RFC 9068; the deviation is the absence of RS256 support. See
`adr/rfc9068-access-token-profile.md`.

This is a deliberate private profile:

- All ID Tokens and client assertions are EC P-384 / ES384.
- JWKS publishes only EC P-384 keys (`kty=EC`, `crv=P-384`, `alg=ES384`, `use=sig`).
- Relying parties in this system are first-party (Sign / Core / Base / Palm) and are configured for
  ES384, so the broad-compatibility argument for `RS256` does not apply.

The logout completion URI is not part of discovery. Discovery continues to publish
`end_session_endpoint` as `https://<visa-surface-host>/oidc/logout`; browser completion returns to
the RP surface-local `/sign/out/complete`, or the Base RP completion route when the RP is a Base
host.

If `RS256` is ever required, it must be implemented end to end (key rotation, JWKS publication, ID
token signing selection, client-assertion verification, and tests) rather than advertised in
metadata alone.

## `ri` is not part of the OIDC contract

`ri` (region identifier, `jp` / `us`; see `app/services/request_context_contract.rb`) is a
localization/preference hint, not an OIDC protocol parameter.

- The discovery endpoint is served by a `BareController` and ignores `ri`.
- `issuer` is always the corresponding `https://visa.umaxica.*` origin with no query or fragment,
  regardless of `ri`.
- Advertised endpoints (`authorization_endpoint`, `token_endpoint`, `userinfo_endpoint`, `jwks_uri`,
  `revocation_endpoint`, `end_session_endpoint`) never contain `ri`.
- Key selection is by surface (host), orthogonal to `ri`.

A client may pass `?ri=jp` on requests for UI localization, but the OIDC contract (issuer, endpoint
URLs, key selection) does not depend on it and must never be broken by it.

## UserInfo is a bearer resource

`/oauth/userinfo` authenticates with an OAuth **access token** only:

- No cookie/session fallback.
- ID tokens are not accepted as bearer credentials.
- `openid` scope is required; missing scope yields `403` with
  `WWW-Authenticate: Bearer error="insufficient_scope", scope="openid"`.
- Missing/invalid tokens yield `401` with `WWW-Authenticate: Bearer ...` (RFC 6750 §3).
- Profile claims are scope-gated: `email` / `email_verified` require the `email` scope, `name`
  requires the `profile` scope.

## Signing-key hygiene on public deployments

`JitSecurityJwtRegistry` refuses to publish dev/test/fixture-marked `kid`s outside local Rails
environments (`enforce_public_key_hygiene?`). Development and test may mint local keys; production,
staging, review, and other non-local environments must provide deployable key identifiers. See
`docs/operations/jwt-key-rotation.md` for rotation guidance.

## Delivered reconciliation (2026-10-24)

Visa is the active OIDC discovery, authorization, token, UserInfo and logout authority. The
discovery document is generated from the registered allowlist and advertises only supported grant
types and endpoints. UserInfo accepts Bearer credentials on GET or POST and applies scope-filtered
claims. The old Acme vocabulary in the lower sections is historical; the current route and client
registry are defined by the Visa OP ADR and live route tests.
