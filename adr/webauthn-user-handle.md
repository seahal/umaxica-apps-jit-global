# Replace Internal Primary Keys with Dedicated Opaque WebAuthn User Handles

## Status

Accepted (2026-07-19)

## Context

WebAuthn registration used an actor's internal bigint primary key (`resource.id.to_s.b`) as
`user.id`. Although this is specification-compliant when it is unique and stable within the RP, it
stores an enumerable internal identifier with the authenticator and passkey provider. A future
discoverable credential would send the value from the client as `userHandle`. The value is also
fragile across primary-key changes and account migrations. A breaking change is permitted because
this implementation has not been deployed.

## Decision

- Add a `webauthn_user_handle` to Client, Visitor, and Operator. Generate it with
  `SecureRandom.urlsafe_base64(32)` through the `WebauthnUserHandleOwner` concern and enforce NOT
  NULL and UNIQUE constraints.
- Use this handle as `user.id` in registration options built by `PasskeyCeremonyContext`.
- Keep the handle immutable after generation. Rotation would orphan existing credentials because the
  value is stored by the authenticator.
- Prohibit PII such as email addresses and internal primary keys as user handles, as documented in
  `docs/security/webauthn-security-invariants.md`.

## Consequences

- The handle satisfies WebAuthn's opaque byte-sequence requirement and removes exposure and
  enumeration of internal IDs. Each surface has an independent handle namespace.
- A future discoverable-credential or usernameless flow will not require another handle redesign.
- Verification: `test/models/webauthn_duplicate_registration_test.rb` covers opacity, uniqueness,
  and inequality with the primary key.
