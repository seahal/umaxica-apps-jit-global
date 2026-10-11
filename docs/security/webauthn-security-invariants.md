# WebAuthn Security Invariants

This document is the authority for the invariants mechanically checked by
`test/unit/security/webauthn_invariants_test.rb` and for duplicate-registration and User
Verification guarantees enforced by the data and ceremony layers. The prohibited patterns have
previously shipped as defects, so static tests reject their reintroduction.

## User Verification (UV)

- Resolve every ceremony's UV policy through the closed `Webauthn::UvPolicy` registry. Call sites
  must not directly specify `"required"`, `"preferred"`, or `"discouraged"` strings.
- Every current registry entry is `required`: `registration`, `direct_sign_in`, `emergency_sign_in`,
  `mfa_challenge`, `ordinary_step_up`, and `high_risk_step_up`. Purposes are separated so that only
  `ordinary_step_up` can be relaxed by a future explicit decision. Such a change must update this
  document and `adr/passkey-uv-policy.md`.
- Enforce UV on the server as well as in client options. In addition to
  `credential.verify(..., user_verification: true)`, verifiers explicitly recheck `user_verified?`
  and `user_present?` in `RegistrationVerifier` and `AssertionVerifier`.
- Never accept a response with UV=false for a purpose whose registry policy requires UV. Record
  achieved assurance separately from UV, freshness, phishing resistance, and step-up completion; UV
  alone does not imply AAL2.

## Ceremony Purposes Are Namespaces

- `Webauthn::ChallengeStore::PURPOSES` is closed, and a challenge issued for one purpose is rejected
  by every other verifier in both directions. Consumption deletes the entry before any binding is
  checked, so a rejected attempt still burns the challenge.
- Org Emergency Access uses `emergency_sign_in`, distinct from normal sign-in's `authentication` and
  from `step_up`. A new purpose must state what it may not be confused with; the exhaustive
  cross-purpose check lives in `test/unit/webauthn/challenge_store_test.rb`.
- Emergency Access must not grow a parallel verifier, challenge store, or credential store. It is a
  different authentication policy running the same cryptographic implementation
  (`docs/security/org-emergency-access.md`).

## Duplicate Registration by Credential ID

- Store the Base64URL credential ID in `webauthn_id`. Each surface table (`client_passkeys`,
  `visitor_passkeys`, and `operator_passkeys`) has a UNIQUE index independent of owner. Within one
  surface, the same credential cannot be registered twice to either the same or a different account.
- Defense has three layers: model validation with `uniqueness: true`; a database UNIQUE index that
  maps a racing `RecordNotUnique` to HTTP 409; and registration `excludeCredentials` containing
  **every credential, including revoked and disabled entries**, so the browser raises
  `InvalidStateError`.
- Continue rejecting the credential ID of a revoked or disabled row until that row is purged. No
  reactivation flow is provided.
- An AAGUID identifies an authenticator product line, not an instance. **Never use an AAGUID,
  provider name, or product name for duplicate detection.** Multiple credentials with one AAGUID are
  valid, including two physical keys of the same product or multiple passkeys from one provider.
- WebAuthn cannot reliably determine whether one physical authenticator generated a new credential
  ID, especially with `attestation: "none"`. This is an accepted protocol limitation.
- RP IDs differ across app/com/org, so one authenticator creates separate credentials for each
  surface. Cross-surface credential sharing and duplication do not occur within this architecture;
  see `docs/security/webauthn-rp-id-origin-boundary.md`.

## User Handle

- WebAuthn `user.id` uses the actor's `webauthn_user_handle`, generated with
  `SecureRandom.urlsafe_base64(32)`, constrained UNIQUE, and immutable after creation.
- Never use an internal bigint primary key or PII such as an email address as a user handle. The
  former implementation exposed the primary key.
- The authenticator stores this handle. Rotating it would orphan existing credentials, so changing
  it is prohibited.

## Authenticator Metadata (Display Only)

- `aaguid`, `transports`, `backup_eligible`, `backup_state`, `authenticator_attachment`,
  `provider_name`, and `metadata_source` support display and inventory only. With
  `attestation: "none"`, these are self-asserted values and must not affect authorization, duplicate
  detection, or security policy.
- Keep the catalog-resolved `provider_name` separate from the user-provided `description`. Metadata
  must never overwrite the user's label.
- A zero or unknown AAGUID and any name-resolution failure must not fail registration.

## RP Configuration

- RP ID and origin come only from an explicit surface declaration such as `webauthn_surface :app`
  and the matching `WEBAUTHN_<APP|COM|ORG>_*` configuration. Prohibit `request.host` fallback,
  shared environment keys, class-name regex surface inference, and mutation of global
  `WebAuthn.configure` state.
- `from_get` and `from_create` always receive an explicit `relying_party:` argument.
- Origin comparison requires an exact scheme, host, and effective port match.
