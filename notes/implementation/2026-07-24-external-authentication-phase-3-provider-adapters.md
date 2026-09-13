# External Authentication Phase 3 Provider Adapter Notes

## Context

- Original plan: `plans/apple-google-external-authentication-architecture-audit.md`
- Phase 1 contract evidence: `notes/implementation/2026-07-24-external-authentication-phase-1.md`
- Phase 2 contracts: `notes/implementation/2026-07-24-external-authentication-phase-2-values.md`
- Implementation date: 2026-07-24

## Implemented Contracts

- `ExternalAuthentication::AppleProviderAdapter`
  - Accepts only `OmniAuth::AuthHash` produced at the infrastructure boundary.
  - Requires the exact Apple provider, top-level UID, and refresh token.
  - Ignores profile data and nested/raw subject claims.
  - Produces the canonical Apple issuer, injected configured audience, pinned verification
    authority, and an Apple-only credential candidate.

- `ExternalAuthentication::GoogleProviderAdapter`
  - Accepts only `OmniAuth::AuthHash` produced at the infrastructure boundary.
  - Requires the exact Google provider and UserInfo-backed top-level UID.
  - Ignores profile data, callback tokens, and nested/raw subject claims.
  - Produces no durable credential candidate.

- `ExternalAuthentication::AppleCredentialCandidate`
  - Contains only the callback refresh token.
  - Redacts `inspect` and `to_s`.
  - Rejects generic JSON serialization so it cannot silently enter session, candidate JSON, audit,
    or log payloads.

- `ExternalAuthentication::ProviderAdapterFactory`
  - Resolves the fixed registry adapter key through exhaustive branches.
  - Uses no `constantize`, provider-controlled class name, or runtime class lookup.

## Security Boundaries

- Provider mismatch, invalid boundary type, missing UID, and missing Apple refresh token become
  typed callback failures with allowlisted safe reasons.
- The adapters do not read `extra.id_info`, `extra.raw_info`, email, name, image, ID token, or
  access token.
- The Apple Adapter does not repeat nonce, signature, issuer, audience, or time verification. Those
  remain owned by the pinned strategy and its contract gate.
- The Google Adapter relies on the Phase 1 proof that the installed strategy derives top-level UID
  from UserInfo and not unsigned ID-token metadata.

## Typed Callback Boundary

The app callback invokes the provider adapter before application processing. Login and link
handlers, signup finalizer, ceremony result issuer, and final committer accept only
`VerifiedPrincipal` plus the provider-specific credential candidate.

The encrypted `identity_social_ceremony_candidates.auth_hash` column remains until the planned
schema migration, but it no longer stores or reconstructs `OmniAuth::AuthHash`. Its payload is
restricted to the minimal verified principal fields and, for Apple only, the refresh token needed to
complete the one-shot ceremony. Access tokens, ID tokens, provider claims, profile fields, and email
are not copied into the candidate.

`ClientAppleIdentity.refresh_token` now uses nondeterministic Active Record Encryption. Legacy token
columns receive the non-secret `[NOT_STORED]` sentinel because the current schema still requires a
token value. Google callback credentials are not retained.

## Legacy Identity Repository Boundary

`ExternalIdentityRepositoryPort` and `LegacyIdentityRepositoryAdapter` wrap the existing
`ClientAppleIdentity` and `ClientGoogleIdentity` tables without schema changes. The explicit factory
maps only Apple and Google; provider input cannot select an arbitrary Active Record class.

The coordinator and login, link, signup, and unlink paths now use this repository boundary for
subject lookup, user binding, credential refresh, activation, and deletion. The application workflow
no longer chooses provider-specific identity models or associations.

## Application Use Case Progress

`LoginUseCase`, `LinkUseCase`, `SignupUseCase`, and `UnlinkUseCase` own their operation-specific
repository selection and database transaction boundaries. They return typed operation results.
`UnlinkUseCase` also owns the last-authentication-method check and Chronicle audit write.

The callback controller boundary uses `CallbackOutcome` to carry only the fields required by Rails
response handling. The former coordinator and its Hash result translation have been removed.
Controllers, ceremony finalization, and unlink endpoints invoke the operation-specific use cases
directly; provider payloads and Active Record model selection do not cross into those use cases.

## Verification

- Focused tests for both adapters, credential redaction, invalid boundary inputs, nested-claim
  rejection, and explicit factory resolution
- Operation-specific use-case, callback outcome, controller concern, ceremony, and unlink regression
  tests
- Targeted RuboCop
- No external provider calls
