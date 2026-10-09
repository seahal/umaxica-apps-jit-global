# JWT/JWKS Responsibility Refactor Implementation Notes

## Context

- Original plan/spec: JWT / JWS / JWKS responsibility refactor with behavior-preserving
  characterization tests before broader rewrites.
- Related docs/plans:
  - `docs/operations/jwt-key-rotation.md`
  - `docs/operations/jump-rt-key-rotation.md`
  - `plans/backlog/jwt-jwks-security-review-followups.md`
- Implementation date: 2026-05-31

## Decisions Made During Implementation

- Decision: token-family TTL and old-kid verification windows live in `Security::TokenLifetimes`,
  not under `Jit::Security::Jwt`.
  - Why: `Jit::Security::Jwt` must remain a low-level JWT/JWS/JWK/JWKS primitive namespace and must
    not know about Auth, Preference, OIDC, or JumpRT token families.
  - Follow-up needed: migrate the remaining key family and registry configuration work to use the
    same application-policy boundary.

- Decision: preserve the deployed behavior of Preference JWT TTL as seven days.
  - Why: the refactor goal is behavior preservation; shortening Preference JWT TTL to one day would
    be a separate security behavior change.
  - Follow-up needed: if a one-day Preference JWT TTL is desired, schedule it as an explicit
    post-refactor change with user-facing and operations impact review.

## Deviations From Plan

- Change: only the first safe slice was implemented.
  - Why: the full family-registry rewrite is a broad, breaking change touching Auth, Preference,
    OIDC, JumpRT, JWKS controllers, initializer wiring, docs, and production boot validation.
  - Risk: the current code still has the pre-existing responsibility issues called out in the plan.
  - Follow-up: continue with pure primitive extraction and key-source/registry wiring in separate
    reviewable slices.

## Review Notes

- Tests run:
  - `bin/rails test test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/services/oidc/jwks_service_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/registry_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/services/preference_token_test.rb test/models/preference_token_test.rb test/models/preference_jwt_test.rb test/controllers/concerns/preference/jwt_and_color_theme_test.rb`
  - `bin/rails test test/services/preference_token_test.rb test/models/preference_token_test.rb test/models/preference_jwt_test.rb test/controllers/concerns/preference/jwt_and_color_theme_test.rb test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/controllers/concerns/authentication/token_service_test.rb test/controllers/concerns/auth/base_token_test.rb test/controllers/concerns/auth/base_test.rb`
  - `bin/rails test test/controllers/concerns/authentication/token_service_test.rb test/controllers/concerns/auth/base_token_test.rb test/controllers/concerns/auth/base_test.rb test/services/oidc/access_token_authenticator_dpop_test.rb test/services/oidc/token_exchange_service_test.rb test/controllers/concerns/authorization/token_claims_test.rb`
  - `bin/rails test test/controllers/concerns/authentication/token_service_test.rb test/controllers/concerns/auth/base_token_test.rb test/controllers/concerns/auth/base_test.rb test/controllers/concerns/authorization/token_claims_test.rb test/services/oidc/access_token_authenticator_dpop_test.rb test/services/oidc/token_exchange_service_test.rb test/services/preference_token_test.rb test/models/preference_token_test.rb test/models/preference_jwt_test.rb test/controllers/concerns/preference/jwt_and_color_theme_test.rb test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/services/oidc/id_token_verifier_test.rb test/services/oidc/token_exchange_service_test.rb test/services/security/token_lifetimes_test.rb`
  - `bin/rails test test/controllers/concerns/authentication/token_service_test.rb test/controllers/concerns/auth/base_token_test.rb test/controllers/concerns/auth/base_test.rb test/controllers/concerns/authorization/token_claims_test.rb test/services/oidc/access_token_authenticator_dpop_test.rb test/services/oidc/token_exchange_service_test.rb test/services/oidc/id_token_verifier_test.rb test/services/preference_token_test.rb test/models/preference_token_test.rb test/models/preference_jwt_test.rb test/controllers/concerns/preference/jwt_and_color_theme_test.rb test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/controllers/concerns/authentication/token_service_test.rb test/controllers/concerns/auth/base_token_test.rb test/controllers/concerns/auth/base_test.rb test/controllers/concerns/authorization/token_claims_test.rb test/services/oidc/access_token_authenticator_dpop_test.rb test/services/oidc/token_exchange_service_test.rb test/services/oidc/id_token_verifier_test.rb test/services/preference_token_test.rb test/models/preference_token_test.rb test/models/preference_jwt_test.rb test/controllers/concerns/preference/jwt_and_color_theme_test.rb test/unit/jit/security/jwt/key_source_test.rb test/unit/jit/security/jwt/issuer_builder_test.rb test/unit/jit/security/jwt/issuer_record_test.rb test/unit/jit/security/jwt/key_material_test.rb test/unit/jit/security/jwt/jwk_test.rb test/unit/jit/security/jwt/jwks_test.rb test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/issuer_test.rb test/services/jump_rt/return_verifier_test.rb`
  - `bin/rails test test/unit/jit/security/jwt/registry_test.rb test/unit/jit/security/jwt/keyring_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb test/services/security/token_lifetimes_test.rb`
  - `bin/rails test test/controllers/concerns/auth/cookie_helpers_test.rb test/services/jump_rt/issuer_test.rb`
  - `bin/rails test test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb test/services/jump_rt/return_verifier_test.rb`
  - syntax checks for the touched Ruby files
- Tests not run:
  - Full `bin/rails test`.
  - A mixed fixture-heavy run hit a PostgreSQL fixture cleanup deadlock/foreign-key error unrelated
    to the new assertions.
- Documentation or ADR promotion needed:
  - Once the family registry rewrite is implemented, update the JWT and JumpRT key-rotation runbooks
    with the final four-family key structure and ENV names.

## Slice 2 Primitive Extraction

- Added `Jit::Security::Jwt::Jwk` for low-level public JWK normalization, validation, public export,
  and public-key import.
- Added `Jit::Security::Jwt::Jwks` for parsing public JWKS collections from either JWK Set objects
  or arrays.
- Kept existing `Registry` and `JwksService` public APIs intact.
- Preserved the existing `JwksService.normalized_public_jwk` behavior that accepts structurally
  valid public JWK hashes even when tests use placeholder coordinate values.

## Slice 3 Key Material Extraction

- Added `Jit::Security::Jwt::KeyMaterial` for low-level private key decoding and private keyset
  parsing.
- Kept `Registry` as the compatibility facade for current callers while delegating private key
  parsing to `KeyMaterial`.
- Updated local dev/test keyset generation so the stored `public_keyset` values are produced via
  `Jwk.export_public` and do not contain private JWK fields.

## Slice 4 Issuer Record Extraction

- Added `Jit::Security::Jwt::IssuerRecord` and `KeyRecord` as low-level immutable record types.
- Moved active/grace verification and JWKS publication state filtering out of `Registry`.
- Kept `Registry` as the registry/settings facade used by existing callers.

## Slice 5 Issuer Builder Extraction

- Added `Jit::Security::Jwt::IssuerBuilder` for keyset and surface issuer construction.
- Moved private/public key merging and surface active-public mismatch detection out of `Registry`.
- Kept ENV/credentials lookup in `Registry` for this slice; provider/source separation remains a
  follow-up step.

## Slice 6 Key Source Extraction

- Added `Jit::Security::Jwt::KeySource` as the single read boundary for ENV and Rails credentials.
- Preserved existing precedence: ENV value first, credentials fallback when ENV is blank.
- Moved CSV parsing for JWT registry inputs into `KeySource`.
- Kept issuer wiring and boot validation behavior unchanged.

## Slice 7 Registry Cleanup And Active JWKS Validation

- Removed unused `Registry` helper methods and require statements after extraction to `KeySource`,
  `IssuerBuilder`, `KeyMaterial`, `Jwk`, and `Jwks`.
- Kept `Registry.export_public_jwk` as a compatibility helper used by existing tests.
- Added registry validation that fails fast when the active signing key is not present in the
  generated JWKS document.

## Slice 8 Universal Registry Invariant Validation

- Avoided production-only validation branches.
- Added environment-independent validation that non-empty issuer records must have issuer and
  audience configuration.
- Preserved existing Auth audience behavior by using the current default `umaxica-api` when
  `AUTH_JWT_AUDIENCES` is blank.
- Kept empty optional surface records valid so unconfigured surface keysets do not fail boot.

## Slice 9 Preference Token Codec

- Added `Security::Jwt::PreferenceTokenCodec` for preference JWT encode/decode behavior.
- Kept `Preference::Token` as the backward-compatible facade used by controllers and tests.
- Preserved existing public constants, encode/decode signatures, extraction helpers, anomaly
  reasons, header validation, host/audience validation, and logging behavior.

## Slice 10 Auth Access Token Codec

- Added `Security::Jwt::AuthAccessTokenCodec` for Auth access JWT encode/decode behavior.
- Kept `Authentication::TokenService` as the backward-compatible facade used by controllers and OIDC
  services.
- Preserved existing constants, encode/decode signatures, allow-expired decode path, claim
  extraction helpers, surface issuer inference, anomaly reasons, and logging behavior.

## Slice 11 OIDC ID Token Codec

- Added `Security::Jwt::OidcIdTokenCodec` for OIDC ID Token payload construction, signing, and
  verification.
- Kept `Oidc::IdTokenIssuer` and `Oidc::IdTokenVerifier` as existing service entry points.
- Preserved issuer/audience/nonce/actor/typ validation, token TTL, and signing key namespace
  resolution behavior.

## Slice 12 JumpRT Token Codec

- Added `Security::Jwt::JumpRtTokenCodec` for JumpRT JWT signing, issue payload construction, header
  validation, return token decode options, and public JWK normalization.
- Kept `JumpRt::Issuer` and `JumpRt::ReturnVerifier` as existing service entry points.
- Left URL normalization, JWKS fetch/cache behavior, return policy checks, and replay cache logic in
  the JumpRT services.
