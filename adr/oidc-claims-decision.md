# OIDC Claims Decision Memo

## Status

Accepted as the current design direction.

> **Partial supersession (2026-06-02):** The vocabulary and security properties in this ADR remain
> useful, but authority ownership is superseded by `adr/identity-authority-boundary.md`. `acme/www`
> owns session, token, account, preference, authorization, downstream-token trust, and step-up
> freshness. `sign/id` owns only credential inventory and short-lived credential ceremony state.

## Decision

For OIDC-facing identity claims, the repository will use:

- `sub` as the stable subject identifier
- `subject_type` as the explicit category of subject
- `acr` as the current verification level
- `amr` as the methods actually used to establish the current authentication state

`act` is intentionally not used in the OIDC-facing `id_token` in the RFC 8693 sense (delegation /
impersonation actor). The repository does not implement token-exchange delegation.

Separately, `AuthorizationTokenClaims.build`
(`app/controllers/concerns/authorization_token_claims.rb`) emits an `act` claim on the internal auth
access token whose value is the resource type (`client`/`operator`/`visitor`), not an RFC 8693
delegation actor. This reuses a claim name reserved by the RAR/token-exchange vocabulary below for a
private, non-standard purpose and is a known naming collision, not evidence of delegation support.
Any consumer of the auth access token must not interpret `act` as an RFC 8693 actor claim. This
claim is scheduled to be renamed to a non-colliding private name (see Open Questions in
`docs/architecture/preference.md` and the DB SSOT / JWT projection audit); until then, treat `act`
on the auth access token strictly as `resource_type`.

## RAR / Authorization Details Reservation

The repository does not implement Rich Authorization Requests (RAR, RFC 9396) or the
`authorization_details` parameter/claim in this phase.

To leave room for a future standards-aligned RAR implementation, Umaxica private claims, request
params, database columns, service names, and internal APIs must not use RAR-reserved or RAR-like
vocabulary for proprietary semantics. Treat these names as reserved for future standards work:

- `authorization_details`
- `authorization_detail`
- `authorization_data`
- `authz_details`
- `authz_detail`
- `details` when used as a generic authorization payload
- `locations`
- `actions`
- `datatypes`
- `privileges`
- `resources` when used in an RAR-like structure

Use explicit Umaxica or standard OAuth/OIDC names instead. Standard claims and parameters such as
`sid`, `jti`, `client_id`, `scope`, `aud`, `sub`, and `iss` may keep their standard names. Umaxica
private values should prefer names such as `region`, `surface`, `tenant_id`, `roles`,
`permission_version`, `policy_version`, `membership_id`, and `access_mode`. If a private claim could
plausibly collide with a current or future OAuth/OIDC extension, prefix it with `umx_`.

## `id_token` must claims

- `iss`
- `sub`
- `subject_type`
- `aud`
- `exp`
- `iat`
- `auth_time`
- `sid`
- `nonce`
- `acr`
- `amr`

## `id_token` should claims

- `jti`

## `subject_type`

Allowed values:

- `user`
- `staff`
- `customer`

## `acr`

Allowed product AAL boundaries are defined in `adr/authentication-assurance-level-boundaries.md`.
For the current OIDC token paths:

- post-login default is always `aal1`;
- even passkey login starts at `aal1`;
- `aal2` is granted only after explicit verification / step-up;
- refreshed access tokens downgrade to `aal1`;
- `aal3` is reserved and not currently emitted.

## `amr`

Allowed values:

- `email_otp`
- `passkey`
- `apple`
- `google`
- `passcode`
- `totp`

Rules:

- `amr` contains methods actually used
- `amr` does not contain the full set of methods available to the subject
- ordering should prefer primary sign-in method first, then later verification methods

Examples:

- `["email_otp"]`
- `["google"]`
- `["passkey"]`
- `["passcode"]`
- `["email_otp", "totp"]`
- `["google", "passkey"]`

## Difference from current implementation

At the time of writing, the repository already has partial foundations such as:

- `sid` in auth token claims
- refresh token rotation support
- verification/session state models

But the full OIDC claim contract above is not yet consistently implemented across all token paths.

Expected gaps include:

- no final `subject_type` claim rollout yet
- no final `nonce` contract consistently enforced across all OIDC callback/token paths yet
- `acr` / `amr` values not yet normalized to this memo everywhere
- `id_token`-specific behavior still needs to be aligned with these decisions

## Implementation follow-up

This memo should be treated as the design reference for the next implementation pass.

## Delivered reconciliation (2026-10-06)

The planned callback contract is now implemented for the current Base RP paths: validate the
authorization response and token response, validate issuer/client/audience/nonce/PKCE, call the
scope-filtered UserInfo endpoint with the returned access token, then resolve the canonical
Identity and RP session before setting cookies. Discovery advertises only accepted endpoints and
grants. The earlier “not yet consistently implemented” list is superseded for these paths; real
provider and deployment verification remain operational prerequisites.
