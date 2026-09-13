# External Authentication Phase 2 Value and Registry Notes

## Context

- Original plan: `plans/apple-google-external-authentication-architecture-audit.md`
- Prior implementation note: `notes/implementation/2026-07-24-external-authentication-phase-1.md`
- Implementation date: 2026-07-24

## Implemented Contracts

- `ExternalAuthentication::VerifiedPrincipal`
  - Contains only provider, subject, canonical issuer, canonical audience, verified time, and
    verification authority.
  - Rejects unsupported providers, missing identity coordinates, invalid verification time, and
    assertion/token fields.

- `ExternalAuthentication::Failure`
  - Uses allowlisted codes and safe reason symbols.
  - Rejects arbitrary provider response text and non-boolean retry classification.

- `ExternalAuthentication::CallbackResult`
  - Has only verified and failed states.
  - A verified result requires `VerifiedPrincipal`; a failed result requires typed `Failure`.
  - Provider credential candidates remain provider-specific and are not interpreted by this value.

- `ExternalAuthentication::AvailabilityDecision`
  - Supports enabled, disabled, draining, and incident-stop states with normalized source metadata.

- `ExternalAuthentication::ProviderAvailabilityPort`
  - Separates start and callback decisions.

- `ExternalAuthentication::EnvironmentProviderAvailabilityAdapter`
  - Strictly requires both provider settings and accepts only literal `true` or `false`.
  - Stops new ceremonies while allowing already-issued callbacks to drain.
  - Does not control notification, revocation, or unlink follow-up consumers.

- `ExternalAuthentication::ProviderRegistry`
  - Contains a fixed Apple/Google allowlist, canonical issuers, credential references, paths,
    adapter identifiers, and per-operation authorization policy.
  - Contains no availability value and reads no environment variables.
  - Google policy is online-only with `openid profile`; Apple policy requests an empty scope.

## Sequencing Decision

Per-Use-Case Results will be introduced with the corresponding Login, Signup, Link, and Unlink Use
Case slices. Defining their payloads before the repository ports and Use Cases exist would either
leak current Active Record models into the new contract or introduce an untyped generic payload. The
approved status sets remain fixed by the audit; this sequencing does not change them.

## Verification

- Focused Minitest coverage for every value, registry entry, and environment-adapter branch
- Targeted RuboCop
- Zeitwerk eager-load check
- External-authentication contract and regression-guard test set
