# Store Passkey Authenticator Metadata for Display and Resolve Names from a Local AAGUID Catalog

## Status

Accepted (2026-07-19)

## Context

The only passkey display name was the user-provided `description`, whose default was "Passkey". This
did not reveal which provider or product issued a credential. webauthn-ruby 3.4.3 exposes the
AAGUID, transports, backup flags, and authenticator attachment from a registration response.
`Webauthn::AuthenticationContext` already calculated these values but did not persist them.

This application uses `attestation: "none"`, so an AAGUID is a self-asserted value. An AAGUID also
identifies a product line, not an individual authenticator. A full FIDO Metadata Service (MDS)
integration would require BLOB retrieval, JWS verification, trust anchors, caching, and failure-mode
operations whose cost is excessive for a display-only feature.

## Decision

- Add display-only columns to the passkey tables for all three surfaces: `aaguid`, `transports`,
  `backup_eligible`, `backup_state`, `authenticator_attachment`, `provider_name`, and
  `metadata_source`.
- Resolve names through the repository-local `config/webauthn/aaguid_catalog.yml` and the
  source-aware `Webauthn::AuthenticatorNameResolver` interface. A future MDS integration can be
  added as another source behind the same interface.
- Use display option D: initialize `description` with the provider name at registration, while
  allowing the user to change it freely. Keep `provider_name` in a separate column and never
  overwrite the user's label later. Unknown or zero AAGUID values use the default name and show
  "Unknown authenticator" on the detail page.
- Metadata supports display and inventory only. It must not affect authorization, duplicate
  detection, or security policy. A resolution failure must not fail registration.

## Consequences

- Major provider and product names can be displayed without external communication or additional
  dependencies. Coverage depends on catalog maintenance; see `docs/operations/passkey-runbook.md`.
- Names are not authenticated because attestation is not collected. This is an accepted tradeoff.
- Verification: `test/services/webauthn/authenticator_name_resolver_test.rb` and
  `test/services/webauthn/verifier_uv_policy_test.rb` for metadata extraction.
