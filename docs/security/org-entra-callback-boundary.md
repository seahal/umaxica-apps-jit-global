# Org Entra Callback Boundary

> Current implementation (2026-10-03): this document describes the hand-written ceremony that
> `adr/org-entra-omniauth-strategy-migration.md` replaced.
> `ExternalAuthenticationOrgEntraCeremonyStore` and the `Auth::Org::Sign::In::Entra::*` controllers
> no longer exist. State, nonce, and PKCE are now verified by the OmniAuth strategy in
> `lib/omniauth/strategies/umaxica_entra.rb`, and the callback is handled by
> `Auth::Org::Omniauth::OmniauthCallbacksController`. The sections below are kept as the record of
> the earlier boundary; the class names and line numbers in them do not match current code.

## Boundary

The org Entra ID sign-in ceremony (`Auth::Org::Sign::In::Entra::AuthorizationsController` and
`Auth::Org::Sign::In::Entra::CallbacksController`) verifies state, nonce, and PKCE at the ceremony
store and provider-adapter boundary before any session is established. See
`adr/org-entra-id-sign-in-boundary.md` for the identity-key and no-provisioning decisions this
boundary supports.

## Ceremony state (server-side, opaque reference)

`ExternalAuthenticationOrgEntraCeremonyStore`
(`app/services/external_authentication_org_entra_ceremony_store.rb`) holds `state`, `nonce`,
`code_verifier`, and the target connection server-side, keyed by a `SecureRandom.urlsafe_base64(32)`
reference. Only that opaque reference is written to the operator's session
(`ExternalAuthenticationEndpoint#store_external_authentication_ceremony_reference`). The actual
`state`, `nonce`, and PKCE verifier never round-trip through client-controlled state.

- `#issue!` (lines 15-35) also registers the `state` value with `OperatorOauthCallbackState.issue!`,
  a single-use, DB-backed record keyed by a SHA-256 digest of the state.
- `#consume!` (lines 37-62) reads and immediately deletes the cache entry (line 38-39, deleted
  unconditionally regardless of outcome), then requires `OperatorOauthCallbackState.consume!` to
  succeed (single-use, DB-locked) **and** a constant-time comparison
  (`ActiveSupport::SecurityUtils.secure_compare`, lines 72-76) between the stored state and the
  callback's `state` parameter. A missing reference, a replayed state, or a state mismatch all
  return `nil`, which `CallbacksController#show` maps to `render_entra_error(:state_mismatch)`.

## Nonce verification

The nonce is generated with `SecureRandom.urlsafe_base64(32)`
(`app/controllers/auth/org/sign/in/entra/authorizations_controller.rb:46`), stored in the ceremony
above, and passed to `ExternalAuthentication::EntraProviderAdapter#call` on callback. Verification
happens unconditionally inside `ExternalSignIn::Providers::EntraId#call`
(`app/lib/external_sign_in/providers/entra_id.rb:44-56`):

- `fail!("missing_nonce")` if the expected nonce is blank, before the token is even decoded
  (line 46) -- absence of a nonce fails closed, it is never treated as "nonce check not applicable."
- `verify_nonce!` (lines 93-96) compares the ID token's `nonce` claim against the expected nonce
  with the same constant-time `secure_equal?` helper (lines 139-145).

There is no branch that skips nonce verification.

## PKCE

`code_verifier` is generated with `SecureRandom.urlsafe_base64(96)`
(`authorizations_controller.rb:47`) and S256-challenged via
`ExternalAuthentication::EntraProviderAdapter.pkce_s256_challenge`
(`app/adapters/external_authentication/entra_provider_adapter.rb:97-100`), sent as `code_challenge`
/ `code_challenge_method: "S256"` on the authorize request. On callback, the same `code_verifier` is
read back from the ceremony store and threaded through `EntraProviderAdapter#call` (line 52) into
`OidcRpTokenClient`'s token-exchange POST body (`app/services/oidc_rp_token_client.rb`), so the
authorization code cannot be redeemed by a party that did not originate the request.

## ID token verification (issuer, audience, algorithm, tenant, time)

`ExternalSignIn::Providers::EntraId#call` also enforces, in order: `RS256`-only signature
verification against the tenant JWKS (`ExternalSignIn::EntraJwksCache`), issuer and audience pinned
to the connection's tenant and client id (`decode_token`, lines 76-91), rejection of the Microsoft
personal-account consumer tenant (line 48), `tid`/`oid` presence and UUID-format validation (lines
98-108), `sub` presence (lines 110-112), and expiry/issued-at/not-before time-claim checks (lines
114-123, `MAX_TOKEN_AGE` 10 minutes, `CLOCK_SKEW` 60 seconds). JWKS fetch or parse failures are
normalized to `ExternalSignIn::EntraJwksCache::FetchError` and mapped to the `jwks_fetch_failed`
verification reason.

## Failure taxonomy

Every failure path renders the shared error template with an explicit reason (`render_entra_error`,
`app/controllers/auth/org/omniauth/omniauth_callbacks_controller.rb`). No failure falls through to a
generic success response.

| Reason                         | Trigger                                                                                                                                                                            |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `state_mismatch`               | Ceremony reference missing, expired, replayed, or state comparison fails                                                                                                           |
| `provider_unavailable`         | `ENTRA_SOCIAL_CEREMONY_ENABLED` kill switch disabled for this operation                                                                                                            |
| `entra_error`                  | Entra returned an `error` callback parameter                                                                                                                                       |
| `connection_not_found`         | `connection_public_id` does not resolve to an active `OrganizationEntraConnection`                                                                                                 |
| `tenant_not_allowed`           | ID token issued by the Microsoft personal-account consumer tenant                                                                                                                  |
| `tenant_mismatch`              | ID token `tid` does not match the connection's configured tenant                                                                                                                   |
| `token_exchange_failed`        | Authorization-code-for-token exchange with Entra failed                                                                                                                            |
| `invalid_callback`             | Malformed callback input (`KeyError`/`ArgumentError`/`TypeError`)                                                                                                                  |
| `token_verification_failed`    | Any other ID token verification failure (nonce, signature, claims, JWKS fetch)                                                                                                     |
| `identity_not_found`           | No pre-provisioned, active `OperatorEntraIdentity` for the verified `(tid, oid)` pair                                                                                              |
| `operator_not_found`           | Resolved operator is nil or not allowed to log in                                                                                                                                  |
| `authentication_method_locked` | Operator has an in-force `unusable`/`permanently_frozen` effect on the `entra` method (checked after `login_allowed?`, before session establishment; `adr/unified-enforcement.md`) |
| `sign_in_failed`               | Session establishment failed after a successful identity resolution                                                                                                                |

## Related

- `adr/org-entra-id-sign-in-boundary.md`
- `docs/security/social-login-provider-scope.md`
- `docs/security/social-callback-boundary.md` (app-surface Google/Apple equivalent)
- `docs/operations/entra-org-login-runbook.md`
