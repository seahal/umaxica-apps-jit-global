# WebAuthn Architecture

This document summarizes the passkey and WebAuthn ceremony architecture. The authoritative
invariants are in `docs/security/webauthn-security-invariants.md`; RP boundaries are in
`docs/security/webauthn-rp-id-origin-boundary.md`.

## Components

| Layer                      | Implementation                                                                                                                                    |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Surface enum               | `app/values/webauthn/surface.rb`, a closed registry for app/com/org                                                                               |
| RP configuration           | `app/values/webauthn/relying_party_config.rb` and `app/resolvers/webauthn/relying_party_config_resolver.rb`                                       |
| UV policy                  | `app/values/webauthn/uv_policy.rb`, a purpose-specific closed registry currently requiring UV for every purpose                                   |
| Verifiers                  | `app/services/webauthn/registration_verifier.rb` and `assertion_verifier.rb`                                                                      |
| Ceremony result            | `app/values/webauthn/authentication_context.rb`, containing user verification, backup flags, AAGUID, transports, and attachment                   |
| Metadata                   | `app/values/webauthn/authenticator_metadata.rb`, `app/services/webauthn/authenticator_name_resolver.rb`, and `config/webauthn/aaguid_catalog.yml` |
| Challenge                  | `app/services/webauthn/challenge_store.rb`, with a ten-minute TTL, purpose/surface/RP/origin/actor binding, and one-time consumption              |
| Authentication context     | `app/values/authentication_context_value.rb`, the closed normal/emergency registry behind Restricted Mode                                        |
| Cross-boundary ceremony    | `*PasskeyCeremonyTransaction` tickets plus grant/result JWTs in `IdentityPasskeyCeremony*`                                                        |
| Shared controller concerns | `PasskeyCeremonyContext`, `PasskeyRegistrationFlow`, `PasskeySignInFlow`, and `SignVerificationPasskeyChecks`                                     |

## Ceremonies Across All Surfaces

| Operation                            | Challenge purpose | UV policy purpose           | Allow/exclude set                        | Persistence                          |
| ------------------------------------ | ----------------- | --------------------------- | ---------------------------------------- | ------------------------------------ |
| Sign-up registration (`app` only)    | registration      | registration (required)     | Exclude every passkey, including revoked | New row and metadata                 |
| Settings registration (all surfaces) | registration      | registration (required)     | Exclude every passkey                    | New row, metadata, and app/org audit |
| Direct sign-in (all surfaces)        | authentication    | direct_sign_in (required)   | ACTIVE only                              | `sign_count`, `last_used_at`         |
| Emergency Access sign-in (`org` only) | emergency_sign_in | emergency_sign_in (required) | ACTIVE only                             | `sign_count`, `last_used_at`         |
| MFA challenge (all surfaces)         | authentication    | mfa_challenge (required)    | ACTIVE only                              | `sign_count`, `last_used_at`         |
| Step-up (all surfaces)               | step_up           | ordinary_step_up (required) | ACTIVE only                              | `sign_count`                         |

- Registration uses `resident_key: "discouraged"` and `attestation: "none"` for an identifier-first,
  non-discoverable flow.
- `user.id` is the actor's opaque, immutable `webauthn_user_handle`.
- The display name is `passkey_resource_display_name`, derived from email or `public_id`.

## Naming and Metadata Flow (Option D)

1. Successful registration verification returns AAGUID, transports, backup flags, and attachment in
   `AuthenticationContext`.
2. `Webauthn::AuthenticatorNameResolver.resolve(aaguid)` resolves a friendly name from the local
   catalog. Unknown and zero AAGUID values return nil without failing the ceremony.
3. The initial `description` precedence is user input, provider name, then the i18n default.
   `provider_name` and `metadata_source` are stored separately and never overwrite the user's label.
4. Lists display `description`; the detail page displays the provider name or "Unknown
   authenticator".
5. The source-aware resolver interface can add a FIDO MDS backend later without a schema change.

## Emergency Access

The org surface has a second sign-in ceremony, Emergency Access, which reuses the operator's
existing passkeys under its own challenge purpose and produces a restricted session. It shares this
entire implementation; only the ceremony purpose, the actor source, the eligibility decision, and
the resulting authentication context differ. Duplicating any of the mechanics above into an
Emergency-specific verifier is prohibited. See `docs/security/org-emergency-access.md`.

## Password Fallback

When passkey sign-in or UV fails, return to the existing identifier-first sign-in screen and its
password-plus-MFA path. Do not mix a password exchange into a WebAuthn ceremony; the password path
retains its own audit and rate limits.
